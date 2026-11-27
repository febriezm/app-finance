import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/app_providers.dart';
import '../../../../core/formatting/currency_formatter.dart';
import '../../../../core/formatting/date_formatter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../reports/presentation/widgets/report_transactions_sheet.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/presentation/widgets/add_transaction_sheet.dart';
import '../../domain/entities/wallet.dart';
import '../widgets/card_theme_helper.dart';
import '../widgets/realistic_card_widget.dart';
import '../widgets/wallet_card_carousel.dart';

/// Halaman Dompet & Rekening — MyFinance Minimal (Quiet, Clean, Premium).
///
/// Karakter Desain:
/// - Total balance minimalis tanpa card bertumpuk.
/// - Daftar dompet terkelompok (Grouped List): Rekening Bank, Kas Tunai, E-Wallet, Lainnya.
/// - Setiap akun menggunakan [WalletListTile] dengan icon sederhana, typography bersih, angka tabular, dan divider tipis.
/// - Mempertahankan seluruh fitur: Tambah, Edit, Detail, Arsip/Aktifkan, Riwayat Mutasi, dan Transfer.
class WalletsScreen extends ConsumerStatefulWidget {
  const WalletsScreen({super.key});

  @override
  ConsumerState<WalletsScreen> createState() => _WalletsScreenState();
}

class _WalletsScreenState extends ConsumerState<WalletsScreen> {
  bool _isBalanceVisible = true;

