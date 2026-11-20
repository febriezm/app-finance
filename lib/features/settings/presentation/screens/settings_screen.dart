import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/app_providers.dart';
import '../../../../core/formatting/date_formatter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../backup_restore/presentation/screens/backup_restore_screen.dart';
import '../../../reports/presentation/widgets/export_sheet.dart';
import '../../../security/presentation/widgets/pin_setup_sheet.dart';
import '../../../security/presentation/widgets/pin_verify_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentMonthKey = AppDateFormatter.toMonthKey(DateTime.now());
    final themeMode = ref.watch(themeModeProvider);
    final lockState = ref.watch(appLockControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // 1. App Info Banner
          AppCard(
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'MyFinance',
                            style: AppTypography.title2.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'v1.0.0',
                              style: AppTypography.caption2.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            '100% Offline • Penyimpanan Lokal Privat',
                            style: AppTypography.caption2.copyWith(
                              color: isDark ? AppColors.primaryLight : AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 2. Section: Tampilan & Tema
          Text(
            'Tampilan & Tema',
            style: AppTypography.headline.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.palette_outlined, color: Colors.purple, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mode Tampilan',
                            style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Pilih tema terang, gelap, atau ikuti pengaturan iOS',
                            style: AppTypography.caption1.copyWith(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('Sistem'),
                        icon: Icon(Icons.brightness_auto_rounded, size: 18),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Terang'),
                        icon: Icon(Icons.light_mode_rounded, size: 18),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Gelap'),
                        icon: Icon(Icons.dark_mode_rounded, size: 18),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (newSelection) {
                      AppHaptics.selection();
                      ref.read(themeModeProvider.notifier).state = newSelection.first;
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 3. Section: Laporan & Ekspor
          Text(
            'Laporan & Ekspor',
            style: AppTypography.headline.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 20),
                  ),
                  title: Text(
                    'Ekspor Laporan (PDF / CSV)',
                    style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Simpan dokumen cetak PDF atau berkas tabular CSV',
                    style: AppTypography.caption1.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  onTap: () {
                    AppHaptics.light();
                    ExportSheet.show(context, currentMonthKey);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 4. Section: Keamanan & Pencadangan
          Text(
            'Keamanan & Pencadangan',
            style: AppTypography.headline.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                // Biometrics & PIN Switch
                SwitchListTile.adaptive(
                  value: lockState.isAppLockEnabled,
                  activeColor: AppColors.primary,
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 20),
                  ),
                  title: Text(
                    'Kunci Aplikasi (Biometrik / Face ID & PIN)',
                    style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    lockState.isAppLockEnabled
                        ? (lockState.isBiometricsAvailable && lockState.isBiometricsEnabled
                            ? 'Aktif • Dilindungi ${lockState.biometricLabel} & Kode Sandi PIN'
                            : 'Aktif • Dilindungi Kode Sandi PIN 6-digit')
                        : 'Minta Kode Sandi atau Face ID saat membuka aplikasi',
                    style: AppTypography.caption1.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  onChanged: (enabled) async {
                    await AppHaptics.light();
                    if (!context.mounted) return;
                    if (enabled) {
                      // Buka sheet setup PIN baru
                      final result = await PinSetupSheet.show(context);
                      if (result == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Kunci aplikasi berhasil diaktifkan.')),
                        );
                      }
                    } else {
                      // Minta verifikasi PIN sebelum mematikan
                      final verified = await PinVerifySheet.show(
                        context,
                        title: 'Matikan Kunci Aplikasi',
                        subtitle: 'Masukkan kode sandi PIN untuk menonaktifkan keamanan',
                        onPinEntered: (pin) =>
                            ref.read(appLockControllerProvider.notifier).disableAppLock(pin),
                      );
                      if (verified == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Kunci aplikasi telah dinonaktifkan.')),
                        );
                      }
                    }
                  },
                ),

                // Sub-opsi ketika Kunci Aplikasi Aktif
                if (lockState.isAppLockEnabled) ...[
                  Divider(
                    height: 1,
                    indent: 56,
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                  // Opsi Ubah PIN
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.pin_outlined, color: Colors.blue, size: 20),
                    ),
                    title: Text(
                      'Ubah Kode Sandi PIN',
                      style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Ganti 6-digit PIN kode sandi aplikasi Anda',
                      style: AppTypography.caption1.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                    onTap: () async {
                      await AppHaptics.light();
                      if (!context.mounted) return;
                      // Verifikasi PIN lama dulu
                      final verified = await PinVerifySheet.show(
                        context,
                        title: 'Verifikasi PIN Saat Ini',
                        subtitle: 'Masukkan kode sandi lama Anda terlebih dahulu',
                        onPinEntered: (pin) =>
                            ref.read(appLockControllerProvider.notifier).unlockWithPin(pin),
                      );

                      if (verified == true && context.mounted) {
                        final changed = await PinSetupSheet.show(context, isChangingPin: true);
                        if (changed == true && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Kode sandi PIN berhasil diubah.')),
                          );
                        }
                      }
                    },
                  ),

                  // Opsi Toggle Biometrik jika perangkat mendukung
                  if (lockState.isBiometricsAvailable) ...[
                    Divider(
                      height: 1,
                      indent: 56,
                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    ),
                    SwitchListTile.adaptive(
                      value: lockState.isBiometricsEnabled,
                      activeColor: AppColors.primary,
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.fingerprint_rounded, color: AppColors.primary, size: 20),
                      ),
                      title: Text(
                        'Buka dengan ${lockState.biometricLabel}',
                        style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Gunakan biometrik untuk membuka aplikasi tanpa mengetik PIN',
                        style: AppTypography.caption1.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      onChanged: (val) {
                        AppHaptics.light();
                        ref.read(appLockControllerProvider.notifier).setBiometricsEnabled(val);
                      },
                    ),
                  ],

                  // Tombol Kunci Sekarang untuk menguji langsung
                  Divider(
                    height: 1,
                    indent: 56,
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.screen_lock_portrait_rounded, color: Colors.orange, size: 20),
                    ),
                    title: Text(
                      'Kunci Aplikasi Sekarang',
                      style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Uji coba langsung layar kunci tanpa harus menutup aplikasi',
                      style: AppTypography.caption1.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                    onTap: () {
                      AppHaptics.medium();
                      ref.read(appLockControllerProvider.notifier).lock();
                    },
                  ),
                ],
                Divider(
                  height: 1,
                  indent: 56,
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
                // Backup & Restore Tile
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.cloud_sync_outlined, color: AppColors.primary, size: 20),
                  ),
                  title: Text(
                    'Cadangkan & Pulihkan (Backup & Restore)',
                    style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Ekspor arsip JSON terstruktur atau pulihkan data',
                    style: AppTypography.caption1.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  onTap: () {
                    AppHaptics.light();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BackupRestoreScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 4. Section: Privasi & Ketentuan
          Text(
            'Privasi & Arsitektur',
            style: AppTypography.headline.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.security_rounded, color: Colors.blue, size: 20),
                  ),
                  title: Text(
                    'Jaminan Privasi Offline-First',
                    style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Tidak ada analitik, server eksternal, atau pelacak',
                    style: AppTypography.caption1.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Privasi 100% Offline'),
                        content: const Text(
                          'MyFinance beroperasi sepenuhnya di dalam sandbox perangkat iPhone Anda.\n\n'
                          '• Basis data SQLite lokal (Drift Engine)\n'
                          '• OCR struk diproses di perangkat tanpa unggah foto\n'
                          '• Tidak ada server backend, analitik pihak ketiga, atau pelacakan data keuangan.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Mengerti'),
                          ),
                        ],
                      ),
                    );
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
