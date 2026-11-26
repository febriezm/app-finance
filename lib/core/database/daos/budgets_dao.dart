import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/budgets_table.dart';
import '../tables/budget_category_limits_table.dart';

part 'budgets_dao.g.dart';

@DriftAccessor(tables: [BudgetsTable, BudgetCategoryLimitsTable])
class BudgetsDao extends DatabaseAccessor<AppDatabase> with _$BudgetsDaoMixin {
  BudgetsDao(super.db);

  /// Mengambil budget berdasarkan bulan (YYYY-MM)
  Future<BudgetEntry?> getBudgetByMonthKey(String monthKey) {
    return (select(budgetsTable)..where((t) => t.monthKey.equals(monthKey))).getSingleOrNull();
  }

  /// Mengambil budget berdasarkan ID
  Future<BudgetEntry?> getBudgetById(String id) {
    return (select(budgetsTable)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Mengambil seluruh data budget
  Future<List<BudgetEntry>> getAllBudgets() {
    return (select(budgetsTable)..orderBy([(t) => OrderingTerm.desc(t.monthKey)])).get();
  }

  /// Watch seluruh data budget
  Stream<List<BudgetEntry>> watchAllBudgets() {
    return (select(budgetsTable)..orderBy([(t) => OrderingTerm.desc(t.monthKey)])).watch();
  }

  /// Watch stream budget berdasarkan bulan (YYYY-MM)
  Stream<BudgetEntry?> watchBudgetByMonthKey(String monthKey) {
    return (select(budgetsTable)..where((t) => t.monthKey.equals(monthKey))).watchSingleOrNull();
  }

  /// Insert budget bulanan
  Future<int> insertBudget(BudgetsTableCompanion budget) {
    return into(budgetsTable).insert(budget);
  }

  /// Insert atau replace budget (untuk sinkronisasi cloud)
  Future<int> insertOrReplaceBudget(BudgetsTableCompanion budget) {
    return into(budgetsTable).insertOnConflictUpdate(budget);
  }

  /// Update budget bulanan
  Future<bool> updateBudget(BudgetsTableCompanion budget) {
    return (update(budgetsTable)..where((t) => t.id.equals(budget.id.value)))
        .write(budget)
        .then((rows) => rows > 0);
  }

  /// Hapus budget bulanan berdasarkan ID
  Future<int> deleteBudget(String id) {
    return (delete(budgetsTable)..where((t) => t.id.equals(id))).go();
  }

  /// Ambil seluruh limit kategori untuk suatu budget
  Future<List<BudgetCategoryLimitEntry>> getCategoryLimitsForBudget(String budgetId) {
    return (select(budgetCategoryLimitsTable)
          ..where((t) => t.budgetId.equals(budgetId)))
        .get();
  }

  /// Watch limit kategori untuk suatu budget
  Stream<List<BudgetCategoryLimitEntry>> watchCategoryLimitsForBudget(String budgetId) {
    return (select(budgetCategoryLimitsTable)
          ..where((t) => t.budgetId.equals(budgetId)))
        .watch();
  }

  /// Insert atau replace limit kategori
  Future<int> insertOrReplaceCategoryLimit(BudgetCategoryLimitsTableCompanion limit) {
    return into(budgetCategoryLimitsTable).insertOnConflictUpdate(limit);
  }

  /// Hapus limit kategori tertentu
  Future<int> deleteCategoryLimit(String id) {
    return (delete(budgetCategoryLimitsTable)..where((t) => t.id.equals(id))).go();
  }

  /// Hapus semua limit kategori untuk suatu budget
  Future<int> deleteCategoryLimitsForBudget(String budgetId) {
    return (delete(budgetCategoryLimitsTable)..where((t) => t.budgetId.equals(budgetId))).go();
  }

  /// Watch seluruh limit kategori
  Stream<List<BudgetCategoryLimitEntry>> watchAllCategoryLimits() {
    return select(budgetCategoryLimitsTable).watch();
  }

  /// Simpan master budget dan seluruh limit kategori dalam satu transaksi atomik.
  /// Menjamin seluruh kategori tersimpan secara konsisten dan stream baru dipicu
  /// setelah seluruh data berhasil di-commit ke basis data.
  Future<void> saveBudgetWithLimits({
    required BudgetsTableCompanion budget,
    required bool isUpdate,
    required String effectiveBudgetId,
    required List<BudgetCategoryLimitsTableCompanion> limits,
  }) {
    return transaction(() async {
      if (isUpdate) {
        await updateBudget(budget);
      } else {
        await insertBudget(budget);
      }
      await deleteCategoryLimitsForBudget(effectiveBudgetId);
      for (final limit in limits) {
        await insertOrReplaceCategoryLimit(limit);
      }
    });
  }
}
