import 'package:flutter/material.dart';
import '../../domain/entities/wallet.dart';

/// Jenis / Brand kartu realistis yang didukung
enum RealisticCardBrand {
  bcaBlue, // BCA
  bcaGold, // Paspor BCA Gold
  bcaPlatinum, // Paspor BCA Platinum
  bcaBlu, // blu by BCA
  mandiri, // Bank Mandiri
  bni, // Bank BNI
  bri, // Bank BRI
  bsi, // Bank Syariah Indonesia
  btn, // Bank BTN
  cimb, // CIMB Niaga
  danamon, // Bank Danamon
  jago, // Bank Jago
  jenius, // Jenius BTPN
  ocbc, // Bank OCBC
  permata, // Permata Bank
  seabank, // SeaBank
  dana, // DANA E-Wallet
  gopay, // GoPay E-Wallet
  ovo, // OVO E-Wallet
  shopeepay, // ShopeePay
  linkaja, // LinkAja
  astrapay, // AstraPay E-Wallet
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
  final String? imageAsset;

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
    this.imageAsset,
  });
}

/// Helper pendeteksi otomatis tema kartu berdasarkan nama & tipe dompet
class CardThemeHelper {
  CardThemeHelper._();

  static const List<CardStyleDefinition> allPresets = [
    // 1. Bank Cards (Sesuai folder assets/kartu_bank)
    CardStyleDefinition(
      brand: RealisticCardBrand.bcaBlue,
      displayName: 'BCA',
      issuerTitle: 'Paspor Platinum',
      logoText: 'BCA',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF232B30), Color(0xFF14191C)],
      ),
      chipType: ChipType.silver,
      paymentNetwork: PaymentNetwork.mastercard,
      imageAsset: 'assets/kartu_bank/bank_bca.png',
      accentGlow: Color(0x4D0058A8),
    ),
    CardStyleDefinition(
      brand: RealisticCardBrand.mandiri,
      displayName: 'Mandiri',
      issuerTitle: 'Debit Platinum',
      logoText: 'Mandiri',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF4A5568), Color(0xFF1A202C)],
      ),
      chipType: ChipType.silver,
      paymentNetwork: PaymentNetwork.mastercard,
      imageAsset: 'assets/kartu_bank/bank_mandiri.png',
      accentGlow: Color(0x4D4A5568),
    ),
    CardStyleDefinition(
      brand: RealisticCardBrand.bni,
      displayName: 'BNI',
      issuerTitle: 'Debit Platinum',
      logoText: 'BNI',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2D3748), Color(0xFF1A202C)],
      ),
      chipType: ChipType.silver,
      paymentNetwork: PaymentNetwork.mastercard,
      imageAsset: 'assets/kartu_bank/bank_bni.png',
      accentGlow: Color(0x4DF15A24),
    ),
    CardStyleDefinition(
      brand: RealisticCardBrand.bri,
      displayName: 'BRI',
      issuerTitle: 'BritAma',
      logoText: 'BRI',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1A202C), Color(0xFF0F172A)],
      ),
      chipType: ChipType.silver,
      paymentNetwork: PaymentNetwork.mastercard,
      imageAsset: 'assets/kartu_bank/bank_bri.png',
      accentGlow: Color(0x4D00529B),
    ),
    CardStyleDefinition(
      brand: RealisticCardBrand.bsi,
      displayName: 'BSI',
      issuerTitle: 'Debit Platinum',
      logoText: 'BSI',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF334155), Color(0xFF1E293B)],
      ),
      chipType: ChipType.gold,
      paymentNetwork: PaymentNetwork.visa,
      imageAsset: 'assets/kartu_bank/bank_bsi.png',
      accentGlow: Color(0x4D00A39D),
    ),
    CardStyleDefinition(
      brand: RealisticCardBrand.btn,
      displayName: 'BTN',
      issuerTitle: 'Prioritas',
      logoText: 'BTN',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
      ),
      chipType: ChipType.gold,
      paymentNetwork: PaymentNetwork.visa,
      imageAsset: 'assets/kartu_bank/bank_btn.png',
      accentGlow: Color(0x4DB45309),
    ),
    CardStyleDefinition(
      brand: RealisticCardBrand.cimb,
      displayName: 'CIMB Niaga',
      issuerTitle: 'Preferred',
      logoText: 'CIMB',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF881337), Color(0xFF4C0519)],
      ),
      chipType: ChipType.gold,
      paymentNetwork: PaymentNetwork.mastercard,
      imageAsset: 'assets/kartu_bank/bank_cimb_niaga.png',
      accentGlow: Color(0x4DE11D48),
    ),
    CardStyleDefinition(
      brand: RealisticCardBrand.danamon,
      displayName: 'Danamon',
      issuerTitle: 'PayLight',
      logoText: 'Danamon',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1F2937), Color(0xFF111827)],
      ),
      chipType: ChipType.silver,
      paymentNetwork: PaymentNetwork.mastercard,
      imageAsset: 'assets/kartu_bank/bank_danamon.png',
      accentGlow: Color(0x4DF97316),
    ),
    CardStyleDefinition(
      brand: RealisticCardBrand.jago,
      displayName: 'Bank Jago',
      issuerTitle: 'Jago',
      logoText: 'jago',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF581C87), Color(0xFF18181B)],
      ),
      chipType: ChipType.none,
      paymentNetwork: PaymentNetwork.visa,
      imageAsset: 'assets/kartu_bank/bank_jago.png',
      accentGlow: Color(0x4DA855F7),
    ),
    CardStyleDefinition(
      brand: RealisticCardBrand.ocbc,
      displayName: 'OCBC',
      issuerTitle: 'Premier Banking',
      logoText: 'OCBC',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
      ),
      chipType: ChipType.silver,
      paymentNetwork: PaymentNetwork.mastercard,
      imageAsset: 'assets/kartu_bank/bank_ocbc.png',
      accentGlow: Color(0x4DEAB308),
    ),
    CardStyleDefinition(
      brand: RealisticCardBrand.permata,
      displayName: 'Permata',
      issuerTitle: 'Priority',
      logoText: 'Permata',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1C1917), Color(0xFF0C0A09)],
      ),
      chipType: ChipType.silver,
      paymentNetwork: PaymentNetwork.visa,
      imageAsset: 'assets/kartu_bank/bank_permata.png',
      accentGlow: Color(0x4DCA8A04),
    ),
    CardStyleDefinition(
      brand: RealisticCardBrand.seabank,
      displayName: 'SeaBank',
      issuerTitle: 'Debit',
      logoText: 'SeaBank',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFB923C), Color(0xFFEA580C)],
      ),
      chipType: ChipType.none,
      paymentNetwork: PaymentNetwork.mastercard,
      imageAsset: 'assets/kartu_bank/seabank.png',
      accentGlow: Color(0x4DF97316),
    ),

    // Bank Tambahan & Variasi BCA
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

    // 3. E-Wallet (GoPay, OVO, DANA, ShopeePay, LinkAja, AstraPay)
    CardStyleDefinition(
      brand: RealisticCardBrand.gopay,
      displayName: 'GoPay',
      issuerTitle: 'GoPay',
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
      issuerTitle: 'OVO',
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
      brand: RealisticCardBrand.dana,
      displayName: 'DANA',
      issuerTitle: 'DANA',
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
      issuerTitle: 'LinkAja',
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
    CardStyleDefinition(
      brand: RealisticCardBrand.astrapay,
      displayName: 'AstraPay',
      issuerTitle: 'AstraPay',
      logoText: 'AstraPay',
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF002C6C), Color(0xFF004394), Color(0xFF001838)],
      ),
      chipType: ChipType.none,
      paymentNetwork: PaymentNetwork.qris,
      patternType: CardPatternType.cleanMinimal,
      accentGlow: Color(0x4D004394),
    ),

    // 4. Tunai & Investasi
    CardStyleDefinition(
      brand: RealisticCardBrand.cash,
      displayName: 'Cash',
      issuerTitle: 'Cash',
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
    if (lowerName.contains('btn')) {
      return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.btn);
    }
    if (lowerName.contains('cimb') || lowerName.contains('octo')) {
      return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.cimb);
    }
    if (lowerName.contains('danamon')) {
      return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.danamon);
    }
    if (lowerName.contains('jago')) {
      return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.jago);
    }
    if (lowerName.contains('ocbc')) {
      return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.ocbc);
    }
    if (lowerName.contains('permata')) {
      return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.permata);
    }
    if (lowerName.contains('seabank') || lowerName.contains('sea bank')) {
      return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.seabank);
    }
    if (lowerName.contains('jenius') || lowerName.contains('btpn')) {
      return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.jenius);
    }

    // 3. Deteksi E-Wallet (GoPay, OVO, DANA, ShopeePay, LinkAja, AstraPay)
    if (lowerName.contains('gopay') || lowerName.contains('gojek')) {
      return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.gopay);
    }
    if (lowerName.contains('ovo')) {
      return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.ovo);
    }
    if (lowerName.contains('dana')) {
      return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.dana);
    }
    if (lowerName.contains('shopee')) {
      return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.shopeepay);
    }
    if (lowerName.contains('linkaja') || lowerName.contains('link aja')) {
      return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.linkaja);
    }
    if (lowerName.contains('astrapay') || lowerName.contains('astra pay')) {
      return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.astrapay);
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
        return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.gopay);
      case WalletType.cash:
        return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.cash);
      case WalletType.other:
        return allPresets.firstWhere((p) => p.brand == RealisticCardBrand.generic);
    }
  }

  /// Mengambil daftar templat kartu yang sesuai dengan WalletType
  static List<CardStyleDefinition> getPresetsForType(WalletType type) {
    switch (type) {
      case WalletType.bank:
        return allPresets.where((p) =>
          p.brand == RealisticCardBrand.bcaBlue ||
          p.brand == RealisticCardBrand.mandiri ||
          p.brand == RealisticCardBrand.bni ||
          p.brand == RealisticCardBrand.bri ||
          p.brand == RealisticCardBrand.bsi ||
          p.brand == RealisticCardBrand.btn ||
          p.brand == RealisticCardBrand.cimb ||
          p.brand == RealisticCardBrand.danamon ||
          p.brand == RealisticCardBrand.jago ||
          p.brand == RealisticCardBrand.ocbc ||
          p.brand == RealisticCardBrand.permata ||
          p.brand == RealisticCardBrand.seabank
        ).toList();

      case WalletType.eWallet:
        return [
          allPresets.firstWhere((p) => p.brand == RealisticCardBrand.gopay),
          allPresets.firstWhere((p) => p.brand == RealisticCardBrand.ovo),
          allPresets.firstWhere((p) => p.brand == RealisticCardBrand.dana),
          allPresets.firstWhere((p) => p.brand == RealisticCardBrand.shopeepay),
          allPresets.firstWhere((p) => p.brand == RealisticCardBrand.linkaja),
          allPresets.firstWhere((p) => p.brand == RealisticCardBrand.astrapay),
        ];

      case WalletType.cash:
        return allPresets.where((p) =>
          p.brand == RealisticCardBrand.cash
        ).toList();

      case WalletType.other:
        return allPresets.where((p) =>
          p.brand == RealisticCardBrand.investment ||
          p.brand == RealisticCardBrand.generic
        ).toList();
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
