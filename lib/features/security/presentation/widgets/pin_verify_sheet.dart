import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/app_haptics.dart';
import 'pin_dots_indicator.dart';
import 'pin_keypad.dart';

class PinVerifySheet extends ConsumerStatefulWidget {
  final String title;
  final String subtitle;
  final Future<bool> Function(String pin) onPinEntered;

  const PinVerifySheet({
    super.key,
    this.title = 'Masukkan Kode Sandi PIN',
    this.subtitle = 'Verifikasi identitas Anda untuk melanjutkan',
    required this.onPinEntered,
  });

  static Future<bool?> show(
    BuildContext context, {
    String title = 'Masukkan Kode Sandi PIN',
    String subtitle = 'Verifikasi identitas Anda untuk melanjutkan',
    required Future<bool> Function(String pin) onPinEntered,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PinVerifySheet(
        title: title,
        subtitle: subtitle,
        onPinEntered: onPinEntered,
      ),
    );
  }

  @override
  ConsumerState<PinVerifySheet> createState() => _PinVerifySheetState();
}

class _PinVerifySheetState extends ConsumerState<PinVerifySheet> {
  String _enteredPin = '';
  String? _errorMessage;
  bool _isVerifying = false;

  void _onDigitPressed(String digit) {
    if (_isVerifying) return;
    setState(() {
      _errorMessage = null;
      if (_enteredPin.length < 6) {
        _enteredPin += digit;
        if (_enteredPin.length == 6) {
          _verify();
        }
      }
    });
  }

  void _onDeletePressed() {
    if (_isVerifying) return;
    setState(() {
      _errorMessage = null;
      if (_enteredPin.isNotEmpty) {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      }
    });
  }

  Future<void> _verify() async {
    setState(() => _isVerifying = true);
    final isValid = await widget.onPinEntered(_enteredPin);
    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (isValid) {
      await AppHaptics.medium();
      if (mounted) Navigator.pop(context, true);
    } else {
      await AppHaptics.heavy();
      if (mounted) {
        setState(() {
          _errorMessage = 'Kode sandi salah. Silakan coba lagi.';
          _enteredPin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                widget.title,
                style: AppTypography.headline.copyWith(fontSize: 16),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            widget.subtitle,
            style: AppTypography.caption1.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Indikator Titik PIN
          PinDotsIndicator(
            currentLength: _enteredPin.length,
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

          // Papan Tombol Angka
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
