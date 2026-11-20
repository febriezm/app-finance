import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/app_providers.dart';
import '../../../../core/formatting/currency_formatter.dart';
import '../../../../core/formatting/date_formatter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../transactions/presentation/widgets/add_transaction_sheet.dart';
import '../../domain/entities/monthly_report.dart';
import '../widgets/export_sheet.dart';
import '../widgets/month_comparison_card.dart';
import '../widgets/report_transactions_sheet.dart';
import '../widgets/wallet_breakdown_list.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int _selectedTab = 0; // 0: Pengeluaran, 1: Pemasukan, 2: Dompet

  void _changeMonth(int delta) {
    final currentKey = ref.read(selectedReportMonthProvider);
    final parts = currentKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final newDate = DateTime(year, month + delta);
    ref.read(selectedReportMonthProvider.notifier).state = AppDateFormatter.toMonthKey(newDate);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentMonthKey = ref.watch(selectedReportMonthProvider);
    final reportAsync = ref.watch(monthlyReportProvider(currentMonthKey));

    final parts = currentMonthKey.split('-');
    final currentMonthDate = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    final monthDisplay = AppDateFormatter.formatMonthYear(currentMonthDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Keuangan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Ekspor Laporan (PDF / CSV)',
            onPressed: () => ExportSheet.show(context, currentMonthKey),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(monthlyReportProvider(currentMonthKey));
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // 1. Month Navigator Header
            _buildMonthNavigator(context, monthDisplay, isDark),

            const SizedBox(height: 16),

            reportAsync.when(
              data: (report) {
                if (report.totalTransactionsCount == 0) {
                  return Column(
                    children: [
                      const SizedBox(height: 32),
                      EmptyState(
                        icon: Icons.bar_chart_outlined,
                        title: 'Belum Ada Transaksi',
                        message: 'Tidak ada transaksi tercatat pada bulan $monthDisplay.',
                        actionLabel: 'Catat Transaksi',
                        onActionPressed: () => AddTransactionSheet.show(context),
                      ),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2. Financial Summary Card
                    _buildSummaryCard(context, report, isDark),

                    const SizedBox(height: 16),

                    // 3. Month-over-Month Comparison Card
                    MonthComparisonCard(report: report),

                    const SizedBox(height: 20),

                    // 4. Segmented Switcher for Expense vs Income vs Wallet Breakdown
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildTabButton(
                              label: 'Pengeluaran',
                              isSelected: _selectedTab == 0,
                              isDark: isDark,
                              onTap: () => setState(() => _selectedTab = 0),
                            ),
                          ),
                          Expanded(
                            child: _buildTabButton(
                              label: 'Pemasukan',
                              isSelected: _selectedTab == 1,
                              isDark: isDark,
                              onTap: () => setState(() => _selectedTab = 1),
                            ),
                          ),
                          Expanded(
                            child: _buildTabButton(
                              label: 'Dompet',
                              isSelected: _selectedTab == 2,
                              isDark: isDark,
                              onTap: () => setState(() => _selectedTab = 2),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 5. Breakdown Sections
                    if (_selectedTab == 0)
                      _buildBreakdownSection(
                        title: 'Distribusi Pengeluaran',
                        items: report.expenseBreakdown,
                        totalAmount: report.totalExpense,
                        isDark: isDark,
                        emptyMessage: 'Tidak ada pengeluaran pada bulan ini.',
                        currentMonthKey: currentMonthKey,
                      )
                    else if (_selectedTab == 1)
                      _buildBreakdownSection(
                        title: 'Sumber Pemasukan',
                        items: report.incomeBreakdown,
                        totalAmount: report.totalIncome,
                        isDark: isDark,
                        emptyMessage: 'Tidak ada pemasukan pada bulan ini.',
                        currentMonthKey: currentMonthKey,
                      )
                    else
                      WalletBreakdownList(
                        items: report.walletBreakdown,
                        isDark: isDark,
                        onWalletTap: (wItem) {
                          ReportTransactionsSheet.show(
                            context,
                            monthKey: currentMonthKey,
                            title: wItem.wallet.name,
                            walletId: wItem.wallet.id,
                          );
                        },
                      ),

                    const SizedBox(height: 32),
                  ],
                );
              },
              loading: () => const SizedBox(
                height: 300,
                child: Center(child: LoadingIndicator(message: 'Menganalisis laporan...')),
              ),
              error: (e, _) => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Belum dapat memuat data laporan. Silakan muat ulang.', style: AppTypography.subhead),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthNavigator(BuildContext context, String monthDisplay, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Bulan Sebelumnya',
            onPressed: () => _changeMonth(-1),
          ),
          Row(
            children: [
              Icon(
                Icons.calendar_month_outlined,
                size: 18,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
              const SizedBox(width: 8),
              Text(
                monthDisplay,
                style: AppTypography.headline.copyWith(fontSize: 16),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Bulan Berikutnya',
            onPressed: () => _changeMonth(1),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, MonthlyReport report, bool isDark) {
    final savingsRatePercent = (report.savingsRate * 100).toStringAsFixed(1);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Arus Kas Bersih (Net Cashflow)',
                style: AppTypography.caption1.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: report.isSurplus
                      ? (isDark ? AppColors.primary.withOpacity(0.2) : AppColors.primaryLight.withOpacity(0.15))
                      : (isDark ? AppColors.error.withOpacity(0.2) : AppColors.errorLight.withOpacity(0.15)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      report.isSurplus ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      size: 14,
                      color: report.isSurplus
                          ? (isDark ? AppColors.primaryLight : AppColors.primary)
                          : (isDark ? AppColors.errorLight : AppColors.error),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      report.isSurplus ? 'Surplus' : 'Defisit',
                      style: AppTypography.caption2.copyWith(
                        fontWeight: FontWeight.bold,
                        color: report.isSurplus
                            ? (isDark ? AppColors.primaryLight : AppColors.primary)
                            : (isDark ? AppColors.errorLight : AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            CurrencyFormatter.formatRupiah(report.netCashflow),
            style: AppTypography.title1.copyWith(
              color: report.isSurplus
                  ? (isDark ? AppColors.primaryLight : AppColors.primary)
                  : (isDark ? AppColors.errorLight : AppColors.error),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  label: 'Total Pemasukan',
                  amount: report.totalIncome,
                  color: isDark ? AppColors.primaryLight : AppColors.primary,
                  isDark: isDark,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
              Expanded(
                child: _buildMetricItem(
                  label: 'Total Pengeluaran',
                  amount: report.totalExpense,
                  color: isDark ? AppColors.errorLight : AppColors.error,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceLight.withOpacity(0.05) : AppColors.surfaceDark.withOpacity(0.03),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.savings_outlined,
                      size: 16,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Tingkat Tabungan (Savings Rate)',
                      style: AppTypography.caption1.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
                Text(
                  '$savingsRatePercent%',
                  style: AppTypography.caption1.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.accentLight : AppColors.accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required String label,
    required int amount,
    required Color color,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.caption1.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            CurrencyFormatter.formatRupiah(amount),
            style: AppTypography.headline.copyWith(
              color: color,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTypography.subhead.copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
          ),
        ),
      ),
    );
  }

  Widget _buildBreakdownSection({
    required String title,
    required List<CategoryReportItem> items,
    required int totalAmount,
    required bool isDark,
    required String emptyMessage,
    required String currentMonthKey,
  }) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 0.8,
          ),
        ),
        alignment: Alignment.center,
        child: Text(emptyMessage, style: AppTypography.subhead),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: AppTypography.headline.copyWith(fontSize: 16),
            ),
            Text(
              '${items.length} Kategori • Ketuk rincian',
              style: AppTypography.caption1.copyWith(
                color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Column(
          children: items.map((item) {
            final catColor = AppIcons.parseColor(item.category.colorHex);
            final percentDisplay = (item.percentage * 100).toStringAsFixed(1);

            return InkWell(
              onTap: () {
                ReportTransactionsSheet.show(
                  context,
                  monthKey: currentMonthKey,
                  title: item.category.name,
                  categoryId: item.category.id,
                );
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    width: 0.8,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: catColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            AppIcons.getIcon(item.category.iconKey),
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.category.name,
                                style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${item.transactionCount} transaksi',
                                style: AppTypography.caption2.copyWith(
                                  color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyFormatter.formatRupiah(item.amount),
                              style: AppTypography.headline.copyWith(fontSize: 14),
                            ),
                            Text(
                              '$percentDisplay%',
                              style: AppTypography.caption2.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: item.percentage.clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: isDark ? AppColors.borderDark : AppColors.borderLight,
                        valueColor: AlwaysStoppedAnimation<Color>(catColor),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
