import 'package:myfinance/features/transfers/domain/entities/transfer.dart';

/// Kontrak Repositori Domain Transfer
abstract class TransferRepository {
  /// Mengambil daftar riwayat transfer (terbaru)
  Future<List<Transfer>> getTransfers({int limit = 50});

  /// Stream daftar riwayat transfer secara reaktif (0 ms SQLite + Cloud Sync)
  Stream<List<Transfer>> watchTransfers({int limit = 50});

  /// Mengambil detail transfer berdasarkan ID
  Future<Transfer?> getTransferById(String id);

  /// Mencatat transaksi transfer baru
  Future<void> createTransfer(Transfer transfer);

  /// Memperbarui informasi transfer
  Future<void> updateTransfer(Transfer transfer);

  /// Membatalkan (void) transfer sehingga tidak lagi memengaruhi saldo buku besar
  Future<void> voidTransfer(String id);

  /// Menghapus transfer secara permanen
  Future<void> deleteTransfer(String id);

  /// Mengambil riwayat transfer yang melibatkan wallet tertentu (sebagai asal atau tujuan)
  Future<List<Transfer>> getTransfersForWallet(String walletId);

  /// Stream riwayat transfer untuk wallet tertentu
  Stream<List<Transfer>> watchTransfersForWallet(String walletId);

  /// Menghitung dampak total transfer pada saldo buku besar wallet:
  /// Total = Sum(Transfer Masuk) - Sum(Transfer Keluar)
  Future<int> calculateWalletTransferBalance(String walletId);
}
