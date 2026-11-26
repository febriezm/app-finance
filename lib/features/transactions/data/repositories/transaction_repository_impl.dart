import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint, kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/transactions_dao.dart';
import '../../../../core/database/daos/wallets_dao.dart';
import '../../../../core/database/daos/categories_dao.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/supabase_service.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_with_details.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/transaction_remote_data_source.dart';
import '../models/transaction_model.dart';
import '../../../wallets/domain/entities/wallet.dart';
import '../../../wallets/data/models/wallet_model.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../categories/data/models/category_model.dart';

/// Implementasi TransactionRepository dengan pola Offline-First:
/// - Reaktivitas instan (0 ms) didorong oleh SQLite lokal (Drift)
/// - Sinkronisasi aman & konsisten ke Supabase Cloud PostgreSQL
/// - Proteksi rekursi (_isSyncing) mencegah feedback loop HTTP query
/// - Buku besar mutasi multi-user terisolasi sesuai RLS
class TransactionRepositoryImpl implements TransactionRepository {
  final TransactionsDao _transactionsDao;
  final WalletsDao _walletsDao;
  final CategoriesDao _categoriesDao;
  final TransactionRemoteDataSource? _remoteDataSource;
  final SupabaseService? _supabaseService;

  final StreamController<void> _cloudSyncEventController =
      StreamController<void>.broadcast();

  bool _isSyncing = false;
  bool _isFetchingCloud = false;

  TransactionRepositoryImpl(
    this._transactionsDao,
    this._walletsDao,
    this._categoriesDao, {
    TransactionRemoteDataSource? remoteDataSource,
    SupabaseService? supabaseService,
  })  : _remoteDataSource = remoteDataSource,
        _supabaseService = supabaseService;

  bool get isCloudActive {
    final svc = _supabaseService;
    return svc != null && svc.isAuthenticated && _remoteDataSource != null;
  }

  String? get currentUserId => _supabaseService?.currentUser?.id;

  Future<TransactionWithDetails> _enrich(Transaction tx) async {
    Wallet? wallet;
    Wallet? destWallet;
    Category? category;

    if (tx.walletId != null) {
      final w = await _walletsDao.getWalletById(tx.walletId!);
      if (w != null) wallet = WalletModel.fromEntry(w);
    }

    if (tx.destinationWalletId != null) {
      final dw = await _walletsDao.getWalletById(tx.destinationWalletId!);
      if (dw != null) destWallet = WalletModel.fromEntry(dw);
    }

    if (tx.categoryId != null) {
      final c = await _categoriesDao.getCategoryById(tx.categoryId!);
      if (c != null) category = CategoryModel.fromEntry(c);
    }

    return TransactionWithDetails(
      transaction: tx,
      wallet: wallet,
      destinationWallet: destWallet,
      category: category,
    );
  }

  Future<TransactionWithDetails> _enrichEntry(TransactionEntry entry) {
    return _enrich(TransactionModel.fromEntry(entry));
  }

  @override
  Future<Transaction?> getTransactionById(String id) async {
    // 1. Cek cache lokal terlebih dahulu (0 ms)
    final localEntry = await _transactionsDao.getTransactionById(id);
    if (localEntry != null) {
      return TransactionModel.fromEntry(localEntry);
    }

    // 2. Ambil dari cloud jika belum ada di lokal
    if (isCloudActive) {
      final cloudTx = await _remoteDataSource!.getTransactionById(id, currentUserId!);
      if (cloudTx != null) {
        await _syncTransactionToLocalCache(cloudTx);
        return cloudTx;
      }
    }

    return null;
  }

  @override
  Future<TransactionWithDetails?> getTransactionWithDetailsById(String id) async {
    final tx = await getTransactionById(id);
    if (tx == null) return null;
    return _enrich(tx);
  }

  @override
  Future<List<TransactionWithDetails>> getRecentTransactions({int limit = 20}) async {
    if (isCloudActive) {
      try {
        final cloudTxs = await _remoteDataSource!.getRecentTransactions(
          currentUserId!,
          limit: limit,
        );
        for (final tx in cloudTxs) {
          await _syncTransactionToLocalCache(tx);
        }
        return await Future.wait(cloudTxs.map(_enrich));
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[TransactionRepositoryImpl] Cloud fetch warning, fallback lokal: $e');
        }
        final entries = await _transactionsDao.watchRecentTransactions(limit: limit).first;
        return Future.wait(entries.map(_enrichEntry));
      }
    }

