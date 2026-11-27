import 'package:flutter/material.dart';
import '../../domain/entities/wallet.dart';

/// Jenis / Brand kartu realistis yang didukung
enum RealisticCardBrand {
  bcaBlue, // Paspor BCA Blue (Gambar 2 kiri)
  bcaGold, // Paspor BCA Gold (Gambar 2 tengah)
  bcaPlatinum, // Paspor BCA Platinum (Gambar 2 kanan)
  bcaBlu, // blu by BCA (Gambar 1)
  mandiri, // Bank Mandiri
  bni, // Bank BNI
  bri, // Bank BRI
  bsi, // Bank Syariah Indonesia
  cimb, // CIMB Niaga
  jago, // Bank Jago
  jenius, // Jenius BTPN
  seabank, // SeaBank
  dana, // DANA E-Wallet
  gopay, // GoPay E-Wallet
  ovo, // OVO E-Wallet
  shopeepay, // ShopeePay
  linkaja, // LinkAja
  cash, // Kas Tunai / Brankas
  investment, // Investasi / Reksadana / Saham
  generic, // Kartu Umum / Titanium
}

enum ChipType {
  silver,
  gold,
  none,
}

enum PaymentNetwork {
  mastercard,
  visa,
  gpn,
  qris,
  cash,
  none,
}

enum CardPatternType {
  bcaPebbles,
  bcaGoldBird,
  bcaPlatinumP,
  bluWaves,
  mandiriSwoosh,
  bniWave,
  briGeometric,
  bsiArabesque,
  jagoSlash,
  danaCurves,
  gopayRing,
  ovoCircles,
  guillocheCash,
  cleanMinimal,
}

/// Definisi gaya visual kartu fisik
class CardStyleDefinition {
  final RealisticCardBrand brand;
  final String displayName;
  final String issuerTitle;
  final String logoText;
  final LinearGradient gradient;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final ChipType chipType;
  final PaymentNetwork paymentNetwork;
  final CardPatternType patternType;
  final Color accentGlow;

  const CardStyleDefinition({
    required this.brand,
    required this.displayName,
    required this.issuerTitle,
    required this.logoText,
    required this.gradient,
    this.primaryTextColor = Colors.white,
    this.secondaryTextColor = const Color(0xCCFFFFFF),
    this.chipType = ChipType.silver,
    this.paymentNetwork = PaymentNetwork.mastercard,
    this.patternType = CardPatternType.cleanMinimal,
    this.accentGlow = const Color(0x33000000),
  });
}

/// Helper pendeteksi otomatis tema kartu berdasarkan nama & tipe dompet
class CardThemeHelper {
  CardThemeHelper._();

