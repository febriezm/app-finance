import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:myfinance/features/transactions/domain/entities/transaction.dart';
import 'package:myfinance/features/transfers/domain/entities/transfer.dart';
import 'package:myfinance/features/transfers/domain/repositories/transfer_repository.dart';

/// State Controller untuk interaksi UI dengan domain Transfer
class TransferController extends StateNotifier<AsyncValue<void>> {
  final TransferRepository _repository;

  TransferController(this._repository) : super(const AsyncValue.data(null));

  /// Mencatat transaksi transfer baru
  Future<bool> createTransfer({
    required int amount,
    required DateTime occurredAt,
    required String sourceWalletId,
    String? destinationWalletId,
    String? merchant,
    String? description,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final transfer = Transfer(
        id: const Uuid().v4(),
        amount: amount,
        occurredAt: occurredAt.toUtc().toIso8601String(),
        sourceWalletId: sourceWalletId,
        destinationWalletId: destinationWalletId,
        merchant: merchant?.trim().isEmpty == true ? null : merchant?.trim(),
        description: description?.trim().isEmpty == true ? null : description?.trim(),
        notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
        source: 'manual',
        status: TransactionStatus.confirmed,
        createdAt: now,
        updatedAt: now,
      );
      await _repository.createTransfer(transfer);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Memperbarui informasi transfer
  Future<bool> updateTransfer(Transfer transfer) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateTransfer(transfer);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Membatalkan (void) transfer
  Future<bool> voidTransfer(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repository.voidTransfer(id);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  /// Menghapus transfer secara permanen
  Future<bool> deleteTransfer(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repository.deleteTransfer(id);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}
