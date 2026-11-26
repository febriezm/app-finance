/// Status tahapan proses migrasi data dari SQLite lokal ke Supabase PostgreSQL Cloud
enum MigrationStatus {
  idle,
  checking,
  promptReady,
  inProgress,
  success,
  failed,
  skipped,
}

/// Hasil eksekusi migrasi data lokal ke cloud
class MigrationResult {
  final MigrationStatus status;
  final String? errorMessage;
  final int migratedRecordsCount;
  final DateTime completedAt;
  final bool isVerified;

  const MigrationResult({
    required this.status,
    this.errorMessage,
    this.migratedRecordsCount = 0,
    required this.completedAt,
    this.isVerified = false,
  });

  bool get isSuccess => status == MigrationStatus.success;
  bool get isFailed => status == MigrationStatus.failed;
}
