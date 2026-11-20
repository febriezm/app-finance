import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/app_haptics.dart';

class PinKeypad extends StatelessWidget {
  final void Function(String digit) onDigitPressed;
  final VoidCallback onDeletePressed;
  final VoidCallback? onBiometricPressed;
  final bool showBiometricButton;
  final IconData biometricIcon;

  const PinKeypad({
    super.key,
    required this.onDigitPressed,
    required this.onDeletePressed,
    this.onBiometricPressed,
    this.showBiometricButton = false,
    this.biometricIcon = Icons.fingerprint_rounded,
  });

  static const List<Map<String, String>> _keys = [
    {'digit': '1', 'letters': ''},
    {'digit': '2', 'letters': 'ABC'},
    {'digit': '3', 'letters': 'DEF'},
    {'digit': '4', 'letters': 'GHI'},
    {'digit': '5', 'letters': 'JKL'},
    {'digit': '6', 'letters': 'MNO'},
    {'digit': '7', 'letters': 'PQRS'},
    {'digit': '8', 'letters': 'TUV'},
    {'digit': '9', 'letters': 'WXYZ'},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Baris 1-3
          for (int row = 0; row < 3; row++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (int col = 0; col < 3; col++)
                    _buildDigitButton(_keys[row * 3 + col], isDark),
                ],
              ),
            ),

          // Baris 4 (Biometrik, 0, Hapus)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Tombol Kiri (Biometrik / Kosong)
                SizedBox(
                  width: 72,
                  height: 72,
                  child: showBiometricButton && onBiometricPressed != null
                      ? IconButton(
                          onPressed: () {
                            AppHaptics.light();
                            onBiometricPressed!();
                          },
                          icon: Icon(biometricIcon, size: 30, color: AppColors.primary),
                          tooltip: 'Biometrik / Face ID',
                        )
                      : const SizedBox.shrink(),
                ),

                // Tombol 0
                _buildDigitButton({'digit': '0', 'letters': ''}, isDark),

                // Tombol Kanan (Hapus Backspace)
                SizedBox(
                  width: 72,
                  height: 72,
                  child: IconButton(
                    onPressed: () {
                      AppHaptics.light();
                      onDeletePressed();
                    },
                    icon: Icon(
                      Icons.backspace_outlined,
                      size: 26,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    tooltip: 'Hapus',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDigitButton(Map<String, String> item, bool isDark) {
    final digit = item['digit']!;
    final letters = item['letters']!;

    return InkResponse(
      onTap: () {
        AppHaptics.light();
        onDigitPressed(digit);
      },
      radius: 36,
      containedInkWell: true,
      highlightShape: BoxShape.circle,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              digit,
              style: AppTypography.title1.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w400,
                height: 1.1,
              ),
            ),
            if (letters.isNotEmpty)
              Text(
                letters,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
