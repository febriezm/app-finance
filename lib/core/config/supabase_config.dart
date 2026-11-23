import 'package:flutter/foundation.dart';

/// Konfigurasi Terpusat Supabase Cloud untuk MyFinance.
///
/// Keamanan:
/// - Hanya menggunakan Public Anon Key (Publishable Key).
/// - SECRET / SERVICE_ROLE KEY TIDAK BOLEH DISIMPAN DI CLIENT APLIKASI.
/// - Mendukung injeksi melalui compile-time environment `--dart-define`:
///   `flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co --dart-define=SUPABASE_ANON_KEY=ey...`
class SupabaseConfig {
  SupabaseConfig._();

  /// URL Supabase Cloud Project
  static const String _envUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');

  /// Publishable Anon Key Supabase
  static const String _envAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  /// Fallback demo/mock URL untuk pengujian unit & development offline
  static const String defaultFallbackUrl = 'https://myfinance-demo.supabase.co';

  /// Fallback demo/mock anon key format JWT standar
  static const String defaultFallbackAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im15ZmluYW5jZS1kZW1vIiwicm9sZSI6ImFub24iLCJpYXQiOjE2MDAwMDAwMDAsImV4cCI6MTkwMDAwMDAwMH0.mock_signature_for_local_testing';

  /// Mendapatkan URL aktif (dari environment atau fallback)
  static String get url => _envUrl.isNotEmpty ? _envUrl : defaultFallbackUrl;

  /// Mendapatkan Anon Key aktif (dari environment atau fallback)
  static String get anonKey => _envAnonKey.isNotEmpty ? _envAnonKey : defaultFallbackAnonKey;

  /// Memeriksa apakah Supabase URL dan Anon Key telah dikonfigurasi melalui environment riil
  static bool get isConfigured {
    if (_envUrl.isEmpty || _envAnonKey.isEmpty) {
      return false;
    }
    return _envUrl.startsWith('https://') &&
        !_envUrl.contains('myfinance-demo.supabase.co') &&
        _envAnonKey.length > 20;
  }

  /// URL tersensor untuk keperluan display aman di UI / log tanpa membuka detail sensitif
  static String get safeUrl {
    if (_envUrl.isEmpty) return 'Belum dikonfigurasi (Mode SQLite Lokal)';
    try {
      final uri = Uri.parse(_envUrl);
      final host = uri.host;
      if (host.length > 10) {
        return '${host.substring(0, 4)}...${host.substring(host.length - 6)}';
      }
      return host;
    } catch (_) {
      return 'Invalid URL';
    }
  }

  /// Status ringkas konfigurasi untuk diagnostik
  static void printDiagnostic() {
    if (kDebugMode) {
      debugPrint('[SupabaseConfig] Configured: $isConfigured');
      debugPrint('[SupabaseConfig] Target Host: $safeUrl');
    }
  }
}
