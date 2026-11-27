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
  final bool isCompact;

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
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = CardThemeHelper.resolveStyle(wallet);

    final rawHolder = accountHolderName?.trim();
    final holderName = (rawHolder != null && rawHolder.isNotEmpty)
        ? rawHolder
        : (wallet.name.isNotEmpty && wallet.name != 'preview' ? wallet.name : 'Nama Akun');

    const double cardRatio = 1.586; // Rasio kartu ID-1 standar ISO 7810

    final bool compact = isCompact || (width != null && width! <= 220) || (height != null && height! <= 140);
    final double cardRadius = compact ? 12.0 : 16.0;

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

    final isImageBased = style.imageAsset != null;
    final isBankJago = style.brand == RealisticCardBrand.jago;

    Widget cardBody = Container(
      width: effectiveWidth,
      height: effectiveHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(cardRadius),
        boxShadow: [
          BoxShadow(
            color: style.accentGlow,
            blurRadius: isSelected ? (compact ? 10 : 16) : (compact ? 6 : 10),
            offset: Offset(0, compact ? 3 : 6),
            spreadRadius: isSelected ? 1 : 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: compact ? 0.12 : 0.18),
            blurRadius: compact ? 6 : 12,
            offset: Offset(0, compact ? 2 : 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cardRadius),
        child: isImageBased
            ? Stack(
                children: [
                  // 1. Gambar Asli Kartu Bank (assets/kartu_bank)
                  Positioned.fill(
                    child: Image.asset(
                      style.imageAsset!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(gradient: style.gradient),
                        );
                      },
                    ),
                  ),

                  // 2. Subtle Glossy Specular Sheen (Apple Card light reflection)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: const Alignment(-0.8, -1.0),
                          end: const Alignment(0.8, 1.0),
                          stops: const [0.0, 0.4, 0.7, 1.0],
                          colors: [
                            Colors.white.withValues(alpha: 0.08),
                            Colors.white.withValues(alpha: 0.02),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.12),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 3. Subtle Border Hairline
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(cardRadius),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 0.8,
                        ),
                      ),
                    ),
                  ),

                  // 4. Badge Arsip (jika status dompet diarsipkan)
                  if (wallet.isArchived)
                    Positioned(
                      top: compact ? 8 : 14,
                      left: compact ? 10 : 18,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6, vertical: compact ? 1 : 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(compact ? 3 : 4),
                          border: Border.all(color: Colors.orange, width: 0.8),
                        ),
                        child: Text(
                          'ARSIP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 7 : 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

                  // 5. Saldo Display (Area tengah kanan, aman dari logo bank & payment network)
                  if (showBalance)
                    Positioned(
                      top: 0,
                      bottom: 0,
                      right: compact ? 12 : 20,
                      child: Center(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'SALDO',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: compact ? 7 : 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: compact ? 0.4 : 0.8,
                                shadows: const [
                                  Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
                                ],
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
                                  color: Colors.white,
                                  fontSize: compact ? 12 : 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                  shadows: const [
                                    Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
                                    Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 6. Nama Akun di Pojok Bawah
                  // Khusus Bank Jago: pojok bawah sebelah KANAN
                  // Bank Lainnya: pojok bawah sebelah KIRI
                  if (isBankJago)
                    Positioned(
                      right: compact ? 12 : 22,
                      bottom: compact ? 8 : 16,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: compact ? 100 : 180),
                        child: Text(
                          holderName,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 9 : 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            shadows: const [
                              Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
                              Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2)),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                  else
                    Positioned(
                      left: compact ? 12 : 20,
                      bottom: compact ? 8 : 16,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: compact ? 100 : 220),
                        child: Text(
                          holderName,
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 9 : 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            shadows: const [
                              Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
                              Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 2)),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              )
            : Stack(
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
                        borderRadius: BorderRadius.circular(cardRadius),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 0.8,
                        ),
                      ),
                    ),
                  ),

                  // 5. Card Foreground Content
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 10 : 18,
                      vertical: compact ? 8 : 14,
                    ),
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
                                    fontSize: compact ? 10 : 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                    shadows: const [
                                      Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1)),
                                    ],
                                  ),
                                ),
                                if (wallet.isArchived) ...[
                                  SizedBox(width: compact ? 4 : 8),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6, vertical: compact ? 1 : 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(compact ? 3 : 4),
                                      border: Border.all(color: Colors.orange, width: 0.8),
                                    ),
                                    child: Text(
                                      'ARSIP',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: compact ? 7 : 9,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),

                            // Bank / Institution Logo (Dihilangkan untuk tipe selain Rekening Bank)
                            if (wallet.type == WalletType.bank)
                              _buildIssuerLogo(style, isCompact: compact)
                            else
                              const SizedBox.shrink(),
                          ],
                        ),

                        // Row B: Middle Area (EMV Chip + Contactless + Saldo Display)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (style.chipType != ChipType.none) ...[
                              SizedBox(
                                width: compact ? 22 : 36,
                                height: compact ? 17 : 27,
                                child: _buildEmvChip(style.chipType),
                              ),
                              SizedBox(width: compact ? 4 : 8),
                              SizedBox(
                                width: compact ? 9 : 14,
                                height: compact ? 11 : 16,
                                child: _buildContactlessWaves(),
                              ),
                              SizedBox(width: compact ? 6 : 12),
                            ] else ...[
                              // Untuk E-Wallet / Cash: Icon Badge
                              Container(
                                width: compact ? 24 : 38,
                                height: compact ? 24 : 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.16),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 0.8),
                                ),
                                child: Icon(
                                  style.brand == RealisticCardBrand.cash
                                      ? Icons.account_balance_wallet_outlined
                                      : Icons.qr_code_2_rounded,
                                  size: compact ? 13 : 20,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: compact ? 6 : 12),
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
                                        fontSize: compact ? 7 : 9,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: compact ? 0.4 : 0.8,
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
                                          fontSize: compact ? 12 : 17,
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
                            // Left: Nama Akun Saja (sesuai instruksi: hanya ada nama akun saja)
                            Expanded(
                              child: Text(
                                holderName,
                                style: TextStyle(
                                  color: style.primaryTextColor,
                                  fontSize: compact ? 9 : 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                  shadows: const [
                                    Shadow(color: Colors.black45, blurRadius: 3, offset: Offset(0, 1)),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                            // Right: Payment Network Badge (Mastercard, VISA, GPN, QRIS)
                            SizedBox(
                              height: compact ? 14 : 20,
                              child: FittedBox(
                                fit: BoxFit.contain,
                                alignment: Alignment.bottomRight,
                                child: _buildPaymentNetworkBadge(style.paymentNetwork),
                              ),
                            ),
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
          borderRadius: BorderRadius.circular(cardRadius),
          child: cardBody,
        ),
      );
    }

    return cardBody;
  }

  /// Logo Bank / Institusi
  Widget _buildIssuerLogo(CardStyleDefinition style, {bool isCompact = false}) {
    if (style.brand == RealisticCardBrand.bcaBlue ||
        style.brand == RealisticCardBrand.bcaGold ||
        style.brand == RealisticCardBrand.bcaPlatinum) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logo BCA Diamond Emblem
          Container(
            width: isCompact ? 10 : 14,
            height: isCompact ? 10 : 14,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isCompact ? 2 : 3),
            ),
            child: Center(
              child: Icon(Icons.change_history_rounded, size: isCompact ? 7 : 10, color: const Color(0xFF0058A8)),
            ),
          ),
          SizedBox(width: isCompact ? 3 : 5),
          Text(
            'BCA',
            style: TextStyle(
              color: Colors.white,
              fontSize: isCompact ? 11 : 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      );
    }

    if (style.brand == RealisticCardBrand.bcaBlu) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: isCompact ? 5 : 7, vertical: isCompact ? 2 : 3),
        decoration: BoxDecoration(
          color: const Color(0xFF00E5FF),
          borderRadius: BorderRadius.circular(isCompact ? 4 : 5),
        ),
        child: Text(
          'blu',
          style: TextStyle(
            color: const Color(0xFF0A1931),
            fontSize: isCompact ? 9 : 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 5 : 7, vertical: isCompact ? 1.5 : 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(isCompact ? 4 : 6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.6),
      ),
      child: Text(
        style.logoText,
        style: TextStyle(
          color: Colors.white,
          fontSize: isCompact ? 8 : 11,
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
