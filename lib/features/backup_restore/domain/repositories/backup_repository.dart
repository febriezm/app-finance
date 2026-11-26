import '../entities/backup_archive.dart';
import '../entities/restore_validation_result.dart';

abstract interface class BackupRepository {
  /// Membuat arsip cadangan data seluruh database (Cloud jika aktif, fallback ke SQLite lokal)
  Future<BackupArchive> createBackup();

  /// Mengenerate berkas string JSON cadangan
  Future<String> exportBackupJson();

  /// Memvalidasi berkas cadangan JSON sebelum dipulihkan (syntax, schema, integritas FK)
  RestoreValidationResult validateBackupJson(String jsonString);

  /// Memulihkan database secara atomik dari data string JSON (transaksional SQLite & Cloud)
  Future<void> restoreFromJson(String jsonString);

  /// Mengosongkan data transaksi, dompet, anggaran, dan reset kategori bawaan (Danger Zone)
  Future<void> resetAllData();

  /// Mengambil arsip cadangan data pengguna saat ini (alias createBackup)
  Future<BackupArchive> getBackupArchive();

  /// Mengambil detail jumlah record per kategori/tabel cadangan
  Future<Map<String, int>> getBackupRecordCounts();

  /// Mengambil daftar subset entitas cadangan berdasarkan jenisnya ('wallets', 'categories', 'transactions', 'budgets', dll.)
  Future<List<Map<String, dynamic>>> getBackupEntitiesByType(String entityType);

  /// Menghitung total seluruh record dalam arsip cadangan
  Future<int> getTotalRecordsCount();

  /// Menghitung total saldo awal dompet dari arsip cadangan
  int calculateArchiveTotalOpeningBalance(BackupArchive archive);

  /// Memperbarui data pengguna dari entitas BackupArchive secara langsung
  Future<void> updateFromArchive(BackupArchive archive);
}
