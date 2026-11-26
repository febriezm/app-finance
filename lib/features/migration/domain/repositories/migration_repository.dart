import '../entities/migration_result.dart';
import '../entities/migration_summary.dart';

abstract interface class MigrationRepository {
  /// Memeriksa apakah SQLite lokal berisi data pengguna yang bermakna (wallets, tx, budgets, custom cats)
  Future<bool> checkHasLocalData();

  /// Memeriksa apakah user cloud saat ini sudah pernah melakukan migrasi dari perangkat ini
  Future<bool> checkIsAlreadyMigrated(String userId);

  /// Memeriksa apakah user cloud saat ini sudah memiliki data finansial di cloud
  Future<bool> checkHasCloudData(String userId);

  /// Menghitung ringkasan data lokal yang siap dimigrasikan ke cloud
  Future<MigrationSummary> getLocalDataSummary();

  /// Menjalankan proses migrasi data dari SQLite lokal ke Supabase PostgreSQL Cloud
  Future<MigrationResult> migrateLocalToCloud(
    String userId, {
    void Function(double progress, String step)? onProgress,
  });

  /// Melakukan verifikasi konsistensi data antara SQLite lokal dan Supabase Cloud
  Future<bool> verifyMigration(String userId);

  /// Menandai status migrasi selesai pada app_settings lokal dan cloud
  Future<void> markMigrationCompleted(String userId);

  /// Menandai status migrasi dilewati (user memilih nanti)
  Future<void> skipMigration(String userId);
}
