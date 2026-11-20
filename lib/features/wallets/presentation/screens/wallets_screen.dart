import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/app_providers.dart';
import '../../../../core/formatting/currency_formatter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../domain/entities/wallet.dart';

class WalletsScreen extends ConsumerWidget {
  const WalletsScreen({super.key});

  void _showAddWalletSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddWalletModal(),
    );
  }

  void _showWalletDetailSheet(BuildContext context, WidgetRef ref, WalletWithBalance item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArchived = item.wallet.isArchived;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppIcons.parseColor(item.wallet.colorHex),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      AppIcons.getIcon(item.wallet.iconKey),
                      color: Colors.white,
                      size: 26,
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
                                style: AppTypography.title3,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isArchived) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Arsip',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(item.wallet.type.displayName, style: AppTypography.subhead),
                      ],
                    ),
                  ),
                ],
              ),
              if (isArchived) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withOpacity(0.4), width: 0.8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Dompet ini diarsipkan sebagai cadangan dan tidak dapat dipilih sebagai sumber dana transaksi.',
                          style: AppTypography.caption1.copyWith(
                            color: isDark ? Colors.orange.shade200 : Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Saldo Berjalan', style: AppTypography.callout),
                        Text(
                          CurrencyFormatter.formatRupiah(item.currentBalance),
                          style: AppTypography.headline.copyWith(
                            color: item.currentBalance >= 0
                                ? (isDark ? AppColors.incomeDark : AppColors.incomeLight)
                                : (isDark ? AppColors.expenseDark : AppColors.expenseLight),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Saldo Awal', style: AppTypography.footnote),
                        Text(
                          CurrencyFormatter.formatRupiah(item.wallet.openingBalance),
                          style: AppTypography.footnote,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (isArchived)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.unarchive_outlined, color: Colors.green),
                    label: const Text(
                      'Aktifkan Kembali Dompet',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.green),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Aktifkan Kembali Dompet?'),
                          content: Text(
                            'Dompet "${item.wallet.name}" akan kembali ke daftar dompet aktif dan dapat digunakan kembali sebagai sumber dana transaksi.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Batal'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text(
                                'Aktifkan Kembali',
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
                            SnackBar(content: Text('Dompet "${item.wallet.name}" berhasil diaktifkan kembali.')),
                          );
                        }
                      }
                    },
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.archive_outlined, color: Colors.orange),
                    label: const Text('Arsipkan Dompet', style: TextStyle(color: Colors.orange)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Arsipkan Dompet?'),
                          content: Text(
                            'Dompet "${item.wallet.name}" akan dipindahkan ke daftar arsip/cadangan dan tidak dapat dipilih sebagai sumber dana transaksi. Riwayat mutasi transaksi tetap tersimpan rapi.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Batal'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Arsipkan', style: TextStyle(color: Colors.orange)),
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
      appBar: AppBar(
        title: const Text('Dompet & Rekening'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Tambah Dompet',
            onPressed: () => _showAddWalletSheet(context),
          ),
        ],
      ),
      body: walletsAsync.when(
        data: (wallets) {
          if (wallets.isEmpty && archivedWallets.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    EmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Belum Ada Dompet',
                      message: 'Tambahkan dompet pertama Anda (rekening bank, kas tunai, atau e-wallet) untuk mulai mencatat keuangan.',
                      actionLabel: 'Tambah Dompet',
                      onActionPressed: () => _showAddWalletSheet(context),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Total Asset Card
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Total Saldo Aset',
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
                            'Ledger Terkalkulasi',
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
                    Text(
                      archivedWallets.isNotEmpty
                          ? '${wallets.length} dompet aktif • ${archivedWallets.length} diarsipkan (Total Semua Aset)'
                          : '${wallets.length} dompet aktif',
                      style: AppTypography.footnote.copyWith(
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Text(
                'Daftar Dompet Aktif',
                style: AppTypography.headline.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 10),

              if (wallets.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      width: 0.8,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Tidak ada dompet aktif. Aktifkan dari arsip di bawah atau tambah dompet baru.',
                      style: AppTypography.caption1.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                // Wallets List
                ...wallets.map((item) {
                  final walletColor = AppIcons.parseColor(item.wallet.colorHex);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _showWalletDetailSheet(context, ref, item),
                      child: Container(
                        padding: const EdgeInsets.all(14),
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
                            // Wallet Icon
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: walletColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                AppIcons.getIcon(item.wallet.iconKey),
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Name & Type
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.wallet.name,
                                    style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 3),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: (isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item.wallet.type.displayName,
                                      style: AppTypography.caption2.copyWith(
                                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Balance
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  CurrencyFormatter.formatRupiah(item.currentBalance),
                                  style: AppTypography.headline.copyWith(
                                    fontSize: 16,
                                    color: item.currentBalance >= 0
                                        ? (isDark ? AppColors.incomeDark : AppColors.incomeLight)
                                        : (isDark ? AppColors.expenseDark : AppColors.expenseLight),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

              // Section: Dompet Diarsipkan / Cadangan
              if (archivedWallets.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(Icons.archive_outlined, size: 18, color: Colors.orange),
                    const SizedBox(width: 6),
                    Text(
                      'Dompet Diarsipkan / Cadangan (${archivedWallets.length})',
                      style: AppTypography.headline.copyWith(fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Dompet cadangan disimpan sebagai arsip saldo dan tidak dapat dipilih sebagai sumber dana transaksi.',
                  style: AppTypography.caption1.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 12),
                ...archivedWallets.map((item) {
                  final walletColor = AppIcons.parseColor(item.wallet.colorHex);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _showWalletDetailSheet(context, ref, item),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.surfaceElevatedDark.withOpacity(0.5)
                              : AppColors.backgroundLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? AppColors.borderDark : AppColors.borderLight,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Wallet Icon (muted)
                            Opacity(
                              opacity: 0.7,
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: walletColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  AppIcons.getIcon(item.wallet.iconKey),
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Name & Type
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          item.wallet.name,
                                          style: AppTypography.body.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? AppColors.textSecondaryDark
                                                : AppColors.textSecondaryLight,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Cadangan',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${item.wallet.type.displayName} • Arsip',
                                    style: AppTypography.caption2.copyWith(
                                      color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Balance
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  CurrencyFormatter.formatRupiah(item.currentBalance),
                                  style: AppTypography.headline.copyWith(
                                    fontSize: 15,
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
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

  final List<String> _colors = [
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
          await HapticFeedback.lightImpact();
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

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          const SizedBox(height: 10),

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
                      fontSize: 16,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
                Text(
                  'Tambah Dompet Baru',
                  style: AppTypography.headline.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                TextButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Simpan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.incomeDark : AppColors.incomeLight,
                          ),
                        ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              children: [
                // Nama Dompet
                Text(
                  'Nama Dompet / Rekening',
                  style: AppTypography.footnote.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Contoh: BCA Utama, GoPay, Dompet Tunai',
                      border: InputBorder.none,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Tipe Dompet
                Text(
                  'Tipe Dompet',
                  style: AppTypography.footnote.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
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

                const SizedBox(height: 18),

                // Saldo Awal
                Text(
                  'Saldo Awal',
                  style: AppTypography.footnote.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _openingBalanceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Rp 0',
                      border: InputBorder.none,
                    ),
                    onChanged: _onBalanceChanged,
                  ),
                ),

                const SizedBox(height: 18),

                // Pilihan Warna
                Text(
                  'Warna Aksen',
                  style: AppTypography.footnote.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: _colors.map((cHex) {
                    final color = AppIcons.parseColor(cHex);
                    final isSelected = _selectedColorHex == cHex;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColorHex = cHex),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 28),

                // Tombol Simpan Utama di Bawah
                AppButton(
                  label: 'Simpan Dompet',
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _submit,
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
