import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/utils/app_haptics.dart';
import '../features/transactions/domain/entities/transaction.dart';
import '../features/transactions/presentation/widgets/add_transaction_sheet.dart';
import 'router.dart';

class ScaffoldWithNavBar extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const ScaffoldWithNavBar({
    super.key,
    required this.navigationShell,
  });

  void _onTap(BuildContext context, int index) {
    if (index == 2) {
      // Tombol tengah: Tampilkan modal aksi cepat (Quick Actions)
      AppHaptics.light();
      _showQuickActionModal(context);
      return;
    }

    AppHaptics.selection();
    final targetBranch = index > 2 ? index - 1 : index;
    navigationShell.goBranch(
      targetBranch,
      initialLocation: targetBranch == navigationShell.currentIndex,
    );
  }

  void _showQuickActionModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceCardDark : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text('Aksi Cepat', style: AppTypography.title3),
                const SizedBox(height: AppSpacing.md),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.expenseContainerDark : AppColors.expenseContainerLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_upward_rounded, color: AppColors.expenseLight),
                  ),
                  title: const Text('Catat Pengeluaran', style: AppTypography.headline),
                  onTap: () {
                    Navigator.pop(ctx);
                    AddTransactionSheet.show(context, initialType: TransactionType.expense);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.incomeContainerDark : AppColors.incomeContainerLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_downward_rounded, color: AppColors.incomeLight),
                  ),
                  title: const Text('Catat Pemasukan', style: AppTypography.headline),
                  onTap: () {
                    Navigator.pop(ctx);
                    AddTransactionSheet.show(context, initialType: TransactionType.income);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.transferContainerDark : AppColors.transferContainerLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.swap_horiz_rounded, color: AppColors.transferLight),
                  ),
                  title: const Text('Transfer Saldo', style: AppTypography.headline),
                  onTap: () {
                    Navigator.pop(ctx);
                    AddTransactionSheet.show(context, initialType: TransactionType.transfer);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.transferContainerDark : AppColors.transferContainerLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.pie_chart_outline, color: AppColors.transferLight),
                  ),
                  title: const Text('Anggaran Bulanan', style: AppTypography.headline),
                  subtitle: const Text('Kelola batas pengeluaran & kategori', style: AppTypography.caption1),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push(AppRouter.budgets);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceElevatedDark : AppColors.dividerLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.document_scanner_outlined, color: AppColors.primaryNavyLight),
                  ),
                  title: const Text('Scan Struk (OCR)', style: AppTypography.headline),
                  subtitle: const Text('Ekstraksi otomatis struk belanja on-device', style: AppTypography.caption1),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push(AppRouter.receiptScanner);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = navigationShell.currentIndex;
    final navIndex = currentIndex >= 2 ? currentIndex + 1 : currentIndex;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navIndex,
        onTap: (index) => _onTap(context, index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_filled),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Transaksi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle, size: 36, color: AppColors.primaryNavy),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Dompet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Laporan',
          ),
        ],
      ),
    );
  }
}
