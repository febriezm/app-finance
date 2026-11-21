import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/file_picker_helper.dart';
import '../../../../shared/widgets/shared_widgets.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  final TextEditingController _jsonInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pastikan state selalu bersih saat membuka layar Cadangkan & Pulihkan
    Future.microtask(() {
      if (mounted) {
        ref.read(backupRestoreControllerProvider.notifier).resetState();
      }
    });
  }

  @override
  void dispose() {
    _jsonInputController.dispose();
    super.dispose();
  }

  void _pickJsonFile() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final content = await FilePickerHelper.pickJsonFile();
      if (content != null && content.isNotEmpty) {
        _jsonInputController.text = content;
        ref.read(backupRestoreControllerProvider.notifier).validateJson(content);
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Gagal membaca berkas cadangan: $e')),
        );
      }
    }
  }

  void _pasteFromClipboard() async {
    String? text;
    try {
      final data = await Clipboard.getData('text/plain');
      text = data?.text?.trim();
    } catch (_) {
      text = null;
    }

    if (text != null && text.isNotEmpty) {
      _jsonInputController.text = text;
      final res = ref.read(backupRestoreControllerProvider.notifier).validateJson(text);
      if (res.isValid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Teks cadangan berhasil dimuat dan divalidasi dari papan klip.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
    }

    // Jika clipboard dibatasi oleh browser (misal Safari iOS pada HTTP) atau belum valid,
    // buka lembar input teks langsung agar pengguna dapat menempelkan (paste) secara manual.
    if (mounted) {
      _showManualPasteModal(context);
    }
  }

  void _showManualPasteModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tempel Teks Cadangan',
                        style: AppTypography.headline.copyWith(fontSize: 17),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        splashRadius: 20,
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Safari iOS membatasi pembacaan otomatis papan klip pada jaringan HTTP lokal. Ketuk kolom teks di bawah lalu pilih opsi "Tempel" (Paste):',
                    style: AppTypography.caption1.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _jsonInputController,
                    maxLines: 7,
                    autofocus: true,
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: 'Ketuk di sini, lalu pilih "Tempel" / "Paste"...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                      ),
                      filled: true,
                      fillColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        ),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.paste_rounded, size: 18),
                          label: const Text('Tempel Otomatis'),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              final data = await Clipboard.getData('text/plain');
                              final t = data?.text?.trim();
                              if (t != null && t.isNotEmpty) {
                                setModalState(() {
                                  _jsonInputController.text = t;
                                });
                              } else {
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Papan klip dibatasi browser. Silakan ketuk kolom teks dan pilih "Tempel".'),
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              }
                            } catch (_) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Akses otomatis dibatasi Safari iOS. Ketuk kolom teks dan pilih "Tempel".'),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                          label: const Text('Periksa & Muat'),
                          onPressed: () {
                            final raw = _jsonInputController.text.trim();
                            if (raw.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Kolom teks masih kosong. Silakan tempel teks cadangan.')),
                              );
                              return;
                            }
                            Navigator.pop(sheetCtx);
                            final res = ref.read(backupRestoreControllerProvider.notifier).validateJson(raw);
                            if (mounted) {
                              if (res.isValid) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Arsip cadangan valid dan siap dipulihkan.'),
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(res.errorMessage ?? 'Format cadangan tidak valid.'),
                                    duration: const Duration(seconds: 4),
                                  ),
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
            );
          },
        );
      },
    );
  }

  Future<void> _confirmRestore(BuildContext context, int recordsCount) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await MinimalDialog.showConfirm(
      context,
      title: 'Konfirmasi Pemulihan',
      message:
          'Aplikasi akan mengganti seluruh data yang ada saat ini dengan data dari cadangan ($recordsCount data).\n\nPastikan Anda telah mencadangkan data saat ini bila diperlukan.',
      confirmText: 'Pulihkan Data',
    );

    if (confirm == true && mounted) {
      final jsonStr = _jsonInputController.text;
      final success = await ref
          .read(backupRestoreControllerProvider.notifier)
          .restoreBackup(jsonStr);

      if (success && mounted) {
        _jsonInputController.clear();
        ref.read(backupRestoreControllerProvider.notifier).clearValidation();
        messenger.showSnackBar(
          const SnackBar(content: Text('Data berhasil dipulihkan!')),
        );
      }
    }
  }

  void _confirmReset(BuildContext context) {
    final resetConfirmController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isConfirmed = resetConfirmController.text.trim().toUpperCase() == 'RESET';

          return AlertDialog(
            backgroundColor: isDark ? AppColors.surfaceModalDark : AppColors.surfaceModalLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                width: 0.8,
              ),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            actionsPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            title: Text(
              'Hapus Seluruh Data?',
              style: AppTypography.title3.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 17,
                letterSpacing: -0.3,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tindakan ini akan menghapus permanen seluruh transaksi, riwayat mutasi, dompet, dan anggaran di perangkat ini.\n\nKetik kata "RESET" di bawah ini untuk mengonfirmasi:',
                  style: TextStyle(
                    color: isDark ? AppColors.expenseDark : AppColors.expenseLight,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: resetConfirmController,
                  style: AppTypography.bodyBold,
                  decoration: InputDecoration(
                    hintText: 'Ketik RESET',
                    filled: true,
                    fillColor: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceElevatedLight,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        width: 0.8,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                        width: 0.8,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.expenseDark : AppColors.expenseLight,
                        width: 1.2,
                      ),
                    ),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
              ],
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Batal', style: TextStyle(fontSize: 14)),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: isConfirmed
                      ? (isDark ? AppColors.expenseDark : AppColors.expenseLight)
                      : (isDark ? AppColors.textDisabledDark : AppColors.textDisabledLight),
                ),
                onPressed: isConfirmed
                    ? () async {
                        Navigator.pop(dialogCtx);
                        final messenger = ScaffoldMessenger.of(context);
                        final success = await ref
                            .read(backupRestoreControllerProvider.notifier)
                            .resetAllData();
                        if (success && mounted) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Basis data berhasil direset.')),
                          );
                        }
                      }
                    : null,
                child: const Text(
                  'Hapus Semua Data',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(backupRestoreControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadangkan & Pulihkan'),
      ),
      body: state.isLoading
          ? Center(
              child: LoadingIndicator(
                message: state.loadingMessage ?? 'Memproses...',
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                // 1. Info Banner
                AppCard(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Penyimpanan Lokal & Privat',
                              style: AppTypography.subhead.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Berkas cadangan berupa arsip terstruktur yang dapat disimpan di iCloud, Drive lokal, atau dipindahkan antar perangkat.',
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

                // Status Message Banners
                if (state.errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.error, width: 0.8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.errorMessage!,
                            style: AppTypography.caption1.copyWith(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (state.successMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary, width: 0.8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.successMessage!,
                            style: AppTypography.caption1.copyWith(color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),

                // 2. Section: Buat Cadangan (Backup)
                Text(
                  'Cadangkan Data (Backup)',
                  style: AppTypography.headline.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 8),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Simpan seluruh basis data MyFinance ke dalam berkas cadangan JSON yang valid dan tervalidasi.',
                        style: AppTypography.caption1.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Buat & Bagikan Cadangan (JSON)'),
                          onPressed: () {
                            ref
                                .read(backupRestoreControllerProvider.notifier)
                                .createAndShareBackup();
                          },
                        ),
                      ),
                      if (state.latestBackupJson != null) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            label: const Text('Salin Teks JSON Cadangan'),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: state.latestBackupJson!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Teks JSON cadangan berhasil disalin ke clipboard!')),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 3. Section: Pulihkan Data (Restore)
                Text(
                  'Pulihkan Data (Restore)',
                  style: AppTypography.headline.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 8),
                AppCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pulihkan data dari berkas cadangan JSON yang valid untuk mengembalikan seluruh mutasi dan dompet Anda.',
                        style: AppTypography.caption1.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.file_open_outlined, size: 20),
                          label: const Text('Pilih Berkas Cadangan (.json)'),
                          onPressed: _pickJsonFile,
                        ),
                      ),
                      if (state.validationResult != null) ...[
                        const SizedBox(height: 12),
                        if (state.validationResult!.isValid) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.primary, width: 0.8),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Arsip Valid (v${state.validationResult!.schemaVersion}) • ${state.validationResult!.totalRecordsCount} data',
                                        style: AppTypography.caption1.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 20),
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                      tooltip: 'Batalkan / Hapus',
                                      splashRadius: 20,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                      onPressed: () {
                                        setState(() {
                                          _jsonInputController.clear();
                                        });
                                        ref.read(backupRestoreControllerProvider.notifier).clearValidation();
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${state.validationResult!.walletsCount} Dompet • ${state.validationResult!.categoriesCount} Kategori • ${state.validationResult!.transactionsCount} Transaksi • ${state.validationResult!.budgetsCount} Anggaran',
                                  style: AppTypography.caption2.copyWith(
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.restore_rounded),
                              label: const Text('Terapkan Pemulihan Data'),
                              onPressed: () => _confirmRestore(
                                context,
                                state.validationResult!.totalRecordsCount,
                              ),
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.error, width: 0.8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.cancel_rounded, color: AppColors.error, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    state.validationResult!.errorMessage ?? 'Arsip tidak valid.',
                                    style: AppTypography.caption1.copyWith(color: AppColors.error),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 20),
                                  color: AppColors.error,
                                  tooltip: 'Batalkan / Hapus',
                                  splashRadius: 20,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                  onPressed: () {
                                    setState(() {
                                      _jsonInputController.clear();
                                    });
                                    ref.read(backupRestoreControllerProvider.notifier).clearValidation();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ] else ...[
                        const SizedBox(height: 6),
                        Center(
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.paste_rounded, size: 14),
                            label: Text(
                              'atau Tempel / Masukkan Teks Cadangan',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                              ),
                            ),
                            onPressed: _pasteFromClipboard,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // 4. Section: Zona Bahaya (Danger Zone)
                Text(
                  'Zona Berbahaya',
                  style: AppTypography.headline.copyWith(
                    fontSize: 16,
                    color: isDark ? AppColors.errorLight : AppColors.error,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (isDark ? AppColors.errorLight : AppColors.error).withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reset Seluruh Basis Data',
                        style: AppTypography.subhead.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.errorLight : AppColors.error,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Menghapus seluruh mutasi transaksi, dompet, dan anggaran di perangkat ini secara permanen.',
                        style: AppTypography.caption1.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? AppColors.errorLight : AppColors.error,
                            side: BorderSide(
                              color: isDark ? AppColors.errorLight : AppColors.error,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.delete_forever_rounded),
                          label: const Text('Reset Seluruh Data Aplikasi'),
                          onPressed: () => _confirmReset(context),
                        ),
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