  static const List<CardStyleDefinition> allPresets = [
    // 1. BCA Family
    CardStyleDefinition(
      brand: RealisticCardBrand.bcaBlue,
      displayName: 'BCA Paspor Blue',
      issuerTitle: 'Paspor',
      logoText: 'BCA',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF007ECC), Color(0xFF0058A8), Color(0xFF003770)],
      ),
      chipType: ChipType.silver,
      paymentNetwork: PaymentNetwork.mastercard,
      patternType: CardPatternType.bcaPebbles,
      accentGlow: Color(0x4D0058A8),
    ),
    CardStyleDefinition(
      brand: RealisticCardBrand.bcaGold,
      displayName: 'BCA Paspor Gold',
      issuerTitle: 'Paspor gold debit',
      logoText: 'BCA',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE5B85C), Color(0xFFC79832), Color(0xFF8F6317)],
      ),
      primaryTextColor: Color(0xFFFFFFFF),
      secondaryTextColor: Color(0xEEFFFFFF),
      chipType: ChipType.gold,
      paymentNetwork: PaymentNetwork.gpn,
      patternType: CardPatternType.bcaGoldBird,
      accentGlow: Color(0x4DC79832),
    ),
    CardStyleDefinition(
      brand: RealisticCardBrand.bcaPlatinum,
      displayName: 'BCA Paspor Platinum',
      issuerTitle: 'Paspor',
      logoText: 'BCA',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF282828), Color(0xFF141414), Color(0xFF050505)],
      ),
      chipType: ChipType.silver,
      paymentNetwork: PaymentNetwork.mastercard,
      patternType: CardPatternType.bcaPlatinumP,
      accentGlow: Color(0x4D333333),
    ),
    CardStyleDefinition(
      brand: RealisticCardBrand.bcaBlu,
      displayName: 'blu by BCA',
      issuerTitle: 'bluAccount',
      logoText: 'blu',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF14243B), Color(0xFF0C1929), Color(0xFF060F1A)],
      ),
      chipType: ChipType.silver,
      paymentNetwork: PaymentNetwork.visa,
      patternType: CardPatternType.bluWaves,
      accentGlow: Color(0x4D00E5FF),
    ),

    // 2. Bank Lainnya
    CardStyleDefinition(
      brand: RealisticCardBrand.mandiri,
      displayName: 'Bank Mandiri',
      issuerTitle: 'Mandiri Debit',
      logoText: 'mandırı',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF001B3A), Color(0xFF002D62), Color(0xFF00142B)],
      ),
      chipType: ChipType.gold,
      paymentNetwork: PaymentNetwork.visa,
      patternType: CardPatternType.mandiriSwoosh,
      accentGlow: Color(0x4D002D62),
    ),
    CardStyleDefinition(
      brand: RealisticCardBrand.bni,
      displayName: 'Bank BNI',
      issuerTitle: 'BNI Taplus',
      logoText: 'BNI',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF005E6A), Color(0xFF00434C), Color(0xFF00272B)],
      ),
      chipType: ChipType.silver,
      paymentNetwork: PaymentNetwork.mastercard,
      patternType: CardPatternType.bniWave,
      accentGlow: Color(0x4D005E6A),
    ),
    CardStyleDefinition(
      brand: RealisticCardBrand.bri,
      displayName: 'Bank BRI',
      issuerTitle: 'BritAma',
      logoText: 'BRI',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF00529C), Color(0xFF0A3B75), Color(0xFF031E3D)],
      ),
      chipType: ChipType.silver,
      paymentNetwork: PaymentNetwork.mastercard,
      patternType: CardPatternType.briGeometric,
      accentGlow: Color(0x4D00529C),
    ),
    CardStyleDefinition(
      brand: RealisticCardBrand.bsi,
      displayName: 'Bank Syariah Indonesia (BSI)',
      issuerTitle: 'BSI Debit',
      logoText: 'BSI',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF00A39D), Color(0xFF006B66), Color(0xFF003D3B)],
      ),
      chipType: ChipType.gold,
      paymentNetwork: PaymentNetwork.gpn,
      patternType: CardPatternType.bsiArabesque,
      accentGlow: Color(0x4D00A39D),
    ),
    CardStyleDefinition(
      brand: RealisticCardBrand.cimb,
      displayName: 'CIMB Niaga',
      issuerTitle: 'OCTO Debit',
      logoText: 'CIMB',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF8B0000), Color(0xFF6B0000), Color(0xFF450000)],
      ),
      chipType: ChipType.silver,
      paymentNetwork: PaymentNetwork.mastercard,
      patternType: CardPatternType.cleanMinimal,
      accentGlow: Color(0x4D8B0000),
    ),
    CardStyleDefinition(
      brand: RealisticCardBrand.jago,
      displayName: 'Bank Jago',
      issuerTitle: 'Kantong Utama',
      logoText: 'jago',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2A0845), Color(0xFF1B052E), Color(0xFF10021C)],
      ),
      chipType: ChipType.silver,
      paymentNetwork: PaymentNetwork.visa,
      patternType: CardPatternType.jagoSlash,
      accentGlow: Color(0x4DFF7A00),
    ),
    CardStyleDefinition(
      brand: RealisticCardBrand.jenius,
      displayName: 'Jenius (BTPN)',
      issuerTitle: 'm-Card',
      logoText: 'jenius',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF7A00), Color(0xFFE85D04), Color(0xFFC02600)],
      ),
      chipType: ChipType.silver,
      paymentNetwork: PaymentNetwork.visa,
      patternType: CardPatternType.cleanMinimal,
      accentGlow: Color(0x4DFF7A00),
    ),
    CardStyleDefinition(
      brand: RealisticCardBrand.seabank,
      displayName: 'SeaBank',
      issuerTitle: 'SeaBank Debit',
      logoText: 'SeaBank',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF5722), Color(0xFFE64A19), Color(0xFFBF360C)],
      ),
      chipType: ChipType.silver,
      paymentNetwork: PaymentNetwork.mastercard,
      patternType: CardPatternType.cleanMinimal,
      accentGlow: Color(0x4DFF5722),
    ),

    // 3. E-Wallet
    CardStyleDefinition(
      brand: RealisticCardBrand.dana,
      displayName: 'DANA E-Wallet',
      issuerTitle: 'DANA Balance',
      logoText: 'DANA',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF118EEA), Color(0xFF0C72BF), Color(0xFF00528F)],
      ),
      chipType: ChipType.none,
      paymentNetwork: PaymentNetwork.qris,
      patternType: CardPatternType.danaCurves,
      accentGlow: Color(0x4D118EEA),
    ),
    CardStyleDefinition(
      brand: RealisticCardBrand.gopay,
      displayName: 'GoPay',
      issuerTitle: 'GoPay Saldo',
      logoText: 'gopay',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF00AED6), Color(0xFF0089A8), Color(0xFF005F75)],
      ),
      chipType: ChipType.none,
      paymentNetwork: PaymentNetwork.qris,
      patternType: CardPatternType.gopayRing,
      accentGlow: Color(0x4D00AED6),
    ),
    CardStyleDefinition(
      brand: RealisticCardBrand.ovo,
      displayName: 'OVO',
      issuerTitle: 'OVO Cash',
      logoText: 'OVO',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF4C3494), Color(0xFF352070), Color(0xFF210F4D)],
      ),
      chipType: ChipType.none,
      paymentNetwork: PaymentNetwork.qris,
      patternType: CardPatternType.ovoCircles,
      accentGlow: Color(0x4D4C3494),
    ),
    CardStyleDefinition(
      brand: RealisticCardBrand.shopeepay,
      displayName: 'ShopeePay',
      issuerTitle: 'ShopeePay',
      logoText: 'ShopeePay',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFEE4D2D), Color(0xFFD63B1D), Color(0xFFA6250B)],
      ),
      chipType: ChipType.none,
      paymentNetwork: PaymentNetwork.qris,
      patternType: CardPatternType.cleanMinimal,
      accentGlow: Color(0x4DEE4D2D),
    ),
    CardStyleDefinition(
      brand: RealisticCardBrand.linkaja,
      displayName: 'LinkAja',
      issuerTitle: 'LinkAja Saldo',
      logoText: 'LinkAja!',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE21B24), Color(0xFFB81018), Color(0xFF82080E)],
      ),
      chipType: ChipType.none,
      paymentNetwork: PaymentNetwork.qris,
      patternType: CardPatternType.cleanMinimal,
      accentGlow: Color(0x4DE21B24),
    ),

    // 4. Tunai & Investasi
    CardStyleDefinition(
      brand: RealisticCardBrand.cash,
      displayName: 'Kas Tunai (Cash)',
      issuerTitle: 'DOMPET TUNAI',
      logoText: 'CASH',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1B4332), Color(0xFF133225), Color(0xFF081C15)],
      ),
      chipType: ChipType.none,
      paymentNetwork: PaymentNetwork.cash,
      patternType: CardPatternType.guillocheCash,
      accentGlow: Color(0x4D1B4332),
    ),
    CardStyleDefinition(
      brand: RealisticCardBrand.investment,
      displayName: 'Investasi / Portofolio',
      issuerTitle: 'PORTOFOLIO ASET',
      logoText: 'INVEST',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
      ),
      chipType: ChipType.gold,
      paymentNetwork: PaymentNetwork.none,
      patternType: CardPatternType.cleanMinimal,
      accentGlow: Color(0x4D203A43),
    ),
    CardStyleDefinition(
      brand: RealisticCardBrand.generic,
      displayName: 'Kartu Finansial Lainnya',
      issuerTitle: 'DEBIT CARD',
      logoText: 'MYFINANCE',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF374151), Color(0xFF1F2937), Color(0xFF111827)],
      ),
      chipType: ChipType.silver,
      paymentNetwork: PaymentNetwork.mastercard,
      patternType: CardPatternType.cleanMinimal,
      accentGlow: Color(0x4D374151),
    ),
  ];

  /// Mendeteksi gaya kartu terbaik berdasarkan Wallet
  static CardStyleDefinition resolveStyle(Wallet wallet) {
    final lowerName = wallet.name.toLowerCase().trim();

    // 1. Deteksi BCA
    if (lowerName.contains('bca') || lowerName.contains('paspor')) {
      if (lowerName.contains('gold')) {
        return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.bcaGold);
      }
      if (lowerName.contains('platinum') || lowerName.contains('black') || lowerName.contains('hitam')) {
        return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.bcaPlatinum);
      }
      if (lowerName.contains('blu')) {
        return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.bcaBlu);
      }
      return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.bcaBlue);
    }

    // 2. Deteksi Bank spesifik
    if (lowerName.contains('mandiri') || lowerName.contains('livin')) {
      return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.mandiri);
    }
    if (lowerName.contains('bni')) {
      return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.bni);
    }
    if (lowerName.contains('bri') || lowerName.contains('britama')) {
      return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.bri);
    }
    if (lowerName.contains('bsi') || lowerName.contains('syariah')) {
      return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.bsi);
    }
    if (lowerName.contains('cimb') || lowerName.contains('octo')) {
      return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.cimb);
    }
    if (lowerName.contains('jago')) {
      return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.jago);
    }
    if (lowerName.contains('jenius') || lowerName.contains('btpn')) {
      return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.jenius);
    }
    if (lowerName.contains('seabank') || lowerName.contains('sea bank')) {
      return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.seabank);
    }

    // 3. Deteksi E-Wallet
    if (lowerName.contains('dana')) {
      return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.dana);
    }
    if (lowerName.contains('gopay') || lowerName.contains('gojek')) {
      return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.gopay);
    }
    if (lowerName.contains('ovo')) {
      return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.ovo);
    }
    if (lowerName.contains('shopee')) {
      return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.shopeepay);
    }
    if (lowerName.contains('linkaja') || lowerName.contains('link aja')) {
      return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.linkaja);
    }

    // 4. Deteksi Tunai & Investasi
    if (wallet.type == WalletType.cash || lowerName.contains('tunai') || lowerName.contains('cash') || lowerName.contains('dompet')) {
      return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.cash);
    }
    if (lowerName.contains('bibit') || lowerName.contains('stockbit') || lowerName.contains('reksa') || lowerName.contains('saham') || lowerName.contains('invest')) {
      return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.investment);
    }

    // 5. Fallback berdasarkan tipe wallet
    switch (wallet.type) {
      case WalletType.bank:
        return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.bcaBlue);
      case WalletType.eWallet:
        return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.dana);
      case WalletType.cash:
        return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.cash);
      case WalletType.other:
        return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.generic);
    }
  }

  /// Menghasilkan 4 digit nomor kartu deterministik dari ID dompet
  static String getCardNumberSuffix(String walletId) {
    int sum = 0;
    for (int i = 0; i < walletId.length; i++) {
      sum = (sum * 31 + walletId.codeUnitAt(i)) % 9000;
    }
    final num = (sum.abs() + 1000).toString();
    return num.length >= 4 ? num.substring(0, 4) : '8398';
  }
}
