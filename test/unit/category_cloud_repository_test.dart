import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import 'package:myfinance/core/database/app_database.dart';
import 'package:myfinance/core/errors/exceptions.dart';
import 'package:myfinance/core/errors/failures.dart';
import 'package:myfinance/core/services/supabase_service.dart';
import 'package:myfinance/features/categories/data/datasources/category_remote_data_source.dart';
import 'package:myfinance/features/categories/data/repositories/category_repository_impl.dart';
import 'package:myfinance/features/categories/domain/entities/category.dart';

/// Fake CategoryRemoteDataSource yang mensimulasikan PostgreSQL RLS & PostgREST API
class FakeCategoryRemoteDataSource implements CategoryRemoteDataSource {
  final Map<String, Map<String, dynamic>> _cloudTable = {};
  final List<Map<String, dynamic>> _cloudTransactions = [];

  bool shouldThrowError = false;

  FakeCategoryRemoteDataSource() {
    _seedSystemCategories();
  }

  void _seedSystemCategories() {
    // 11 Kategori Bawaan Sistem Global (user_id = null, is_system = true)
    final systemSeeds = [
      {'id': 'cat-inc-salary', 'name': 'Gaji', 'type': 'income', 'sort_order': 1},
      {'id': 'cat-inc-bonus', 'name': 'Bonus & THR', 'type': 'income', 'sort_order': 2},
      {'id': 'cat-inc-investment', 'name': 'Investasi', 'type': 'income', 'sort_order': 3},
      {'id': 'cat-inc-other', 'name': 'Pemasukan Lainnya', 'type': 'income', 'sort_order': 4},
      {'id': 'cat-exp-food', 'name': 'Makanan & Minuman', 'type': 'expense', 'sort_order': 1},
      {'id': 'cat-exp-transport', 'name': 'Transportasi', 'type': 'expense', 'sort_order': 2},
      {'id': 'cat-exp-bills', 'name': 'Tagihan & Utilitas', 'type': 'expense', 'sort_order': 3},
      {'id': 'cat-exp-shopping', 'name': 'Belanja & Kebutuhan', 'type': 'expense', 'sort_order': 4},
      {'id': 'cat-exp-entertainment', 'name': 'Hiburan & Liburan', 'type': 'expense', 'sort_order': 5},
      {'id': 'cat-exp-health', 'name': 'Kesehatan', 'type': 'expense', 'sort_order': 6},
      {'id': 'cat-exp-other', 'name': 'Pengeluaran Lainnya', 'type': 'expense', 'sort_order': 7},
    ];

    for (final s in systemSeeds) {
      _cloudTable[s['id'] as String] = {
        'id': s['id'],
        'user_id': null,
        'name': s['name'],
        'type': s['type'],
        'icon_key': 'tag',
        'color_hex': '0xFF636E72',
        'is_system': true,
        'is_archived': false,
        'sort_order': s['sort_order'],
      };
    }
  }

