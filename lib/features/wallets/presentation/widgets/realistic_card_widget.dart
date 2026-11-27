import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/formatting/currency_formatter.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../domain/entities/wallet.dart';
import 'card_theme_helper.dart';

/// Kartu Fisik ATM / E-Wallet Realistis (Apple HIG & Authentic Indonesian Card Aesthetic)
///
/// Merender kartu debit/kredit/e-wallet menyerupai fisik aslinya:
/// - Paspor BCA Blue (Pebble water pattern, "Paspor", BCA Logo, Mastercard)
/// - Paspor BCA Gold (Batik Bird vector, gold sheen, "Paspor gold debit", GPN/Mastercard)
/// - Paspor BCA Platinum (Calligraphy "P", matte black carbon, "Paspor", Mastercard)
/// - blu by BCA (Deep navy, blu cyan waves, "blu in", VISA Debit)
/// - Mandiri, BNI, BRI, BSI, CIMB, Jago, Jenius, DANA, GoPay, OVO, ShopeePay, LinkAja, Kas Tunai
class RealisticCardWidget extends StatelessWidget {
  final Wallet wallet;
  final int currentBalance;
  final bool isBalanceVisible;
  final String? accountHolderName;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final bool isSelected;
  final bool showBalance;

  const RealisticCardWidget({
    super.key,
    required this.wallet,
    required this.currentBalance,
    this.isBalanceVisible = true,
    this.accountHolderName,
    this.onTap,
    this.width,
    this.height,
    this.isSelected = false,
    this.showBalance = true,
  });

