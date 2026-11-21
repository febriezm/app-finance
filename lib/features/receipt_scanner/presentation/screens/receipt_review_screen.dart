import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/app_providers.dart';
import '../../../../app/router.dart';
import '../../../../core/formatting/currency_formatter.dart';
import '../../../../core/formatting/date_formatter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/presentation/widgets/add_transaction_sheet.dart';
import '../../domain/entities/receipt_draft.dart';
import '../widgets/confidence_badge.dart';
import '../widgets/receipt_items_list.dart';

/// Layar Review & Konfirmasi Hasil Scan Struk — MyFinance Minimal (Quiet, Clean, Premium).
///
/// Karakter Desain:
/// - Preview foto struk yang rapi dengan rasio proporsional.
/// - Input nominal pengeluaran besar dan terfokus (32px, tabular figures).
/// - Form detail tanpa card bertumpuk dengan border hairline halus.
/// - Rincian item belanja yang bersih dengan divider tipis.
/// - Tombol konfirmasi satu sentuhan dengan feedback haptik.
class ReceiptReviewScreen extends ConsumerStatefulWidget {
  final ReceiptDraft draft;

  const ReceiptReviewScreen({
    super.key,
    required this.draft,
  });

  @override
  ConsumerState<ReceiptReviewScreen> createState() => _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends ConsumerState<ReceiptReviewScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _merchantController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  int _amount = 0;
  String? _selectedWalletId;
  String? _selectedCategoryId;
  late DateTime _occurredAt;
  bool _isSaving = false;
  bool _showRawOcr = false;
  late String _rawText;

