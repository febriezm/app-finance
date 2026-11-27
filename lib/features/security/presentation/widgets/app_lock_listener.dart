import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/app_providers.dart';
import 'app_lock_screen.dart';

/// Listener Kunci Aplikasi — MyFinance Minimal.
///
/// Kebijakan Penguncian:
/// - Kunci Aplikasi HANYA aktif saat aplikasi pertama kali dibuka atau di-refresh (cold start / reload)
///   dan pengguna telah terautentikasi (login) serta memiliki proteksi Kunci Aplikasi aktif pada akunnya.
/// - Setelah berhasil di-unlock, aplikasi TIDAK AKAN mengunci ulang di tengah penggunaan
///   (misal saat membuka kamera, Scan Struk OCR, atau berpindah menu).
class AppLockListener extends ConsumerWidget {
  final Widget child;

  const AppLockListener({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authCurrentUserProvider);
    final lockState = ref.watch(appLockControllerProvider);

    // Kunci aplikasi HANYA aktif saat pengguna telah terautentikasi (login)
    // dan belum di-unlock pada sesi aktif ini.
    if (authUser != null && lockState.isAppLockEnabled && !lockState.isUnlocked) {
      return const AppLockScreen();
    }

    return child;
  }
}