  @override
  Widget build(BuildContext context) {
    final style = CardThemeHelper.resolveStyle(wallet);
    final cardSuffix = CardThemeHelper.getCardNumberSuffix(wallet.id);

    final rawHolder = accountHolderName?.trim();
    final holderName = (rawHolder != null && rawHolder.isNotEmpty)
        ? rawHolder
        : wallet.name;

    const double cardRatio = 1.586; // Rasio kartu ID-1 standar ISO 7810

    // Hitung dimensi presisi agar kartu selalu proporsional dan tidak pernah lonjong/gepeng
    final double? effectiveWidth;
    final double? effectiveHeight;

    if (width != null && height != null) {
      effectiveWidth = width;
      effectiveHeight = height;
    } else if (height != null) {
      effectiveHeight = height;
      effectiveWidth = height! * cardRatio;
    } else if (width != null) {
      effectiveWidth = width;
      effectiveHeight = width! / cardRatio;
    } else {
      effectiveWidth = null;
      effectiveHeight = null;
    }

    Widget cardBody = Container(
      width: effectiveWidth,
      height: effectiveHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: style.accentGlow,
            blurRadius: isSelected ? 16 : 10,
            offset: const Offset(0, 6),
            spreadRadius: isSelected ? 1 : 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // 1. Base Gradient Background
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: style.gradient,
                ),
              ),
            ),

            // 2. Authentic Motif Texture Painter
            Positioned.fill(
              child: CustomPaint(
                painter: _CardPatternPainter(
                  patternType: style.patternType,
                  brand: style.brand,
                ),
              ),
            ),

            // 3. Subtle Glossy Specular Sheen (Apple Card light reflection)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: const Alignment(-0.8, -1.0),
                    end: const Alignment(0.8, 1.0),
                    stops: const [0.0, 0.4, 0.7, 1.0],
                    colors: [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.03),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.15),
                    ],
                  ),
                ),
              ),
            ),

            // 4. Subtle Border Hairline
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 0.8,
                  ),
                ),
              ),
            ),

            // 5. Card Foreground Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Row A: Top (Issuer Program Title + Bank / Institution Logo)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Card Series / Title (e.g. "Paspor", "bluAccount", "DANA Balance")
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            style.issuerTitle,
                            style: TextStyle(
                              color: style.primaryTextColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                              shadows: const [
                                Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1)),
                              ],
                            ),
                          ),
                          if (wallet.isArchived) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.orange, width: 0.8),
                              ),
                              child: const Text(
                                'ARSIP',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      // Bank / Institution Logo
                      _buildIssuerLogo(style),
                    ],
                  ),

                  // Row B: Middle Area (EMV Chip + Contactless + Saldo Display)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (style.chipType != ChipType.none) ...[
                        _buildEmvChip(style.chipType),
                        const SizedBox(width: 8),
                        _buildContactlessWaves(),
                        const SizedBox(width: 12),
                      ] else ...[
                        // Untuk E-Wallet / Cash: Icon Badge
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 0.8),
                          ),
                          child: Icon(
                            style.brand == RealisticCardBrand.cash
                                ? Icons.account_balance_wallet_outlined
                                : Icons.qr_code_2_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],

                      // Hero Saldo
                      if (showBalance)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'SALDO',
                                style: TextStyle(
                                  color: style.secondaryTextColor.withValues(alpha: 0.85),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 1),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  isBalanceVisible
                                      ? CurrencyFormatter.formatRupiah(currentBalance)
                                      : 'Rp ••••••••',
                                  style: TextStyle(
                                    color: style.primaryTextColor,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                    shadows: const [
                                      Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 1)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  // Row C: Bottom (Holder Name + Masked Number + Expiry + Payment Network)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Left: Cardholder Name & Masked Number
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              holderName,
                              style: TextStyle(
                                color: style.primaryTextColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                                shadows: const [
                                  Shadow(color: Colors.black45, blurRadius: 3, offset: Offset(0, 1)),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '•••• $cardSuffix',
                                    style: TextStyle(
                                      color: style.secondaryTextColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'VALID THRU 12/29',
                                    style: TextStyle(
                                      color: style.secondaryTextColor.withValues(alpha: 0.75),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Right: Payment Network Badge (Mastercard, VISA, GPN, QRIS)
                      _buildPaymentNetworkBadge(style.paymentNetwork),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (effectiveWidth == null && effectiveHeight == null) {
      cardBody = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AspectRatio(
            aspectRatio: 1.586,
            child: cardBody,
          ),
        ),
      );
    } else {
      cardBody = Center(
        child: cardBody,
      );
    }

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            unawaited(AppHaptics.light());
            onTap?.call();
          },
          borderRadius: BorderRadius.circular(16),
          child: cardBody,
        ),
      );
    }

    return cardBody;
  }

  /// Logo Bank / Institusi
  Widget _buildIssuerLogo(CardStyleDefinition style) {
    if (style.brand == RealisticCardBrand.bcaBlue ||
        style.brand == RealisticCardBrand.bcaGold ||
        style.brand == RealisticCardBrand.bcaPlatinum) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logo BCA Diamond Emblem
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Center(
              child: Icon(Icons.change_history_rounded, size: 10, color: Color(0xFF0058A8)),
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'BCA',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      );
    }

    if (style.brand == RealisticCardBrand.bcaBlu) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF00E5FF),
          borderRadius: BorderRadius.circular(5),
        ),
        child: const Text(
          'blu',
          style: TextStyle(
            color: Color(0xFF0A1931),
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.6),
      ),
      child: Text(
        style.logoText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  /// EMV Metallic Smart Chip
  Widget _buildEmvChip(ChipType type) {
    final isGold = type == ChipType.gold;
    return Container(
      width: 36,
      height: 27,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isGold
              ? const [Color(0xFFFFDF79), Color(0xFFF0C05A), Color(0xFFC99426), Color(0xFFE5B85C)]
              : const [Color(0xFFEDEDED), Color(0xFFD6D6D6), Color(0xFFAFAFAF), Color(0xFFD0D0D0)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
        border: Border.all(color: Colors.black.withValues(alpha: 0.25), width: 0.6),
      ),
      child: CustomPaint(
        painter: _EmvChipPainter(isGold: isGold),
      ),
    );
  }

  /// Contactless Payment Wave Signals `)))`
  Widget _buildContactlessWaves() {
    return SizedBox(
      width: 14,
      height: 16,
      child: CustomPaint(
        painter: _ContactlessPainter(),
      ),
    );
  }

  /// Logo Jaringan Pembayaran (Mastercard, VISA, GPN, QRIS)
  Widget _buildPaymentNetworkBadge(PaymentNetwork network) {
    switch (network) {
      case PaymentNetwork.mastercard:
        return SizedBox(
          width: 38,
          height: 24,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 0,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFEB001B),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFF79E1B),
                  ),
                ),
              ),
            ],
          ),
        );

      case PaymentNetwork.visa:
        return const Text(
          'VISA',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: 0.5,
            shadows: [Shadow(color: Colors.black38, blurRadius: 2, offset: Offset(0, 1))],
          ),
        );

      case PaymentNetwork.gpn:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_rounded, size: 12, color: Color(0xFFED1C24)),
              SizedBox(width: 2),
              Text(
                'GPN',
                style: TextStyle(
                  color: Color(0xFFED1C24),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );

      case PaymentNetwork.qris:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'QRIS',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
        );

      case PaymentNetwork.cash:
        return const Icon(
          Icons.payments_outlined,
          color: Colors.white70,
          size: 20,
        );

      case PaymentNetwork.none:
        return const SizedBox.shrink();
    }
  }
}

/// CustomPainter untuk pola autentik kartu perbankan Indonesia (Gambar 2 & Gambar 1)
class _CardPatternPainter extends CustomPainter {
  final CardPatternType patternType;
  final RealisticCardBrand brand;