  @override
  void initState() {
    super.initState();
    _amount = widget.draft.totalAmount ?? 0;
    if (_amount > 0) {
      _amountController.text = CurrencyFormatter.formatRupiah(_amount);
    }
    _merchantController.text = widget.draft.merchant ?? '';
    _occurredAt = widget.draft.occurredAt ?? DateTime.now();
    _selectedCategoryId = widget.draft.suggestedCategoryId;
    _rawText = widget.draft.rawText;

    // Prefill Keterangan / Catatan dengan rincian item belanja struk
    if (widget.draft.items.isNotEmpty) {
      final itemsSummary = widget.draft.items.map((i) {
        final qtyStr = i.quantity > 1 ? '${i.quantity}x ' : '';
        return '$qtyStr${i.name} (${CurrencyFormatter.formatRupiah(i.totalPrice)})';
      }).join(', ');
      _notesController.text = itemsSummary;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String val) {
    final clean = val.replaceAll(RegExp(r'[^0-9]'), '');
    final num = int.tryParse(clean) ?? 0;
    setState(() {
      _amount = num;
    });
    final formatted = num > 0 ? CurrencyFormatter.formatRupiah(num) : '';
    if (_amountController.text != formatted) {
      _amountController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  Future<void> _selectDate() async {
    unawaited(AppHaptics.selection());
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      if (!mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_occurredAt),
      );
      if (!mounted) return;
      setState(() {
        _occurredAt = DateTime(
          picked.year,
          picked.month,
          picked.day,
          time?.hour ?? _occurredAt.hour,
          time?.minute ?? _occurredAt.minute,
        );
      });
    }
  }

  Future<void> _confirmAndSave() async {
    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal pengeluaran harus lebih dari Rp 0.')),
      );
      return;
    }
    if (_selectedWalletId == null || _selectedWalletId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih dompet sumber dana.')),
      );
      return;
    }
    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan tentukan kategori pengeluaran.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final merchant = _merchantController.text.trim();
    final notes = _notesController.text.trim();

    // Rangkum item ke deskripsi / keterangan transaksi agar muncul di riwayat
    String description;
    if (widget.draft.items.isNotEmpty) {
      final itemNames = widget.draft.items.map((i) => i.name).join(', ');
      description = merchant.isNotEmpty ? '$merchant: $itemNames' : itemNames;
    } else if (merchant.isNotEmpty) {
      description = 'Belanja di $merchant';
    } else {
      description = 'Scan Struk Pembelian';
    }

    final txId = await ref.read(receiptScannerControllerProvider.notifier).confirmTransaction(
          draft: widget.draft,
          walletId: _selectedWalletId!,
          categoryId: _selectedCategoryId!,
          amount: _amount,
          occurredAt: _occurredAt,
          merchant: merchant.isNotEmpty ? merchant : null,
          description: description,
          notes: notes.isNotEmpty ? notes : null,
          imageBytes: widget.draft.imageBytes,
        );

    setState(() => _isSaving = false);

    if (mounted) {
      if (txId != null) {
        unawaited(AppHaptics.medium());
        // Refresh providers
        ref.invalidate(walletsWithBalanceStreamProvider);
        ref.invalidate(recentTransactionsStreamProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi struk berhasil dikonfirmasi dan dicatat!')),
        );
        // Kembali ke dashboard/transaksi
        context.go(AppRouter.transactions);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan transaksi. Silakan periksa kembali data.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final walletsAsync = ref.watch(walletsWithBalanceStreamProvider);
    final categoriesAsync = ref.watch(activeCategoriesStreamProvider(CategoryType.expense));

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Review Hasil Struk'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        children: [
          // 1. Preview Foto Struk (jika tersedia)
          if (widget.draft.imageBytes != null && widget.draft.imageBytes!.isNotEmpty) ...[
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  width: 0.8,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Image.memory(
                    widget.draft.imageBytes!,
                    width: double.infinity,
                    height: 190,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.attachment_rounded, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Lampiran Struk',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 2. Banner Status / Verifikasi
          if (widget.draft.totalAmount == null || widget.draft.totalAmount == 0) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceElevatedDark : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppColors.warningDark : AppColors.warningLight,
                  width: 0.8,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.warningLight, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nominal Belum Terdeteksi Otomatis',
                          style: AppTypography.subhead.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.warningDark : AppColors.warningLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Sistem tidak menemukan angka total belanja pada foto ini. Silakan masukkan nominal dan nama toko secara manual. Foto struk tetap tersimpan sebagai bukti transaksi.',
                          style: AppTypography.caption.copyWith(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // 3. Nominal Pengeluaran (Fokus Utama)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'NOMINAL PENGELUARAN',
                style: AppTypography.caption.copyWith(
                  color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
              ConfidenceBadge(isCertain: widget.draft.isTotalCertain),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                width: 0.8,
              ),
            ),
            child: TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: AppTypography.headline.copyWith(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.expenseDark : AppColors.expenseLight,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
              decoration: const InputDecoration(
                hintText: 'Rp 0',
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: _onAmountChanged,
            ),
          ),
          if (!widget.draft.isTotalCertain) ...[
            const SizedBox(height: 4),
            Text(
              'Nominal total struk belum terdeteksi pasti. Harap periksa kebenaran angka di atas.',
              style: AppTypography.caption2.copyWith(
                color: isDark ? AppColors.warningDark : AppColors.warningLight,
              ),
            ),
          ],

          const SizedBox(height: 20),

          // 4. Toko / Merchant & Tanggal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'NAMA TOKO / MERCHANT',
                style: AppTypography.caption.copyWith(
                  color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
              ConfidenceBadge(isCertain: widget.draft.isMerchantCertain),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                width: 0.8,
              ),
            ),
            child: TextField(
              controller: _merchantController,
              style: AppTypography.body,
              decoration: const InputDecoration(
                hintText: 'Contoh: Indomaret, HokBen, SPBU...',
                border: InputBorder.none,
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Tanggal & Waktu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TANGGAL & WAKTU',
                style: AppTypography.caption.copyWith(
                  color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
              ConfidenceBadge(isCertain: widget.draft.isDateCertain),
            ],
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: _selectDate,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppDateFormatter.formatDateTime(_occurredAt),
                    style: AppTypography.body.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Icon(Icons.calendar_today_outlined, size: 18, color: Colors.grey),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          // 5. Dompet Sumber Dana
          Text(
            'DOMPET SUMBER DANA',
            style: AppTypography.caption.copyWith(
              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          walletsAsync.when(
            data: (wallets) {
              if (wallets.isEmpty) {
                return const Text('Belum ada dompet aktif.');
              }
              if (_selectedWalletId == null && wallets.isNotEmpty) {
                _selectedWalletId = wallets.first.wallet.id;
              }
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    width: 0.8,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedWalletId,
                    isExpanded: true,
                    items: wallets.map((w) {
                      return DropdownMenuItem(
                        value: w.wallet.id,
                        child: Text(
                          '${w.wallet.name} (${CurrencyFormatter.formatRupiah(w.currentBalance)})',
                          style: AppTypography.body.copyWith(fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      unawaited(AppHaptics.selection());
                      setState(() => _selectedWalletId = val);
                    },
                  ),
                ),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => const Text('Gagal memuat dompet', style: TextStyle(color: Colors.red, fontSize: 13)),
          ),

          const SizedBox(height: 18),

          // 6. Kategori Pengeluaran
          Text(
            'KATEGORI PENGELUARAN',
            style: AppTypography.caption.copyWith(
              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          categoriesAsync.when(
            data: (categories) {
              if (categories.isEmpty) {
                return const Text('Belum ada kategori pengeluaran.');
              }
              if (_selectedCategoryId == null || !categories.any((c) => c.id == _selectedCategoryId)) {
                _selectedCategoryId = categories.first.id;
              }
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    width: 0.8,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategoryId,
                    isExpanded: true,
                    items: categories.map((c) {
                      return DropdownMenuItem(
                        value: c.id,
                        child: Row(
                          children: [
                            Icon(AppIcons.getIcon(c.iconKey), size: 18, color: AppIcons.parseColor(c.colorHex)),
                            const SizedBox(width: 10),
                            Text(c.name, style: AppTypography.body.copyWith(fontSize: 14)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      unawaited(AppHaptics.selection());
                      setState(() => _selectedCategoryId = val);
                    },
                  ),
                ),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => const Text('Gagal memuat kategori', style: TextStyle(color: Colors.red, fontSize: 13)),
          ),

          const SizedBox(height: 18),

          // 7. Catatan Tambahan
          Text(
            'CATATAN / KETERANGAN TAMBAHAN',
            style: AppTypography.caption.copyWith(
              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceElevatedDark : AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                width: 0.8,
              ),
            ),
            child: TextField(
              controller: _notesController,
              style: AppTypography.body,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Tulis catatan jika diperlukan...',
                border: InputBorder.none,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 8. Ringkasan Finansial Struk (Subtotal & Pajak)
          if (widget.draft.subtotal != null || widget.draft.taxAmount != null) ...[
            const MinimalSectionHeader(title: 'Rincian Biaya Struk'),
            if (widget.draft.subtotal != null)
              FinanceSummaryRow(
                label: 'Subtotal',
                customValue: CurrencyFormatter.formatRupiah(widget.draft.subtotal!),
              ),
            if (widget.draft.taxAmount != null)
              FinanceSummaryRow(
                label: 'Pajak (PPN/PB1)',
                customValue: CurrencyFormatter.formatRupiah(widget.draft.taxAmount!),
              ),
            if (widget.draft.serviceCharge != null)
              FinanceSummaryRow(
                label: 'Biaya Layanan',
                customValue: CurrencyFormatter.formatRupiah(widget.draft.serviceCharge!),
              ),
            if (widget.draft.discountAmount != null)
              FinanceSummaryRow(
                label: 'Diskon / Potongan',
                customValue: '- ${CurrencyFormatter.formatRupiah(widget.draft.discountAmount!)}',
                valueColor: isDark ? AppColors.incomeDark : AppColors.incomeLight,
              ),
            const SizedBox(height: 20),
          ],

          // 9. Rincian Item Produk Terdeteksi
          MinimalSectionHeader(
            title: 'Rincian Item Belanja',
            actionLabel: '${widget.draft.items.length} item',
          ),
          const SizedBox(height: 4),
          ReceiptItemsList(items: widget.draft.items),

          const SizedBox(height: 20),

          // 10. Teks OCR Mentah (Audit & Debugging)
          InkWell(
            onTap: () {
              unawaited(AppHaptics.selection());
              setState(() => _showRawOcr = !_showRawOcr);
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _showRawOcr ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Teks OCR Mentah (Lokal)',
                        style: AppTypography.subhead.copyWith(fontSize: 14),
                      ),
                    ],
                  ),
                  if (_rawText.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        setState(() => _rawText = '');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Teks mentah OCR telah dibersihkan.')),
                        );
                      },
                      child: Text(
                        'Hapus',
                        style: TextStyle(
                          color: isDark ? AppColors.expenseDark : AppColors.expenseLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_showRawOcr) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceElevatedDark : AppColors.dividerLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _rawText.isNotEmpty ? _rawText : '(Teks mentah telah dibersihkan)',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ],

          const SizedBox(height: 32),

          // 11. Tombol Konfirmasi Simpan
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? AppColors.incomeDark : AppColors.incomeLight,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isSaving ? null : _confirmAndSave,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Konfirmasi & Simpan Transaksi',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),

          if (widget.draft.totalAmount == null || widget.draft.totalAmount == 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    width: 0.8,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  AddTransactionSheet.show(context, initialType: TransactionType.expense);
                },
                child: const Text('Beralih ke Input Manual'),
              ),
            ),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
