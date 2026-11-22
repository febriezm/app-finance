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
/// Karakteristik Desain:
/// - Pratinjau foto struk ringkas (compact 140px) dengan kemampuan pinch-to-zoom interaktif layar penuh.
/// - Display nominal pengeluaran typography-first menonjol (28px tabular figures) dengan edit mulus.
/// - Form detail tanpa tumpukan card berlebihan (flat, hairline border 0.8px, whitespace lapang).
/// - Sticky bottom action bar untuk konfirmasi cepat tanpa harus scroll ke ujung struk belanja panjang.
/// - Validasi presisi dan perlindungan anti-duplikasi saat proses penyimpanan.
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

    // Prefill Keterangan / Catatan dengan rincian item belanja jika tersedia
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

  void _showZoomedReceipt() {
    if (widget.draft.imageBytes == null || widget.draft.imageBytes!.isEmpty) return;
    unawaited(AppHaptics.light());

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.90),
      builder: (ctx) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            title: const Text(
              'Pratinjau Struk',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            centerTitle: true,
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.5,
              child: Image.memory(
                widget.draft.imageBytes!,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmAndSave() async {
    // Pencegahan double submission
    if (_isSaving) return;

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
        // Sinkronisasi bulan tab Transaksi ke bulan transaksi struk yang disimpan
        ref.read(selectedTransactionMonthProvider.notifier).state =
            DateTime(_occurredAt.year, _occurredAt.month, 1);

        // Refresh providers agar Home dan Riwayat Transaksi sinkron seketika
        ref.invalidate(walletsWithBalanceStreamProvider);
        ref.invalidate(recentTransactionsStreamProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi struk berhasil dikonfirmasi dan dicatat!')),
        );
        // Kembali ke tab Transaksi dengan bulan transaksi terpilih
        context.go(AppRouter.transactions, extra: {'initialMonth': _occurredAt});
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
    final surfaceColor = isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final expenseColor = isDark ? AppColors.expenseDark : AppColors.expenseLight;
    final textTertiary = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Review Hasil Struk'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Pindai Ulang',
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                children: [
                  // 1. Preview Foto Struk (Ringkas & Dapat Dizoom)
                  if (widget.draft.imageBytes != null && widget.draft.imageBytes!.isNotEmpty) ...[
                    GestureDetector(
                      onTap: _showZoomedReceipt,
                      child: Container(
                        height: 140,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor, width: 0.8),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.memory(
                              widget.draft.imageBytes!,
                              fit: BoxFit.cover,
                            ),
                            // Gradient lembut untuk kontras indikator
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.55),
                                    ],
                                    stops: const [0.5, 1.0],
                                  ),
                                ),
                              ),
                            ),
                            // Badge Lampiran Struk
                            Positioned(
                              bottom: 10,
                              left: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.attachment_rounded, color: Colors.white, size: 13),
                                    SizedBox(width: 4),
                                    Text(
                                      'Lampiran Struk',
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Tombol Perbesar Struk
                            Positioned(
                              bottom: 10,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'Perbesar',
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 2. Banner Informasi jika Nominal Tidak Ditemukan Otomatis
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
                                  'Angka total belanja tidak ditemukan otomatis pada foto ini. Silakan masukkan nominal secara manual. Foto struk tetap tersimpan sebagai bukti transaksi.',
                                  style: AppTypography.caption.copyWith(color: textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 3. Nominal Pengeluaran (Fokus Utama / Typography-First)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL PENGELUARAN',
                        style: AppTypography.caption.copyWith(
                          color: textTertiary,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      ConfidenceBadge(isCertain: widget.draft.isTotalCertain),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor, width: 0.8),
                    ),
                    child: TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      style: AppTypography.headline.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: expenseColor,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Rp 0',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
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

                  const SizedBox(height: 18),

                  // 4. Nama Toko / Merchant
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'NAMA TOKO / MERCHANT',
                        style: AppTypography.caption.copyWith(
                          color: textTertiary,
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
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor, width: 0.8),
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

                  // 5. Tanggal & Waktu Transaksi
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TANGGAL & WAKTU',
                        style: AppTypography.caption.copyWith(
                          color: textTertiary,
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
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor, width: 0.8),
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
                          Icon(Icons.calendar_today_outlined, size: 18, color: textSecondary),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 6. Dompet Sumber Dana
                  Text(
                    'DOMPET SUMBER DANA',
                    style: AppTypography.caption.copyWith(
                      color: textTertiary,
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
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor, width: 0.8),
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
                    loading: () => Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor, width: 0.8),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        'Memuat dompet...',
                        style: AppTypography.caption.copyWith(color: textSecondary),
                      ),
                    ),
                    error: (e, _) => const Text('Gagal memuat dompet', style: TextStyle(color: Colors.red, fontSize: 13)),
                  ),

                  const SizedBox(height: 18),

                  // 7. Kategori Pengeluaran
                  Text(
                    'KATEGORI PENGELUARAN',
                    style: AppTypography.caption.copyWith(
                      color: textTertiary,
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
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor, width: 0.8),
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
                    loading: () => Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor, width: 0.8),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        'Memuat kategori...',
                        style: AppTypography.caption.copyWith(color: textSecondary),
                      ),
                    ),
                    error: (e, _) => const Text('Gagal memuat kategori', style: TextStyle(color: Colors.red, fontSize: 13)),
                  ),

                  const SizedBox(height: 18),

                  // 8. Catatan Tambahan
                  Text(
                    'CATATAN / KETERANGAN TAMBAHAN',
                    style: AppTypography.caption.copyWith(
                      color: textTertiary,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor, width: 0.8),
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

                  // 9. Ringkasan Finansial Struk (Subtotal & Pajak jika terdeteksi)
                  if (widget.draft.subtotal != null ||
                      widget.draft.taxAmount != null ||
                      widget.draft.serviceCharge != null ||
                      widget.draft.discountAmount != null) ...[
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

                  // 10. Rincian Item Belanja Produk
                  MinimalSectionHeader(
                    title: 'Rincian Item Belanja',
                    actionLabel: '${widget.draft.items.length} item',
                  ),
                  const SizedBox(height: 4),
                  ReceiptItemsList(items: widget.draft.items),

                  const SizedBox(height: 20),

                  // 11. Teks Mentah OCR (Audit / Transparansi)
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
                                color: textSecondary,
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
                                  color: expenseColor,
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
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor, width: 0.8),
                      ),
                      child: Text(
                        _rawText.isNotEmpty ? _rawText : '(Teks mentah telah dibersihkan)',
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),

            // 12. Sticky Bottom Action Bar (Aksi Cepat)
            _buildBottomActionBar(isDark, surfaceColor, borderColor),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionBar(bool isDark, Color surfaceColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(top: BorderSide(color: borderColor, width: 0.8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? AppColors.incomeDark : AppColors.incomeLight,
                foregroundColor: Colors.white,
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
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
          if (widget.draft.totalAmount == null || widget.draft.totalAmount == 0) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: borderColor, width: 0.8),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  AddTransactionSheet.show(context, initialType: TransactionType.expense);
                },
                child: const Text('Beralih ke Input Manual'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
