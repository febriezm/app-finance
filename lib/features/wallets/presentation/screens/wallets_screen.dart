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

/// Halaman Dompet & Rekening — MyFinance Minimal (Quiet, Clean, Premium).
///
/// Karakter Desain:
/// - Total balance minimalis tanpa card bertumpuk.
/// - Daftar dompet terkelompok (Grouped List): Rekening Bank, Kas Tunai, E-Wallet, Lainnya.
/// - Setiap akun menggunakan [WalletListTile] dengan icon sederhana, typography bersih, angka tabular, dan divider tipis.
/// - Mempertahankan seluruh fitur: Tambah, Edit, Detail, Arsip/Aktifkan, Riwayat Mutasi, dan Transfer.
class WalletsScreen extends ConsumerWidget {
  const WalletsScreen({super.key});

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
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceModalDark : AppColors.surfaceModalLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 20),

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
                        Navigator.of(context).pop();
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
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Aktifkan Kembali Dompet?'),
                                  content: Text(
                                    'Dompet "${item.wallet.name}" akan kembali ke daftar aktif dan dapat dipilih sebagai sumber dana transaksi.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(false),
                                      child: const Text('Batal'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(true),
                                      child: const Text(
                                        'Aktifkan',
                                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                await ref.read(walletsControllerProvider.notifier).unarchiveWallet(item.wallet.id);
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
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Arsipkan Dompet?'),
                                  content: Text(
                                    'Dompet "${item.wallet.name}" akan dipindahkan ke daftar arsip cadangan. Riwayat mutasi transaksi tetap tersimpan utuh.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(false),
                                      child: const Text('Batal'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(true),
                                      child: const Text(
                                        'Arsipkan',
                                        style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                await ref.read(walletsControllerProvider.notifier).archiveWallet(item.wallet.id);
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
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final walletsAsync = ref.watch(walletsWithBalanceStreamProvider);
    final archivedWalletsAsync = ref.watch(archivedWalletsWithBalanceStreamProvider);
    final totalBalance = ref.watch(totalAllAssetBalanceProvider);

    final archivedWallets = archivedWalletsAsync.asData?.value ?? [];

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

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            children: [
              // 1. Total Balance Minimalis (Quiet, Clean, Typography-First)
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'TOTAL SALDO ASET',
                    style: AppTypography.caption.copyWith(
                      color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    archivedWallets.isNotEmpty
                        ? '${wallets.length} aktif • ${archivedWallets.length} arsip'
                        : '${wallets.length} dompet aktif',
                    style: AppTypography.caption.copyWith(
                      color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              FinanceAmountText(
                amount: totalBalance,
                type: AmountDisplayType.neutral,
                style: AppTypography.balanceLarge,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
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

              const SizedBox(height: 28),

              // 2. Rekening Bank Group
              if (bankWallets.isNotEmpty) ...[
                MinimalSectionHeader(
                  title: 'Rekening Bank',
                  actionLabel: '${bankWallets.length}',
                ),
                ...bankWallets.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  return WalletListTile(
                    wallet: item.wallet,
                    currentBalance: item.currentBalance,
                    showDivider: idx < bankWallets.length - 1,
                    onTap: () => _showWalletDetailSheet(context, ref, item),
                  );
                }),
                const SizedBox(height: 24),
              ],

              // 3. Kas Tunai Group
              if (cashWallets.isNotEmpty) ...[
                MinimalSectionHeader(
                  title: 'Kas Tunai',
                  actionLabel: '${cashWallets.length}',
                ),
                ...cashWallets.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  return WalletListTile(
                    wallet: item.wallet,
                    currentBalance: item.currentBalance,
                    showDivider: idx < cashWallets.length - 1,
                    onTap: () => _showWalletDetailSheet(context, ref, item),
                  );
                }),
                const SizedBox(height: 24),
              ],

              // 4. E-Wallet Group
              if (eWalletWallets.isNotEmpty) ...[
                MinimalSectionHeader(
                  title: 'E-Wallet',
                  actionLabel: '${eWalletWallets.length}',
                ),
                ...eWalletWallets.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  return WalletListTile(
                    wallet: item.wallet,
                    currentBalance: item.currentBalance,
                    showDivider: idx < eWalletWallets.length - 1,
                    onTap: () => _showWalletDetailSheet(context, ref, item),
                  );
                }),
                const SizedBox(height: 24),
              ],

              // 5. Lainnya Group
              if (otherWallets.isNotEmpty) ...[
                MinimalSectionHeader(
                  title: 'Lainnya / Investasi',
                  actionLabel: '${otherWallets.length}',
                ),
                ...otherWallets.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  return WalletListTile(
                    wallet: item.wallet,
                    currentBalance: item.currentBalance,
                    showDivider: idx < otherWallets.length - 1,
                    onTap: () => _showWalletDetailSheet(context, ref, item),
                  );
                }),
                const SizedBox(height: 24),
              ],

              // State jika dompet aktif kosong tetapi arsip tersedia
              if (wallets.isEmpty) ...[
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
                const SizedBox(height: 24),
              ],

              // 6. Dompet Diarsipkan / Cadangan Group
              if (archivedWallets.isNotEmpty) ...[
                MinimalSectionHeader(
                  title: 'Dompet Diarsipkan',
                  actionLabel: '${archivedWallets.length}',
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Dompet cadangan disimpan sebagai arsip saldo dan tidak dapat dipilih sebagai sumber dana transaksi.',
                    style: AppTypography.caption.copyWith(
                      color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                    ),
                  ),
                ),
                ...archivedWallets.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  return WalletListTile(
                    wallet: item.wallet,
                    currentBalance: item.currentBalance,
                    showDivider: idx < archivedWallets.length - 1,
                    onTap: () => _showWalletDetailSheet(context, ref, item),
                  );
                }),
                const SizedBox(height: 32),
              ],
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

