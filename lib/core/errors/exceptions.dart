class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}

class DatabaseException extends AppException {
  const DatabaseException([super.message = 'Terjadi kesalahan pada database SQLite.']);
}

class ValidationException extends AppException {
  const ValidationException(super.message);
}

class NotFoundException extends AppException {
  const NotFoundException([super.message = 'Data tidak ditemukan.']);
}

class SupabaseException extends AppException {
  final String? code;
  const SupabaseException(super.message, [this.code]);
}

class SupabaseConnectionException extends SupabaseException {
  const SupabaseConnectionException([super.message = 'Gagal terhubung ke Supabase Cloud.', super.code]);
}

class SupabaseAuthException extends SupabaseException {
  const SupabaseAuthException([super.message = 'Terjadi kesalahan otentikasi Supabase.', super.code]);
}

class SupabaseDatabaseException extends SupabaseException {
  const SupabaseDatabaseException([super.message = 'Terjadi kesalahan pada Supabase PostgreSQL.', super.code]);
}
