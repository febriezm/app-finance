import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import 'package:myfinance/core/database/app_database.dart';
import 'package:myfinance/core/errors/exceptions.dart';
import 'package:myfinance/core/errors/failures.dart';
import 'package:myfinance/core/services/supabase_service.dart';
import 'package:myfinance/features/wallets/domain/entities/wallet.dart';
import 'package:myfinance/features/wallets/data/repositories/wallet_repository_impl.dart';
import 'package:myfinance/features/transactions/domain/entities/transaction.dart';
import 'package:myfinance/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:myfinance/features/budgets/domain/entities/budget.dart';
import 'package:myfinance/features/budgets/data/datasources/budget_remote_data_source.dart';
import 'package:myfinance/features/budgets/data/repositories/budget_repository_impl.dart';
import 'package:myfinance/features/budgets/presentation/controllers/budgets_controller.dart';

/// Fake BudgetRemoteDataSource yang mensimulasikan Supabase PostgreSQL Cloud dengan RLS
class FakeBudgetRemoteDataSource implements BudgetRemoteDataSource {
  final Map<String, Map<String, dynamic>> _cloudBudgetsTable = {};
  final Map<String, Map<String, dynamic>> _cloudLimitsTable = {};
  bool shouldThrowError = false;

  @override
  Future<List<Budget>> getBudgets(String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Network connection timeout', 'PGRST_TIMEOUT');
    }

    // RLS: WHERE user_id = :userId
    return _cloudBudgetsTable.values
        .where((row) => row['user_id'] == userId)
        .map(_mapToBudget)
        .toList()
      ..sort((a, b) => b.monthKey.compareTo(a.monthKey));
  }

  @override
  Future<Budget?> getBudgetByMonthKey(String monthKey, String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Database query failed', '42P01');
    }

    // RLS: WHERE user_id = :userId AND month_key = :monthKey
    for (final row in _cloudBudgetsTable.values) {
      if (row['user_id'] == userId && row['month_key'] == monthKey) {
        return _mapToBudget(row);
      }
    }
    return null;
  }

  @override
  Future<Budget?> getBudgetById(String id, String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Database query failed', '42P01');
    }

    final row = _cloudBudgetsTable[id];
    if (row == null || row['user_id'] != userId) return null;
    return _mapToBudget(row);
  }

  @override
  Future<List<BudgetCategoryLimit>> getCategoryLimits(String budgetId, String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Database query failed', '42P01');
    }

    // RLS: WHERE user_id = :userId AND budget_id = :budgetId
    return _cloudLimitsTable.values
        .where((row) => row['user_id'] == userId && row['budget_id'] == budgetId)
        .map(_mapToLimit)
        .toList();
  }

  @override
  Future<void> saveBudget({
    required Budget budget,
    required List<BudgetCategoryLimit> categoryLimits,
    required String userId,
  }) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Failed to save budget in cloud', '23505');
    }

    // Upsert pada uq_budgets_user_month (user_id, month_key)
    String effectiveId = budget.id;
    for (final existing in _cloudBudgetsTable.values) {
      if (existing['user_id'] == userId && existing['month_key'] == budget.monthKey) {
        effectiveId = existing['id'] as String;
        break;
      }
    }

    _cloudBudgetsTable[effectiveId] = {
      'id': effectiveId,
      'user_id': userId,
      'month_key': budget.monthKey,
      'total_limit': budget.totalLimit,
      'alert_thresholds': budget.alertThresholds,
      'carry_over_enabled': budget.carryOverEnabled,
      'notes': budget.notes,
      'created_at': budget.createdAt,
      'updated_at': budget.updatedAt,
    };

    // Bersihkan limit kategori lama untuk budget ini
    _cloudLimitsTable.removeWhere(
      (key, row) => row['user_id'] == userId && row['budget_id'] == effectiveId,
    );

    // Masukkan limit kategori baru
    for (final limit in categoryLimits) {
      _cloudLimitsTable[limit.id] = {
        'id': limit.id,
        'user_id': userId,
        'budget_id': effectiveId,
        'category_id': limit.categoryId,
        'limit_amount': limit.limitAmount,
      };
    }
  }

  @override
  Future<void> deleteBudget(String budgetId, String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Failed to delete budget in cloud', '42501');
    }

    final row = _cloudBudgetsTable[budgetId];
    if (row != null && row['user_id'] == userId) {
      _cloudBudgetsTable.remove(budgetId);
      _cloudLimitsTable.removeWhere(
        (key, limit) => limit['budget_id'] == budgetId && limit['user_id'] == userId,
      );
    }
  }

  Budget _mapToBudget(Map<String, dynamic> row) {
    return Budget(
      id: row['id'] as String,
      monthKey: row['month_key'] as String,
      totalLimit: row['total_limit'] as int,
      alertThresholds: (row['alert_thresholds'] as List<dynamic>).cast<int>(),
      carryOverEnabled: row['carry_over_enabled'] as bool? ?? false,
      notes: row['notes'] as String?,
      createdAt: row['created_at'] as String? ?? '',
      updatedAt: row['updated_at'] as String? ?? '',
    );
  }

  BudgetCategoryLimit _mapToLimit(Map<String, dynamic> row) {
    return BudgetCategoryLimit(
      id: row['id'] as String,
      budgetId: row['budget_id'] as String,
      categoryId: row['category_id'] as String,
      limitAmount: row['limit_amount'] as int,
    );
  }
}

