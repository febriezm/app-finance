import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import 'package:myfinance/core/database/app_database.dart';
import 'package:myfinance/core/errors/exceptions.dart';
import 'package:myfinance/core/errors/failures.dart';
import 'package:myfinance/core/services/supabase_service.dart';
import 'package:myfinance/features/transactions/data/datasources/transaction_remote_data_source.dart';
import 'package:myfinance/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:myfinance/features/transactions/domain/entities/transaction.dart';

/// Fake TransactionRemoteDataSource yang mensimulasikan PostgreSQL RLS & PostgREST API
class FakeTransactionRemoteDataSource implements TransactionRemoteDataSource {
  final Map<String, Map<String, dynamic>> _cloudTable = {};
  bool shouldThrowError = false;

  @override
  Future<List<Transaction>> getRecentTransactions(String userId, {int limit = 50}) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Network connection timeout', 'PGRST_TIMEOUT');
    }

    // RLS: WHERE user_id = :userId
    return _cloudTable.values
        .where((row) => row['user_id'] == userId)
        .map(_mapToTransaction)
        .toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  }

  @override
  Future<List<Transaction>> getTransactionsForWallet(String walletId, String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Database query failed', '42P01');
    }

    // RLS: WHERE user_id = :userId AND (wallet_id = :wId OR destination_wallet_id = :wId)
    return _cloudTable.values
        .where((row) =>
            row['user_id'] == userId &&
            (row['wallet_id'] == walletId || row['destination_wallet_id'] == walletId))
        .map(_mapToTransaction)
        .toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  }

  @override
  Future<List<Transaction>> getTransactionsInDateRange(
    String userId,
    String startIsoUtc,
    String endIsoUtc, {
    TransactionType? filterType,
  }) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Network query error', 'PGRST_ERROR');
    }

    return _cloudTable.values.where((row) {
      if (row['user_id'] != userId) return false;
      final occurred = row['occurred_at'] as String;
      if (occurred.compareTo(startIsoUtc) < 0 || occurred.compareTo(endIsoUtc) > 0) return false;
      if (filterType != null && row['type'] != filterType.toDbString()) return false;
      return true;
    }).map(_mapToTransaction).toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  }

  @override
  Future<Transaction?> getTransactionById(String id, String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Database query failed', '42P01');
    }

    final row = _cloudTable[id];
    if (row == null || row['user_id'] != userId) return null; // RLS block
    return _mapToTransaction(row);
  }

  @override
  Future<void> createTransaction(Transaction transaction, String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Failed to insert transaction', '23505');
    }

    _cloudTable[transaction.id] = {
      'id': transaction.id,
      'user_id': userId,
      'type': transaction.type.toDbString(),
      'amount': transaction.amount,
      'occurred_at': transaction.occurredAt,
      'wallet_id': transaction.walletId,
      'destination_wallet_id': transaction.destinationWalletId,
      'category_id': transaction.categoryId,
      'merchant': transaction.merchant,
      'description': transaction.description,
      'notes': transaction.notes,
      'source': transaction.source,
      'status': transaction.status.toDbString(),
      'created_at': transaction.createdAt,
      'updated_at': transaction.updatedAt,
    };
  }

  @override
  Future<void> updateTransaction(Transaction transaction, String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Failed to update transaction');
    }

    final existing = _cloudTable[transaction.id];
    if (existing == null || existing['user_id'] != userId) {
      throw const SupabaseDatabaseException('Row not found or permission denied (RLS)');
    }

    _cloudTable[transaction.id] = {
      ...existing,
      'type': transaction.type.toDbString(),
      'amount': transaction.amount,
      'occurred_at': transaction.occurredAt,
      'wallet_id': transaction.walletId,
      'destination_wallet_id': transaction.destinationWalletId,
      'category_id': transaction.categoryId,
      'merchant': transaction.merchant,
      'description': transaction.description,
      'notes': transaction.notes,
      'source': transaction.source,
      'status': transaction.status.toDbString(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  @override
  Future<void> voidTransaction(String id, String userId, String updatedAtUtcIso) async {
    final existing = _cloudTable[id];
    if (existing == null || existing['user_id'] != userId) {
      throw const SupabaseDatabaseException('Permission denied (RLS)');
    }
    existing['status'] = 'voided';
    existing['updated_at'] = updatedAtUtcIso;
  }

  @override
  Future<void> deleteTransaction(String id, String userId) async {
    final existing = _cloudTable[id];
    if (existing == null || existing['user_id'] != userId) {
      throw const SupabaseDatabaseException('Permission denied (RLS)');
    }
    _cloudTable.remove(id);
  }

  @override
  Future<int> getMonthlyIncome(String userId, int year, int month) async {
    final start = DateTime(year, month, 1).toUtc().toIso8601String();
    final end = DateTime(year, month + 1, 0, 23, 59, 59, 999).toUtc().toIso8601String();

    int total = 0;
    for (final row in _cloudTable.values) {
      if (row['user_id'] != userId) continue;
      if (row['type'] != 'income') continue;
      if (row['status'] != 'confirmed') continue;
      final occurred = row['occurred_at'] as String;
      if (occurred.compareTo(start) >= 0 && occurred.compareTo(end) <= 0) {
        total += (row['amount'] as num).toInt();
      }
    }
    return total;
  }

  @override
  Future<int> getMonthlyExpense(String userId, int year, int month) async {
    final start = DateTime(year, month, 1).toUtc().toIso8601String();
    final end = DateTime(year, month + 1, 0, 23, 59, 59, 999).toUtc().toIso8601String();

    int total = 0;
    for (final row in _cloudTable.values) {
      if (row['user_id'] != userId) continue;
      if (row['type'] != 'expense') continue;
      if (row['status'] != 'confirmed') continue;
      final occurred = row['occurred_at'] as String;
      if (occurred.compareTo(start) >= 0 && occurred.compareTo(end) <= 0) {
        total += (row['amount'] as num).toInt();
      }
    }
    return total;
  }

  Transaction _mapToTransaction(Map<String, dynamic> row) {
    return Transaction(
      id: row['id'] as String,
      type: TransactionType.fromString(row['type'] as String),
      amount: (row['amount'] as num).toInt(),
      occurredAt: row['occurred_at'] as String,
      walletId: row['wallet_id'] as String?,
      destinationWalletId: row['destination_wallet_id'] as String?,
      categoryId: row['category_id'] as String?,
      merchant: row['merchant'] as String?,
      description: row['description'] as String?,
      notes: row['notes'] as String?,
      source: row['source'] as String? ?? 'manual',
      status: TransactionStatus.fromString(row['status'] as String? ?? 'confirmed'),
      createdAt: row['created_at'] as String,
      updatedAt: row['updated_at'] as String,
    );
  }
}

/// Fake SupabaseService untuk pengujian multi-user & autentikasi
class FakeSupabaseService extends SupabaseService {
  final sp.User _mockUser;
  bool _authenticated = true;

  FakeSupabaseService(this._mockUser);

  @override
  bool get isAuthenticated => _authenticated;

  @override
  sp.User? get currentUser => _authenticated ? _mockUser : null;

  void setAuthenticated(bool value) {
    _authenticated = value;
  }
}

void main() {
  late AppDatabase db;
  late FakeTransactionRemoteDataSource fakeRemoteDataSource;
  late FakeSupabaseService fakeSupabaseService;
  late TransactionRepositoryImpl repository;

  final testUserA = sp.User(
    id: 'user-tx-aaaa-1111',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: DateTime.now().toIso8601String(),
  );

  final testUserB = sp.User(
    id: 'user-tx-bbbb-2222',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: DateTime.now().toIso8601String(),
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    fakeRemoteDataSource = FakeTransactionRemoteDataSource();
    fakeSupabaseService = FakeSupabaseService(testUserA);

    repository = TransactionRepositoryImpl(
      db.transactionsDao,
      db.walletsDao,
      db.categoriesDao,
      remoteDataSource: fakeRemoteDataSource,
      supabaseService: fakeSupabaseService,
    );

    // Seed wallet dan kategori di SQLite lokal untuk validasi
    final now = DateTime.now().toUtc().toIso8601String();
    await db.walletsDao.insertWallet(
      WalletsTableCompanion.insert(
        id: 'w-cash-main',
        name: 'Dompet Utama',
        type: 'cash',
        openingBalance: 1000000,
        openingDate: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.walletsDao.insertWallet(
      WalletsTableCompanion.insert(
        id: 'w-bank-bca',
        name: 'BCA Tabungan',
        type: 'bank',
        openingBalance: 5000000,
        openingDate: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Transaction Cloud Repository & RLS Verification Suite', () {
    final now = DateTime.now().toUtc().toIso8601String();

    // 1. Test load Transactions
    test('1. Test load Transactions: loads recent transactions with wallet & category details', () async {
      await repository.createTransaction(Transaction(
        id: 'tx-load-1',
        type: TransactionType.expense,
        amount: 50000,
        occurredAt: now,
        walletId: 'w-cash-main',
        categoryId: 'cat-exp-food',
        description: 'Makan siang',
        createdAt: now,
        updatedAt: now,
      ));

      final recents = await repository.getRecentTransactions(limit: 10);
      expect(recents.length, equals(1));
      expect(recents.first.transaction.id, equals('tx-load-1'));
      expect(recents.first.wallet?.name, equals('Dompet Utama'));
      expect(recents.first.category?.name, equals('Makanan & Minuman'));
    });

    // 2. Test create Transactions (Income, Expense, Transfer)
    test('2. Test create Transactions: creates income, expense, and transfer with strict validation', () async {
      // Expense
      await repository.createTransaction(Transaction(
        id: 'tx-exp-1',
        type: TransactionType.expense,
        amount: 25000,
        occurredAt: now,
        walletId: 'w-cash-main',
        categoryId: 'cat-exp-food',
        createdAt: now,
        updatedAt: now,
      ));

      // Transfer antar dompet
      await repository.createTransaction(Transaction(
        id: 'tx-trf-1',
        type: TransactionType.transfer,
        amount: 200000,
        occurredAt: now,
        walletId: 'w-cash-main',
        destinationWalletId: 'w-bank-bca',
        createdAt: now,
        updatedAt: now,
      ));

      // Verifikasi di cloud data source
      final cloudExp = await fakeRemoteDataSource.getTransactionById('tx-exp-1', testUserA.id);
      expect(cloudExp, isNotNull);
      expect(cloudExp!.amount, equals(25000));

      final cloudTrf = await fakeRemoteDataSource.getTransactionById('tx-trf-1', testUserA.id);
      expect(cloudTrf, isNotNull);
      expect(cloudTrf!.destinationWalletId, equals('w-bank-bca'));

      // Validasi nominal <= 0 harus ditolak
      expect(
        () => repository.createTransaction(Transaction(
          id: 'tx-invalid-amt',
          type: TransactionType.expense,
          amount: 0,
          occurredAt: now,
          walletId: 'w-cash-main',
          categoryId: 'cat-exp-food',
          createdAt: now,
          updatedAt: now,
        )),
        throwsA(isA<ValidationFailure>()),
      );

      // Validasi transfer ke dompet yang sama harus ditolak
      expect(
        () => repository.createTransaction(Transaction(
          id: 'tx-same-wallet',
          type: TransactionType.transfer,
          amount: 100000,
          occurredAt: now,
          walletId: 'w-cash-main',
          destinationWalletId: 'w-cash-main',
          createdAt: now,
          updatedAt: now,
        )),
        throwsA(isA<ValidationFailure>()),
      );
    });

    // 3. Test edit Transactions
    test('3. Test edit Transactions: updates transaction details successfully in local and cloud', () async {
      const originalTx = Transaction(
        id: 'tx-edit-target',
        type: TransactionType.expense,
        amount: 40000,
        occurredAt: '2026-11-20T10:00:00.000Z',
        walletId: 'w-cash-main',
        categoryId: 'cat-exp-food',
        description: 'Sarapan pagi',
        createdAt: '2026-11-20T10:00:00.000Z',
        updatedAt: '2026-11-20T10:00:00.000Z',
      );
      await repository.createTransaction(originalTx);

      final updatedTx = originalTx.copyWith(
        amount: 45000,
        description: 'Sarapan pagi & kopi',
      );
      await repository.updateTransaction(updatedTx);

      final fetched = await repository.getTransactionById(originalTx.id);
      expect(fetched?.amount, equals(45000));
      expect(fetched?.description, equals('Sarapan pagi & kopi'));

      final cloudFetched = await fakeRemoteDataSource.getTransactionById(originalTx.id, testUserA.id);
      expect(cloudFetched?.amount, equals(45000));
      expect(cloudFetched?.description, equals('Sarapan pagi & kopi'));
    });

    // 4. Test delete Transactions (Hard Delete & Void Transaction)
    test('4. Test delete Transactions: voids status and hard deletes transaction properly', () async {
      const tx = Transaction(
        id: 'tx-del-target',
        type: TransactionType.income,
        amount: 1000000,
        occurredAt: '2026-11-15T08:00:00.000Z',
        walletId: 'w-bank-bca',
        categoryId: 'cat-inc-salary',
        createdAt: '2026-11-15T08:00:00.000Z',
        updatedAt: '2026-11-15T08:00:00.000Z',
      );
      await repository.createTransaction(tx);

      // Void transaksi
      await repository.voidTransaction(tx.id);
      final voidedLocal = await repository.getTransactionById(tx.id);
      expect(voidedLocal?.status, equals(TransactionStatus.voided));
      final voidedCloud = await fakeRemoteDataSource.getTransactionById(tx.id, testUserA.id);
      expect(voidedCloud?.status, equals(TransactionStatus.voided));

      // Hard delete transaksi
      await repository.deleteTransaction(tx.id);
      final deletedLocal = await repository.getTransactionById(tx.id);
      expect(deletedLocal, isNull);
      final deletedCloud = await fakeRemoteDataSource.getTransactionById(tx.id, testUserA.id);
      expect(deletedCloud, isNull);
    });

    // 5. Test Transactions detail
    test('5. Test Transactions detail: retrieves transaction with full details by ID', () async {
      await repository.createTransaction(Transaction(
        id: 'tx-detail-test',
        type: TransactionType.expense,
        amount: 75000,
        occurredAt: now,
        walletId: 'w-cash-main',
        categoryId: 'cat-exp-food',
        merchant: 'Kopi Kenangan',
        createdAt: now,
        updatedAt: now,
      ));

      final details = await repository.getTransactionWithDetailsById('tx-detail-test');
      expect(details, isNotNull);
      expect(details!.transaction.merchant, equals('Kopi Kenangan'));
      expect(details.wallet?.id, equals('w-cash-main'));
      expect(details.category?.id, equals('cat-exp-food'));
    });

    // 6. Test Transactions balance (Monthly Income & Monthly Expense)
    test('6. Test Transactions balance: accurately calculates monthly income & expense totals', () async {
      // Pemasukan bulan November 2026
      await repository.createTransaction(const Transaction(
        id: 'tx-bal-inc-1',
        type: TransactionType.income,
        amount: 8000000,
        occurredAt: '2026-11-01T09:00:00.000Z',
        walletId: 'w-bank-bca',
        categoryId: 'cat-inc-salary',
        createdAt: '2026-11-01T09:00:00.000Z',
        updatedAt: '2026-11-01T09:00:00.000Z',
      ));

      // Pengeluaran bulan November 2026
      await repository.createTransaction(const Transaction(
        id: 'tx-bal-exp-1',
        type: TransactionType.expense,
        amount: 250000,
        occurredAt: '2026-11-10T12:00:00.000Z',
        walletId: 'w-cash-main',
        categoryId: 'cat-exp-food',
        createdAt: '2026-11-10T12:00:00.000Z',
        updatedAt: '2026-11-10T12:00:00.000Z',
      ));

      final incomeTotal = await repository.getMonthlyIncome(2026, 11);
      final expenseTotal = await repository.getMonthlyExpense(2026, 11);

      expect(incomeTotal, equals(8000000));
      expect(expenseTotal, equals(250000));
    });

    // 7. Test Transactions selection (Date range filter & Wallet ledger)
    test('7. Test Transactions selection: filters by date range and wallet ledger', () async {
      await repository.createTransaction(const Transaction(
        id: 'tx-range-1',
        type: TransactionType.expense,
        amount: 30000,
        occurredAt: '2026-11-05T10:00:00.000Z',
        walletId: 'w-cash-main',
        categoryId: 'cat-exp-transport',
        createdAt: '2026-11-05T10:00:00.000Z',
        updatedAt: '2026-11-05T10:00:00.000Z',
      ));

      await repository.createTransaction(const Transaction(
        id: 'tx-range-2',
        type: TransactionType.expense,
        amount: 90000,
        occurredAt: '2026-11-20T15:00:00.000Z',
        walletId: 'w-bank-bca',
        categoryId: 'cat-exp-bills',
        createdAt: '2026-11-20T15:00:00.000Z',
        updatedAt: '2026-11-20T15:00:00.000Z',
      ));

      // Filter rentang tanggal
      final rangeTxs = await repository.getTransactionsInDateRange(
        DateTime.utc(2026, 11, 1),
        DateTime.utc(2026, 11, 10),
      );
      expect(rangeTxs.length, equals(1));
      expect(rangeTxs.first.transaction.id, equals('tx-range-1'));

      // Filter per wallet
      final bcaTxs = await repository.getTransactionsForWallet('w-bank-bca');
      expect(bcaTxs.length, equals(1));
      expect(bcaTxs.first.transaction.id, equals('tx-range-2'));
    });

    // 8. Test user ownership
    test('8. Test user ownership: strictly assigns authenticated user id', () async {
      await repository.createTransaction(Transaction(
        id: 'tx-owner-test',
        type: TransactionType.expense,
        amount: 15000,
        occurredAt: now,
        walletId: 'w-cash-main',
        categoryId: 'cat-exp-food',
        createdAt: now,
        updatedAt: now,
      ));

      final rawRow = fakeRemoteDataSource._cloudTable['tx-owner-test'];
      expect(rawRow?['user_id'], equals(testUserA.id));
    });

    // 9. Test RLS
    test('9. Test RLS: User A cannot see, update, or delete User B transactions', () async {
      // User B mencatat transaksi di cloud
      await fakeRemoteDataSource.createTransaction(
        Transaction(
          id: 'tx-secret-user-b',
          type: TransactionType.income,
          amount: 50000000,
          occurredAt: now,
          walletId: 'w-other',
          categoryId: 'cat-inc-salary',
          createdAt: now,
          updatedAt: now,
        ),
        testUserB.id,
      );

      // User A tidak boleh melihat transaksi User B
      final txUserA = await repository.getTransactionById('tx-secret-user-b');
      expect(txUserA, isNull);

      final recentsA = await repository.getRecentTransactions();
      expect(recentsA.any((t) => t.transaction.id == 'tx-secret-user-b'), isFalse);

      // User A tidak boleh mengubah transaksi User B
      expect(
        () => fakeRemoteDataSource.updateTransaction(
          Transaction(
            id: 'tx-secret-user-b',
            type: TransactionType.expense,
            amount: 1000,
            occurredAt: now,
            createdAt: now,
            updatedAt: now,
          ),
          testUserA.id,
        ),
        throwsA(isA<SupabaseDatabaseException>()),
      );

      // User A tidak boleh menghapus transaksi User B
      expect(
        () => fakeRemoteDataSource.deleteTransaction('tx-secret-user-b', testUserA.id),
        throwsA(isA<SupabaseDatabaseException>()),
      );
    });

    // 10. Test error handling
    test('10. Test error handling: falls back to local cache when cloud fails', () async {
      await repository.createTransaction(Transaction(
        id: 'tx-fallback-test',
        type: TransactionType.expense,
        amount: 12000,
        occurredAt: now,
        walletId: 'w-cash-main',
        categoryId: 'cat-exp-food',
        createdAt: now,
        updatedAt: now,
      ));

      // Simulasikan gangguan cloud
      fakeRemoteDataSource.shouldThrowError = true;

      // Harus fallback ke cache lokal tanpa crash
      final localRecents = await repository.getRecentTransactions();
      expect(localRecents.isNotEmpty, isTrue);
      expect(localRecents.any((t) => t.transaction.id == 'tx-fallback-test'), isTrue);
    });

    // 11. Test loading state & stream reactivity
    test('11. Test loading state: watchRecentTransactions emits immediately from local and updates upon sync', () async {
      final initialData = await repository.watchRecentTransactions().first;
      expect(initialData, isNotNull);

      // Catat transaksi baru
      await repository.createTransaction(Transaction(
        id: 'tx-stream-reactive',
        type: TransactionType.expense,
        amount: 88000,
        occurredAt: now,
        walletId: 'w-cash-main',
        categoryId: 'cat-exp-food',
        createdAt: now,
        updatedAt: now,
      ));

      final updatedData = await repository.watchRecentTransactions().first;
      expect(updatedData.any((t) => t.transaction.id == 'tx-stream-reactive'), isTrue);
    });
  });
}
