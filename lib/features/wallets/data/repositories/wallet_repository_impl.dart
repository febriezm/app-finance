import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/wallets_dao.dart';
import '../../../../core/database/daos/transactions_dao.dart';
import '../../../../core/services/supabase_service.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../datasources/wallet_remote_data_source.dart';
import '../models/wallet_model.dart';

/// Implementasi WalletRepository dengan pola Offline-First:
/// - Reaktivitas instan (0 ms) didorong oleh SQLite lokal (Drift)
/// - Sinkronisasi aman & konsisten ke Supabase Cloud PostgreSQL
/// - Proteksi rekursi (_isSyncing) mencegah feedback loop HTTP query
class WalletRepositoryImpl implements WalletRepository {
  final WalletsDao _walletsDao;
  final TransactionsDao _transactionsDao;
  final WalletRemoteDataSource? _remoteDataSource;
  final SupabaseService? _supabaseService;

  final StreamController<void> _cloudSyncEventController =
      StreamController<void>.broadcast();

  WalletRepositoryImpl(
    this._walletsDao,
    this._transactionsDao, {
    WalletRemoteDataSource? remoteDataSource,
    SupabaseService? supabaseService,
  })  : _remoteDataSource = remoteDataSource,
        _supabaseService = supabaseService;

  bool get isCloudActive {
    final svc = _supabaseService;
    return svc != null && svc.isAuthenticated && _remoteDataSource != null;
  }

  String? get currentUserId => _supabaseService?.currentUser?.id;

  @override
  Future<List<Wallet>> getActiveWallets() async {
    if (isCloudActive) {
      try {
        final cloudWallets =
            await _remoteDataSource!.getActiveWallets(currentUserId!);
        for (final w in cloudWallets) {
          await _syncWalletToLocalCache(w);
        }
        return cloudWallets;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[WalletRepositoryImpl] Cloud fetch warning, fallback ke cache lokal: $e');
        }
        // Fallback ke cache lokal jika jaringan bermasalah
        final entries = await _walletsDao.getActiveWallets();
        if (entries.isNotEmpty) {
          return entries.map(WalletModel.fromEntry).toList();
        }
        rethrow;
      }
    }

