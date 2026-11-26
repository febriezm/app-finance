import 'package:flutter/material.dart';
import '../../core/formatting/date_formatter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/app_haptics.dart';

/// Pemilih bulan minimalis dengan tipografi bersih dan tombol panah outline.
class MinimalMonthSelector extends StatelessWidget {
  final DateTime currentMonth;
  final ValueChanged<DateTime> onMonthChanged;
  final bool isAllPeriod;
  final VoidCallback? onToggleAllPeriod;

  const MinimalMonthSelector({
    super.key,
    required this.currentMonth,
    required this.onMonthChanged,
    this.isAllPeriod = false,
    this.onToggleAllPeriod,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final isCurrentMonth = currentMonth.year == now.year && currentMonth.month == now.month;
    final monthDisplay = isAllPeriod ? 'Semua Periode' : AppDateFormatter.formatMonthYear(currentMonth);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Panah Sebelumnya
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 24),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            color: isAllPeriod
                ? (isDark ? AppColors.textDisabledDark : AppColors.textDisabledLight)
                : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
            onPressed: isAllPeriod
                ? null
                : () {
                    AppHaptics.selection();
                    final prev = DateTime(currentMonth.year, currentMonth.month - 1, 1);
                    onMonthChanged(prev);
                  },
          ),

          // Teks Bulan & Tombol Reset Bulan Ini jika relevan
          GestureDetector(
            onTap: () {
              AppHaptics.selection();
              if (isAllPeriod) {
                onMonthChanged(DateTime(now.year, now.month, 1));
              } else if (!isCurrentMonth) {
                onMonthChanged(DateTime(now.year, now.month, 1));
              } else {
                onToggleAllPeriod?.call();
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      monthDisplay,
                      style: AppTypography.sectionTitle.copyWith(
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isAllPeriod) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.all_inclusive_rounded,
                        size: 15,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ],
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    isAllPeriod
                        ? 'Ketuk untuk kembali ke bulan ini'
                        : (!isCurrentMonth ? 'Ketuk untuk bulan ini' : 'Ketuk untuk semua periode'),
                    style: AppTypography.caption2.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Panah Berikutnya
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 24),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            color: isAllPeriod
                ? (isDark ? AppColors.textDisabledDark : AppColors.textDisabledLight)
                : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
            onPressed: isAllPeriod
                ? null
                : () {
                    AppHaptics.selection();
                    final next = DateTime(currentMonth.year, currentMonth.month + 1, 1);
                    onMonthChanged(next);
                  },
          ),
        ],
      ),
    );
  }
}