/// Modal Tambah Dompet Baru — Minimal & Bersih
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
  String _selectedColorHex = '0xFF0E7A4A';
  String _selectedIconKey = 'bank';
  bool _isLoading = false;

  final List<String> _colors = const [
    '0xFF0E7A4A', // Emerald
    '0xFF0984E3', // Blue
    '0xFF9B59B6', // Purple
    '0xFFE67E22', // Orange
    '0xFFD63031', // Crimson
    '0xFF2C3E50', // Navy
  ];

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

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama dompet wajib diisi.')),
      );
      return;
    }

    setState(() => _isLoading = true);

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
            SnackBar(
              content: Text('Gagal membuat dompet: ${err ?? "Terjadi kesalahan"}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;

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
                  color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

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
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
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
            Divider(
              height: 1,
              thickness: 0.6,
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            ),

            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  // Nama Dompet
                  Text(
                    'Nama Dompet / Rekening',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        width: 0.8,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _nameController,
                      style: AppTypography.body,
                      decoration: const InputDecoration(
                        hintText: 'Contoh: BCA Utama, GoPay, Dompet Tunai',
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Tipe Dompet
                  Text(
                    'Tipe Dompet',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: WalletType.values.map((type) {
                      final isSelected = _selectedType == type;
                      return ChoiceChip(
                        label: Text(type.displayName),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            unawaited(AppHaptics.selection());
                            setState(() {
                              _selectedType = type;
                              if (type == WalletType.cash) _selectedIconKey = 'cash';
                              if (type == WalletType.bank) _selectedIconKey = 'bank';
                              if (type == WalletType.eWallet) _selectedIconKey = 'card';
                              if (type == WalletType.other) _selectedIconKey = 'wallet';
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Saldo Awal
                  Text(
                    'Saldo Awal',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        width: 0.8,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _openingBalanceController,
                      keyboardType: TextInputType.number,
                      style: AppTypography.body.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Rp 0',
                        border: InputBorder.none,
                      ),
                      onChanged: _onBalanceChanged,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Pilihan Warna Aksen
                  Text(
                    'Warna Aksen',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: _colors.map((cHex) {
                      final color = AppIcons.parseColor(cHex);
                      final isSelected = _selectedColorHex == cHex;
                      return GestureDetector(
                        onTap: () {
                          unawaited(AppHaptics.selection());
                          setState(() => _selectedColorHex = cHex);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 14),
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? (isDark ? Colors.white : Colors.black87) : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 28),

                  // Tombol Simpan Utama
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: isDark ? AppColors.incomeDark : AppColors.incomeLight,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Simpan Dompet',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal Edit Dompet — Minimal & Bersih
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

  final List<String> _colors = const [
    '0xFF0E7A4A', // Emerald
    '0xFF0984E3', // Blue
    '0xFF9B59B6', // Purple
    '0xFFE67E22', // Orange
    '0xFFD63031', // Crimson
    '0xFF2C3E50', // Navy
  ];

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

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama dompet wajib diisi.')),
      );
      return;
    }

    setState(() => _isLoading = true);

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
            SnackBar(
              content: Text('Gagal memperbarui dompet: ${err ?? "Terjadi kesalahan"}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                  color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Batal',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
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
            Divider(
              height: 1,
              thickness: 0.6,
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            ),

            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  // Nama Dompet
                  Text(
                    'Nama Dompet / Rekening',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        width: 0.8,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _nameController,
                      style: AppTypography.body,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Tipe Dompet
                  Text(
                    'Tipe Dompet',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: WalletType.values.map((type) {
                      final isSelected = _selectedType == type;
                      return ChoiceChip(
                        label: Text(type.displayName),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            unawaited(AppHaptics.selection());
                            setState(() {
                              _selectedType = type;
                              if (type == WalletType.cash) _selectedIconKey = 'cash';
                              if (type == WalletType.bank) _selectedIconKey = 'bank';
                              if (type == WalletType.eWallet) _selectedIconKey = 'card';
                              if (type == WalletType.other) _selectedIconKey = 'wallet';
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Warna Aksen
                  Text(
                    'Warna Aksen',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: _colors.map((cHex) {
                      final color = AppIcons.parseColor(cHex);
                      final isSelected = _selectedColorHex == cHex;
                      return GestureDetector(
                        onTap: () {
                          unawaited(AppHaptics.selection());
                          setState(() => _selectedColorHex = cHex);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 14),
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? (isDark ? Colors.white : Colors.black87) : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 18)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 28),

                  // Tombol Simpan Perubahan
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: isDark ? AppColors.incomeDark : AppColors.incomeLight,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'Simpan Perubahan',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
