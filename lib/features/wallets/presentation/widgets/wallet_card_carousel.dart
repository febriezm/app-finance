import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../domain/entities/wallet.dart';
import 'realistic_card_widget.dart';

/// Carousel Kartu Realistis Horisontal (Persis Gambar 1 — Blu/BCA Card Deck)
///
/// Fitur:
/// - Efek kartu mengintip di sebelah kanan (viewportFraction: 0.88).
/// - Indikator titik animasi mulus di bawah carousel.
/// - Menampilkan nama akun pemilik (accountHolderName) atau nama dompet.
class WalletCardCarousel extends StatefulWidget {
  final List<WalletWithBalance> wallets;
  final bool isBalanceVisible;
  final String? accountHolderName;
  final ValueChanged<WalletWithBalance>? onCardTap;
  final ValueChanged<int>? onPageChanged;
  final int initialPage;

  const WalletCardCarousel({
    super.key,
    required this.wallets,
    this.isBalanceVisible = true,
    this.accountHolderName,
    this.onCardTap,
    this.onPageChanged,
    this.initialPage = 0,
  });

  @override
  State<WalletCardCarousel> createState() => _WalletCardCarouselState();
}

class _WalletCardCarouselState extends State<WalletCardCarousel> {
  late final PageController _pageController;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(0, (widget.wallets.length - 1).clamp(0, 9999));
    _pageController = PageController(
      initialPage: _currentPage,
      viewportFraction: 0.88,
    );
  }

  @override
  void didUpdateWidget(covariant WalletCardCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.wallets.isNotEmpty && _currentPage >= widget.wallets.length) {
      _currentPage = widget.wallets.length - 1;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    if (widget.wallets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Horizontal PageView Slider (Gambar 1)
        SizedBox(
          height: 204,
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.wallets.length,
            onPageChanged: (index) {
              unawaited(AppHaptics.selection());
              setState(() => _currentPage = index);
              widget.onPageChanged?.call(index);
            },
            itemBuilder: (context, index) {
              final item = widget.wallets[index];
              final isCurrent = index == _currentPage;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                child: AnimatedScale(
                  scale: isCurrent ? 1.0 : 0.96,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: RealisticCardWidget(
                    wallet: item.wallet,
                    currentBalance: item.currentBalance,
                    isBalanceVisible: widget.isBalanceVisible,
                    accountHolderName: widget.accountHolderName,
                    isSelected: isCurrent,
                    onTap: () => widget.onCardTap?.call(item),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        // 2. Animated Dots Indicator & Counter
        if (widget.wallets.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...List.generate(widget.wallets.length, (index) {
                final isCurrent = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isCurrent ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? (isDark ? Colors.white : AppColors.primaryNavy)
                        : (isDark ? Colors.white24 : Colors.black12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
              const SizedBox(width: 10),
              Text(
                '${_currentPage + 1} / ${widget.wallets.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
