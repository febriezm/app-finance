/// Ringkasan data lokal SQLite yang siap dimigrasikan ke Supabase PostgreSQL Cloud
class MigrationSummary {
  final int walletsCount;
  final int customCategoriesCount;
  final int transactionsCount;
  final int budgetsCount;
  final int budgetLimitsCount;
  final int attachmentsCount;
  final int totalOpeningBalance;
  final int totalLedgerBalance;
  final bool hasData;

  const MigrationSummary({
    required this.walletsCount,
    required this.customCategoriesCount,
    required this.transactionsCount,
    required this.budgetsCount,
    required this.budgetLimitsCount,
    required this.attachmentsCount,
    required this.totalOpeningBalance,
    required this.totalLedgerBalance,
  }) : hasData = walletsCount > 0 || transactionsCount > 0 || budgetsCount > 0 || customCategoriesCount > 0;

  int get totalRecordsCount =>
      walletsCount + customCategoriesCount + transactionsCount + budgetsCount + budgetLimitsCount + attachmentsCount;

  static const empty = MigrationSummary(
    walletsCount: 0,
    customCategoriesCount: 0,
    transactionsCount: 0,
    budgetsCount: 0,
    budgetLimitsCount: 0,
    attachmentsCount: 0,
    totalOpeningBalance: 0,
    totalLedgerBalance: 0,
  );
}
