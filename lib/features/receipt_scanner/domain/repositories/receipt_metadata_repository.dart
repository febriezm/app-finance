import 'dart:typed_data';
import '../entities/receipt_metadata.dart';

/// Kontrak repositori domain untuk operasi metadata dan berkas lampiran struk belanja
abstract interface class ReceiptMetadataRepository {
  /// Mengambil seluruh metadata lampiran struk milik user aktif
  Future<List<ReceiptMetadata>> getAllReceiptMetadata();

  /// Mengambil daftar lampiran struk untuk transaksi tertentu
  Future<List<ReceiptMetadata>> getReceiptMetadataForTransaction(String transactionId);

  /// Mengambil satu metadata lampiran struk berdasarkan ID
  Future<ReceiptMetadata?> getReceiptMetadataById(String id);

  /// Menyimpan metadata lampiran struk baru (dan opsional file biner ke cloud/lokal)
  Future<void> saveReceiptMetadata(ReceiptMetadata metadata, {Uint8List? imageBytes});

  /// Memperbarui metadata lampiran struk
  Future<void> updateReceiptMetadata(ReceiptMetadata metadata);

  /// Menghapus lampiran struk berdasarkan ID (termasuk file di storage jika ada)
  Future<void> deleteReceiptMetadata(String id);

  /// Menghitung total alokasi ukuran penyimpanan file lampiran (dalam bytes)
  Future<int> getTotalReceiptStorageBytes();

  /// Stream reaktif untuk memantau lampiran struk pada transaksi tertentu
  Stream<List<ReceiptMetadata>> watchReceiptMetadataForTransaction(String transactionId);

  /// Mengambil data biner berkas gambar struk untuk keperluan preview atau pemrosesan
  /// (Mengecek disk lokal terlebih dahulu, jika belum ada mengunduh dari Supabase Storage private bucket)
  Future<Uint8List?> getReceiptImageBytes(String storagePath);

  /// Menghasilkan URL bertanda tangan (Signed URL) berbatas waktu untuk akses berkas private di Supabase Storage
  Future<String?> getReceiptSignedUrl(String storagePath, {int expiresInSeconds = 3600});

  /// Mengunggah ulang berkas struk lokal yang gagal tersinkronisasi ke Supabase Storage (mekanisme retry)
  Future<bool> retryUploadReceiptImage(String id, Uint8List imageBytes);
}
