import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/app_providers.dart';
import '../../../../app/router.dart';
import '../../../../core/formatting/currency_formatter.dart';
import '../../../../core/formatting/date_formatter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../budgets/domain/entities/budget.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/presentation/widgets/add_transaction_sheet.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalBalance = ref.watch(netOperationalBalanceProvider);
    final walletsAsync = ref.watch(walletsWithBalanceStreamProvider);
    final recentTransactionsAsync = ref.watch(recentTransactionsStreamProvider);

    // Current month info
    final currentMonthKey = AppDateFormatter.toMonthKey(DateTime.now());
    final budgetProgressAsync = ref.watch(budgetProgressStreamProvider(currentMonthKey));
    final monthlyIncomeAsync = ref.watch(monthlyIncomeProvider(currentMonthKey));
    final monthlyExpenseAsync = ref.watch(monthlyExpenseProvider(currentMonthKey));

    final currentMonthDate = DateTime.now();
    final monthDisplay = AppDateFormatter.formatMonthYear(currentMonthDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MyFinance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Pengaturan',
            onPressed: () => context.push(AppRouter.settings),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            tooltip: 'Notifikasi',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tidak ada notifikasi baru.')),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(walletsWithBalanceStreamProvider);
          ref.invalidate(recentTransactionsStreamProvider);
          ref.invalidate(budgetProgressStreamProvider(currentMonthKey));
          ref.invalidate(monthlyIncomeProvider(currentMonthKey));
          ref.invalidate(monthlyExpenseProvider(currentMonthKey));
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // 1. Total Balance Card
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Total Saldo Bersih',
                          style: AppTypography.subhead.copyWith(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.incomeContainerDark : AppColors.incomeContainerLight),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Aset Kas Aktif',
                          style: AppTypography.caption2.copyWith(
                            color: isDark ? AppColors.incomeDark : AppColors.incomeLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    CurrencyFormatter.formatRupiah(totalBalance),
                    style: AppTypography.balanceLarge.copyWith(
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  walletsAsync.maybeWhen(
                    data: (w) => Text(
                      'Tersimpan di ${w.length} dompet & rekening',
                      style: AppTypography.footnote.copyWith(
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                      ),
                    ),
                    orElse: () => const SizedBox(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. Quick Actions
            Row(
              children: [
                _buildQuickAction(
                  context,
                  label: 'Pengeluaran',
                  icon: Icons.arrow_outward_rounded,
                  color: isDark ? AppColors.expenseDark : AppColors.expenseLight,
                  bgColor: isDark ? AppColors.expenseContainerDark : AppColors.expenseContainerLight,
                  onTap: () => AddTransactionSheet.show(context, initialType: TransactionType.expense),
                ),
                const SizedBox(width: 10),
                _buildQuickAction(
                  context,
                  label: 'Pemasukan',
                  icon: Icons.arrow_downward_rounded,
                  color: isDark ? AppColors.incomeDark : AppColors.incomeLight,
                  bgColor: isDark ? AppColors.incomeContainerDark : AppColors.incomeContainerLight,
                  onTap: () => AddTransactionSheet.show(context, initialType: TransactionType.income),
                ),
                const SizedBox(width: 10),
                _buildQuickAction(
                  context,
                  label: 'Transfer',
                  icon: Icons.swap_horiz_rounded,
                  color: isDark ? AppColors.transferDark : AppColors.transferLight,
                  bgColor: isDark ? AppColors.transferContainerDark : AppColors.transferContainerLight,
                  onTap: () => AddTransactionSheet.show(context, initialType: TransactionType.transfer),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 3. Monthly Financial Overview & Budget Card
            _buildMonthlyOverview(
              context,
              monthDisplay: monthDisplay,
              incomeAsync: monthlyIncomeAsync,
              expenseAsync: monthlyExpenseAsync,
              budgetAsync: budgetProgressAsync,
              isDark: isDark,
            ),

            const SizedBox(height: 24),

            // 4. Dompet Saya Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Dompet & Rekening',
                    style: AppTypography.headline.copyWith(fontSize: 18),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push(AppRouter.wallets),
                  child: const Text('Lihat Semua'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            walletsAsync.when(
              data: (wallets) {
                if (wallets.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined, size: 32, color: Colors.grey),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Belum ada dompet terdaftar.',
                            style: AppTypography.subhead,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push(AppRouter.wallets),
                          child: const Text('Tambah'),
                        ),
                      ],
                    ),
                  );
                }

                return SizedBox(
                  height: 110,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: wallets.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final item = wallets[index];
                      final walletColor = AppIcons.parseColor(item.wallet.colorHex);
                      return InkWell(
                        onTap: () => context.push(AppRouter.wallets),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 160,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? AppColors.borderDark : AppColors.borderLight,
                              width: 0.8,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: walletColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      AppIcons.getIcon(item.wallet.iconKey),
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      item.wallet.name,
                                      style: AppTypography.caption1.copyWith(fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.wallet.type.displayName,
                                    style: AppTypography.caption2.copyWith(
                                      color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    CurrencyFormatter.formatRupiah(item.currentBalance),
                                    style: AppTypography.headline.copyWith(
                                      fontSize: 14,
                                      color: item.currentBalance >= 0
                                          ? (isDark ? AppColors.incomeDark : AppColors.incomeLight)
                                          : (isDark ? AppColors.expenseDark : AppColors.expenseLight),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Belum dapat memuat data dompet. Silakan muat ulang halaman.',
                  style: AppTypography.caption1,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 5. Transaksi Terakhir Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Transaksi Terkini',
                    style: AppTypography.headline.copyWith(fontSize: 18),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go(AppRouter.transactions),
                  child: const Text('Lihat Semua'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            recentTransactionsAsync.when(
              data: (transactions) {
                if (transactions.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        width: 0.8,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.receipt_long_outlined, size: 36, color: Colors.grey),
                        const SizedBox(height: 8),
                        const Text('Belum ada transaksi.', style: AppTypography.subhead),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => AddTransactionSheet.show(context),
                          child: const Text('Catat Transaksi Pertama'),
                        ),
                      ],
                    ),
                  );
                }

                // Show top 5
                final displayList = transactions.take(5).toList();
                return Column(
                  children: displayList.map((item) {
                    final tx = item.transaction;
                    final isVoided = tx.status == TransactionStatus.voided;

                    Color itemColor;
                    IconData itemIcon;

                    if (tx.type == TransactionType.transfer) {
                      itemColor = isDark ? AppColors.transferDark : AppColors.transferLight;
                      itemIcon = Icons.swap_horiz_rounded;
                    } else if (tx.type == TransactionType.income) {
                      itemColor = isDark ? AppColors.incomeDark : AppColors.incomeLight;
                      itemIcon = AppIcons.getIcon(item.category?.iconKey ?? 'briefcase');
                    } else {
                      itemColor = isDark ? AppColors.expenseDark : AppColors.expenseLight;
                      itemIcon = AppIcons.getIcon(item.category?.iconKey ?? 'utensils');
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: itemColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(itemIcon, color: itemColor, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.displayTitle,
                                  style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  item.displaySubtitle.isNotEmpty ? '${item.displaySubtitle} • ${DateFormatter.formatDateAndTime(tx.occurredAt)}' : DateFormatter.formatDateAndTime(tx.occurredAt),
                                  style: AppTypography.caption1.copyWith(
                                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            (tx.type == TransactionType.expense ? '- ' : tx.type == TransactionType.income ? '+ ' : '') +
                                CurrencyFormatter.formatRupiah(tx.amount),
                            style: AppTypography.headline.copyWith(
                              fontSize: 14,
                              color: isVoided
                                  ? Colors.grey
                                  : (tx.type == TransactionType.expense
                                      ? (isDark ? AppColors.expenseDark : AppColors.expenseLight)
                                      : tx.type == TransactionType.income
                                          ? (isDark ? AppColors.incomeDark : AppColors.incomeLight)
                                          : (isDark ? AppColors.transferDark : AppColors.transferLight)),
                              decoration: isVoided ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Belum dapat memuat mutasi transaksi terbaru.',
                  style: AppTypography.caption1,
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyOverview(
    BuildContext context, {
    required String monthDisplay,
    required AsyncValue<int> incomeAsync,
    required AsyncValue<int> expenseAsync,
    required AsyncValue<BudgetProgress> budgetAsync,
    required bool isDark,
  }) {
    final income = incomeAsync.value ?? 0;
    final expense = expenseAsync.value ?? 0;
    final netCashflow = income - expense;
    final isSurplus = netCashflow >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Arus Kas $monthDisplay',
                style: AppTypography.headline.copyWith(fontSize: 15),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isSurplus
                          ? (isDark ? AppColors.incomeDark : AppColors.incomeLight)
                          : (isDark ? AppColors.expenseDark : AppColors.expenseLight))
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  (isSurplus ? '+ ' : '- ') + CurrencyFormatter.formatRupiah(netCashflow.abs()),
                  style: AppTypography.caption2.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isSurplus
                        ? (isDark ? AppColors.incomeDark : AppColors.incomeLight)
                        : (isDark ? AppColors.expenseDark : AppColors.expenseLight),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Pemasukan & Pengeluaran sub-row
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.incomeContainerDark : AppColors.incomeContainerLight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_downward_rounded,
                        size: 14,
                        color: isDark ? AppColors.incomeDark : AppColors.incomeLight,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pemasukan', style: AppTypography.caption2),
                          Text(
                            CurrencyFormatter.formatRupiah(income),
                            style: AppTypography.caption1.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.expenseContainerDark : AppColors.expenseContainerLight,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        size: 14,
                        color: isDark ? AppColors.expenseDark : AppColors.expenseLight,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pengeluaran', style: AppTypography.caption2),
                          Text(
                            CurrencyFormatter.formatRupiah(expense),
                            style: AppTypography.caption1.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Budget Widget Card
          budgetAsync.maybeWhen(
            data: (progress) {
              if (!progress.hasBudget) {
                return InkWell(
                  onTap: () => context.push(AppRouter.budgets),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.pie_chart_outline, size: 20, color: AppColors.transferLight),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Belum ada anggaran bulan ini.',
                            style: AppTypography.caption1,
                          ),
                        ),
                        Text(
                          'Atur Sekarang >',
                          style: TextStyle(
                            color: AppColors.transferLight,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final pct = (progress.percentage * 100).toStringAsFixed(0);
              final statusColor = progress.status == BudgetStatus.normal
                  ? (isDark ? AppColors.incomeDark : AppColors.incomeLight)
                  : progress.status == BudgetStatus.warning
                      ? (isDark ? AppColors.warningDark : AppColors.warningLight)
                      : progress.status == BudgetStatus.critical
                          ? const Color(0xFFE17055)
                          : (isDark ? AppColors.expenseDark : AppColors.expenseLight);

              return InkWell(
                onTap: () => context.push(AppRouter.budgets),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.pie_chart_rounded, size: 18, color: AppColors.primaryNavyLight),
                              const SizedBox(width: 6),
                              Text(
                                'Sisa Anggaran: ${CurrencyFormatter.formatRupiah(progress.remaining)}',
                                style: AppTypography.caption1.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              progress.status.displayName,
                              style: AppTypography.caption2.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress.percentage.clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor: isDark ? AppColors.borderDark : AppColors.borderLight,
                          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Terpakai $pct%',
                            style: AppTypography.caption2.copyWith(
                              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                            ),
                          ),
                          Text(
                            'Limit: ${CurrencyFormatter.formatCompact(progress.totalLimit)}',
                            style: AppTypography.caption2.copyWith(
                              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
            orElse: () => const SizedBox(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: AppTypography.caption1.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
