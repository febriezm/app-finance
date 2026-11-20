import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class PinDotsIndicator extends StatelessWidget {
  final int pinLength;
  final int currentLength;
  final bool hasError;

  const PinDotsIndicator({
    super.key,
    this.pinLength = 6,
    required this.currentLength,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pinLength, (index) {
        final isFilled = index < currentLength;
        final color = hasError
            ? AppColors.error
            : isFilled
                ? AppColors.primary
                : (isDark ? const Color(0xFF3A3A3C) : const Color(0xFFD1D1D6));

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: isFilled ? 16 : 14,
          height: isFilled ? 16 : 14,
          decoration: BoxDecoration(
            color: isFilled ? color : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: color,
              width: 2,
            ),
          ),
        );
      }),
    );
  }
}
