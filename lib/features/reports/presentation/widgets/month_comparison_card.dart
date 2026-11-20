import 'package:flutter/material.dart';
import '../../../../core/formatting/currency_formatter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/monthly_report.dart';

class MonthComparisonCard extends StatelessWidget {
  final MonthlyReport report;

  const MonthComparisonCard({
    super.key,
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Jika bulan lalu tidak ada data sama sekali, tampilkan info
    final hasPreviousData = report.previousMonthIncome > 0 || report.previousMonthExpense > 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.compare_arrows_rounded,
                size: 20,
                color: isDark ? AppColors.accentLight : AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Perbandingan vs Bulan Lalu',
                style: AppTypography.headline.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasPreviousData)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Belum ada data transaksi pada bulan sebelumnya untuk dibandingkan.',
                style: AppTypography.caption1.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _buildComparisonItem(
                    title: 'Pemasukan',
                    currentAmount: report.totalIncome,
                    prevAmount: report.previousMonthIncome,
                    percentage: report.incomeChangePercentage,
                    isPositiveFavorable: true, // Lebih banyak pemasukan = bagus
                    isDark: isDark,
                  ),
                ),
                Container(
                  width: 1,
                  height: 48,
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
                Expanded(
                  child: _buildComparisonItem(
                    title: 'Pengeluaran',
                    currentAmount: report.totalExpense,
                    prevAmount: report.previousMonthExpense,
                    percentage: report.expenseChangePercentage,
                    isPositiveFavorable: false, // Lebih banyak pengeluaran = merah
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComparisonItem({
    required String title,
    required int currentAmount,
    required int prevAmount,
    required double? percentage,
    required bool isPositiveFavorable,
    required bool isDark,
  }) {
    final delta = currentAmount - prevAmount;

    Color badgeColor;
    Color badgeTextColor;
    IconData trendIcon;
    String badgeText;

    if (percentage == null) {
      badgeColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
      badgeTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade700;
      trendIcon = Icons.remove;
      badgeText = '0%';
    } else {
      final isUp = delta > 0;
      final isGood = isPositiveFavorable ? isUp : !isUp;

      badgeColor = isGood
          ? (isDark ? AppColors.primary.withOpacity(0.2) : AppColors.primaryLight.withOpacity(0.15))
          : (isDark ? AppColors.error.withOpacity(0.2) : AppColors.errorLight.withOpacity(0.15));
      badgeTextColor = isGood
          ? (isDark ? AppColors.primaryLight : AppColors.primary)
          : (isDark ? AppColors.errorLight : AppColors.error);

      trendIcon = isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
      final prefix = isUp ? '+' : '';
      badgeText = '$prefix${percentage.toStringAsFixed(1)}%';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.caption1.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            CurrencyFormatter.formatRupiah(currentAmount),
            style: AppTypography.subhead.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(trendIcon, size: 12, color: badgeTextColor),
                    const SizedBox(width: 2),
                    Text(
                      badgeText,
                      style: AppTypography.caption2.copyWith(
                        color: badgeTextColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'vs lalu',
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption2.copyWith(
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