/// Fake SupabaseService untuk mock authenticated user session
class FakeSupabaseService extends SupabaseService {
  String? _fakeUid;
  bool _fakeIsAuth = false;

  void setAuthenticatedUser(String uid) {
    _fakeUid = uid;
    _fakeIsAuth = true;
  }

  void clearSession() {
    _fakeUid = null;
    _fakeIsAuth = false;
  }

  @override
  bool get isAuthenticated => _fakeIsAuth;

  @override
  sp.User? get currentUser => _fakeIsAuth && _fakeUid != null
      ? sp.User(
          id: _fakeUid!,
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        )
      : null;
}

void main() {
  late AppDatabase db;
  late WalletRepositoryImpl walletRepo;
  late TransactionRepositoryImpl txRepo;
  late FakeBudgetRemoteDataSource fakeRemoteDataSource;
  late FakeSupabaseService fakeSupabaseService;
  late BudgetRepositoryImpl budgetRepo;

  const testUserId = 'user-uuid-111';
  const otherUserId = 'user-uuid-222';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    walletRepo = WalletRepositoryImpl(db.walletsDao, db.transactionsDao);
    txRepo = TransactionRepositoryImpl(db.transactionsDao, db.walletsDao, db.categoriesDao);
    fakeRemoteDataSource = FakeBudgetRemoteDataSource();
    fakeSupabaseService = FakeSupabaseService();
    fakeSupabaseService.setAuthenticatedUser(testUserId);

    budgetRepo = BudgetRepositoryImpl(
      db.budgetsDao,
      db.transactionsDao,
      db.categoriesDao,
      remoteDataSource: fakeRemoteDataSource,
      supabaseService: fakeSupabaseService,
    );

    // Setup dompet uji
    final now = DateTime.now().toUtc().toIso8601String();
    await walletRepo.createWallet(
      Wallet(
        id: 'w-1',
        name: 'Rekening Utama',
        type: WalletType.bank,
        openingBalance: 10000000,
        openingDate: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Domain Budgets — 12 Poin Pengujian Komprehensif', () {
    // 1. Test load Budgets
    test('1. Test load Budgets: mengambil data anggaran master dan daftar budget dari cloud', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      final budget = Budget(
        id: 'b-2026-11',
        monthKey: '2026-11',
        totalLimit: 5000000,
        alertThresholds: const [75, 90, 100],
        createdAt: now,
        updatedAt: now,
      );
      final limits = [
        const BudgetCategoryLimit(
          id: 'l-1',
          budgetId: 'b-2026-11',
          categoryId: 'cat-exp-food',
          limitAmount: 2000000,
        ),
      ];

      await fakeRemoteDataSource.saveBudget(
        budget: budget,
        categoryLimits: limits,
        userId: testUserId,
      );

      final loaded = await budgetRepo.getBudgetByMonthKey('2026-11');
      expect(loaded, isNotNull);
      expect(loaded!.id, equals('b-2026-11'));
      expect(loaded.totalLimit, equals(5000000));

      final allBudgets = await budgetRepo.getAllBudgets();
      expect(allBudgets.length, equals(1));
      expect(allBudgets.first.monthKey, equals('2026-11'));
    });

    // 2. Test create Budgets
    test('2. Test create Budgets: mencatat master budget dan limit kategori ke SQLite dan Supabase', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      final budget = Budget(
        id: 'b-create-1',
        monthKey: '2026-12',
        totalLimit: 3000000,
        notes: 'Anggaran liburan akhir tahun',
        createdAt: now,
        updatedAt: now,
      );
      final limits = [
        const BudgetCategoryLimit(
          id: 'l-create-1',
          budgetId: 'b-create-1',
          categoryId: 'cat-exp-food',
          limitAmount: 1500000,
        ),
        const BudgetCategoryLimit(
          id: 'l-create-2',
          budgetId: 'b-create-1',
          categoryId: 'cat-exp-transport',
          limitAmount: 800000,
        ),
      ];

      await budgetRepo.saveBudget(budget: budget, categoryLimits: limits);

      // Verifikasi SQLite lokal
      final localBudget = await db.budgetsDao.getBudgetByMonthKey('2026-12');
      expect(localBudget, isNotNull);
      expect(localBudget!.totalLimit, equals(3000000));
      expect(localBudget.notes, equals('Anggaran liburan akhir tahun'));

      final localLimits = await db.budgetsDao.getCategoryLimitsForBudget('b-create-1');
      expect(localLimits.length, equals(2));

      // Verifikasi Cloud Supabase
      final cloudBudget = await fakeRemoteDataSource.getBudgetByMonthKey('2026-12', testUserId);
      expect(cloudBudget, isNotNull);
      expect(cloudBudget!.totalLimit, equals(3000000));

      final cloudLimits = await fakeRemoteDataSource.getCategoryLimits('b-create-1', testUserId);
      expect(cloudLimits.length, equals(2));
    });

    // 3. Test edit Budgets
    test('3. Test edit Budgets: memperbarui total plafon anggaran dan limit kategori di lokal dan cloud', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      final budget = Budget(
        id: 'b-edit-1',
        monthKey: '2026-11',
        totalLimit: 4000000,
        createdAt: now,
        updatedAt: now,
      );
      final limits = [
        const BudgetCategoryLimit(
          id: 'l-edit-1',
          budgetId: 'b-edit-1',
          categoryId: 'cat-exp-food',
          limitAmount: 2000000,
        ),
      ];
      await budgetRepo.saveBudget(budget: budget, categoryLimits: limits);

      // Edit plafon menjadi 6.000.000 dan update limit kategori
      final updatedBudget = budget.copyWith(totalLimit: 6000000, notes: 'Revisi plafon naik');
      final updatedLimits = [
        const BudgetCategoryLimit(
          id: 'l-edit-1-rev',
          budgetId: 'b-edit-1',
          categoryId: 'cat-exp-food',
          limitAmount: 3000000,
        ),
      ];

      await budgetRepo.saveBudget(budget: updatedBudget, categoryLimits: updatedLimits);

      final localResult = await db.budgetsDao.getBudgetByMonthKey('2026-11');
      expect(localResult!.totalLimit, equals(6000000));
      expect(localResult.notes, equals('Revisi plafon naik'));

      final cloudResult = await fakeRemoteDataSource.getBudgetByMonthKey('2026-11', testUserId);
      expect(cloudResult!.totalLimit, equals(6000000));

      final cloudLimits = await fakeRemoteDataSource.getCategoryLimits('b-edit-1', testUserId);
      expect(cloudLimits.first.limitAmount, equals(3000000));
    });

    // 4. Test delete Budgets
    test('4. Test delete Budgets: menghapus master budget beserta limit kategori dari lokal dan cloud', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      final budget = Budget(
        id: 'b-del-1',
        monthKey: '2026-10',
        totalLimit: 2000000,
        createdAt: now,
        updatedAt: now,
      );
      final limits = [
        const BudgetCategoryLimit(
          id: 'l-del-1',
          budgetId: 'b-del-1',
          categoryId: 'cat-exp-food',
          limitAmount: 1000000,
        ),
      ];
      await budgetRepo.saveBudget(budget: budget, categoryLimits: limits);

      // Hapus anggaran
      await budgetRepo.deleteBudget('b-del-1');

      // Verifikasi terhapus dari SQLite
      final localB = await db.budgetsDao.getBudgetById('b-del-1');
      expect(localB, isNull);
      final localLimits = await db.budgetsDao.getCategoryLimitsForBudget('b-del-1');
      expect(localLimits.isEmpty, isTrue);

      // Verifikasi terhapus dari Cloud
      final cloudB = await fakeRemoteDataSource.getBudgetById('b-del-1', testUserId);
      expect(cloudB, isNull);
      final cloudL = await fakeRemoteDataSource.getCategoryLimits('b-del-1', testUserId);
      expect(cloudL.isEmpty, isTrue);
    });

    // 5. Test Budgets detail
    test('5. Test Budgets detail: mengambil detail anggaran lengkap dengan konfigurasi threshold', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      final budget = Budget(
        id: 'b-det-1',
        monthKey: '2026-11',
        totalLimit: 5000000,
        alertThresholds: const [50, 80, 100],
        carryOverEnabled: true,
        notes: 'Detail test',
        createdAt: now,
        updatedAt: now,
      );
      await budgetRepo.saveBudget(budget: budget, categoryLimits: []);

      final detail = await budgetRepo.getBudgetById('b-det-1');
      expect(detail, isNotNull);
      expect(detail!.alertThresholds, equals([50, 80, 100]));
      expect(detail.carryOverEnabled, isTrue);
      expect(detail.notes, equals('Detail test'));
    });

    // 6. Test Budgets balance
    test('6. Test Budgets balance: totalSpent strictly hanya menghitung pengeluaran (confirmed expense)', () async {
      final nowUtc = DateTime.utc(2026, 11, 10, 10, 0, 0).toIso8601String();

      // Buat budget 1.000.000
      await budgetRepo.saveBudget(
        budget: Budget(
          id: 'b-bal-1',
          monthKey: '2026-11',
          totalLimit: 1000000,
          createdAt: nowUtc,
          updatedAt: nowUtc,
        ),
        categoryLimits: [
          const BudgetCategoryLimit(
            id: 'l-bal-1',
            budgetId: 'b-bal-1',
            categoryId: 'cat-exp-food',
            limitAmount: 500000,
          ),
        ],
      );

      // 1. Pengeluaran terkonfirmasi (300.000)
      await txRepo.createTransaction(
        Transaction(
          id: 'tx-exp-1',
          type: TransactionType.expense,
          amount: 300000,
          occurredAt: nowUtc,
          walletId: 'w-1',
          categoryId: 'cat-exp-food',
          createdAt: nowUtc,
          updatedAt: nowUtc,
        ),
      );

      // 2. Pemasukan (2.000.000) - TIDAK boleh menambah kuota atau mengurangi totalSpent
      await txRepo.createTransaction(
        Transaction(
          id: 'tx-inc-1',
          type: TransactionType.income,
          amount: 2000000,
          occurredAt: nowUtc,
          walletId: 'w-1',
          categoryId: 'cat-inc-salary',
          createdAt: nowUtc,
          updatedAt: nowUtc,
        ),
      );

      // 3. Transfer (500.000) - TIDAK boleh mengurangi kuota anggaran
      await txRepo.createTransaction(
        Transaction(
          id: 'tx-tr-1',
          type: TransactionType.transfer,
          amount: 500000,
          occurredAt: nowUtc,
          walletId: 'w-1',
          merchant: 'Transfer Rekanan',
          createdAt: nowUtc,
          updatedAt: nowUtc,
        ),
      );

      final progress = await budgetRepo.getBudgetProgress('2026-11');
      expect(progress.totalLimit, equals(1000000));
      expect(progress.totalSpent, equals(300000)); // Hanya expense yang dihitung
      expect(progress.remaining, equals(700000)); // 1.000.000 - 300.000
      expect(progress.percentage, closeTo(0.30, 0.001));

      // Kategori Food
      final foodProgress = progress.categoryProgresses.first;
      expect(foodProgress.spentAmount, equals(300000));
      expect(foodProgress.remainingAmount, equals(200000)); // 500.000 - 300.000
    });

    // 7. Test Budgets selection
    test('7. Test Budgets selection: memilih anggaran berdasarkan bulan unik (monthKey)', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      await budgetRepo.saveBudget(
        budget: Budget(
          id: 'b-nov',
          monthKey: '2026-11',
          totalLimit: 2500000,
          createdAt: now,
          updatedAt: now,
        ),
        categoryLimits: [],
      );
      await budgetRepo.saveBudget(
        budget: Budget(
          id: 'b-dec',
          monthKey: '2026-12',
          totalLimit: 4000000,
          createdAt: now,
          updatedAt: now,
        ),
        categoryLimits: [],
      );

      final nov = await budgetRepo.getBudgetByMonthKey('2026-11');
      final dec = await budgetRepo.getBudgetByMonthKey('2026-12');

      expect(nov!.totalLimit, equals(2500000));
      expect(dec!.totalLimit, equals(4000000));
    });

    // 8. Test user ownership
    test('8. Test user ownership: seluruh budget dan limit tersimpan dengan user_id pengguna terautentikasi', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      await budgetRepo.saveBudget(
        budget: Budget(
          id: 'b-owner',
          monthKey: '2026-11',
          totalLimit: 1000000,
          createdAt: now,
          updatedAt: now,
        ),
        categoryLimits: [
          const BudgetCategoryLimit(
            id: 'l-owner',
            budgetId: 'b-owner',
            categoryId: 'cat-exp-food',
            limitAmount: 500000,
          ),
        ],
      );

      final cloudBudget = fakeRemoteDataSource._cloudBudgetsTable['b-owner'];
      expect(cloudBudget!['user_id'], equals(testUserId));

      final cloudLimit = fakeRemoteDataSource._cloudLimitsTable['l-owner'];
      expect(cloudLimit!['user_id'], equals(testUserId));
    });

    // 9. Test RLS
    test('9. Test RLS: user tidak dapat membaca atau memodifikasi budget milik pengguna lain', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      await fakeRemoteDataSource.saveBudget(
        budget: Budget(
          id: 'b-other-user',
          monthKey: '2026-11',
          totalLimit: 9000000,
          createdAt: now,
          updatedAt: now,
        ),
        categoryLimits: [],
        userId: otherUserId,
      );

      // User aktif tidak dapat mengakses data user lain
      final fetched = await fakeRemoteDataSource.getBudgetByMonthKey('2026-11', testUserId);
      expect(fetched, isNull);

      final all = await fakeRemoteDataSource.getBudgets(testUserId);
      expect(all.any((b) => b.id == 'b-other-user'), isFalse);
    });

    // 10. Test error handling
    test('10. Test error handling: validasi gagal jika total limit <= 0 atau format bulan salah', () async {
      final now = DateTime.now().toUtc().toIso8601String();

      // Total limit 0
      expect(
        () => budgetRepo.saveBudget(
          budget: Budget(
            id: 'err-1',
            monthKey: '2026-11',
            totalLimit: 0,
            createdAt: now,
            updatedAt: now,
          ),
          categoryLimits: [],
        ),
        throwsA(isA<ValidationFailure>()),
      );

      // Format bulan tidak valid
      expect(
        () => budgetRepo.saveBudget(
          budget: Budget(
            id: 'err-2',
            monthKey: 'November-2026',
            totalLimit: 1000000,
            createdAt: now,
            updatedAt: now,
          ),
          categoryLimits: [],
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    // 11. Test loading state
    test('11. Test loading state: BudgetsController mengelola loading dan error state dengan benar', () async {
      final controller = BudgetsController(budgetRepo);
      expect(controller.state.isLoading, isFalse);

      final success = await controller.saveBudget(
        monthKey: '2026-11',
        totalLimit: 2000000,
        categoryLimitsMap: {'cat-exp-food': 1000000},
      );

      expect(success, isTrue);
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.hasError, isFalse);
    });

    // 12. Status & Thresholds
    test('12. Status & Thresholds: menghitung status peringatan (Normal, Warning, Kritis, Exceeded, dan Config Warning)', () async {
      final nowUtc = DateTime.utc(2026, 11, 1, 10, 0, 0).toIso8601String();

      // Plafon 1.000.000 dengan limit kategori 1.500.000 (menimbulkan configuration warning)
      await budgetRepo.saveBudget(
        budget: Budget(
          id: 'b-stat-1',
          monthKey: '2026-11',
          totalLimit: 1000000,
          createdAt: nowUtc,
          updatedAt: nowUtc,
        ),
        categoryLimits: [
          const BudgetCategoryLimit(
            id: 'l-stat-1',
            budgetId: 'b-stat-1',
            categoryId: 'cat-exp-food',
            limitAmount: 1500000,
          ),
        ],
      );

      var p = await budgetRepo.getBudgetProgress('2026-11');
      expect(p.status, equals(BudgetStatus.normal));
      expect(p.hasConfigurationWarning, isTrue); // 1.500.000 > 1.000.000

      // Belanja 750.000 (75%) -> Warning
      await txRepo.createTransaction(
        Transaction(
          id: 'tx-stat-75',
          type: TransactionType.expense,
          amount: 750000,
          occurredAt: nowUtc,
          walletId: 'w-1',
          categoryId: 'cat-exp-food',
          createdAt: nowUtc,
          updatedAt: nowUtc,
        ),
      );
      p = await budgetRepo.getBudgetProgress('2026-11');
      expect(p.status, equals(BudgetStatus.warning));

      // Tambah belanja 150.000 (total 900.000 = 90%) -> Critical
      await txRepo.createTransaction(
        Transaction(
          id: 'tx-stat-90',
          type: TransactionType.expense,
          amount: 150000,
          occurredAt: nowUtc,
          walletId: 'w-1',
          categoryId: 'cat-exp-food',
          createdAt: nowUtc,
          updatedAt: nowUtc,
        ),
      );
      p = await budgetRepo.getBudgetProgress('2026-11');
      expect(p.status, equals(BudgetStatus.critical));

      // Tambah belanja 150.000 (total 1.050.000 = 105%) -> Exceeded
      await txRepo.createTransaction(
        Transaction(
          id: 'tx-stat-105',
          type: TransactionType.expense,
          amount: 150000,
          occurredAt: nowUtc,
          walletId: 'w-1',
          categoryId: 'cat-exp-food',
          createdAt: nowUtc,
          updatedAt: nowUtc,
        ),
      );
      p = await budgetRepo.getBudgetProgress('2026-11');
      expect(p.status, equals(BudgetStatus.exceeded));
    });
  });
}
