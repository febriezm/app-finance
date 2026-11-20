import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../app/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/presentation/widgets/add_transaction_sheet.dart';
import 'receipt_review_screen.dart';

class ReceiptScannerScreen extends ConsumerStatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  ConsumerState<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends ConsumerState<ReceiptScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  String _statusMessage = '';

  Future<void> _processScan(String imagePath, [Uint8List? imageBytes]) async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Menjalankan OCR On-Device...';
    });

    try {
      final draft = await ref.read(receiptScannerControllerProvider.notifier).scanImage(
            imagePath: imagePath,
            imageBytes: imageBytes,
          );

      if (!mounted) return;

      setState(() => _isProcessing = false);

      if (draft != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => ReceiptReviewScreen(draft: draft),
          ),
        );
      } else {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Gagal Memindai Struk'),
            content: const Text(
              'Teks struk tidak dapat dikenali secara otomatis. Apakah Anda ingin beralih mencatat transaksi secara manual?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                  AddTransactionSheet.show(context, initialType: TransactionType.expense);
                },
                child: const Text('Input Manual'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Pindai Struk Bermasalah'),
            content: Text(
              'Terjadi kendala saat memindai: $e.\n\nApakah Anda ingin mencatat pengeluaran secara manual?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                  AddTransactionSheet.show(context, initialType: TransactionType.expense);
                },
                child: const Text('Input Manual'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final photo = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        await _processScan(photo.path, bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak dapat membuka kamera/galeri: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isProcessing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Memindai Struk')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LoadingIndicator(message: ''),
              const SizedBox(height: 16),
              Text(_statusMessage, style: AppTypography.headline),
              const SizedBox(height: 8),
              const Text(
                'Memproses teks secara lokal pada perangkat Anda...',
                style: AppTypography.caption1,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pindai Struk (OCR)'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Banner Privasi & Izin (Apple HIG Compliance & Blueprint 4.5)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                width: 0.8,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.incomeContainerDark : AppColors.incomeContainerLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shield_outlined, color: AppColors.incomeLight, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '100% On-Device & Privat',
                        style: AppTypography.headline.copyWith(fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Foto dan teks struk diproses langsung di HP Anda. Tidak ada data finansial yang diunggah ke server cloud.',
                        style: AppTypography.footnote.copyWith(
                          color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Tombol Aksi Kamera & Galeri
          Text(
            'AMBIL FOTO STRUK',
            style: AppTypography.caption1.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
            ),
          ),
          const SizedBox(height: 10),

          AppButton(
            label: 'Buka Kamera iPhone',
            icon: const Icon(Icons.camera_alt_outlined, color: Colors.white),
            onPressed: () => _pickImage(ImageSource.camera),
          ),

          const SizedBox(height: 12),

          AppButton(
            label: 'Pilih dari Galeri Foto',
            variant: AppButtonVariant.secondary,
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: () => _pickImage(ImageSource.gallery),
          ),

          const SizedBox(height: 24),

          // Opsi Input Transaksi Manual (Bila OCR / Kamera Gagal Terus Menerus)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                width: 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.expenseContainerDark : AppColors.expenseContainerLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit_note_rounded, color: AppColors.expenseLight, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pindai Gagal atau Teks Buram?',
                            style: AppTypography.headline.copyWith(fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Jika kamera atau OCR berulang kali gagal membaca teks struk, gunakan opsi catat manual di bawah.',
                            style: AppTypography.footnote.copyWith(
                              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Catat Pengeluaran Manual',
                  variant: AppButtonVariant.outlined,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: () {
                    Navigator.of(context).pop();
                    AddTransactionSheet.show(context, initialType: TransactionType.expense);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
