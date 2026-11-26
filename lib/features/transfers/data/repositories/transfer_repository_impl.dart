import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:myfinance/core/database/app_database.dart';
import 'package:myfinance/core/database/daos/transactions_dao.dart';
import 'package:myfinance/core/database/daos/wallets_dao.dart';
import 'package:myfinance/core/errors/failures.dart';
import 'package:myfinance/core/services/supabase_service.dart';
import 'package:myfinance/features/wallets/domain/entities/wallet.dart';
import 'package:myfinance/features/wallets/data/models/wallet_model.dart';
import 'package:myfinance/features/transfers/domain/entities/transfer.dart';
import 'package:myfinance/features/transfers/domain/repositories/transfer_repository.dart';
import 'package:myfinance/features/transfers/data/datasources/transfer_remote_data_source.dart';
import 'package:myfinance/features/transfers/data/models/transfer_model.dart';

/// Implementasi TransferRepository dengan pola Offline-First Hybrid:
/// - Menyajikan data instan (0 ms) langsung dari Drift SQLite lokal
/// - Mengunggah & menyinkronkan mutasi transfer secara atomic ke Supabase PostgreSQL
/// - Menjaga isolasi user_id terautentikasi sesuai kebijakan Row Level Security (RLS)
/// - Menegakkan Transfer Invariants:
///   1. Transfer antar dompet tidak memengaruhi Total Aset Bersih (Delta = 0)
///   2. Transfer tidak dihitung sebagai Pemasukan maupun Pengeluaran bulanan
///   3. Validasi dompet sumber dan tujuan tidak boleh sama
class TransferRepositoryImpl implements TransferRepository {
  final TransactionsDao _transactionsDao;
  final WalletsDao _walletsDao;
  final TransferRemoteDataSource? _remoteDataSource;
  final SupabaseService? _supabaseService;

  final StreamController<void> _cloudSyncEventController =
      StreamController<void>.broadcast();

  bool _isFetchingCloud = false;

  TransferRepositoryImpl(
    this._transactionsDao,
    this._walletsDao, {
    TransferRemoteDataSource? remoteDataSource,
    SupabaseService? supabaseService,
  })  : _remoteDataSource = remoteDataSource,
        _supabaseService = supabaseService;

  bool get isCloudActive {
    final svc = _supabaseService;
    return svc != null && svc.isAuthenticated && _remoteDataSource != null;
  }

  String? get currentUserId => _supabaseService?.currentUser?.id;

  /// Memperkaya data Transfer dengan entity Wallet sumber dan tujuan
  Future<Transfer> _enrich(Transfer transfer) async {
    Wallet? sourceWallet;
    Wallet? destWallet;

    if (transfer.sourceWalletId.isNotEmpty) {
      final sw = await _walletsDao.getWalletById(transfer.sourceWalletId);
      if (sw != null) sourceWallet = WalletModel.fromEntry(sw);
    }

    if (transfer.destinationWalletId != null && transfer.destinationWalletId!.isNotEmpty) {
      final dw = await _walletsDao.getWalletById(transfer.destinationWalletId!);
      if (dw != null) destWallet = WalletModel.fromEntry(dw);
    }

    return transfer.copyWith(
      sourceWallet: sourceWallet,
      destinationWallet: destWallet,
    );
  }

  Future<Transfer> _enrichEntry(TransactionEntry entry) {
    return _enrich(TransferModel.fromEntry(entry));
  }

  Future<void> _syncTransferToLocalCache(Transfer transfer) async {
    await _transactionsDao.insertOrReplaceTransaction(
      TransactionsTableCompanion(
        id: Value(transfer.id),
        type: const Value('transfer'),
        amount: Value(transfer.amount),
        occurredAt: Value(transfer.occurredAt),
        walletId: Value(transfer.sourceWalletId),
        destinationWalletId: Value(transfer.destinationWalletId),
        categoryId: const Value(null),
        merchant: Value(transfer.merchant),
        description: Value(transfer.description),
        notes: Value(transfer.notes),
        source: Value(transfer.source),
        status: Value(transfer.status.toDbString()),
        createdAt: Value(transfer.createdAt),
        updatedAt: Value(transfer.updatedAt),
      ),
    );
  }

  @override
  Future<Transfer?> getTransferById(String id) async {
    // 1. Cek cache lokal terlebih dahulu (0 ms)
    final localEntry = await _transactionsDao.getTransactionById(id);
    if (localEntry != null && localEntry.type == 'transfer') {
      return _enrichEntry(localEntry);
    }

    // 2. Ambil dari cloud jika belum ada di lokal
    if (isCloudActive) {
      final cloudTransfer = await _remoteDataSource!.getTransferById(id, currentUserId!);
      if (cloudTransfer != null) {
        await _syncTransferToLocalCache(cloudTransfer);
        return _enrich(cloudTransfer);
      }
    }

    return null;
  }

