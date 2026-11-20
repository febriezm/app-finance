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
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/presentation/widgets/add_transaction_sheet.dart';
import '../../domain/entities/receipt_draft.dart';
import '../widgets/confidence_badge.dart';
import '../widgets/receipt_items_list.dart';

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
      appBar: AppBar(
        title: const Text('Review Hasil Scan Struk'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        children: [
          // Preview Foto Struk (jika tersedia dari kamera atau galeri)
          if (widget.draft.imageBytes != null && widget.draft.imageBytes!.isNotEmpty) ...[
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
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
                    height: 220,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.attachment, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Lampiran Foto Struk',
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

          // Banner Status Deteksi Struk (Sesuai Blueprint 4.5 & 14 #9)
          if (widget.draft.totalAmount == null || widget.draft.totalAmount == 0) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceCardDark : const Color(0xFFFFF9E6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.warningDark : AppColors.warningLight,
                  width: 0.8,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.warningLight, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Teks Struk Tidak Terdeteksi Otomatis',
                          style: AppTypography.headline.copyWith(fontSize: 14, color: isDark ? AppColors.warningDark : AppColors.warningLight),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Sistem tidak menemukan nominal total belanja pada foto ini (atau foto bukan struk belanja). Silakan masukkan nominal dan nama toko secara manual di bawah. Foto struk tetap tersimpan sebagai lampiran bukti transaksi.',
                          style: AppTypography.caption1.copyWith(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            // Banner Verifikasi Wajib (Blueprint 4.5)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceCardDark : AppColors.dividerLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_outlined, color: AppColors.primaryNavyLight, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Periksa kembali data struk di bawah ini sebelum menyimpan transaksi ke dompet Anda.',
                      style: AppTypography.caption1.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 1. Total Pengeluaran Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL PENGELUARAN',
                      style: AppTypography.caption1.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                      ),
                    ),
                    ConfidenceBadge(isCertain: widget.draft.isTotalCertain),
                  ],
                ),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _amountController,
                  label: null,
                  hintText: 'Rp 0',
                  keyboardType: TextInputType.number,
                  onChanged: _onAmountChanged,
                ),
                if (!widget.draft.isTotalCertain) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Nominal total struk belum terdeteksi pasti. Harap pastikan kebenaran angka di atas.',
                    style: AppTypography.caption2.copyWith(
                      color: isDark ? AppColors.warningDark : AppColors.warningLight,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 2. Merchant & Tanggal
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOKO / MERCHANT',
                      style: AppTypography.caption1.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                      ),
                    ),
                    ConfidenceBadge(isCertain: widget.draft.isMerchantCertain),
                  ],
                ),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _merchantController,
                  hintText: 'Contoh: Indomaret, HokBen, SPBU...',
                ),

                const SizedBox(height: 14),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TANGGAL & WAKTU',
                      style: AppTypography.caption1.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                      ),
                    ),
                    ConfidenceBadge(isCertain: widget.draft.isDateCertain),
                  ],
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _selectDate,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppDateFormatter.formatDateTime(_occurredAt),
                          style: AppTypography.body,
                        ),
                        const Icon(Icons.calendar_today_outlined, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 3. Pemilihan Dompet & Kategori
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DOMPET SUMBER DANA',
                  style: AppTypography.caption1.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                walletsAsync.when(
                  data: (wallets) {
                    if (wallets.isEmpty) {
                      return const Text('Belum ada dompet aktif. Silakan buat dompet terlebih dahulu.');
                    }
                    if (_selectedWalletId == null && wallets.isNotEmpty) {
                      _selectedWalletId = wallets.first.wallet.id;
                    }
                    return DropdownButtonFormField<String>(
                      value: _selectedWalletId,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: wallets.map((w) {
                        return DropdownMenuItem(
                          value: w.wallet.id,
                          child: Text(
                            '${w.wallet.name} (${CurrencyFormatter.formatRupiah(w.currentBalance)})',
                            style: AppTypography.body.copyWith(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedWalletId = val),
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => const Text('Gagal memuat dompet', style: TextStyle(color: Colors.red, fontSize: 13)),
                ),

                const SizedBox(height: 16),

                Text(
                  'KATEGORI PENGELUARAN',
                  style: AppTypography.caption1.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                categoriesAsync.when(
                  data: (categories) {
                    if (categories.isEmpty) {
                      return const Text('Belum ada kategori pengeluaran.');
                    }
                    if (_selectedCategoryId == null || !categories.any((c) => c.id == _selectedCategoryId)) {
                      _selectedCategoryId = categories.first.id;
                    }
                    return DropdownButtonFormField<String>(
                      value: _selectedCategoryId,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: categories.map((c) {
                        return DropdownMenuItem(
                          value: c.id,
                          child: Row(
                            children: [
                              Icon(AppIcons.getIcon(c.iconKey), size: 18, color: AppIcons.parseColor(c.colorHex)),
                              const SizedBox(width: 8),
                              Text(c.name, style: AppTypography.body.copyWith(fontSize: 14)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedCategoryId = val),
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => const Text('Gagal memuat kategori', style: TextStyle(color: Colors.red, fontSize: 13)),
                ),

                const SizedBox(height: 16),

                Text(
                  'CATATAN TAMBAHAN (OPSIONAL)',
                  style: AppTypography.caption1.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  ),
                ),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _notesController,
                  hintText: 'Tulis catatan jika diperlukan...',
                  maxLines: 2,
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 4. Ringkasan Finansial Struk (Subtotal & Pajak)
          if (widget.draft.subtotal != null || widget.draft.taxAmount != null)
            AppCard(
              child: Column(
                children: [
                  if (widget.draft.subtotal != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal', style: AppTypography.subhead),
                        Text(
                          CurrencyFormatter.formatRupiah(widget.draft.subtotal!),
                          style: AppTypography.subhead,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (widget.draft.taxAmount != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Pajak (PPN/PB1)', style: AppTypography.caption1),
                        Text(
                          CurrencyFormatter.formatRupiah(widget.draft.taxAmount!),
                          style: AppTypography.caption1,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (widget.draft.serviceCharge != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Biaya Layanan', style: AppTypography.caption1),
                        Text(
                          CurrencyFormatter.formatRupiah(widget.draft.serviceCharge!),
                          style: AppTypography.caption1,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (widget.draft.discountAmount != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Diskon / Potongan', style: AppTypography.caption1.copyWith(color: AppColors.incomeLight)),
                        Text(
                          '- ${CurrencyFormatter.formatRupiah(widget.draft.discountAmount!)}',
                          style: AppTypography.caption1.copyWith(color: AppColors.incomeLight, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 14),

          // 5. Rincian Item Produk Terdeteksi
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rincian Item (${widget.draft.items.length})',
                style: AppTypography.headline.copyWith(fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ReceiptItemsList(items: widget.draft.items),

          const SizedBox(height: 14),

          // 6. Teks OCR Mentah (Audit & Debugging - Blueprint 4.5)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                width: 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _showRawOcr = !_showRawOcr),
                      child: Row(
                        children: [
                          Icon(
                            _showRawOcr ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          const Text('Teks OCR Mentah (Lokal)', style: AppTypography.subhead),
                        ],
                      ),
                    ),
                    if (_rawText.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() => _rawText = '');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Teks mentah OCR telah dihapus secara lokal.')),
                          );
                        },
                        child: const Text('Hapus Teks', style: TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                  ],
                ),
                if (_showRawOcr) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _rawText.isNotEmpty ? _rawText : '(Teks mentah telah dibersihkan)',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Tombol Konfirmasi Transaksi
          AppButton(
            label: 'Konfirmasi & Catat Pengeluaran',
            icon: const Icon(Icons.check_circle_outline, color: Colors.white),
            isLoading: _isSaving,
            onPressed: _confirmAndSave,
          ),

          if (widget.draft.totalAmount == null || widget.draft.totalAmount == 0) ...[
            const SizedBox(height: 12),
            AppButton(
              label: 'Beralih ke Input Pengeluaran Biasa',
              variant: AppButtonVariant.outlined,
              icon: const Icon(Icons.edit_note_outlined, size: 18),
              onPressed: () {
                Navigator.of(context).pop();
                AddTransactionSheet.show(context, initialType: TransactionType.expense);
              },
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