    final entries = await _walletsDao.getActiveWallets();
    return entries.map(WalletModel.fromEntry).toList();
  }

  @override
  Stream<List<Wallet>> watchActiveWallets() {
    if (isCloudActive) {
      late StreamController<List<Wallet>> controller;
      StreamSubscription? subLocal;
      StreamSubscription? subSync;

      void emitFromCache() async {
        try {
          final entries = await _walletsDao.getActiveWallets();
          final localData = entries.map(WalletModel.fromEntry).toList();
          if (!controller.isClosed) {
            controller.add(localData);
          }
        } catch (_) {}
      }

      bool isFetching = false;
      void syncAndRefresh() async {
        if (isFetching) return;
        isFetching = true;
        try {
          final cloudWallets =
              await _remoteDataSource!.getActiveWallets(currentUserId!);
          for (final w in cloudWallets) {
            await _syncWalletToLocalCache(w);
          }
          if (!controller.isClosed) {
            controller.add(cloudWallets);
          }
        } catch (e) {
          emitFromCache();
        } finally {
          isFetching = false;
        }
      }

      controller = StreamController<List<Wallet>>(
        onListen: () {
          // 1. Emit langsung dari SQLite lokal (0 ms)
          emitFromCache();

          // 2. Sinkronkan dengan cloud di latar belakang
          syncAndRefresh();

          // 3. Dengarkan mutasi lokal & sync event tanpa rekursi
          subLocal = _walletsDao.watchActiveWallets().listen((_) => emitFromCache());
          subSync = _cloudSyncEventController.stream.listen((_) => syncAndRefresh());
        },
        onCancel: () {
          subLocal?.cancel();
          subSync?.cancel();
          controller.close();
        },
      );

      return controller.stream;
    }

    return _walletsDao.watchActiveWallets().map(
          (entries) => entries.map(WalletModel.fromEntry).toList(),
        );
  }

  @override
  Future<int> calculateWalletBalance(String walletId) async {
    // Ambil saldo awal (dari cache lokal yang instan atau cloud jika belum ada)
    int openingBalance = 0;
    final localEntry = await _walletsDao.getWalletById(walletId);
    if (localEntry != null) {
      openingBalance = localEntry.openingBalance;
    } else {
      final cloudWallet = await getWalletById(walletId);
      if (cloudWallet == null) return 0;
      openingBalance = cloudWallet.openingBalance;
    }

    if (isCloudActive) {
      return await _remoteDataSource!.calculateWalletBalance(
        walletId,
        openingBalance,
        currentUserId!,
      );
    }

    int balance = openingBalance;
    final ledger = await _transactionsDao.getConfirmedLedgerForWallet(walletId);

    for (final tx in ledger) {
      if (tx.status != 'confirmed') continue;

      if (tx.type == 'income' && tx.walletId == walletId) {
        balance += tx.amount;
      } else if (tx.type == 'expense' && tx.walletId == walletId) {
        balance -= tx.amount;
      } else if (tx.type == 'transfer') {
        if (tx.destinationWalletId == walletId) {
          balance += tx.amount;
        }
        if (tx.walletId == walletId) {
          balance -= tx.amount;
        }
      }
    }

    return balance;
  }

  @override
  Future<List<WalletWithBalance>> getActiveWalletsWithBalance() async {
    final wallets = await getActiveWallets();
    final result = <WalletWithBalance>[];

    for (final wallet in wallets) {
      final balance = await calculateWalletBalance(wallet.id);
      result.add(WalletWithBalance(wallet: wallet, currentBalance: balance));
    }

    return result;
  }

  @override
  Stream<List<WalletWithBalance>> watchActiveWalletsWithBalance() {
    late StreamController<List<WalletWithBalance>> controller;
    StreamSubscription? subWallets;
    StreamSubscription? subTransactions;
    StreamSubscription? subSync;

    void emitFromLocal() async {
      try {
        final entries = await _walletsDao.getActiveWallets();
        final wallets = entries.map(WalletModel.fromEntry).toList();
        final list = <WalletWithBalance>[];

        for (final w in wallets) {
          int balance = w.openingBalance;
          final ledger = await _transactionsDao.getConfirmedLedgerForWallet(w.id);
          for (final tx in ledger) {
            if (tx.status != 'confirmed') continue;
            if (tx.type == 'income' && tx.walletId == w.id) {
              balance += tx.amount;
            } else if (tx.type == 'expense' && tx.walletId == w.id) {
              balance -= tx.amount;
            } else if (tx.type == 'transfer') {
              if (tx.destinationWalletId == w.id) balance += tx.amount;
              if (tx.walletId == w.id) balance -= tx.amount;
            }
          }
          list.add(WalletWithBalance(wallet: w, currentBalance: balance));
        }

        if (!controller.isClosed) {
          controller.add(list);
        }
      } catch (_) {}
    }

    bool isFetching = false;
    void syncAndRefresh() async {
      if (isFetching) return;
      isFetching = true;
      try {
        final data = await getActiveWalletsWithBalance();
        if (!controller.isClosed) {
          controller.add(data);
        }
      } catch (e) {
        emitFromLocal();
      } finally {
        isFetching = false;
      }
    }

    controller = StreamController<List<WalletWithBalance>>(
      onListen: () {
        // 1. Tampilkan data instan dari SQLite lokal (0 ms, 60fps)
        emitFromLocal();

        // 2. Sinkronkan dengan Supabase Cloud di latar belakang
        if (isCloudActive) {
          syncAndRefresh();
        }

        // 3. Listener mutasi lokal dengan respons instan
        subWallets = _walletsDao.watchActiveWallets().listen((_) => emitFromLocal());
        subTransactions = _transactionsDao
            .watchRecentTransactions(limit: 1)
            .listen((_) => emitFromLocal());
        subSync = _cloudSyncEventController.stream.listen((_) => syncAndRefresh());
      },
      onCancel: () {
        subWallets?.cancel();
        subTransactions?.cancel();
        subSync?.cancel();
        controller.close();
      },
    );

    return controller.stream;
  }

  @override
  Future<int> calculateTotalAssetBalance() async {
    final walletsWithBalance = await getActiveWalletsWithBalance();
    int total = 0;
    for (final item in walletsWithBalance) {
      total += item.currentBalance;
    }
    return total;
  }

  @override
  Future<Wallet?> getWalletById(String id) async {
    // Cek cache lokal terlebih dahulu (0 ms)
    final localEntry = await _walletsDao.getWalletById(id);
    if (localEntry != null) {
      return WalletModel.fromEntry(localEntry);
    }

    if (isCloudActive) {
      final cloudWallet =
          await _remoteDataSource!.getWalletById(id, currentUserId!);
      if (cloudWallet != null) {
        await _syncWalletToLocalCache(cloudWallet);
        return cloudWallet;
      }
    }

    return null;
  }

  @override
  Future<void> createWallet(Wallet wallet) async {
    // 1. Simpan ke SQLite lokal secara instan (UI langsung responsif)
    await _syncWalletToLocalCache(wallet);

    // 2. Simpan ke Supabase Cloud
    if (isCloudActive) {
      await _remoteDataSource!.createWallet(wallet, currentUserId!);
    }

    _cloudSyncEventController.add(null);
  }

  @override
  Future<void> updateWallet(Wallet wallet) async {
    // 1. Simpan ke SQLite lokal
    await _walletsDao.updateWallet(
      WalletsTableCompanion(
        id: Value(wallet.id),
        name: Value(wallet.name),
        type: Value(wallet.type.toDbString()),
        openingBalance: Value(wallet.openingBalance),
        openingDate: Value(wallet.openingDate),
        currencyCode: Value(wallet.currencyCode),
        iconKey: Value(wallet.iconKey),
        colorHex: Value(wallet.colorHex),
        isArchived: Value(wallet.isArchived),
        createdAt: Value(wallet.createdAt),
        updatedAt: Value(DateTime.now().toUtc().toIso8601String()),
      ),
    );

    // 2. Simpan ke Supabase Cloud
    if (isCloudActive) {
      await _remoteDataSource!.updateWallet(wallet, currentUserId!);
    }

    _cloudSyncEventController.add(null);
  }

  @override
  Future<void> archiveWallet(String id) async {
    await _walletsDao.archiveWallet(id);

    if (isCloudActive) {
      try {
        await _remoteDataSource!.archiveWallet(id, currentUserId!);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[WalletRepositoryImpl] Warning cloud archive wallet: $e');
        }
      }
    }

    _cloudSyncEventController.add(null);
  }

  @override
  Future<void> unarchiveWallet(String id) async {
    await _walletsDao.unarchiveWallet(id);

    if (isCloudActive) {
      try {
        await _remoteDataSource!.unarchiveWallet(id, currentUserId!);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[WalletRepositoryImpl] Warning cloud unarchive wallet: $e');
        }
      }
    }

    _cloudSyncEventController.add(null);
  }

  @override
  Future<void> deleteWallet(String id) async {
    await _walletsDao.deleteWallet(id);

    if (isCloudActive) {
      try {
        await _remoteDataSource!.deleteWallet(id, currentUserId!);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[WalletRepositoryImpl] Warning cloud delete wallet: $e');
        }
      }
    }

    _cloudSyncEventController.add(null);
  }

  @override
  Future<List<WalletWithBalance>> getArchivedWalletsWithBalance() async {
    List<Wallet> wallets;
    if (isCloudActive) {
      try {
        wallets = await _remoteDataSource!.getArchivedWallets(currentUserId!);
        for (final w in wallets) {
          await _syncWalletToLocalCache(w);
        }
      } catch (e) {
        final entries = await _walletsDao.getArchivedWallets();
        wallets = entries.map(WalletModel.fromEntry).toList();
      }
    } else {
      final entries = await _walletsDao.getArchivedWallets();
      wallets = entries.map(WalletModel.fromEntry).toList();
    }

    final result = <WalletWithBalance>[];
    for (final wallet in wallets) {
      final balance = await calculateWalletBalance(wallet.id);
      result.add(WalletWithBalance(wallet: wallet, currentBalance: balance));
    }

    return result;
  }

  @override
  Stream<List<WalletWithBalance>> watchArchivedWalletsWithBalance() {
    late StreamController<List<WalletWithBalance>> controller;
    StreamSubscription? subWallets;
    StreamSubscription? subTransactions;
    StreamSubscription? subSync;

    void emitFromLocal() async {
      try {
        final entries = await _walletsDao.getArchivedWallets();
        final wallets = entries.map(WalletModel.fromEntry).toList();
        final list = <WalletWithBalance>[];

        for (final w in wallets) {
          final balance = await calculateWalletBalance(w.id);
          list.add(WalletWithBalance(wallet: w, currentBalance: balance));
        }

        if (!controller.isClosed) {
          controller.add(list);
        }
      } catch (_) {}
    }

    bool isFetching = false;
    void syncAndRefresh() async {
      if (isFetching) return;
      isFetching = true;
      try {
        final data = await getArchivedWalletsWithBalance();
        if (!controller.isClosed) {
          controller.add(data);
        }
      } catch (_) {
        emitFromLocal();
      } finally {
        isFetching = false;
      }
    }

    controller = StreamController<List<WalletWithBalance>>(
      onListen: () {
        emitFromLocal();
        if (isCloudActive) syncAndRefresh();

        subWallets = _walletsDao.watchArchivedWallets().listen((_) => emitFromLocal());
        subTransactions = _transactionsDao
            .watchRecentTransactions(limit: 1)
            .listen((_) => emitFromLocal());
        subSync = _cloudSyncEventController.stream.listen((_) => syncAndRefresh());
      },
      onCancel: () {
        subWallets?.cancel();
        subTransactions?.cancel();
        subSync?.cancel();
        controller.close();
      },
    );

    return controller.stream;
  }

  Future<void> _syncWalletToLocalCache(Wallet wallet) async {
    final existing = await _walletsDao.getWalletById(wallet.id);
    if (existing == null) {
      await _walletsDao.insertWallet(
        WalletsTableCompanion.insert(
          id: wallet.id,
          name: wallet.name,
          type: wallet.type.toDbString(),
          openingBalance: wallet.openingBalance,
          openingDate: wallet.openingDate,
          currencyCode: Value(wallet.currencyCode),
          iconKey: Value(wallet.iconKey),
          colorHex: Value(wallet.colorHex),
          isArchived: Value(wallet.isArchived),
          createdAt: wallet.createdAt,
          updatedAt: wallet.updatedAt,
        ),
      );
    } else {
      await _walletsDao.updateWallet(
        WalletsTableCompanion(
          id: Value(wallet.id),
          name: Value(wallet.name),
          type: Value(wallet.type.toDbString()),
          openingBalance: Value(wallet.openingBalance),
          openingDate: Value(wallet.openingDate),
          currencyCode: Value(wallet.currencyCode),
          iconKey: Value(wallet.iconKey),
          colorHex: Value(wallet.colorHex),
          isArchived: Value(wallet.isArchived),
          createdAt: Value(wallet.createdAt),
          updatedAt: Value(wallet.updatedAt),
        ),
      );
    }
  }
}