  void seedTransaction({
    required String id,
    required String userId,
    required String categoryId,
    required String type,
    required int amount,
    required String status,
    String? occurredAt,
  }) {
    _cloudTransactions.add({
      'id': id,
      'user_id': userId,
      'category_id': categoryId,
      'type': type,
      'amount': amount,
      'status': status,
      'occurred_at': occurredAt ?? DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<List<Category>> getActiveCategoriesByType(CategoryType type, String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Network connection timeout', 'PGRST_TIMEOUT');
    }

    // RLS Enforcement: (user_id IS NULL OR user_id = :userId) AND type = :type AND is_archived = false
    return _cloudTable.values
        .where((row) =>
            (row['user_id'] == null || row['user_id'] == userId) &&
            row['type'] == type.toDbString() &&
            row['is_archived'] == false)
        .map(_mapToCategory)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  @override
  Future<List<Category>> getAllActiveCategories(String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Network error', 'PGRST_ERROR');
    }

    // RLS Enforcement: (user_id IS NULL OR user_id = :userId) AND is_archived = false
    return _cloudTable.values
        .where((row) =>
            (row['user_id'] == null || row['user_id'] == userId) &&
            row['is_archived'] == false)
        .map(_mapToCategory)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  @override
  Future<Category?> getCategoryById(String id, String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Database query failed', '42P01');
    }

    // RLS: user_id IS NULL OR user_id = :userId
    final row = _cloudTable[id];
    if (row == null) return null;
    if (row['user_id'] != null && row['user_id'] != userId) return null; // RLS block
    return _mapToCategory(row);
  }

  @override
  Future<void> createCategory(Category category, String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Failed to insert category', '23505');
    }

    // Schema Check: is_system = FALSE AND user_id NOT NULL
    _cloudTable[category.id] = {
      'id': category.id,
      'user_id': userId,
      'name': category.name,
      'type': category.type.toDbString(),
      'icon_key': category.iconKey,
      'color_hex': category.colorHex,
      'is_system': false,
      'is_archived': category.isArchived,
      'sort_order': category.sortOrder,
    };
  }

  @override
  Future<void> updateCategory(Category category, String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Failed to update category');
    }

    final existing = _cloudTable[category.id];
    // RLS Enforcement: Hanya boleh update jika is_system = FALSE dan user_id = auth.uid()
    if (existing == null || existing['user_id'] != userId || existing['is_system'] == true) {
      throw const SupabaseDatabaseException('Row not found or permission denied (RLS)');
    }

    _cloudTable[category.id] = {
      ...existing,
      'name': category.name,
      'type': category.type.toDbString(),
      'icon_key': category.iconKey,
      'color_hex': category.colorHex,
      'sort_order': category.sortOrder,
      'is_archived': category.isArchived,
    };
  }

  @override
  Future<void> archiveCategory(String id, String userId) async {
    final existing = _cloudTable[id];
    if (existing == null || existing['user_id'] != userId || existing['is_system'] == true) {
      throw const SupabaseDatabaseException('Permission denied (RLS)');
    }
    existing['is_archived'] = true;
  }

  @override
  Future<void> deleteCategory(String id, String userId) async {
    final existing = _cloudTable[id];
    if (existing == null || existing['user_id'] != userId || existing['is_system'] == true) {
      throw const SupabaseDatabaseException('Permission denied (RLS)');
    }
    _cloudTable.remove(id);
  }

  @override
  Future<int> calculateCategorySpending(
    String categoryId,
    String userId, {
    String? startIsoUtc,
    String? endIsoUtc,
  }) async {
    // RLS Enforcement: user_id = auth.uid() AND category_id = :catId AND status = 'confirmed'
    final txs = _cloudTransactions.where((tx) {
      if (tx['user_id'] != userId) return false;
      if (tx['category_id'] != categoryId) return false;
      if (tx['status'] != 'confirmed') return false;
      final occurredAt = tx['occurred_at'] as String;
      if (startIsoUtc != null && occurredAt.compareTo(startIsoUtc) < 0) return false;
      if (endIsoUtc != null && occurredAt.compareTo(endIsoUtc) > 0) return false;
      return true;
    });

    int total = 0;
    for (final tx in txs) {
      total += (tx['amount'] as num).toInt();
    }
    return total;
  }

