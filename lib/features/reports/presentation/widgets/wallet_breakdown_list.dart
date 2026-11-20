import 'package:flutter/material.dart';
import '../../../../core/formatting/currency_formatter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/wallet_report_item.dart';

class WalletBreakdownList extends StatelessWidget {
  final List<WalletReportItem> items;
  final bool isDark;
  final void Function(WalletReportItem item)? onWalletTap;

  const WalletBreakdownList({
    super.key,
    required this.items,
    required this.isDark,
    this.onWalletTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Belum ada transaksi pada dompet di bulan ini.',
            style: AppTypography.subhead.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ),
      );
    }

    return Column(
      children: items.map((item) {
        final iconData = AppIcons.getIcon(item.wallet.iconKey);
        final color = item.wallet.colorHex != null
            ? Color(int.parse(item.wallet.colorHex!))
            : AppColors.primary;

        final isNetPositive = item.netFlow >= 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            padding: const EdgeInsets.all(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onWalletTap != null ? () => onWalletTap!(item) : null,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(iconData, color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.wallet.name,
                          style: AppTypography.subhead.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.transactionCount} transaksi',
                          style: AppTypography.caption1.copyWith(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Masuk: +${CurrencyFormatter.formatRupiah(item.incomeAmount + item.transferInAmount)}',
                              style: AppTypography.caption2.copyWith(
                                color: isDark ? AppColors.primaryLight : AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Keluar: -${CurrencyFormatter.formatRupiah(item.expenseAmount + item.transferOutAmount)}',
                              style: AppTypography.caption2.copyWith(
                                color: isDark ? AppColors.errorLight : AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        isNetPositive ? 'Arus Kas +' : 'Arus Kas -',
                        style: AppTypography.caption2.copyWith(
                          color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${isNetPositive ? "+" : ""}${CurrencyFormatter.formatRupiah(item.netFlow)}',
                        style: AppTypography.subhead.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isNetPositive
                              ? (isDark ? AppColors.primaryLight : AppColors.primary)
                              : (isDark ? AppColors.errorLight : AppColors.error),
                        ),
                      ),
                      if (onWalletTap != null)
                        const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