  _CardPatternPainter({
    required this.patternType,
    required this.brand,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (patternType) {
      case CardPatternType.bcaPebbles:
        _drawBcaPebbles(canvas, size);
        break;
      case CardPatternType.bcaGoldBird:
        _drawBcaGoldBird(canvas, size);
        break;
      case CardPatternType.bcaPlatinumP:
        _drawBcaPlatinumP(canvas, size);
        break;
      case CardPatternType.bluWaves:
        _drawBluWaves(canvas, size);
        break;
      case CardPatternType.mandiriSwoosh:
        _drawMandiriSwoosh(canvas, size);
        break;
      case CardPatternType.bniWave:
        _drawBniWave(canvas, size);
        break;
      case CardPatternType.briGeometric:
        _drawBriGeometric(canvas, size);
        break;
      case CardPatternType.bsiArabesque:
        _drawBsiArabesque(canvas, size);
        break;
      case CardPatternType.jagoSlash:
        _drawJagoSlash(canvas, size);
        break;
      case CardPatternType.danaCurves:
        _drawDanaCurves(canvas, size);
        break;
      case CardPatternType.gopayRing:
        _drawGopayRing(canvas, size);
        break;
      case CardPatternType.ovoCircles:
        _drawOvoCircles(canvas, size);
        break;
      case CardPatternType.guillocheCash:
        _drawGuillocheCash(canvas, size);
        break;
      case CardPatternType.cleanMinimal:
        _drawMinimalMesh(canvas, size);
        break;
    }
  }

  /// Paspor BCA Blue (Pebbles / Gelembung Kaca Khas BCA) — Gambar 2 Kiri
  void _drawBcaPebbles(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    final pebbles = [
      Offset(size.width * 0.15, size.height * 0.65),
      Offset(size.width * 0.32, size.height * 0.35),
      Offset(size.width * 0.40, size.height * 0.75),
      Offset(size.width * 0.55, size.height * 0.45),
      Offset(size.width * 0.70, size.height * 0.85),
      Offset(size.width * 0.85, size.height * 0.30),
      Offset(size.width * 0.90, size.height * 0.70),
    ];

    for (int i = 0; i < pebbles.length; i++) {
      final p = pebbles[i];
      final radius = 22.0 + (i % 3) * 12.0;
      paint.color = Colors.white.withValues(alpha: 0.04 + (i % 3) * 0.03);
      final rrect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: p, width: radius * 1.5, height: radius * 1.8),
        Radius.circular(radius * 0.6),
      );
      canvas.drawRRect(rrect, paint);
    }
  }

  /// Paspor BCA Gold (Batik Bird / Garuda Emas) — Gambar 2 Tengah
  void _drawBcaGoldBird(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFFFFF0B3).withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final fillPaint = Paint()
      ..color = const Color(0xFF7A5400).withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width * 0.62, size.height * 0.55);

    // Sayap & Ekor Garuda Batik
    final path = Path();
    path.moveTo(center.dx - 40, center.dy + 30);
    path.cubicTo(center.dx - 10, center.dy - 35, center.dx + 40, center.dy - 40, center.dx + 70, center.dy - 10);
    path.cubicTo(center.dx + 90, center.dy + 15, center.dx + 60, center.dy + 45, center.dx + 25, center.dy + 40);
    path.close();
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, linePaint);

    // Bulu-bulu sayap batik
    for (int i = 1; i <= 5; i++) {
      final wingPath = Path();
      wingPath.moveTo(center.dx - 20 + i * 12, center.dy - 10);
      wingPath.quadraticBezierTo(
        center.dx + i * 16,
        center.dy - 35 - i * 4,
        center.dx + 25 + i * 14,
        center.dy - 5,
      );
      canvas.drawPath(wingPath, linePaint);
    }
  }

  /// Paspor BCA Platinum (Silver Calligraphy "P") — Gambar 2 Kanan
  void _drawBcaPlatinumP(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width * 0.68, size.height * 0.52);

    // Kaligrafi "P" besar khas Paspor Platinum
    final pPath = Path();
    // Batang kiri melengkung
    pPath.moveTo(center.dx - 25, center.dy + 48);
    pPath.cubicTo(
      center.dx - 20, center.dy + 10,
      center.dx - 10, center.dy - 30,
      center.dx - 8, center.dy - 45,
    );
    // Lengkungan kepala P besar
    pPath.cubicTo(
      center.dx + 15, center.dy - 55,
      center.dx + 52, center.dy - 35,
      center.dx + 42, center.dy + 5,
    );
    pPath.cubicTo(
      center.dx + 30, center.dy + 30,
      center.dx - 15, center.dy + 15,
      center.dx - 22, center.dy - 5,
    );
    canvas.drawPath(pPath, paint);

    // Subtle carbon circles
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.04);
    canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.70), 30, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.35), 45, dotPaint);
  }

  /// blu by BCA Waves — Gambar 1
  void _drawBluWaves(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Lingkaran navy kedua di kanan
    paint.color = const Color(0xFF1E3A5F).withValues(alpha: 0.45);
    canvas.drawCircle(Offset(size.width * 0.88, size.height * 0.50), size.height * 0.75, paint);

    // Lingkaran aksen tengah
    paint.color = const Color(0xFF0F2642).withValues(alpha: 0.35);
    canvas.drawCircle(Offset(size.width * 0.42, size.height * 0.30), size.height * 0.45, paint);
  }

  /// Mandiri Golden Swoosh
  void _drawMandiriSwoosh(Canvas canvas, Size size) {
    final swooshPaint = Paint()
      ..color = const Color(0xFFFFB800).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.85);
    path.cubicTo(size.width * 0.3, size.height * 0.75, size.width * 0.65, size.height * 0.95, size.width, size.height * 0.70);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, swooshPaint);
  }

  /// BNI Wave
  void _drawBniWave(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF15A24).withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final path = Path();
    path.moveTo(size.width * 0.2, size.height);
    path.cubicTo(size.width * 0.5, size.height * 0.6, size.width * 0.7, size.height * 0.8, size.width, size.height * 0.4);
    canvas.drawPath(path, paint);
  }

  /// BRI Geometric
  void _drawBriGeometric(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 0; i < 6; i++) {
      canvas.drawLine(
        Offset(size.width * 0.4 + i * 25, 0),
        Offset(size.width * 0.1 + i * 25, size.height),
        paint,
      );
    }
  }

  /// BSI Arabesque Star
  void _drawBsiArabesque(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final center = Offset(size.width * 0.80, size.height * 0.55);
    canvas.drawCircle(center, 38, paint);
    canvas.drawCircle(center, 24, paint);
  }

  /// Jago Slash
  void _drawJagoSlash(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF7A00).withValues(alpha: 0.20)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width * 0.65, 0);
    path.lineTo(size.width * 0.80, 0);
    path.lineTo(size.width * 0.55, size.height);
    path.lineTo(size.width * 0.40, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  /// DANA Curves
  void _drawDanaCurves(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.2), 65, paint);
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.8), 50, paint);
  }

  /// GoPay Ring
  void _drawGopayRing(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16.0;

    canvas.drawCircle(Offset(size.width * 0.78, size.height * 0.50), 52, paint);
  }

  /// OVO Circles
  void _drawOvoCircles(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC4B5FD).withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final center = Offset(size.width * 0.78, size.height * 0.52);
    canvas.drawCircle(center, 45, paint);
    canvas.drawCircle(center, 28, paint);
  }

  /// Kas Tunai Guilloche
  void _drawGuillocheCash(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(8, 8, size.width - 16, size.height - 16),
      const Radius.circular(10),
    );
    canvas.drawRRect(rect, paint);
  }

  void _drawMinimalMesh(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.3), 70, paint);
  }

  @override
  bool shouldRepaint(covariant _CardPatternPainter oldDelegate) =>
      oldDelegate.patternType != patternType || oldDelegate.brand != brand;
}