  void _showAddWalletSheet(BuildContext context) {
    unawaited(AppHaptics.selection());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddWalletModal(),
    );
  }

  void _showEditWalletSheet(BuildContext context, Wallet wallet) {
    unawaited(AppHaptics.selection());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditWalletModal(wallet: wallet),
    );
  }

  void _showWalletDetailSheet(BuildContext context, WidgetRef ref, WalletWithBalance item) {
    unawaited(AppHaptics.light());
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArchived = item.wallet.isArchived;
    final walletColor = AppIcons.parseColor(item.wallet.colorHex);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.88,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceModalDark : AppColors.surfaceModalLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              // Handle Bar
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Scrollable Detail Body
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Visual Realistic Physical Card (Gambar 1 & 2)
                      Center(
                        child: RealisticCardWidget(
                          wallet: item.wallet,
                          currentBalance: item.currentBalance,
                          isBalanceVisible: _isBalanceVisible,
                          accountHolderName: ref.read(authCurrentUserProvider)?.name,
                        ),
                      ),
                      const SizedBox(height: 18),

              // Wallet Header (Icon, Name, Type)
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: walletColor.withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: walletColor.withValues(alpha: isDark ? 0.4 : 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Icon(
                      AppIcons.getIcon(item.wallet.iconKey),
                      color: isDark ? Colors.white : walletColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.wallet.name,
                                style: AppTypography.title3.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isArchived) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Arsip',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.wallet.type.displayName,
                          style: AppTypography.caption.copyWith(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (isArchived) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Dompet ini diarsipkan sebagai cadangan dan tidak muncul sebagai opsi sumber dana transaksi.',
                          style: AppTypography.caption.copyWith(
                            color: isDark ? Colors.orange.shade200 : Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Saldo Berjalan (Large Focus)
              Text(
                'SALDO BERJALAN',
                style: AppTypography.caption.copyWith(
                  color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              FinanceAmountText(
                amount: item.currentBalance,
                type: AmountDisplayType.auto,
                style: AppTypography.balanceMedium,
                color: item.currentBalance >= 0
                    ? (isDark ? AppColors.incomeDark : AppColors.incomeLight)
                    : (isDark ? AppColors.expenseDark : AppColors.expenseLight),
              ),

              const SizedBox(height: 20),
              Divider(
                height: 1,
                thickness: 0.6,
                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              ),
              const SizedBox(height: 12),

              // Detail List (Quiet Key-Value pairs)
              FinanceSummaryRow(
                label: 'Saldo Awal',
                customValue: CurrencyFormatter.formatRupiah(item.wallet.openingBalance),
              ),
              const SizedBox(height: 8),
              FinanceSummaryRow(
                label: 'Tipe Akun',
                customValue: item.wallet.type.displayName,
              ),
              const SizedBox(height: 8),
              FinanceSummaryRow(
                label: 'Mata Uang',
                customValue: item.wallet.currencyCode,
              ),
              const SizedBox(height: 8),
              FinanceSummaryRow(
                label: 'Status',
                customValue: isArchived ? 'Diarsipkan (Cadangan)' : 'Aktif',
              ),

              const SizedBox(height: 24),
              Divider(
                height: 1,
                thickness: 0.6,
                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              ),
              const SizedBox(height: 16),

              // Action Buttons
              // 1. Mutasi Transaksi
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: const Text('Riwayat Mutasi Transaksi'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      width: 0.8,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    ReportTransactionsSheet.show(
                      context,
                      monthKey: AppDateFormatter.toMonthKey(DateTime.now()),
                      title: 'Mutasi ${item.wallet.name}',
                      walletId: item.wallet.id,
                    );
                  },
                ),
              ),

              const SizedBox(height: 10),

              // 2. Transfer Antar Dompet (hanya jika aktif)
              if (!isArchived) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: const Text('Transfer dari Dompet Ini'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        width: 0.8,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      AddTransactionSheet.show(
                        context,
                        initialType: TransactionType.transfer,
                        initialWalletId: item.wallet.id,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // 3. Edit & Arsip Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          width: 0.8,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _showEditWalletSheet(context, item.wallet);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: isArchived
                        ? OutlinedButton.icon(
                            icon: const Icon(Icons.unarchive_outlined, size: 18, color: Colors.green),
                            label: const Text(
                              'Aktifkan',
                              style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: Colors.green, width: 0.8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              final confirm = await MinimalDialog.showConfirm(
                                context,
                                title: 'Aktifkan Kembali Dompet?',
                                message: 'Dompet "${item.wallet.name}" akan kembali ke daftar aktif dan dapat dipilih sebagai sumber dana transaksi.',
                                confirmText: 'Aktifkan',
                                confirmColor: isDark ? AppColors.incomeDark : AppColors.incomeLight,
                              );

                              if (confirm == true) {
                                await ref.read(walletsControllerProvider.notifier).unarchiveWallet(item.wallet.id);
                                ref.invalidate(walletsWithBalanceStreamProvider);
                                ref.invalidate(archivedWalletsWithBalanceStreamProvider);
                                ref.invalidate(totalAllAssetBalanceProvider);
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Dompet "${item.wallet.name}" diaktifkan kembali.')),
                                  );
                                }
                              }
                            },
                          )
                        : OutlinedButton.icon(
                            icon: const Icon(Icons.archive_outlined, size: 18, color: Colors.orange),
                            label: const Text(
                              'Arsipkan',
                              style: TextStyle(color: Colors.orange),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: Colors.orange, width: 0.8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              final confirm = await MinimalDialog.showConfirm(
                                context,
                                title: 'Arsipkan Dompet?',
                                message: 'Dompet "${item.wallet.name}" akan dipindahkan ke daftar arsip cadangan. Riwayat mutasi transaksi tetap tersimpan utuh.',
                                confirmText: 'Arsipkan',
                                confirmColor: Colors.orange,
                              );

                              if (confirm == true) {
                                await ref.read(walletsControllerProvider.notifier).archiveWallet(item.wallet.id);
                                ref.invalidate(walletsWithBalanceStreamProvider);
                                ref.invalidate(archivedWalletsWithBalanceStreamProvider);
                                ref.invalidate(totalAllAssetBalanceProvider);
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Dompet "${item.wallet.name}" berhasil diarsipkan.')),
                                  );
                                }
                              }
                            },
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                  label: const Text(
                    'Hapus Dompet',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(
                      color: Colors.red.withValues(alpha: 0.5),
                      width: 0.8,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    unawaited(AppHaptics.selection());
                    final confirm = await MinimalDialog.showConfirm(
                      context,
                      title: 'Hapus Dompet?',
                      message: 'Dompet "${item.wallet.name}" akan dihapus secara permanen dari sistem.',
                      confirmText: 'Ya, Hapus',
                      isDestructive: true,
                    );

                    if (confirm == true) {
                      final success = await ref.read(walletsControllerProvider.notifier).deleteWallet(item.wallet.id);
                      ref.invalidate(walletsWithBalanceStreamProvider);
                      ref.invalidate(archivedWalletsWithBalanceStreamProvider);
                      ref.invalidate(totalAllAssetBalanceProvider);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Dompet "${item.wallet.name}" berhasil dihapus.')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Gagal menghapus dompet.')),
                          );
                        }
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  ),
),
      ),
    );
  }

  Widget _buildDedicatedAssetCard(
    BuildContext context, {
    required int totalBalance,
    required List<WalletWithBalance> wallets,
    required List<WalletWithBalance> archivedWallets,
    required List<WalletWithBalance> bankWallets,
    required List<WalletWithBalance> cashWallets,
    required List<WalletWithBalance> eWalletWallets,
    required List<WalletWithBalance> otherWallets,
    required bool isDark,
    required Color surfaceColor,
    required Color borderColor,
  }) {
    final dividerColor = isDark ? AppColors.dividerDark : AppColors.dividerLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final textTertiary = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

    final bankAndCashTotal = (bankWallets + cashWallets).fold<int>(0, (sum, w) => sum + w.currentBalance);
    final eWalletAndOtherTotal = (eWalletWallets + otherWallets).fold<int>(0, (sum, w) => sum + w.currentBalance);

    final walletCountLabel = archivedWallets.isNotEmpty
        ? '${wallets.length} Aktif • ${archivedWallets.length} Arsip'
        : '${wallets.length} Dompet Aktif';

    return Container(
      key: const Key('dedicated_asset_balance_card'),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header: Label + Visibility Toggle + Wallets Glance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'TOTAL SALDO ASET',
                        style: AppTypography.caption.copyWith(
                          color: textSecondary,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
                        AppHaptics.light();
                        setState(() {
                          _isBalanceVisible = !_isBalanceVisible;
                        });
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          _isBalanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 16,
                          color: textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                walletCountLabel,
                style: AppTypography.caption2.copyWith(
                  color: textTertiary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 2. Hero Balance Amount (Focal Point Utama)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: _isBalanceVisible
                ? FinanceAmountText(
                    amount: totalBalance,
                    type: AmountDisplayType.neutral,
                    style: AppTypography.balanceLarge.copyWith(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  )
                : Text(
                    'Rp ••••••••',
                    style: AppTypography.balanceLarge.copyWith(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
          ),

          const SizedBox(height: 16),

          // 3. Hairline Divider
          Divider(height: 0.8, thickness: 0.8, color: dividerColor),

          const SizedBox(height: 14),

          // 4. Compact Asset Breakdown
          Row(
            children: [
              // Kas & Bank
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? AppColors.incomeDark : AppColors.incomeLight,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Kas & Bank',
                            style: AppTypography.caption2.copyWith(
                              color: textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: _isBalanceVisible
                          ? FinanceAmountText(
                              amount: bankAndCashTotal,
                              type: AmountDisplayType.neutral,
                              showPlusSign: false,
                              style: AppTypography.bodyBold.copyWith(
                                fontSize: 14,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            )
                          : Text(
                              'Rp ••••••',
                              style: AppTypography.bodyBold.copyWith(
                                fontSize: 14,
                                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                    ),
                  ],
                ),
              ),

              // Vertical subtle separator
              const SizedBox(width: 10),
              Container(
                height: 28,
                width: 0.8,
                color: dividerColor,
              ),
              const SizedBox(width: 10),

              // E-Wallet & Lainnya
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? AppColors.transferDark : AppColors.transferLight,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'E-Wallet & Lainnya',
                            style: AppTypography.caption2.copyWith(
                              color: textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: _isBalanceVisible
                          ? FinanceAmountText(
                              amount: eWalletAndOtherTotal,
                              type: AmountDisplayType.neutral,
                              showPlusSign: false,
                              style: AppTypography.bodyBold.copyWith(
                                fontSize: 14,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            )
                          : Text(
                              'Rp ••••••',
                              style: AppTypography.bodyBold.copyWith(
                                fontSize: 14,
                                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Helper untuk merender section per tipe dompet (dengan Card Carousel / Deck UI)
  Widget _buildWalletTypeSection({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required List<WalletWithBalance> wallets,
    required bool isDark,
    required String? accountHolderName,
    String? description,
  }) {
    if (wallets.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTypography.caption.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${wallets.length}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ],
              ),
              if (wallets.length > 1)
                Text(
                  'Geser kartu ➔',
                  style: AppTypography.caption.copyWith(
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              description,
              style: AppTypography.caption.copyWith(
                color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        WalletCardCarousel(
          wallets: wallets,
          isBalanceVisible: _isBalanceVisible,
          accountHolderName: accountHolderName,
          onCardTap: (item) => _showWalletDetailSheet(context, ref, item),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final walletsAsync = ref.watch(walletsWithBalanceStreamProvider);
    final archivedWalletsAsync = ref.watch(archivedWalletsWithBalanceStreamProvider);
    final totalBalance = ref.watch(totalAllAssetBalanceProvider);

    final archivedWallets = archivedWalletsAsync.value ?? [];
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Dompet & Rekening'),
        actions: [
          MinimalIconButton(
            icon: Icons.add_rounded,
            tooltip: 'Tambah Dompet',
            onPressed: () => _showAddWalletSheet(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: walletsAsync.when(
        data: (wallets) {
          if (wallets.isEmpty && archivedWallets.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: EmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Belum Ada Dompet',
                  message: 'Tambahkan dompet pertama Anda (rekening bank, kas tunai, atau e-wallet) untuk mulai mencatat keuangan.',
                  actionLabel: 'Tambah Dompet',
                  onActionPressed: () => _showAddWalletSheet(context),
                ),
              ),
            );
          }

          // Klasifikasi kelompok akun
          final bankWallets = wallets.where((w) => w.wallet.type == WalletType.bank).toList();
          final cashWallets = wallets.where((w) => w.wallet.type == WalletType.cash).toList();
          final eWalletWallets = wallets.where((w) => w.wallet.type == WalletType.eWallet).toList();
          final otherWallets = wallets.where((w) => w.wallet.type == WalletType.other).toList();
          final authUser = ref.watch(authCurrentUserProvider);
          final accountHolderName = authUser?.name;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            children: [
              const SizedBox(height: 4),

              // 1. Dedicated Asset Balance Card (Focal Point Utama — MyFinance Minimal)
              _buildDedicatedAssetCard(
                context,
                totalBalance: totalBalance,
                wallets: wallets,
                archivedWallets: archivedWallets,
                bankWallets: bankWallets,
                cashWallets: cashWallets,
                eWalletWallets: eWalletWallets,
                otherWallets: otherWallets,
                isDark: isDark,
                surfaceColor: surfaceColor,
                borderColor: borderColor,
              ),

              const SizedBox(height: 16),

              // Quick Actions Bar (Transfer & Tambah Dompet)
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        unawaited(AppHaptics.light());
                        AddTransactionSheet.show(
                          context,
                          initialType: TransactionType.transfer,
                        );
                      },
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: const Text('Transfer Saldo'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                        side: BorderSide(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          width: 0.8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      onPressed: () => _showAddWalletSheet(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Tambah'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                        side: BorderSide(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          width: 0.8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // UI Kartu Per Tipe Dompet (Horizontal Carousel / Deck per Kategori)
              // 2. Rekening Bank
              _buildWalletTypeSection(
                context: context,
                ref: ref,
                title: 'REKENING BANK',
                wallets: bankWallets,
                isDark: isDark,
                accountHolderName: accountHolderName,
              ),

              // 3. Kas Tunai
              _buildWalletTypeSection(
                context: context,
                ref: ref,
                title: 'KAS TUNAI',
                wallets: cashWallets,
                isDark: isDark,
                accountHolderName: accountHolderName,
              ),

              // 4. E-Wallet (DANA, GoPay, OVO, ShopeePay, LinkAja dll)
              _buildWalletTypeSection(
                context: context,
                ref: ref,
                title: 'E-WALLET',
                wallets: eWalletWallets,
                isDark: isDark,
                accountHolderName: accountHolderName,
              ),

              // 5. Lainnya / Investasi
              _buildWalletTypeSection(
                context: context,
                ref: ref,
                title: 'LAINNYA / INVESTASI',
                wallets: otherWallets,
                isDark: isDark,
                accountHolderName: accountHolderName,
              ),

              // State jika dompet aktif kosong tetapi arsip tersedia
              if (wallets.isEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      width: 0.8,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Tidak ada dompet aktif. Tambahkan dompet baru atau aktifkan dari daftar arsip di bawah.',
                      style: AppTypography.caption.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],

              // 6. Dompet Diarsipkan / Cadangan
              _buildWalletTypeSection(
                context: context,
                ref: ref,
                title: 'DOMPET DIARSIPKAN',
                wallets: archivedWallets,
                isDark: isDark,
                accountHolderName: accountHolderName,
                description: 'Dompet cadangan disimpan sebagai arsip saldo dan tidak dapat dipilih sebagai sumber dana transaksi.',
              ),
              const SizedBox(height: 24),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Belum dapat memuat data dompet. Silakan muat ulang.',
              style: AppTypography.subhead,
            ),
          ),
        ),
      ),
    );
  }
}

/// Modal Tambah Dompet Baru — MyFinance Minimal (Quiet, Clean, Premium)
class _AddWalletModal extends ConsumerStatefulWidget {
  const _AddWalletModal();

  @override
  ConsumerState<_AddWalletModal> createState() => _AddWalletModalState();
}

class _AddWalletModalState extends ConsumerState<_AddWalletModal> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _openingBalanceController = TextEditingController();

  WalletType _selectedType = WalletType.bank;
  int _openingBalance = 0;
  final String _selectedColorHex = '0xFF0E7A4A';
  String _selectedIconKey = 'bank';
  bool _isLoading = false;
  String? _nameError;

  @override
  void dispose() {
    _nameController.dispose();
    _openingBalanceController.dispose();
    super.dispose();
  }

  void _onBalanceChanged(String val) {
    final clean = val.replaceAll(RegExp(r'[^0-9]'), '');
    final num = int.tryParse(clean) ?? 0;
    _openingBalance = num;
    final formatted = num > 0 ? CurrencyFormatter.formatRupiah(num) : '';
    if (_openingBalanceController.text != formatted) {
      _openingBalanceController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  void _onTypeSelected(WalletType type) {
    unawaited(AppHaptics.selection());
    setState(() {
      _selectedType = type;
      switch (type) {
        case WalletType.cash:
          _selectedIconKey = 'cash';
          break;
        case WalletType.bank:
          _selectedIconKey = 'bank';
          break;
        case WalletType.eWallet:
          _selectedIconKey = 'card';
          break;
        case WalletType.other:
          _selectedIconKey = 'wallet';
          break;
      }

      // Auto-set nama dompet sesuai template pertama dari tipe yang baru dipilih
      final availablePresets = CardThemeHelper.getPresetsForType(type);
      final currentMatches = availablePresets.any((p) => p.displayName.toLowerCase() == _nameController.text.trim().toLowerCase());
      if (!currentMatches && availablePresets.isNotEmpty) {
        _nameController.text = availablePresets.first.displayName;
      }
      if (_nameError != null) _nameError = null;
    });
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _nameError = 'Nama dompet wajib diisi.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _nameError = null;
    });

    try {
      final success = await ref.read(walletsControllerProvider.notifier).createWallet(
            name: name,
            type: _selectedType,
            openingBalance: _openingBalance,
            iconKey: _selectedIconKey,
            colorHex: _selectedColorHex,
          );

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          unawaited(AppHaptics.medium());
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Dompet "$name" berhasil dibuat.')),
            );
          }
        } else {
          final err = ref.read(walletsControllerProvider).error;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal membuat dompet: ${err ?? "Terjadi kesalahan"}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
    final dividerColor = isDark ? AppColors.dividerDark : AppColors.dividerLight;
    final surfaceElevated = isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.only(bottom: keyboardPadding),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceModalDark : AppColors.surfaceModalLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Top Header: Batal, Title, Simpan
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Batal',
                      style: TextStyle(fontSize: 15, color: textSecondary),
                    ),
                  ),
                  Text(
                    'Tambah Dompet Baru',
                    style: AppTypography.headline.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            'Simpan',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.incomeDark : AppColors.incomeLight,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 0.6, color: dividerColor),

            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  // 1. Live Realistic Card Preview (Persis Desain Gambar 1 & 2)
                  Center(
                    child: RealisticCardWidget(
                      wallet: Wallet(
                        id: 'preview',
                        name: _nameController.text.trim().isNotEmpty
                            ? _nameController.text.trim()
                            : (_selectedType == WalletType.cash ? 'Cash' : (_selectedType == WalletType.eWallet ? 'GoPay' : 'BCA')),
                        type: _selectedType,
                        openingBalance: _openingBalance,
                        openingDate: DateTime.now().toIso8601String(),
                        createdAt: DateTime.now().toIso8601String(),
                        updatedAt: DateTime.now().toIso8601String(),
                        iconKey: _selectedIconKey,
                        colorHex: _selectedColorHex,
                      ),
                      currentBalance: _openingBalance,
                      isBalanceVisible: true,
                      accountHolderName: ref.watch(authCurrentUserProvider)?.name,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 2. Tipe Dompet
                  Text(
                    'TIPE DOMPET',
                    style: AppTypography.caption1.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: WalletType.values.map((type) {
                      final isSelected = _selectedType == type;
                      return InkWell(
                        onTap: () => _onTypeSelected(type),
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark ? AppColors.surfaceElevatedDark : AppColors.textPrimaryLight)
                                : (isDark ? AppColors.surfaceModalDark : AppColors.surfaceModalLight),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? (isDark ? AppColors.borderLight : AppColors.textPrimaryLight)
                                  : borderColor,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            type.displayName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected
                                  ? (isDark ? AppColors.textPrimaryDark : Colors.white)
                                  : textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 18),

                  // 3. Preset Pilihan Sesuai Tipe Dompet
                  Text(
                    'PILIH TEMPLAT / PENERBIT KARTU',
                    style: AppTypography.caption1.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: CardThemeHelper.getPresetsForType(_selectedType).map((preset) {
                        final isSelected = _nameController.text.trim().toLowerCase() == preset.displayName.toLowerCase();
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () {
                              unawaited(AppHaptics.selection());
                              setState(() {
                                _nameController.text = preset.displayName;
                                if (_nameError != null) _nameError = null;
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                gradient: preset.gradient,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? Colors.white : Colors.white24,
                                  width: isSelected ? 1.8 : 0.6,
                                ),
                              ),
                              child: Text(
                                preset.displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 4. Nama Dompet
                  Text(
                    'NAMA DOMPET / REKENING',
                    style: AppTypography.caption1.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    style: AppTypography.body,
                    decoration: InputDecoration(
                      hintText: 'Contoh: BCA Utama, GoPay, Dompet Tunai',
                      filled: true,
                      fillColor: surfaceElevated,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderColor, width: 0.8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderColor, width: 0.8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          width: 1.2,
                        ),
                      ),
                      errorText: _nameError,
                    ),
                    onChanged: (_) {
                      if (_nameError != null) setState(() => _nameError = null);
                    },
                  ),

                  const SizedBox(height: 20),

                  // Saldo Awal
                  Text(
                    'SALDO AWAL',
                    style: AppTypography.caption1.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _openingBalanceController,
                    keyboardType: TextInputType.number,
                    style: AppTypography.title3.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Rp 0',
                      filled: true,
                      fillColor: surfaceElevated,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderColor, width: 0.8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderColor, width: 0.8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          width: 1.2,
                        ),
                      ),
                    ),
                    onChanged: _onBalanceChanged,
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal Edit Dompet — MyFinance Minimal (Quiet, Clean, Premium)
class _EditWalletModal extends ConsumerStatefulWidget {
  final Wallet wallet;

  const _EditWalletModal({required this.wallet});

  @override
  ConsumerState<_EditWalletModal> createState() => _EditWalletModalState();
}

class _EditWalletModalState extends ConsumerState<_EditWalletModal> {
  late final TextEditingController _nameController;
  late WalletType _selectedType;
  late String _selectedColorHex;
  late String _selectedIconKey;
  bool _isLoading = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.wallet.name);
    _selectedType = widget.wallet.type;
    _selectedColorHex = widget.wallet.colorHex ?? '0xFF0E7A4A';
    _selectedIconKey = widget.wallet.iconKey ?? 'wallet';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onTypeSelected(WalletType type) {
    unawaited(AppHaptics.selection());
    setState(() {
      _selectedType = type;
      switch (type) {
        case WalletType.cash:
          _selectedIconKey = 'cash';
          break;
        case WalletType.bank:
          _selectedIconKey = 'bank';
          break;
        case WalletType.eWallet:
          _selectedIconKey = 'card';
          break;
        case WalletType.other:
          _selectedIconKey = 'wallet';
          break;
      }

      // Auto-set nama dompet sesuai template pertama dari tipe yang baru dipilih
      final availablePresets = CardThemeHelper.getPresetsForType(type);
      final currentMatches = availablePresets.any((p) => p.displayName.toLowerCase() == _nameController.text.trim().toLowerCase());
      if (!currentMatches && availablePresets.isNotEmpty) {
        _nameController.text = availablePresets.first.displayName;
      }
      if (_nameError != null) _nameError = null;
    });
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _nameError = 'Nama dompet wajib diisi.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _nameError = null;
    });

    try {
      final success = await ref.read(walletsControllerProvider.notifier).updateWallet(
            id: widget.wallet.id,
            name: name,
            type: _selectedType,
            openingBalance: widget.wallet.openingBalance,
            iconKey: _selectedIconKey,
            colorHex: _selectedColorHex,
            isArchived: widget.wallet.isArchived,
            openingDate: widget.wallet.openingDate,
            currencyCode: widget.wallet.currencyCode,
            createdAt: widget.wallet.createdAt,
          );

      if (mounted) {
        setState(() => _isLoading = false);
        if (success) {
          unawaited(AppHaptics.medium());
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Dompet "$name" berhasil diperbarui.')),
            );
          }
        } else {
          final err = ref.read(walletsControllerProvider).error;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memperbarui: ${err ?? "Terjadi kesalahan"}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
    final dividerColor = isDark ? AppColors.dividerDark : AppColors.dividerLight;
    final surfaceElevated = isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.only(bottom: keyboardPadding),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceModalDark : AppColors.surfaceModalLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Top Header: Batal, Title, Simpan
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Batal',
                      style: TextStyle(fontSize: 15, color: textSecondary),
                    ),
                  ),
                  Text(
                    'Edit Dompet',
                    style: AppTypography.headline.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            'Simpan',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.incomeDark : AppColors.incomeLight,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 0.6, color: dividerColor),

            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  // 1. Live Realistic Card Preview (Persis Desain Gambar 1 & 2)
                  Center(
                    child: RealisticCardWidget(
                      wallet: Wallet(
                        id: widget.wallet.id,
                        name: _nameController.text.trim().isNotEmpty
                            ? _nameController.text.trim()
                            : widget.wallet.name,
                        type: _selectedType,
                        openingBalance: widget.wallet.openingBalance,
                        openingDate: widget.wallet.openingDate,
                        createdAt: widget.wallet.createdAt,
                        updatedAt: DateTime.now().toIso8601String(),
                        iconKey: _selectedIconKey,
                        colorHex: _selectedColorHex,
                        currencyCode: widget.wallet.currencyCode,
                        isArchived: widget.wallet.isArchived,
                      ),
                      currentBalance: ref.watch(walletsWithBalanceStreamProvider).value?.where((w) => w.wallet.id == widget.wallet.id).firstOrNull?.currentBalance ?? widget.wallet.openingBalance,
                      isBalanceVisible: true,
                      accountHolderName: ref.watch(authCurrentUserProvider)?.name,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Tipe Dompet
                  Text(
                    'TIPE DOMPET',
                    style: AppTypography.caption1.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: WalletType.values.map((type) {
                      final isSelected = _selectedType == type;
                      return InkWell(
                        onTap: () => _onTypeSelected(type),
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark ? AppColors.surfaceElevatedDark : AppColors.textPrimaryLight)
                                : (isDark ? AppColors.surfaceModalDark : AppColors.surfaceModalLight),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? (isDark ? AppColors.borderLight : AppColors.textPrimaryLight)
                                  : borderColor,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            type.displayName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected
                                  ? (isDark ? AppColors.textPrimaryDark : Colors.white)
                                  : textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // 3. Preset Pilihan Sesuai Tipe
                  Text(
                    'PILIH TEMPLAT / PENERBIT KARTU',
                    style: AppTypography.caption1.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: CardThemeHelper.getPresetsForType(_selectedType).map((preset) {
                        final isSelected = _nameController.text.trim().toLowerCase() == preset.displayName.toLowerCase();
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () {
                              unawaited(AppHaptics.selection());
                              setState(() {
                                _nameController.text = preset.displayName;
                                if (_nameError != null) _nameError = null;
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                gradient: preset.gradient,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? Colors.white : Colors.white24,
                                  width: isSelected ? 1.8 : 0.6,
                                ),
                              ),
                              child: Text(
                                preset.displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 4. Nama Dompet
                  Text(
                    'NAMA DOMPET / REKENING',
                    style: AppTypography.caption1.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    style: AppTypography.body,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: surfaceElevated,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderColor, width: 0.8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderColor, width: 0.8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          width: 1.2,
                        ),
                      ),
                      errorText: _nameError,
                    ),
                    onChanged: (_) {
                      if (_nameError != null) setState(() => _nameError = null);
                    },
                  ),

                  const SizedBox(height: 20),

                  // Saldo Awal (Aturan MyFinance: Ditampilkan terformat sesuai integritas buku kas)
                  Text(
                    'SALDO AWAL',
                    style: AppTypography.caption1.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor, width: 0.8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          CurrencyFormatter.formatRupiah(widget.wallet.openingBalance),
                          style: AppTypography.title3.copyWith(
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceModalDark : AppColors.surfaceModalLight,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: borderColor, width: 0.6),
                          ),
                          child: Text(
                            'Tersimpan',
                            style: AppTypography.caption2.copyWith(color: textSecondary, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Saldo awal dikunci untuk menjaga konsistensi kalkulasi mutasi transaksi.',
                    style: AppTypography.caption2.copyWith(color: textSecondary, fontSize: 11),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
