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
import '../../../auth/domain/entities/auth_user.dart';
import '../../../security/presentation/widgets/pin_setup_sheet.dart';
import '../../../security/presentation/widgets/pin_verify_sheet.dart';

/// Halaman Profil Pengguna — MyFinance Minimal (Quiet, Clean, Premium).
///
/// Karakter Desain:
/// - Hero Avatar minimalis dengan inisial nama/email pengguna.
/// - Status Cloud Active badge dengan indikator hijau hening.
/// - Daftar terkelompok (Grouped List) berdivider tipis hairline (0.6px).
/// - Informasi profil (Nama, Email, Nomor Telepon, Member Sejak).
/// - Modul Keamanan & Kredensial terintegrasi (Kunci PIN/Biometrik, Reset Kata Sandi, Enkripsi Cloud).
/// - Tombol Keluar (Sign Out) dengan dialog konfirmasi aman.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  String _getInitials(String name, String email) {
    final source = name.trim().isNotEmpty ? name.trim() : email.trim();
    if (source.isEmpty) return 'U';
    final parts = source.split(RegExp(r'[\s.@]+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return source.substring(0, source.length >= 2 ? 2 : 1).toUpperCase();
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

  void _showSecurityInfoDialog(BuildContext context) {
    unawaited(AppHaptics.light());
    MinimalDialog.showInfo(
      context,
      title: 'Privasi & Keamanan Cloud',
      message: 'MyFinance beroperasi dengan arsitektur Full Cloud Supabase PostgreSQL yang mengutamakan keamanan dan privasi data finansial Anda.\n\n'
          '• Database Cloud Supabase PostgreSQL dengan isolasi Row Level Security (RLS)\n'
          '• Akses data terisolasi ketat hanya untuk akun terautentikasi (auth.uid())\n'
          '• Berkas struk tersimpan privat di Supabase Storage (User-Scoped Bucket)\n'
          '• Seluruh transmisi data dienkripsi dengan standar TLS 1.3.',
    );
  }

  void _showEditProfileModal(BuildContext context, WidgetRef ref, AuthUser? user) {
    unawaited(AppHaptics.selection());
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController(text: user?.name ?? '');
    final phoneController = TextEditingController(text: user?.phone ?? '');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: isDark ? AppColors.surfaceModalDark : AppColors.surfaceModalLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Kelola Informasi Kontak',
                  style: AppTypography.title2.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Perbarui nama lengkap dan nomor telepon akun Anda.',
                  style: AppTypography.caption.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 20),
                AppTextField(
                  label: 'Nama Lengkap',
                  hintText: 'Nama lengkap Anda',
                  controller: nameController,
                  keyboardType: TextInputType.name,
                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Nomor Telepon',
                  hintText: 'Contoh: +628123456789 atau 08123456789',
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      unawaited(AppHaptics.medium());
                      final success = await ref.read(authControllerProvider.notifier).updateProfile(
                        name: nameController.text.trim(),
                        phone: phoneController.text.trim(),
                      );
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success ? 'Profil berhasil diperbarui.' : 'Gagal memperbarui profil.'),
                            ),
                          );
                        }
                      }
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Simpan Perubahan', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
    final name = authUser?.name;
    final phone = authUser?.phone;
    final initials = _getInitials(name ?? '', email);
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
                  if (name != null && name.trim().isNotEmpty) ...[
                    Text(
                      name.trim(),
                      style: AppTypography.title2.copyWith(fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: AppTypography.body.copyWith(color: textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    Text(
                      email,
                      style: AppTypography.title2.copyWith(fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 8),
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

            // Group 1: INFORMASI AKUN (Nama, Email, Nomor Telepon, Member Sejak)
            _buildSectionHeader('INFORMASI AKUN', isDark),
            _buildGroupCard(
              isDark: isDark,
              borderColor: borderColor,
              cardColor: cardColor,
              children: [
                // 1. Nama Lengkap
                _buildProfileTile(
                  icon: Icons.person_outline_rounded,
                  title: 'Nama Lengkap',
                  value: (name != null && name.trim().isNotEmpty) ? name.trim() : 'Belum diisi (Ketuk untuk menambah)',
                  isDark: isDark,
                  showChevron: true,
                  onTap: () => _showEditProfileModal(context, ref, authUser),
                ),
                Divider(height: 1, thickness: 0.6, indent: 52, color: dividerColor),

                // 2. Alamat Email
                _buildProfileTile(
                  icon: Icons.mail_outline_rounded,
                  title: 'Alamat Email',
                  value: email,
                  isDark: isDark,
                  onTap: () => _copyToClipboard(context, email, 'Email'),
                  trailing: Icon(Icons.copy_rounded, size: 16, color: textSecondary),
                ),
                Divider(height: 1, thickness: 0.6, indent: 52, color: dividerColor),

                // 3. Nomor Telepon
                _buildProfileTile(
                  icon: Icons.phone_outlined,
                  title: 'Nomor Telepon',
                  value: (phone != null && phone.trim().isNotEmpty)
                      ? phone.trim()
                      : 'Belum diatur (Ketuk untuk menambah)',
                  isDark: isDark,
                  trailingBadge: (phone != null && phone.trim().isNotEmpty) ? 'Terdaftar' : null,
                  showChevron: true,
                  onTap: () => _showEditProfileModal(context, ref, authUser),
                ),
                Divider(height: 1, thickness: 0.6, indent: 52, color: dividerColor),

                // 4. Member Sejak
                _buildProfileTile(
                  icon: Icons.calendar_today_outlined,
                  title: 'Member Sejak',
                  value: createdAtStr,
                  isDark: isDark,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Group 2: PENYIMPANAN CLOUD (Kapasitas Gambar Struk)
            _buildSectionHeader('PENYIMPANAN CLOUD', isDark),
            _buildGroupCard(
              isDark: isDark,
              borderColor: borderColor,
              cardColor: cardColor,
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
              ],
            ),

            const SizedBox(height: 24),

            // Group 3: KEAMANAN & KREDENSIAL (Kunci PIN/Biometrik, Ubah PIN, Reset Kata Sandi, Enkripsi TLS)
            _buildSectionHeader('KEAMANAN & KREDENSIAL', isDark),
            _buildGroupCard(
              isDark: isDark,
              borderColor: borderColor,
              cardColor: cardColor,
              children: [
                // Switch Kunci Aplikasi
                SwitchListTile.adaptive(
                  value: lockState.isAppLockEnabled,
                  activeColor: isDark ? AppColors.incomeDark : AppColors.incomeLight,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  secondary: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: (isDark ? AppColors.incomeDark : AppColors.incomeLight).withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      color: isDark ? AppColors.incomeDark : AppColors.incomeLight,
                      size: 17,
                    ),
                  ),
                  title: Text(
                    'Kunci Aplikasi',
                    style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    lockState.isAppLockEnabled
                        ? (lockState.isBiometricsAvailable && lockState.isBiometricsEnabled
                            ? 'Aktif • Dilindungi ${lockState.biometricLabel} & PIN'
                            : 'Aktif • Dilindungi PIN 6-digit')
                        : 'Minta PIN atau Biometrik saat membuka aplikasi',
                    style: AppTypography.caption.copyWith(color: textSecondary),
                  ),
                  onChanged: (enabled) async {
                    unawaited(AppHaptics.light());
                    if (!context.mounted) return;
                    if (enabled) {
                      final result = await PinSetupSheet.show(context);
                      if (result == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Kunci aplikasi berhasil diaktifkan.')),
                        );
                      }
                    } else {
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

                if (lockState.isAppLockEnabled) ...[
                  Divider(height: 1, thickness: 0.6, indent: 52, color: dividerColor),
                  _buildProfileTile(
                    icon: Icons.pin_outlined,
                    title: 'Ubah Kode Sandi PIN',
                    value: 'Ganti 6-digit PIN kode sandi aplikasi Anda',
                    showChevron: true,
                    isDark: isDark,
                    onTap: () async {
                      unawaited(AppHaptics.light());
                      if (!context.mounted) return;
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

                  if (lockState.isBiometricsAvailable) ...[
                    Divider(height: 1, thickness: 0.6, indent: 52, color: dividerColor),
                    SwitchListTile.adaptive(
                      value: lockState.isBiometricsEnabled,
                      activeColor: isDark ? AppColors.incomeDark : AppColors.incomeLight,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      secondary: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.incomeDark : AppColors.incomeLight).withValues(alpha: isDark ? 0.2 : 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.fingerprint_rounded, color: isDark ? AppColors.incomeDark : AppColors.incomeLight, size: 17),
                      ),
                      title: Text(
                        'Buka dengan ${lockState.biometricLabel}',
                        style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Buka kunci cepat menggunakan biometrik tanpa mengetik PIN',
                        style: AppTypography.caption.copyWith(color: textSecondary),
                      ),
                      onChanged: (val) {
                        unawaited(AppHaptics.light());
                        ref.read(appLockControllerProvider.notifier).setBiometricsEnabled(val);
                      },
                    ),
                  ],
                ],

                Divider(height: 1, thickness: 0.6, indent: 52, color: dividerColor),

                // Ubah Kata Sandi Akun
                _buildProfileTile(
                  icon: Icons.lock_reset_rounded,
                  title: 'Ubah Kata Sandi',
                  value: 'Kirim tautan reset kata sandi ke email Anda',
                  isDark: isDark,
                  showChevron: true,
                  onTap: () => _sendPasswordResetEmail(context, ref, email),
                ),

                Divider(height: 1, thickness: 0.6, indent: 52, color: dividerColor),

                // Jaminan Privasi & Enkripsi Cloud
                _buildProfileTile(
                  icon: Icons.shield_outlined,
                  title: 'Jaminan Privasi & Enkripsi Cloud',
                  value: 'PostgreSQL RLS terisolasi & TLS 1.3',
                  isDark: isDark,
                  showChevron: true,
                  onTap: () => _showSecurityInfoDialog(context),
                ),
              ],
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

  Widget _buildGroupCard({
    required bool isDark,
    required Color borderColor,
    required Color cardColor,
    required List<Widget> children,
  }) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 0.8),
        ),
        child: Column(
          children: children,
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