/// CustomPainter untuk garis sirkuit chip EMV realistis
class _EmvChipPainter extends CustomPainter {
  final bool isGold;

  _EmvChipPainter({required this.isGold});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = isGold ? const Color(0xFF7A5400).withValues(alpha: 0.5) : const Color(0xFF555555).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    // Garis pembagi sirkuit internal chip
    canvas.drawLine(Offset(size.width * 0.32, 0), Offset(size.width * 0.32, size.height), linePaint);
    canvas.drawLine(Offset(size.width * 0.68, 0), Offset(size.width * 0.68, size.height), linePaint);
    canvas.drawLine(Offset(0, size.height * 0.50), Offset(size.width, size.height * 0.50), linePaint);

    final centerRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(size.width * 0.5, size.height * 0.5), width: 10, height: 8),
      const Radius.circular(2),
    );
    canvas.drawRRect(centerRect, linePaint);
  }

  @override
  bool shouldRepaint(covariant _EmvChipPainter oldDelegate) => oldDelegate.isGold != isGold;
}

/// CustomPainter untuk gelombang contactless `)))`
class _ContactlessPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    final center = Offset(-size.width * 0.4, size.height * 0.5);

    for (int i = 1; i <= 3; i++) {
      final radius = 6.0 + i * 4.5;
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(rect, -math.pi / 4.2, math.pi / 2.1, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ContactlessPainter oldDelegate) => false;
}
