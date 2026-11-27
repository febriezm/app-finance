import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../shared/widgets/app_button.dart';

/// Halaman Landing / Sambutan (Landing Page) — MyFinance Minimalist.
///
/// Ditampilkan saat aplikasi pertama kali dibuka dan pengguna belum terautentikasi.
/// Dirancang mematuhi filosofi Apple Human Interface Guidelines:
/// - Bersih, terstruktur, elegan, dan tenang (*quiet luxury design*).
/// - Menghadirkan ringkasan keunggulan sistem (buku besar presisi, cloud privat, OCR struk, keamanan biometrik).
/// - Akses cepat menuju pendaftaran akun baru atau masuk ke akun yang ada.
class LandingScreen extends ConsumerWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgScaffold = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final cardColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: bgScaffold,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),

                  // 1. Hero Brand Icon
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: borderColor, width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 38,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.primaryNavy,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 2. Title & Pill Tagline
                  Center(
                    child: Text(
                      'MyFinance',
                      style: AppTypography.largeTitle.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.incomeDark : AppColors.incomeLight).withValues(alpha: isDark ? 0.16 : 0.1),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                        border: Border.all(
                          color: (isDark ? AppColors.incomeDark : AppColors.incomeLight).withValues(alpha: 0.25),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        'Full Cloud Supabase & Ledger Invariance',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.incomeDark : AppColors.incomeLight,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Kelola arus kas, anggaran, dan bukti pengeluaran dengan presisi tinggi, tenang, dan privat.',
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(
                      color: textSecondary,
                      height: 1.45,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // 3. Highlight Cards (Apple HIG Grouped Style)
                  _buildHighlightCard(
                    icon: Icons.calculate_outlined,
                    iconColor: isDark ? AppColors.primaryNavy : const Color(0xFF2563EB),
                    title: 'Buku Besar Presisi',
                    description: 'Penghitungan saldo integer Rupiah deterministik tanpa celah pembulatan.',
                    cardColor: cardColor,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(height: 12),

                  _buildHighlightCard(
                    icon: Icons.cloud_done_outlined,
                    iconColor: isDark ? AppColors.incomeDark : AppColors.incomeLight,
                    title: 'Sinkronisasi Cloud Terisolasi',
                    description: 'Penyimpanan terenkripsi Row Level Security (RLS) di Supabase PostgreSQL.',
                    cardColor: cardColor,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(height: 12),

                  _buildHighlightCard(
                    icon: Icons.document_scanner_outlined,
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Pemindai Struk OCR',
                    description: 'Ekstraksi transaksi instan dari struk belanja dengan penyimpanan bukti privat.',
                    cardColor: cardColor,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),
                  const SizedBox(height: 12),

                  _buildHighlightCard(
                    icon: Icons.fingerprint_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    title: 'Kunci PIN & Biometrik',
                    description: 'Keamanan berlapis Face ID / Touch ID saat membuka aplikasi.',
                    cardColor: cardColor,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  ),

                  const SizedBox(height: 32),

                  // 4. Action Buttons
                  AppButton(
                    label: 'Mulai Sekarang',
                    variant: AppButtonVariant.primary,
                    onPressed: () {
                      unawaited(AppHaptics.medium());
                      final router = GoRouter.maybeOf(context);
                      if (router != null) {
                        router.go(AppRouter.register);
                      } else {
                        context.push(AppRouter.register);
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  AppButton(
                    label: 'Sudah Memiliki Akun? Masuk',
                    variant: AppButtonVariant.secondary,
                    onPressed: () {
                      unawaited(AppHaptics.light());
                      final router = GoRouter.maybeOf(context);
                      if (router != null) {
                        router.go(AppRouter.login);
                      } else {
                        context.push(AppRouter.login);
                      }
                    },
                  ),

                  const SizedBox(height: 20),

                  // 5. Minimal Privacy Footer
                  Center(
                    child: Text(
                      'Privasi Terjamin • Enkripsi TLS 1.3 • Standar Apple HIG',
                      style: AppTypography.caption.copyWith(
                        color: textSecondary.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required Color cardColor,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