  @override
  Future<List<Transfer>> getTransfers({int limit = 50}) async {
    if (isCloudActive) {
      try {
        final cloudTransfers = await _remoteDataSource!.getTransfers(
          currentUserId!,
          limit: limit,
        );
        for (final t in cloudTransfers) {
          await _syncTransferToLocalCache(t);
        }
        return await Future.wait(cloudTransfers.map(_enrich));
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[TransferRepositoryImpl] Cloud fetch warning, fallback lokal: $e');
        }
        final entries = await _transactionsDao.watchRecentTransactions(limit: 500).first;
        final transferEntries = entries.where((e) => e.type == 'transfer').take(limit);
        return Future.wait(transferEntries.map(_enrichEntry));
      }
    }

    final entries = await _transactionsDao.watchRecentTransactions(limit: 500).first;
    final transferEntries = entries.where((e) => e.type == 'transfer').take(limit);
    return Future.wait(transferEntries.map(_enrichEntry));
  }

  @override
  Stream<List<Transfer>> watchTransfers({int limit = 50}) {
    if (isCloudActive) {
      late StreamController<List<Transfer>> controller;
      StreamSubscription? subLocal;
      StreamSubscription? subSync;

      void emitFromCache() async {
        try {
          final entries = await _transactionsDao.watchRecentTransactions(limit: 500).first;
          final transferEntries = entries.where((e) => e.type == 'transfer').take(limit);
          final details = await Future.wait(transferEntries.map(_enrichEntry));
          if (!controller.isClosed) {
            controller.add(details);
          }
        } catch (_) {}
      }

      void syncAndRefresh() async {
        if (_isFetchingCloud) return;
        _isFetchingCloud = true;
        try {
          final cloudTransfers = await _remoteDataSource!.getTransfers(
            currentUserId!,
            limit: limit,
          );
          for (final t in cloudTransfers) {
            await _syncTransferToLocalCache(t);
          }
          final details = await Future.wait(cloudTransfers.map(_enrich));
          if (!controller.isClosed) {
            controller.add(details);
          }
        } catch (e) {
          emitFromCache();
        } finally {
          _isFetchingCloud = false;
        }
      }

      controller = StreamController<List<Transfer>>(
        onListen: () {
          emitFromCache();
          syncAndRefresh();

          subLocal = _transactionsDao.watchRecentTransactions(limit: 500).listen((_) {
            emitFromCache();
          });
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

    return _transactionsDao.watchRecentTransactions(limit: 500).asyncMap(
      (entries) async {
        final transferEntries = entries.where((e) => e.type == 'transfer').take(limit);
        return Future.wait(transferEntries.map(_enrichEntry));
      },
    );
  }

  @override
  Future<void> createTransfer(Transfer transfer) async {
    // 1. Validasi nominal
    if (transfer.amount <= 0) {
      throw const ValidationFailure('Nominal transfer harus lebih dari 0.');
    }

    // 2. Validasi dompet sumber
    if (transfer.sourceWalletId.trim().isEmpty) {
      throw const ValidationFailure('Dompet sumber transfer wajib dipilih.');
    }
    final sourceWallet = await _walletsDao.getWalletById(transfer.sourceWalletId);
    if (sourceWallet == null) {
      throw const ValidationFailure('Dompet sumber tidak ditemukan.');
    }

    // 3. Validasi dompet tujuan (internal) vs penerima luar (external)
    if (transfer.destinationWalletId != null &&
        transfer.destinationWalletId!.trim().isNotEmpty) {
      if (transfer.destinationWalletId == transfer.sourceWalletId) {
        throw const ValidationFailure('Dompet sumber dan dompet tujuan tidak boleh sama.');
      }
      final destWallet = await _walletsDao.getWalletById(transfer.destinationWalletId!);
      if (destWallet == null) {
        throw const ValidationFailure('Dompet tujuan transfer tidak ditemukan.');
      }
    } else {
      final target = (transfer.merchant?.trim().isNotEmpty == true)
          ? transfer.merchant!.trim()
          : transfer.description?.trim();
      if (target == null || target.isEmpty) {
        throw const ValidationFailure(
          'Tujuan transfer (nama penerima / bank / e-wallet) wajib diisi.',
        );
      }
    }

    // 4. Simpan ke SQLite lokal secara instan (0 ms)
    await _syncTransferToLocalCache(transfer);

    // 5. Simpan ke Supabase Cloud
    if (isCloudActive) {
      await _remoteDataSource!.createTransfer(transfer, currentUserId!);
    }

    _cloudSyncEventController.add(null);
  }

  @override
  Future<void> updateTransfer(Transfer transfer) async {
    final existing = await getTransferById(transfer.id);
    if (existing == null) {
      throw const NotFoundFailure('Transaksi transfer tidak ditemukan.');
    }

    // 1. Simpan ke SQLite lokal
    await _transactionsDao.updateTransaction(
      TransactionsTableCompanion(
        id: Value(transfer.id),
        type: const Value('transfer'),
        amount: Value(transfer.amount),
        occurredAt: Value(transfer.occurredAt),
        walletId: Value(transfer.sourceWalletId),
        destinationWalletId: Value(transfer.destinationWalletId),
        categoryId: const Value(null),
        merchant: Value(transfer.merchant),
        description: Value(transfer.description),
        notes: Value(transfer.notes),
        source: Value(transfer.source),
        status: Value(transfer.status.toDbString()),
        createdAt: Value(transfer.createdAt),
        updatedAt: Value(DateTime.now().toUtc().toIso8601String()),
      ),
    );

    // 2. Simpan ke Supabase Cloud
    if (isCloudActive) {
      await _remoteDataSource!.updateTransfer(transfer, currentUserId!);
    }

    _cloudSyncEventController.add(null);
  }

  @override
  Future<void> voidTransfer(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();

    // 1. Update SQLite lokal (0 ms)
    await _transactionsDao.voidTransaction(id, now);

    // 2. Update status di Supabase Cloud
    if (isCloudActive) {
      await _remoteDataSource!.voidTransfer(id, currentUserId!, now);
    }

    _cloudSyncEventController.add(null);
  }

  @override
  Future<void> deleteTransfer(String id) async {
    // 1. Hapus dari SQLite lokal
    await _transactionsDao.deleteTransaction(id);

    // 2. Hapus dari Supabase Cloud
    if (isCloudActive) {
      await _remoteDataSource!.deleteTransfer(id, currentUserId!);
    }

    _cloudSyncEventController.add(null);
  }

  @override
  Future<List<Transfer>> getTransfersForWallet(String walletId) async {
    if (isCloudActive) {
      try {
        final cloudTransfers = await _remoteDataSource!.getTransfersForWallet(
          walletId,
          currentUserId!,
        );
        for (final t in cloudTransfers) {
          await _syncTransferToLocalCache(t);
        }
        return await Future.wait(cloudTransfers.map(_enrich));
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[TransferRepositoryImpl] Warning cloud wallet transfers: $e');
        }
      }
    }

    final entries = await _transactionsDao.getConfirmedLedgerForWallet(walletId);
    final transferEntries = entries.where((e) => e.type == 'transfer');
    return Future.wait(transferEntries.map(_enrichEntry));
  }

  @override
  Stream<List<Transfer>> watchTransfersForWallet(String walletId) {
    if (isCloudActive) {
      late StreamController<List<Transfer>> controller;
      StreamSubscription? subLocal;
      StreamSubscription? subSync;

      void emitFromCache() async {
        try {
          final entries = await _transactionsDao.getConfirmedLedgerForWallet(walletId);
          final transferEntries = entries.where((e) => e.type == 'transfer');
          final details = await Future.wait(transferEntries.map(_enrichEntry));
          if (!controller.isClosed) {
            controller.add(details);
          }
        } catch (_) {}
      }

      void syncAndRefresh() async {
        if (_isFetchingCloud) return;
        _isFetchingCloud = true;
        try {
          final cloudTransfers = await _remoteDataSource!.getTransfersForWallet(
            walletId,
            currentUserId!,
          );
          for (final t in cloudTransfers) {
            await _syncTransferToLocalCache(t);
          }
          final details = await Future.wait(cloudTransfers.map(_enrich));
          if (!controller.isClosed) {
            controller.add(details);
          }
        } catch (e) {
          emitFromCache();
        } finally {
          _isFetchingCloud = false;
        }
      }

      controller = StreamController<List<Transfer>>(
        onListen: () {
          emitFromCache();
          syncAndRefresh();

          subLocal = _transactionsDao
              .watchConfirmedLedgerForWallet(walletId)
              .listen((_) => emitFromCache());
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

    return _transactionsDao.watchConfirmedLedgerForWallet(walletId).asyncMap(
      (entries) async {
        final transferEntries = entries.where((e) => e.type == 'transfer');
        return Future.wait(transferEntries.map(_enrichEntry));
      },
    );
  }

  @override
  Future<int> calculateWalletTransferBalance(String walletId) async {
    final ledger = await _transactionsDao.getConfirmedLedgerForWallet(walletId);
    int transferBalance = 0;

    for (final tx in ledger) {
      if (tx.status != 'confirmed' || tx.type != 'transfer') continue;

      if (tx.destinationWalletId == walletId) {
        transferBalance += tx.amount; // Transfer Masuk
      }
      if (tx.walletId == walletId) {
        transferBalance -= tx.amount; // Transfer Keluar
      }
    }

    return transferBalance;
  }
}