    final entries = await _transactionsDao.watchRecentTransactions(limit: limit).first;
    return Future.wait(entries.map(_enrichEntry));
  }

  @override
  Stream<List<TransactionWithDetails>> watchRecentTransactions({int limit = 20}) {
    if (isCloudActive) {
      late StreamController<List<TransactionWithDetails>> controller;
      StreamSubscription? subLocal;
      StreamSubscription? subSync;

      void emitFromCache() async {
        try {
          final entries = await _transactionsDao.watchRecentTransactions(limit: limit).first;
          final details = await Future.wait(entries.map(_enrichEntry));
          if (!controller.isClosed) {
            controller.add(details);
          }
        } catch (_) {}
      }

      void syncAndRefresh() async {
        if (_isFetchingCloud) return;
        _isFetchingCloud = true;
        try {
          final cloudTxs = await _remoteDataSource!.getRecentTransactions(
            currentUserId!,
            limit: limit,
          );
          for (final tx in cloudTxs) {
            await _syncTransactionToLocalCache(tx);
          }
          final details = await Future.wait(cloudTxs.map(_enrich));
          if (!controller.isClosed) {
            controller.add(details);
          }
        } catch (e) {
          emitFromCache();
        } finally {
          _isFetchingCloud = false;
        }
      }

      controller = StreamController<List<TransactionWithDetails>>(
        onListen: () {
          emitFromCache();
          syncAndRefresh();

          subLocal = _transactionsDao
              .watchRecentTransactions(limit: limit)
              .listen((_) {
            if (!_isSyncing) emitFromCache();
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

    return _transactionsDao.watchRecentTransactions(limit: limit).asyncMap(
          (entries) => Future.wait(entries.map(_enrichEntry)),
        );
  }

  @override
  Future<List<TransactionWithDetails>> getTransactionsForWallet(String walletId) async {
    if (isCloudActive) {
      try {
        final cloudTxs = await _remoteDataSource!.getTransactionsForWallet(
          walletId,
          currentUserId!,
        );
        for (final tx in cloudTxs) {
          await _syncTransactionToLocalCache(tx);
        }
        return await Future.wait(cloudTxs.map(_enrich));
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[TransactionRepositoryImpl] Cloud wallet txs warning, fallback lokal: $e');
        }
        final entries = await _transactionsDao.getConfirmedLedgerForWallet(walletId);
        return Future.wait(entries.map(_enrichEntry));
      }
    }

    final entries = await _transactionsDao.getConfirmedLedgerForWallet(walletId);
    return Future.wait(entries.map(_enrichEntry));
  }

  @override
  Stream<List<TransactionWithDetails>> watchTransactionsForWallet(String walletId) {
    if (isCloudActive) {
      late StreamController<List<TransactionWithDetails>> controller;
      StreamSubscription? subLocal;
      StreamSubscription? subSync;

      void emitFromCache() async {
        try {
          final entries = await _transactionsDao.getConfirmedLedgerForWallet(walletId);
          final details = await Future.wait(entries.map(_enrichEntry));
          if (!controller.isClosed) {
            controller.add(details);
          }
        } catch (_) {}
      }

      void syncAndRefresh() async {
        if (_isFetchingCloud) return;
        _isFetchingCloud = true;
        try {
          final cloudTxs = await _remoteDataSource!.getTransactionsForWallet(
            walletId,
            currentUserId!,
          );
          for (final tx in cloudTxs) {
            await _syncTransactionToLocalCache(tx);
          }
          final details = await Future.wait(cloudTxs.map(_enrich));
          if (!controller.isClosed) {
            controller.add(details);
          }
        } catch (e) {
          emitFromCache();
        } finally {
          _isFetchingCloud = false;
        }
      }

      controller = StreamController<List<TransactionWithDetails>>(
        onListen: () {
          emitFromCache();
          syncAndRefresh();

          subLocal = _transactionsDao
              .watchConfirmedLedgerForWallet(walletId)
              .listen((_) {
            if (!_isSyncing) emitFromCache();
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

    return _transactionsDao.watchConfirmedLedgerForWallet(walletId).asyncMap(
          (entries) => Future.wait(entries.map(_enrichEntry)),
        );
  }

  @override
  Future<List<TransactionWithDetails>> getTransactionsInDateRange(
    DateTime start,
    DateTime end, {
    TransactionType? filterType,
  }) async {
    final startIso = start.toUtc().toIso8601String();
    final endIso = end.toUtc().toIso8601String();

    if (isCloudActive) {
      try {
        final cloudTxs = await _remoteDataSource!.getTransactionsInDateRange(
          currentUserId!,
          startIso,
          endIso,
          filterType: filterType,
        );
        for (final tx in cloudTxs) {
          await _syncTransactionToLocalCache(tx);
        }
        return await Future.wait(cloudTxs.map(_enrich));
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[TransactionRepositoryImpl] Cloud range fetch warning, fallback lokal: $e');
        }
      }
    }

    List<TransactionEntry> entries;
    if (filterType == TransactionType.expense) {
      entries = await _transactionsDao.getConfirmedExpensesInDateRange(startIso, endIso);
    } else if (filterType == TransactionType.income) {
      entries = await _transactionsDao.getConfirmedIncomesInDateRange(startIso, endIso);
    } else {
      final allRecent = await _transactionsDao.watchRecentTransactions(limit: 500).first;
      entries = allRecent.where((t) {
        return t.occurredAt.compareTo(startIso) >= 0 && t.occurredAt.compareTo(endIso) <= 0;
      }).toList();
    }

    return Future.wait(entries.map(_enrichEntry));
  }

  @override
  Future<void> createTransaction(Transaction transaction) async {
    // 1. Validasi nominal
    if (transaction.amount <= 0) {
      throw const ValidationFailure('Nominal transaksi harus lebih dari 0.');
    }

    // 2. Validasi wallet asal
    if (transaction.walletId == null || transaction.walletId!.trim().isEmpty) {
      throw const ValidationFailure('Dompet sumber wajib dipilih.');
    }
    final sourceWallet = await _walletsDao.getWalletById(transaction.walletId!);
    if (sourceWallet == null) {
      throw const ValidationFailure('Dompet sumber tidak ditemukan.');
    }

    // 3. Validasi berdasarkan jenis
    if (transaction.type == TransactionType.income || transaction.type == TransactionType.expense) {
      if (transaction.categoryId == null || transaction.categoryId!.trim().isEmpty) {
        throw const ValidationFailure('Kategori transaksi wajib dipilih.');
      }
      final category = await _categoriesDao.getCategoryById(transaction.categoryId!);
      if (category == null) {
        throw const ValidationFailure('Kategori transaksi tidak ditemukan.');
      }
    } else if (transaction.type == TransactionType.transfer) {
      if (transaction.destinationWalletId != null &&
          transaction.destinationWalletId!.trim().isNotEmpty) {
        if (transaction.destinationWalletId == transaction.walletId) {
          throw const ValidationFailure('Dompet sumber dan dompet tujuan tidak boleh sama.');
        }
        final destWallet = await _walletsDao.getWalletById(transaction.destinationWalletId!);
        if (destWallet == null) {
          throw const ValidationFailure('Dompet tujuan transfer tidak ditemukan.');
        }
      } else {
        final target = (transaction.merchant?.trim().isNotEmpty == true)
            ? transaction.merchant!.trim()
            : transaction.description?.trim();
        if (target == null || target.isEmpty) {
          throw const ValidationFailure('Tujuan transfer (nama penerima / bank / e-wallet) wajib diisi.');
        }
      }
    }

    // 4. Simpan ke SQLite lokal secara instan (0 ms)
    await _syncTransactionToLocalCache(transaction);

    // 5. Simpan ke Supabase Cloud
    if (isCloudActive) {
      await _remoteDataSource!.createTransaction(transaction, currentUserId!);
    }

    _cloudSyncEventController.add(null);
  }

  @override
  Future<void> updateTransaction(Transaction transaction) async {
    final existing = await getTransactionById(transaction.id);
    if (existing == null) {
      throw const NotFoundFailure('Transaksi tidak ditemukan.');
    }

    // 1. Simpan ke SQLite lokal
    await _transactionsDao.updateTransaction(
      TransactionsTableCompanion(
        id: Value(transaction.id),
        type: Value(transaction.type.toDbString()),
        amount: Value(transaction.amount),
        occurredAt: Value(transaction.occurredAt),
        walletId: Value(transaction.walletId),
        destinationWalletId: Value(transaction.destinationWalletId),
        categoryId: Value(transaction.categoryId),
        merchant: Value(transaction.merchant),
        description: Value(transaction.description),
        notes: Value(transaction.notes),
        source: Value(transaction.source),
        status: Value(transaction.status.toDbString()),
        createdAt: Value(transaction.createdAt),
        updatedAt: Value(DateTime.now().toUtc().toIso8601String()),
      ),
    );

    // 2. Simpan ke Supabase Cloud
    if (isCloudActive) {
      await _remoteDataSource!.updateTransaction(transaction, currentUserId!);
    }

    _cloudSyncEventController.add(null);
  }

  @override
  Future<void> voidTransaction(String id) async {
    final existing = await getTransactionById(id);
    if (existing == null) {
      throw const NotFoundFailure('Transaksi tidak ditemukan.');
    }

    final updatedAt = DateTime.now().toUtc().toIso8601String();

    // 1. Update ke SQLite lokal
    await _transactionsDao.voidTransaction(id, updatedAt);

    // 2. Update ke Supabase Cloud
    if (isCloudActive) {
      await _remoteDataSource!.voidTransaction(id, currentUserId!, updatedAt);
    }

    _cloudSyncEventController.add(null);
  }

  @override
  Future<void> deleteTransaction(String id) async {
    final existing = await getTransactionById(id);
    if (existing == null) {
      throw const NotFoundFailure('Transaksi tidak ditemukan.');
    }

    // 1. Bersihkan berkas lampiran fisik lokal jika ada
    try {
      final attachments = await _transactionsDao.getAttachmentsForTransaction(id);
      if (!kIsWeb && attachments.isNotEmpty) {
        final docsDir = await getApplicationDocumentsDirectory();
        for (final att in attachments) {
          final cleanFileName = att.localPath.contains('/')
              ? att.localPath.split('/').last
              : att.localPath;
          final file = File(p.join(docsDir.path, 'receipts', cleanFileName));
          if (await file.exists()) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[TransactionRepositoryImpl] Local attachment cleanup warning: $e');
      }
    }

    // 2. Hapus dari SQLite lokal
    await _transactionsDao.deleteTransaction(id);

    // 3. Hapus dari Supabase Cloud (termasuk Supabase Storage)
    if (isCloudActive) {
      await _remoteDataSource!.deleteTransaction(id, currentUserId!);
    }

    _cloudSyncEventController.add(null);
  }

  @override
  Future<int> getMonthlyIncome(int year, int month) async {
    if (isCloudActive) {
      try {
        return await _remoteDataSource!.getMonthlyIncome(currentUserId!, year, month);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[TransactionRepositoryImpl] Cloud monthly income warning: $e');
        }
      }
    }

    final start = DateTime(year, month, 1).toUtc().toIso8601String();
    final end = DateTime(year, month + 1, 0, 23, 59, 59, 999).toUtc().toIso8601String();

    final entries = await _transactionsDao.getConfirmedIncomesInDateRange(start, end);
    int total = 0;
    for (final e in entries) {
      total += e.amount;
    }
    return total;
  }

  @override
  Stream<int> watchMonthlyIncome(int year, int month) {
    if (isCloudActive) {
      late StreamController<int> controller;
      StreamSubscription? subLocal;
      StreamSubscription? subSync;

      void emitFromCache() async {
        try {
          final start = DateTime(year, month, 1).toUtc().toIso8601String();
          final end = DateTime(year, month + 1, 0, 23, 59, 59, 999).toUtc().toIso8601String();
          final entries = await _transactionsDao.getConfirmedIncomesInDateRange(start, end);
          int total = 0;
          for (final e in entries) {
            total += e.amount;
          }
          if (!controller.isClosed) {
            controller.add(total);
          }
        } catch (_) {}
      }

      void syncAndRefresh() async {
        try {
          final total = await _remoteDataSource!.getMonthlyIncome(currentUserId!, year, month);
          if (!controller.isClosed) {
            controller.add(total);
          }
        } catch (_) {
          emitFromCache();
        }
      }

      controller = StreamController<int>(
        onListen: () {
          emitFromCache();
          syncAndRefresh();

          final start = DateTime(year, month, 1).toUtc().toIso8601String();
          final end = DateTime(year, month + 1, 0, 23, 59, 59, 999).toUtc().toIso8601String();
          subLocal = _transactionsDao
              .watchConfirmedIncomesInDateRange(start, end)
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

    final start = DateTime(year, month, 1).toUtc().toIso8601String();
    final end = DateTime(year, month + 1, 0, 23, 59, 59, 999).toUtc().toIso8601String();

    return _transactionsDao.watchConfirmedIncomesInDateRange(start, end).map((entries) {
      int total = 0;
      for (final e in entries) {
        total += e.amount;
      }
      return total;
    });
  }

  @override
  Future<int> getMonthlyExpense(int year, int month) async {
    if (isCloudActive) {
      try {
        return await _remoteDataSource!.getMonthlyExpense(currentUserId!, year, month);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[TransactionRepositoryImpl] Cloud monthly expense warning: $e');
        }
      }
    }

    final start = DateTime(year, month, 1).toUtc().toIso8601String();
    final end = DateTime(year, month + 1, 0, 23, 59, 59, 999).toUtc().toIso8601String();

    final entries = await _transactionsDao.getConfirmedExpensesInDateRange(start, end);
    int total = 0;
    for (final e in entries) {
      total += e.amount;
    }
    return total;
  }

  @override
  Stream<int> watchMonthlyExpense(int year, int month) {
    if (isCloudActive) {
      late StreamController<int> controller;
      StreamSubscription? subLocal;
      StreamSubscription? subSync;

      void emitFromCache() async {
        try {
          final start = DateTime(year, month, 1).toUtc().toIso8601String();
          final end = DateTime(year, month + 1, 0, 23, 59, 59, 999).toUtc().toIso8601String();
          final entries = await _transactionsDao.getConfirmedExpensesInDateRange(start, end);
          int total = 0;
          for (final e in entries) {
            total += e.amount;
          }
          if (!controller.isClosed) {
            controller.add(total);
          }
        } catch (_) {}
      }

      void syncAndRefresh() async {
        try {
          final total = await _remoteDataSource!.getMonthlyExpense(currentUserId!, year, month);
          if (!controller.isClosed) {
            controller.add(total);
          }
        } catch (_) {
          emitFromCache();
        }
      }

      controller = StreamController<int>(
        onListen: () {
          emitFromCache();
          syncAndRefresh();

          final start = DateTime(year, month, 1).toUtc().toIso8601String();
          final end = DateTime(year, month + 1, 0, 23, 59, 59, 999).toUtc().toIso8601String();
          subLocal = _transactionsDao
              .watchConfirmedExpensesInDateRange(start, end)
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

    final start = DateTime(year, month, 1).toUtc().toIso8601String();
    final end = DateTime(year, month + 1, 0, 23, 59, 59, 999).toUtc().toIso8601String();

    return _transactionsDao.watchConfirmedExpensesInDateRange(start, end).map((entries) {
      int total = 0;
      for (final e in entries) {
        total += e.amount;
      }
      return total;
    });
  }

  Future<void> _syncTransactionToLocalCache(Transaction tx) async {
    _isSyncing = true;
    try {
      await _transactionsDao.insertOrReplaceTransaction(
        TransactionsTableCompanion.insert(
          id: tx.id,
          type: tx.type.toDbString(),
          amount: tx.amount,
          occurredAt: tx.occurredAt,
          walletId: Value(tx.walletId),
          destinationWalletId: Value(tx.destinationWalletId),
          categoryId: Value(tx.categoryId),
          merchant: Value(tx.merchant),
          description: Value(tx.description),
          notes: Value(tx.notes),
          source: Value(tx.source),
          status: Value(tx.status.toDbString()),
          createdAt: tx.createdAt,
          updatedAt: tx.updatedAt,
        ),
      );
    } finally {
      _isSyncing = false;
    }
  }
}
