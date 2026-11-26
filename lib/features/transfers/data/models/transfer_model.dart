import 'package:myfinance/core/database/app_database.dart';
import 'package:myfinance/features/transactions/domain/entities/transaction.dart';
import 'package:myfinance/features/transfers/domain/entities/transfer.dart';

class TransferModel {
  static Transfer fromEntry(TransactionEntry entry) {
    return Transfer(
      id: entry.id,
      amount: entry.amount,
      occurredAt: entry.occurredAt,
      sourceWalletId: entry.walletId ?? '',
      destinationWalletId: entry.destinationWalletId,
      merchant: entry.merchant,
      description: entry.description,
      notes: entry.notes,
      source: entry.source,
      status: TransactionStatus.fromString(entry.status),
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    );
  }
}
