import 'package:myfinance/features/transactions/domain/entities/transaction.dart';
import 'package:myfinance/features/transactions/domain/entities/transaction_with_details.dart';
import 'package:myfinance/features/wallets/domain/entities/wallet.dart';

/// Entitas Transfer Domain MyFinance
///
/// Mewakili mutasi pemindahan dana baik internal (antar dompet terdaftar)
/// maupun external (ke rekening/rekanan luar).
class Transfer {
  final String id;
  final int amount; // Satuan Rupiah penuh (> 0)
  final String occurredAt; // ISO-8601 UTC
  final String sourceWalletId;
  final String? destinationWalletId;
  final String? merchant;
  final String? description;
  final String? notes;
  final String source;
  final TransactionStatus status;
  final String createdAt;
  final String updatedAt;
  final Wallet? sourceWallet;
  final Wallet? destinationWallet;

  const Transfer({
    required this.id,
    required this.amount,
    required this.occurredAt,
    required this.sourceWalletId,
    this.destinationWalletId,
    this.merchant,
    this.description,
    this.notes,
    this.source = 'manual',
    this.status = TransactionStatus.confirmed,
    required this.createdAt,
    required this.updatedAt,
    this.sourceWallet,
    this.destinationWallet,
  });

  /// Menandakan apakah transfer ini ditujukan ke pihak luar (bukan internal antar dompet)
  bool get isExternal => destinationWalletId == null;

  /// Judul tampilan human-readable
  String get displayTitle {
    if (destinationWallet != null) {
      return 'Transfer ke ${destinationWallet!.name}';
    }
    if (merchant != null && merchant!.trim().isNotEmpty) {
      return 'Transfer ke ${merchant!.trim()}';
    }
    if (description != null && description!.trim().isNotEmpty) {
      return description!.trim();
    }
    return 'Transfer Dana';
  }

  /// Subtitle alur mutasi (Dompet Asal → Dompet Tujuan / Rekanan)
  String get displaySubtitle {
    final source = sourceWallet?.name ?? 'Dompet Asal';
    final dest = destinationWallet?.name ?? (merchant ?? 'Penerima Luar');
    return '$source → $dest';
  }

  /// Konversi ke entitas Transaction umum
  Transaction toTransaction() {
    return Transaction(
      id: id,
      type: TransactionType.transfer,
      amount: amount,
      occurredAt: occurredAt,
      walletId: sourceWalletId,
      destinationWalletId: destinationWalletId,
      categoryId: null,
      merchant: merchant,
      description: description,
      notes: notes,
      source: source,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Factory dari entitas Transaction
  factory Transfer.fromTransaction(
    Transaction tx, {
    Wallet? sourceWallet,
    Wallet? destinationWallet,
  }) {
    return Transfer(
      id: tx.id,
      amount: tx.amount,
      occurredAt: tx.occurredAt,
      sourceWalletId: tx.walletId ?? '',
      destinationWalletId: tx.destinationWalletId,
      merchant: tx.merchant,
      description: tx.description,
      notes: tx.notes,
      source: tx.source,
      status: tx.status,
      createdAt: tx.createdAt,
      updatedAt: tx.updatedAt,
      sourceWallet: sourceWallet,
      destinationWallet: destinationWallet,
    );
  }

  /// Factory dari TransactionWithDetails
  factory Transfer.fromTransactionWithDetails(TransactionWithDetails twd) {
    return Transfer(
      id: twd.transaction.id,
      amount: twd.transaction.amount,
      occurredAt: twd.transaction.occurredAt,
      sourceWalletId: twd.transaction.walletId ?? '',
      destinationWalletId: twd.transaction.destinationWalletId,
      merchant: twd.transaction.merchant,
      description: twd.transaction.description,
      notes: twd.transaction.notes,
      source: twd.transaction.source,
      status: twd.transaction.status,
      createdAt: twd.transaction.createdAt,
      updatedAt: twd.transaction.updatedAt,
      sourceWallet: twd.wallet,
      destinationWallet: twd.destinationWallet,
    );
  }

  Transfer copyWith({
    String? id,
    int? amount,
    String? occurredAt,
    String? sourceWalletId,
    String? destinationWalletId,
    String? merchant,
    String? description,
    String? notes,
    String? source,
    TransactionStatus? status,
    String? createdAt,
    String? updatedAt,
    Wallet? sourceWallet,
    Wallet? destinationWallet,
  }) {
    return Transfer(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      occurredAt: occurredAt ?? this.occurredAt,
      sourceWalletId: sourceWalletId ?? this.sourceWalletId,
      destinationWalletId: destinationWalletId ?? this.destinationWalletId,
      merchant: merchant ?? this.merchant,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      source: source ?? this.source,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sourceWallet: sourceWallet ?? this.sourceWallet,
      destinationWallet: destinationWallet ?? this.destinationWallet,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Transfer &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
