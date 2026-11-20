import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/app_haptics.dart';
import 'pin_dots_indicator.dart';
import 'pin_keypad.dart';

class PinSetupSheet extends ConsumerStatefulWidget {
  final bool isChangingPin;
  final VoidCallback? onSuccess;

  const PinSetupSheet({
    super.key,
    this.isChangingPin = false,
    this.onSuccess,
  });

  static Future<bool?> show(BuildContext context, {bool isChangingPin = false}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PinSetupSheet(
        isChangingPin: isChangingPin,
        onSuccess: () => Navigator.of(ctx).pop(true),
      ),
    );
  }

  @override
  ConsumerState<PinSetupSheet> createState() => _PinSetupSheetState();
}

class _PinSetupSheetState extends ConsumerState<PinSetupSheet> {
  String _firstPin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  String? _errorMessage;
  bool _enableBiometrics = true;

  void _onDigitPressed(String digit) {
    setState(() {
      _errorMessage = null;
      if (!_isConfirming) {
        if (_firstPin.length < 6) {
          _firstPin += digit;
          if (_firstPin.length == 6) {
            // Berpindah ke tahap konfirmasi
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted) {
                setState(() {
                  _isConfirming = true;
                });
              }
            });
          }
        }
      } else {
        if (_confirmPin.length < 6) {
          _confirmPin += digit;
          if (_confirmPin.length == 6) {
            // Verifikasi kecocokan
            _finalizePin();
          }
        }
      }
    });
  }

  void _onDeletePressed() {
    setState(() {
      _errorMessage = null;
      if (!_isConfirming) {
        if (_firstPin.isNotEmpty) {
          _firstPin = _firstPin.substring(0, _firstPin.length - 1);
        }
      } else {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        } else {
          // Kembali ke tahap awal jika menekan hapus saat confirm kosong
          _isConfirming = false;
        }
      }
    });
  }

  Future<void> _finalizePin() async {
    if (_firstPin == _confirmPin) {
      await AppHaptics.medium();
      final success = await ref.read(appLockControllerProvider.notifier).setupPin(
            _firstPin,
            enableBiometrics: _enableBiometrics,
          );
      if (success && mounted) {
        widget.onSuccess?.call();
      }
    } else {
      await AppHaptics.heavy();
      setState(() {
        _errorMessage = 'Kode sandi konfirmasi tidak cocok. Ulangi kembali.';
        _confirmPin = '';
        _firstPin = '';
        _isConfirming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lockState = ref.watch(appLockControllerProvider);
    final currentLength = _isConfirming ? _confirmPin.length : _firstPin.length;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context, false),
                icon: const Icon(Icons.close_rounded),
              ),
              Text(
                widget.isChangingPin ? 'Ubah Kode Sandi PIN' : 'Atur Kode Sandi PIN',
                style: AppTypography.headline.copyWith(fontSize: 16),
              ),
              const SizedBox(width: 48), // Spacer penyeimbang
            ],
          ),
          const SizedBox(height: 16),

          // Judul tahap
          Text(
            _isConfirming ? 'Konfirmasi Kode Sandi' : 'Masukkan 6 Digit Angka',
            style: AppTypography.title2.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            _isConfirming
                ? 'Masukkan kembali kode sandi untuk memverifikasi'
                : 'Kode sandi ini akan digunakan untuk membuka aplikasi',
            style: AppTypography.caption1.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Indikator Titik PIN
          PinDotsIndicator(
            currentLength: currentLength,
            hasError: _errorMessage != null,
          ),
          const SizedBox(height: 16),

          // Pesan Error
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _errorMessage!,
                style: AppTypography.caption1.copyWith(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
            )
          else
            const SizedBox(height: 18),

          // Opsi Biometrik jika perangkat mendukung
          if (lockState.isBiometricsAvailable)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Checkbox(
                    value: _enableBiometrics,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() {
                        _enableBiometrics = val ?? true;
                      });
                    },
                  ),
                  Text(
                    'Aktifkan juga ${lockState.biometricLabel}',
                    style: AppTypography.caption1,
                  ),
                ],
              ),
            ),

          // Papan Tombol Angka Khas iOS
          PinKeypad(
            onDigitPressed: _onDigitPressed,
            onDeletePressed: _onDeletePressed,
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
