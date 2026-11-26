abstract class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => message;
}

class DatabaseFailure extends Failure {
  const DatabaseFailure([super.message = 'Terjadi kesalahan pada database lokal.']);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Data tidak ditemukan.']);
}

class InsufficientBalanceFailure extends Failure {
  const InsufficientBalanceFailure([super.message = 'Saldo wallet tidak mencukupi.']);
}

class DuplicateDataFailure extends Failure {
  const DuplicateDataFailure([super.message = 'Data sudah ada sebelumnya.']);
}

class SupabaseFailure extends Failure {
  final String? code;
  const SupabaseFailure(super.message, [this.code]);
}

class SupabaseConnectionFailure extends SupabaseFailure {
  const SupabaseConnectionFailure([super.message = 'Gagal terhubung ke Supabase Cloud.', super.code]);
}

class SupabaseAuthFailure extends SupabaseFailure {
  const SupabaseAuthFailure([super.message = 'Autentikasi Supabase bermasalah.', super.code]);
}

class SupabaseDatabaseFailure extends SupabaseFailure {
  const SupabaseDatabaseFailure([super.message = 'Terjadi kesalahan pada database Supabase.', super.code]);
}