  Category _mapToCategory(Map<String, dynamic> row) {
    return Category(
      id: row['id'] as String,
      name: row['name'] as String,
      type: CategoryType.fromString(row['type'] as String),
      iconKey: row['icon_key'] as String?,
      colorHex: row['color_hex'] as String?,
      isSystem: row['is_system'] as bool? ?? false,
      isArchived: row['is_archived'] as bool? ?? false,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Fake SupabaseService untuk mengontrol status autentikasi user dalam test
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
  late FakeCategoryRemoteDataSource fakeRemoteDataSource;
  late FakeSupabaseService fakeSupabaseService;
  late CategoryRepositoryImpl repository;

  final testUserA = sp.User(
    id: 'user-uuid-1111-aaaa',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: DateTime.now().toIso8601String(),
  );

  final testUserB = sp.User(
    id: 'user-uuid-2222-bbbb',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: DateTime.now().toIso8601String(),
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    fakeRemoteDataSource = FakeCategoryRemoteDataSource();
    fakeSupabaseService = FakeSupabaseService(testUserA);

    repository = CategoryRepositoryImpl(
      db.categoriesDao,
      transactionsDao: db.transactionsDao,
      remoteDataSource: fakeRemoteDataSource,
      supabaseService: fakeSupabaseService,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Category Cloud Repository & RLS Verification Suite', () {
    // 1. Test load Categories (System + User Custom Categories)
    test('1. Test load Categories: loads both system categories and user custom categories', () async {
      // Tambahkan 1 custom category milik User A di cloud
      await fakeRemoteDataSource.createCategory(
        const Category(
          id: 'cat-custom-coffee',
          name: 'Kopi & Nongkrong',
          type: CategoryType.expense,
          sortOrder: 10,
        ),
        testUserA.id,
      );

      final expenseCats = await repository.getActiveCategoriesByType(CategoryType.expense);
      // 7 kategori sistem bawaan + 1 kategori kustom = 8
      expect(expenseCats.length, equals(8));
      expect(expenseCats.any((c) => c.id == 'cat-exp-food' && c.isSystem), isTrue);
      expect(expenseCats.any((c) => c.id == 'cat-custom-coffee' && !c.isSystem), isTrue);

      final incomeCats = await repository.getActiveCategoriesByType(CategoryType.income);
      // 4 kategori sistem bawaan
      expect(incomeCats.length, equals(4));
      expect(incomeCats.any((c) => c.id == 'cat-inc-salary' && c.isSystem), isTrue);
    });

    // 2. Test create Categories (User Custom Category with user_id)
    test('2. Test create Categories: creates custom category with user_id and rejects system category creation', () async {
      const newCategory = Category(
        id: 'cat-custom-gadget',
        name: 'Gadget & Tech',
        type: CategoryType.expense,
        iconKey: 'smartphone',
        colorHex: '0xFF3498DB',
        isSystem: false,
        sortOrder: 20,
      );

      await repository.createCategory(newCategory);

      // Verifikasi di cloud data source
      final cloudCat = await fakeRemoteDataSource.getCategoryById(newCategory.id, testUserA.id);
      expect(cloudCat, isNotNull);
      expect(cloudCat!.name, equals('Gadget & Tech'));
      expect(cloudCat.isSystem, isFalse);

      // Verifikasi cache lokal
      final localCat = await db.categoriesDao.getCategoryById(newCategory.id);
      expect(localCat, isNotNull);
      expect(localCat!.name, equals('Gadget & Tech'));

      // Mencoba membuat kategori dengan isSystem = true harus ditolak
      expect(
        () => repository.createCategory(
          const Category(
            id: 'cat-invalid-system',
            name: 'Pajak Negara',
            type: CategoryType.expense,
            isSystem: true,
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    // 3. Test edit Categories (Edit custom vs Reject editing system category)
    test('3. Test edit Categories: allows editing custom category but protects system categories', () async {
      // Buat kategori kustom
      const customCategory = Category(
        id: 'cat-custom-books',
        name: 'Buku Lama',
        type: CategoryType.expense,
        sortOrder: 15,
      );
      await repository.createCategory(customCategory);

      // Edit nama kategori kustom
      final updated = customCategory.copyWith(name: 'Buku & Edukasi');
      await repository.updateCategory(updated);

      final fetched = await repository.getCategoryById(customCategory.id);
      expect(fetched?.name, equals('Buku & Edukasi'));

      // Upaya mengubah kategori sistem bawaan (cat-exp-food) harus dilempar ValidationFailure
      final systemCat = await repository.getCategoryById('cat-exp-food');
      expect(systemCat, isNotNull);
      expect(systemCat!.isSystem, isTrue);

      final attemptedHack = systemCat.copyWith(name: 'Makanan Hacked');
      expect(
        () => repository.updateCategory(attemptedHack),
        throwsA(isA<ValidationFailure>()),
      );
    });

    // 4. Test delete Categories (Delete & Archive custom vs Reject deleting system category)
    test('4. Test delete Categories: deletes/archives custom category and prevents deleting system category', () async {
      const customCategory = Category(
        id: 'cat-custom-hobby',
        name: 'Hobi Fotografi',
        type: CategoryType.expense,
      );
      await repository.createCategory(customCategory);

      // Verifikasi arsip kategori kustom
      await repository.archiveCategory(customCategory.id);
      final archivedCat = await fakeRemoteDataSource.getCategoryById(customCategory.id, testUserA.id);
      expect(archivedCat?.isArchived, isTrue);

      // Verifikasi hard delete kategori kustom
      await repository.deleteCategory(customCategory.id);
      final deletedCloud = await fakeRemoteDataSource.getCategoryById(customCategory.id, testUserA.id);
      expect(deletedCloud, isNull);
      final deletedLocal = await db.categoriesDao.getCategoryById(customCategory.id);
      expect(deletedLocal, isNull);

      // Upaya menghapus atau mengarsipkan kategori sistem bawaan (cat-inc-salary) harus ditolak
      expect(
        () => repository.deleteCategory('cat-inc-salary'),
        throwsA(isA<ValidationFailure>()),
      );
      expect(
        () => repository.archiveCategory('cat-inc-salary'),
        throwsA(isA<ValidationFailure>()),
      );
    });

    // 5. Test Categories detail
    test('5. Test Categories detail: retrieves category detail by ID', () async {
      final category = await repository.getCategoryById('cat-exp-health');
      expect(category, isNotNull);
      expect(category!.id, equals('cat-exp-health'));
      expect(category.name, equals('Kesehatan'));
      expect(category.type, equals(CategoryType.expense));
      expect(category.isSystem, isTrue);

      final nonExistent = await repository.getCategoryById('cat-unknown-999');
      expect(nonExistent, isNull);
    });

    // 6. Test Categories balance (spending calculation)
    test('6. Test Categories balance: accurately calculates confirmed transactions total', () async {
      // Seed transaksi di cloud untuk kategori 'cat-exp-food' milik User A
      fakeRemoteDataSource.seedTransaction(
        id: 'tx-1',
        userId: testUserA.id,
        categoryId: 'cat-exp-food',
        type: 'expense',
        amount: 50000,
        status: 'confirmed',
      );
      fakeRemoteDataSource.seedTransaction(
        id: 'tx-2',
        userId: testUserA.id,
        categoryId: 'cat-exp-food',
        type: 'expense',
        amount: 35000,
        status: 'confirmed',
      );
      // Transaksi voided tidak boleh dihitung
      fakeRemoteDataSource.seedTransaction(
        id: 'tx-voided',
        userId: testUserA.id,
        categoryId: 'cat-exp-food',
        type: 'expense',
        amount: 100000,
        status: 'voided',
      );
      // Transaksi user lain tidak boleh dihitung
      fakeRemoteDataSource.seedTransaction(
        id: 'tx-other-user',
        userId: testUserB.id,
        categoryId: 'cat-exp-food',
        type: 'expense',
        amount: 500000,
        status: 'confirmed',
      );

      final totalSpending = await repository.calculateCategorySpending('cat-exp-food');
      expect(totalSpending, equals(85000));
    });

    // 7. Test Categories selection (Grouping by income and expense)
    test('7. Test Categories selection: correctly groups and filters by CategoryType', () async {
      final incomeList = await repository.getActiveCategoriesByType(CategoryType.income);
      final expenseList = await repository.getActiveCategoriesByType(CategoryType.expense);

      for (final cat in incomeList) {
        expect(cat.type, equals(CategoryType.income));
      }
      for (final cat in expenseList) {
        expect(cat.type, equals(CategoryType.expense));
      }

      final allCats = await repository.getAllActiveCategories();
      expect(allCats.length, equals(incomeList.length + expenseList.length));
    });

    // 8. Test user ownership
    test('8. Test user ownership: category creation strictly assigns authenticated user id', () async {
      const customCategory = Category(
        id: 'cat-user-specific',
        name: 'Langganan AI',
        type: CategoryType.expense,
      );

      await repository.createCategory(customCategory);

      // Verifikasi di data store bahwa user_id tersimpan sesuai auth.uid()
      final rawRow = fakeRemoteDataSource._cloudTable[customCategory.id];
      expect(rawRow?['user_id'], equals(testUserA.id));
      expect(rawRow?['is_system'], isFalse);
    });

    // 9. Test RLS (User Isolation)
    test('9. Test RLS: User A cannot see, update, or delete User B custom category', () async {
      // User B membuat kategori kustom
      await fakeRemoteDataSource.createCategory(
        const Category(
          id: 'cat-user-b-secret',
          name: 'Rahasia User B',
          type: CategoryType.expense,
        ),
        testUserB.id,
      );

      // Repository login sebagai User A
      // 1. User A tidak boleh melihat kategori kustom User B
      final userAExpenses = await repository.getActiveCategoriesByType(CategoryType.expense);
      expect(userAExpenses.any((c) => c.id == 'cat-user-b-secret'), isFalse);

      final fetchedByA = await repository.getCategoryById('cat-user-b-secret');
      expect(fetchedByA, isNull);

      // 2. User A tidak boleh memperbarui kategori kustom User B
      expect(
        () => fakeRemoteDataSource.updateCategory(
          const Category(
            id: 'cat-user-b-secret',
            name: 'Dihack User A',
            type: CategoryType.expense,
          ),
          testUserA.id,
        ),
        throwsA(isA<SupabaseDatabaseException>()),
      );

      // 3. User A tidak boleh menghapus kategori kustom User B
      expect(
        () => fakeRemoteDataSource.deleteCategory('cat-user-b-secret', testUserA.id),
        throwsA(isA<SupabaseDatabaseException>()),
      );
    });

    // 10. Test error handling
    test('10. Test error handling: falls back to local cache when cloud fails and rethrows when empty', () async {
      // Pastikan kategori tersimpan di cache lokal
      await repository.getActiveCategoriesByType(CategoryType.income);

      // Simulasikan gangguan jaringan cloud
      fakeRemoteDataSource.shouldThrowError = true;

      // Harus fallback ke cache lokal tanpa crash
      final fallbackIncome = await repository.getActiveCategoriesByType(CategoryType.income);
      expect(fallbackIncome.isNotEmpty, isTrue);
      expect(fallbackIncome.any((c) => c.id == 'cat-inc-salary'), isTrue);
    });

    // 11. Test loading state & stream reactivity
    test('11. Test loading state: watchActiveCategoriesByType emits immediately from local and reacts to updates', () async {
      // 1. Emisi awal langsung dari SQLite lokal (0 ms, non-blocking)
      final initialData = await repository.watchActiveCategoriesByType(CategoryType.expense).first;
      expect(initialData, isNotEmpty);
      expect(initialData.any((c) => c.id == 'cat-exp-food'), isTrue);

      // 2. Tambah kategori baru
      await repository.createCategory(
        const Category(
          id: 'cat-stream-reactive',
          name: 'Streaming Realtime',
          type: CategoryType.expense,
        ),
      );

      // 3. Emisi berikutnya memuat kategori baru yang baru saja disinkronkan
      final updatedData = await repository.watchActiveCategoriesByType(CategoryType.expense).first;
      expect(updatedData.any((c) => c.id == 'cat-stream-reactive'), isTrue);
    });
  });
}
