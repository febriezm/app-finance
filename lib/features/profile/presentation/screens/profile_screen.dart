import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/app_providers.dart';
import '../../../../app/router.dart';
import '../../../../core/formatting/date_formatter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../shared/widgets/shared_widgets.dart';

/// Halaman Profil Pengguna — MyFinance Minimal (Quiet, Clean, Premium).
///
/// Karakter Desain:
/// - Hero Avatar minimalis dengan inisial nama/email pengguna.
/// - Status Cloud Active badge dengan indikator hijau hening.
/// - Daftar terkelompok (Grouped List) berdivider tipis hairline (0.6px).
/// - Informasi kredensial, sesi Cloud PostgreSQL, dan kuota Supabase Storage.
/// - Tombol Keluar (Sign Out) dengan dialog konfirmasi aman.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  String _getInitials(String email) {
    if (email.isEmpty) return 'U';
    final parts = email.split('@').first.split('.');
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return email.substring(0, email.length >= 2 ? 2 : 1).toUpperCase();
  }

  String _formatStorageSize(int bytes) {
    if (bytes <= 0) return '0 KB';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    unawaited(AppHaptics.selection());
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label berhasil disalin ke clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showSignOutDialog(BuildContext context, WidgetRef ref, String email) {
    unawaited(AppHaptics.selection());
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari Akun Cloud'),
        content: Text(
          'Apakah Anda yakin ingin keluar dari akun $email?\n\n'
          'Sesi Anda pada perangkat ini akan diakhiri. Seluruh data transaksi, dompet, dan struk tersimpan aman di Supabase Cloud.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Berhasil keluar dari akun cloud.')),
                );
              }
            },
            child: const Text('Keluar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _sendPasswordResetEmail(BuildContext context, WidgetRef ref, String email) async {
    unawaited(AppHaptics.selection());
    final confirm = await MinimalDialog.showConfirm(
      context,
      title: 'Kirim Tautan Atur Ulang Sandi?',
      message: 'Tautan reset kata sandi akan dikirim ke alamat email:\n$email',
      confirmText: 'Kirim Email',
    );

    if (confirm == true && context.mounted) {
      await ref.read(authControllerProvider.notifier).sendPasswordReset(email: email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tautan pengaturan ulang sandi telah dikirim ke email Anda.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authUser = ref.watch(authCurrentUserProvider);
    final storageBytesAsync = ref.watch(totalReceiptStorageBytesProvider);
    final lockState = ref.watch(appLockControllerProvider);

    final bgScaffold = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final cardColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final dividerColor = isDark ? AppColors.dividerDark : AppColors.dividerLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final email = authUser?.email ?? 'Pengguna MyFinance';
    final userId = authUser?.id ?? '-';
    final initials = _getInitials(email);
    final createdAtStr = authUser?.createdAt != null
        ? DateFormatter.formatDate(authUser!.createdAt!)
        : 'Baru saja';

    return Scaffold(
      backgroundColor: bgScaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Profil Pengguna'),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
          onPressed: () {
            unawaited(AppHaptics.light());
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go(AppRouter.home);
            }
          },
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Hero Profile Header
            Center(
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      border: Border.all(
                        color: isDark ? AppColors.incomeDark.withValues(alpha: 0.4) : AppColors.incomeLight.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.incomeDark : AppColors.incomeLight,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    email,
                    style: AppTypography.title2.copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isDark ? AppColors.incomeDark : AppColors.incomeLight).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                      border: Border.all(
                        color: (isDark ? AppColors.incomeDark : AppColors.incomeLight).withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? AppColors.incomeDark : AppColors.incomeLight,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          authUser?.isEmailConfirmed == true
                              ? 'Akun Cloud Terverifikasi'
                              : 'Sesi Cloud Aktif',
                          style: AppTypography.caption.copyWith(
                            color: isDark ? AppColors.incomeDark : AppColors.incomeLight,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Group 1: INFORMASI AKUN
            _buildSectionHeader('INFORMASI AKUN', isDark),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 0.8),
              ),
              child: Column(
                children: [
                  _buildProfileTile(
                    icon: Icons.mail_outline_rounded,
                    title: 'Alamat Email',
                    value: email,
                    isDark: isDark,
                    onTap: () => _copyToClipboard(context, email, 'Email'),
                    trailing: Icon(Icons.copy_rounded, size: 16, color: textSecondary),
                  ),
                  Divider(height: 1, thickness: 0.6, indent: 52, color: dividerColor),
                  _buildProfileTile(
                    icon: Icons.fingerprint_rounded,
                    title: 'ID Pengguna (UID)',
                    value: userId.length > 18 ? '${userId.substring(0, 18)}...' : userId,
                    isDark: isDark,
                    onTap: () => _copyToClipboard(context, userId, 'User ID'),
                    trailing: Icon(Icons.copy_rounded, size: 16, color: textSecondary),
                  ),
                  Divider(height: 1, thickness: 0.6, indent: 52, color: dividerColor),
                  _buildProfileTile(
                    icon: Icons.calendar_today_outlined,
                    title: 'Member Sejak',
                    value: createdAtStr,
                    isDark: isDark,
                  ),
                  Divider(height: 1, thickness: 0.6, indent: 52, color: dividerColor),
                  _buildProfileTile(
                    icon: Icons.cloud_done_outlined,
                    title: 'Tipe Layanan',
                    value: 'Full Cloud Supabase',
                    isDark: isDark,
                    trailingBadge: 'PostgreSQL',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Group 2: PENYIMPANAN CLOUD
            _buildSectionHeader('PENYIMPANAN CLOUD', isDark),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 0.8),
              ),
              child: Column(
                children: [
                  _buildProfileTile(
                    icon: Icons.receipt_long_outlined,
                    title: 'Kapasitas Gambar Struk',
                    value: storageBytesAsync.when(
                      data: (bytes) => _formatStorageSize(bytes),
                      loading: () => 'Memuat...',
                      error: (_, __) => '-',
                    ),
                    isDark: isDark,
                    trailingBadge: 'Private Bucket',
                  ),
                  Divider(height: 1, thickness: 0.6, indent: 52, color: dividerColor),
                  _buildProfileTile(
                    icon: Icons.dns_outlined,
                    title: 'Proteksi Akses Data',
                    value: 'Row Level Security (RLS)',
                    isDark: isDark,
                    trailingBadge: 'Aktif',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Group 3: KEAMANAN & KREDENSIAL
            _buildSectionHeader('KEAMANAN & KREDENSIAL', isDark),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 0.8),
              ),
              child: Column(
                children: [
                  _buildProfileTile(
                    icon: Icons.lock_reset_rounded,
                    title: 'Ubah Kata Sandi',
                    value: 'Kirim tautan reset ke email',
                    isDark: isDark,
                    showChevron: true,
                    onTap: () => _sendPasswordResetEmail(context, ref, email),
                  ),
                  Divider(height: 1, thickness: 0.6, indent: 52, color: dividerColor),
                  _buildProfileTile(
                    icon: Icons.security_outlined,
                    title: 'Kunci Aplikasi (PIN/Biometrik)',
                    value: lockState.isAppLockEnabled
                        ? (lockState.isBiometricsEnabled ? 'PIN & Biometrik Aktif' : 'PIN 6-Digit Aktif')
                        : 'Tidak Aktif',
                    isDark: isDark,
                    trailingBadge: lockState.isAppLockEnabled ? 'Terproteksi' : 'Off',
                    onTap: () {
                      unawaited(AppHaptics.selection());
                      context.push(AppRouter.settings);
                    },
                    showChevron: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Group 4: TOMBOL KELUAR (Sign Out)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: Icon(
                  Icons.logout_rounded,
                  size: 19,
                  color: isDark ? AppColors.expenseDark : AppColors.expenseLight,
                ),
                label: Text(
                  'Keluar dari Akun',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.expenseDark : AppColors.expenseLight,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: (isDark ? AppColors.expenseDark : AppColors.expenseLight).withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                  backgroundColor: (isDark ? AppColors.expenseDark : AppColors.expenseLight).withValues(alpha: 0.06),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => _showSignOutDialog(context, ref, email),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: AppTypography.caption.copyWith(
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildProfileTile({
    required IconData icon,
    required String title,
    required String value,
    required bool isDark,
    VoidCallback? onTap,
    Widget? trailing,
    String? trailingBadge,
    bool showChevron = false,
  }) {
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 17, color: textPrimary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.caption.copyWith(color: textSecondary, fontSize: 11),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (trailingBadge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.incomeDark : AppColors.incomeLight).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  trailingBadge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.incomeDark : AppColors.incomeLight,
                  ),
                ),
              ),
            ],
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing,
            ],
            if (showChevron) ...[
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, size: 18, color: textSecondary),
            ],
          ],
        ),
      ),
    );
  }
}
