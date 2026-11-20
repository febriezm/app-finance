import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/app_haptics.dart';
import 'pin_dots_indicator.dart';
import 'pin_keypad.dart';

class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  String _enteredPin = '';
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    // Otomatis picu biometrik (Face ID / Touch ID) saat layar terkunci tampil jika aktif
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryAutoBiometrics();
    });
  }

  Future<void> _tryAutoBiometrics() async {
    final lockState = ref.read(appLockControllerProvider);
    if (lockState.isBiometricsAvailable && lockState.isBiometricsEnabled) {
      await ref.read(appLockControllerProvider.notifier).unlockWithBiometrics();
    }
  }

  void _onDigitPressed(String digit) {
    if (_isChecking) return;

    setState(() {
      if (_enteredPin.length < 6) {
        _enteredPin += digit;
        if (_enteredPin.length == 6) {
          _verifyPin();
        }
      }
    });
  }

  void _onDeletePressed() {
    if (_isChecking) return;

    setState(() {
      if (_enteredPin.isNotEmpty) {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      }
    });
  }

  Future<void> _verifyPin() async {
    setState(() => _isChecking = true);
    final success = await ref
        .read(appLockControllerProvider.notifier)
        .unlockWithPin(_enteredPin);
    setState(() => _isChecking = false);

    if (success) {
      await AppHaptics.medium();
    } else {
      await AppHaptics.heavy();
      setState(() {
        _enteredPin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lockState = ref.watch(appLockControllerProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(height: 12),

                      // Bagian Atas: Ikon & Judul
                      Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.lock_outline_rounded,
                                size: 36,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'MyFinance Terkunci',
                            style: AppTypography.title2.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Masukkan 6 digit kode sandi Anda',
                            style: AppTypography.caption1.copyWith(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),

                          // Indikator Titik PIN
                          PinDotsIndicator(
                            currentLength: _enteredPin.length,
                            hasError: lockState.errorMessage != null,
                          ),

                          const SizedBox(height: 12),

                          // Pesan Error jika salah
                          if (lockState.errorMessage != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                lockState.errorMessage!,
                                style: AppTypography.caption2.copyWith(color: AppColors.error),
                                textAlign: TextAlign.center,
                              ),
                            )
                          else
                            const SizedBox(height: 24),
                        ],
                      ),

                      // Bagian Bawah: Keypad Numerik
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: PinKeypad(
                          onDigitPressed: _onDigitPressed,
                          onDeletePressed: _onDeletePressed,
                          showBiometricButton: lockState.isBiometricsAvailable && lockState.isBiometricsEnabled,
                          biometricIcon: Icons.fingerprint_rounded,
                          onBiometricPressed: () {
                            ref.read(appLockControllerProvider.notifier).unlockWithBiometrics();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
