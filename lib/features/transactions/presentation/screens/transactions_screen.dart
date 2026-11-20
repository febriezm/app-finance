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
import '../../../../shared/widgets/empty_state.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_with_details.dart';
import '../widgets/add_transaction_sheet.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  int _selectedFilterIndex = 0; // 0: Semua, 1: Pengeluaran, 2: Pemasukan, 3: Transfer

  void _showAddTransaction(BuildContext context) {
    AddTransactionSheet.show(context);
  }

  void _showDetailSheet(BuildContext context, TransactionWithDetails item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tx = item.transaction;

    final typeColor = tx.type == TransactionType.expense
        ? (isDark ? AppColors.expenseDark : AppColors.expenseLight)
        : tx.type == TransactionType.income
            ? (isDark ? AppColors.incomeDark : AppColors.incomeLight)
            : (isDark ? AppColors.transferDark : AppColors.transferLight);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
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

                // Title & Amount
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.displayTitle, style: AppTypography.title3),
                          const SizedBox(height: 2),
                          Text(
                            DateFormatter.formatDateAndTime(tx.occurredAt),
                            style: AppTypography.footnote.copyWith(
                              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      (tx.type == TransactionType.expense ? '- ' : tx.type == TransactionType.income ? '+ ' : '') +
                          CurrencyFormatter.formatRupiah(tx.amount),
                      style: AppTypography.headline.copyWith(
                        color: tx.status == TransactionStatus.voided ? Colors.grey : typeColor,
                        decoration: tx.status == TransactionStatus.voided ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Details card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRow('Jenis', tx.type.displayName, isDark),
                      const Divider(height: 16),
                      _buildRow('Status', tx.status.displayName, isDark,
                          valueColor: tx.status == TransactionStatus.confirmed ? Colors.green : Colors.red),
                      const Divider(height: 16),
                      _buildRow('Dompet Sumber', item.wallet?.name ?? '-', isDark),
                      if (tx.type == TransactionType.transfer) ...[
                        const Divider(height: 16),
                        _buildRow(
                          'Tujuan Transfer',
                          item.destinationWallet?.name ?? (tx.merchant ?? 'Rekening / Pihak Luar'),
                          isDark,
                        ),
                      ],
                      if (item.category != null) ...[
                        const Divider(height: 16),
                        _buildRow('Kategori', item.category!.name, isDark),
                      ],
                      if (tx.merchant != null && tx.merchant!.isNotEmpty && tx.type != TransactionType.transfer) ...[
                        const Divider(height: 16),
                        _buildRow('Merchant/Penerima', tx.merchant!, isDark),
                      ],
                      if (tx.description != null && tx.description!.isNotEmpty && tx.description != tx.merchant) ...[
                        const Divider(height: 18),
                        _buildBlockSection('Keterangan', tx.description!, isDark),
                      ],
                      if (tx.notes != null && tx.notes!.isNotEmpty) ...[
                        const Divider(height: 18),
                        _buildBlockSection('Rincian Item / Catatan', tx.notes!, isDark),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                if (tx.status == TransactionStatus.confirmed)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                      label: const Text('Batalkan Transaksi (Void)', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Batalkan Transaksi?'),
                            content: const Text(
                              'Transaksi ini akan ditandai "Voided" dan tidak akan lagi memengaruhi saldo dompet maupun laporan keuangan.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Tidak'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Ya, Batalkan', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          await ref.read(transactionsControllerProvider.notifier).voidTransaction(tx.id);
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Transaksi berhasil dibatalkan.')),
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
      ),
    );
  }

  Widget _buildRow(String label, String value, bool isDark, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: AppTypography.footnote.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppTypography.footnote.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBlockSection(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption1.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceCardDark : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
              width: 0.8,
            ),
          ),
          child: Text(
            value,
            style: AppTypography.subhead.copyWith(
              fontWeight: FontWeight.w500,
              height: 1.4,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final transactionsAsync = ref.watch(recentTransactionsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_outlined),
            tooltip: 'Scan Struk (OCR)',
            onPressed: () => context.push(AppRouter.receiptScanner),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Catat Transaksi',
            onPressed: () => _showAddTransaction(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs Segment
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _buildFilterTab(0, 'Semua', isDark),
                  _buildFilterTab(1, 'Pengeluaran', isDark),
                  _buildFilterTab(2, 'Pemasukan', isDark),
                  _buildFilterTab(3, 'Transfer', isDark),
                ],
              ),
            ),
          ),

          // Transactions List
          Expanded(
            child: transactionsAsync.when(
              data: (transactions) {
                // Apply filter
                final filtered = transactions.where((item) {
                  if (_selectedFilterIndex == 1) return item.transaction.type == TransactionType.expense;
                  if (_selectedFilterIndex == 2) return item.transaction.type == TransactionType.income;
                  if (_selectedFilterIndex == 3) return item.transaction.type == TransactionType.transfer;
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Belum Ada Transaksi',
                    message: _selectedFilterIndex == 0
                        ? 'Catat transaksi pertama Anda untuk mulai memantau arus kas.'
                        : 'Tidak ada transaksi untuk filter ini.',
                    actionLabel: 'Catat Transaksi',
                    onActionPressed: () => _showAddTransaction(context),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
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

                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _showDetailSheet(context, item),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                            // Icon Avatar
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isVoided ? Colors.grey.withValues(alpha: 0.2) : itemColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                itemIcon,
                                color: isVoided ? Colors.grey : itemColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Title & Subtitle
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.displayTitle,
                                          style: AppTypography.body.copyWith(
                                            fontWeight: FontWeight.w600,
                                            decoration: isVoided ? TextDecoration.lineThrough : null,
                                            color: isVoided
                                                ? (isDark ? AppColors.textDisabledDark : AppColors.textDisabledLight)
                                                : null,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isVoided)
                                        Container(
                                          margin: const EdgeInsets.only(left: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'VOID',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.displaySubtitle.isNotEmpty
                                        ? '${item.displaySubtitle} • ${DateFormatter.formatDateAndTime(tx.occurredAt)}'
                                        : DateFormatter.formatDateAndTime(tx.occurredAt),
                                    style: AppTypography.caption1.copyWith(
                                      color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Amount
                            Text(
                              (tx.type == TransactionType.expense ? '- ' : tx.type == TransactionType.income ? '+ ' : '') +
                                  CurrencyFormatter.formatRupiah(tx.amount),
                              style: AppTypography.headline.copyWith(
                                fontSize: 15,
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
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Belum dapat memuat daftar transaksi. Silakan muat ulang.',
                    style: AppTypography.subhead,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(int index, String title, bool isDark) {
    final isSelected = _selectedFilterIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilterIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.surfaceCardDark : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)
                  : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
            ),
          ),
        ),
      ),
    );
  }
}
