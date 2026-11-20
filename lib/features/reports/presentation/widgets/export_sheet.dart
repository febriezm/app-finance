import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../../app/app_providers.dart';
import '../../../../core/utils/file_export_helper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/loading_indicator.dart';

class ExportSheet extends ConsumerStatefulWidget {
  final String monthKey;

  const ExportSheet({
    super.key,
    required this.monthKey,
  });

  static Future<void> show(BuildContext context, String monthKey) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExportSheet(monthKey: monthKey),
    );
  }

  @override
  ConsumerState<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<ExportSheet> {
  bool _isLoading = false;
  String? _loadingMessage;

  Future<void> _exportPdf() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Menyiapkan berkas PDF...';
    });

    try {
      final exportPdfUseCase = ref.read(exportReportPdfUseCaseProvider);
      final pdfBytes = await exportPdfUseCase.execute(widget.monthKey);

      final filename = 'MyFinance_Laporan_${widget.monthKey}.pdf';
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: filename,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Laporan PDF $filename berhasil dibuat.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengekspor PDF: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMessage = null;
        });
      }
    }
  }

  Future<void> _exportCsv() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Menyiapkan berkas CSV...';
    });

    try {
      final exportCsvUseCase = ref.read(exportReportCsvUseCaseProvider);
      final csvString = await exportCsvUseCase.execute(widget.monthKey);

      final filename = 'MyFinance_Laporan_${widget.monthKey}.csv';
      final bytes = Uint8List.fromList(utf8.encode(csvString));

      // Gunakan FileExportHelper: Download otomatis di Web, Share Sheet di iOS/Android
      await FileExportHelper.saveOrShare(
        bytes: bytes,
        filename: filename,
        mimeType: 'text/csv',
        subject: 'Laporan Keuangan MyFinance (${widget.monthKey})',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kIsWeb
                  ? 'Berkas CSV $filename berhasil diunduh.'
                  : 'Berkas CSV $filename berhasil dibagikan.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengekspor CSV: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMessage = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceModalDark : AppColors.surfaceModalLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Ekspor Laporan Keuangan',
              style: AppTypography.title2.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Pilih format dokumen laporan untuk periode ${widget.monthKey}',
              style: AppTypography.caption1.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: LoadingIndicator(message: _loadingMessage ?? 'Memproses...'),
                ),
              )
            else ...[
              _buildOptionTile(
                icon: Icons.picture_as_pdf_rounded,
                iconColor: Colors.red.shade600,
                title: 'Dokumen PDF Cetak',
                subtitle: 'Tata letak Apple-styled resmi dengan kartu KPI & rincian mutasi',
                onTap: _exportPdf,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              _buildOptionTile(
                icon: Icons.table_chart_rounded,
                iconColor: Colors.green.shade600,
                title: 'Berkas Data CSV (Excel / Numbers)',
                subtitle: 'Format tabular standar RFC 4180 dengan encoding UTF-8 BOM',
                onTap: _exportCsv,
                isDark: isDark,
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
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
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.caption1.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
