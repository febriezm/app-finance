import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../errors/exceptions.dart';
import '../errors/failures.dart';

/// Status koneksi Supabase Cloud
enum SupabaseConnectionStatus {
  connected,
  unauthenticated,
  unconfigured,
  disconnected,
  error,
}

/// Hasil uji koneksi Supabase Cloud
class SupabaseConnectionResult {
  final bool isConnected;
  final SupabaseConnectionStatus status;
  final int latencyMs;
  final String? errorMessage;
  final String? userId;
  final DateTime testedAt;

  const SupabaseConnectionResult({
    required this.isConnected,
    required this.status,
    required this.latencyMs,
    this.errorMessage,
    this.userId,
    required this.testedAt,
  });

  factory SupabaseConnectionResult.notConfigured() {
    return SupabaseConnectionResult(
      isConnected: false,
      status: SupabaseConnectionStatus.unconfigured,
      latencyMs: 0,
      errorMessage: 'Supabase URL & Anon Key belum dikonfigurasi. Berjalan dalam mode SQLite lokal.',
      testedAt: DateTime.now(),
    );
  }

  factory SupabaseConnectionResult.success({
    required int latencyMs,
    String? userId,
  }) {
    return SupabaseConnectionResult(
      isConnected: true,
      status: SupabaseConnectionStatus.connected,
      latencyMs: latencyMs,
      userId: userId,
      testedAt: DateTime.now(),
    );
  }

  factory SupabaseConnectionResult.failure({
    required String errorMessage,
    int latencyMs = 0,
    SupabaseConnectionStatus status = SupabaseConnectionStatus.error,
  }) {
    return SupabaseConnectionResult(
      isConnected: false,
      status: status,
      latencyMs: latencyMs,
      errorMessage: errorMessage,
      testedAt: DateTime.now(),
    );
  }
}

/// Layanan terpusat Supabase Client untuk MyFinance.
///
/// Karakteristik:
/// - Mengisolasi akses Supabase dari komponen antarmuka (Widgets).
/// - Menyediakan inisialisasi yang tahan banting (graceful fallback ke SQLite jika offline/unconfigured).
/// - Mengelola siklus sesi autentikasi dan status koneksi secara reaktif.
class SupabaseService {
  static bool _isInitialized = false;

  /// Memeriksa apakah Supabase SDK telah berhasil diinisialisasi
  static bool get isInitialized => _isInitialized;

  /// Inisialisasi awal Supabase SDK pada peluncuran aplikasi (main.dart)
  static Future<bool> init({
    String? customUrl,
    String? customAnonKey,
  }) async {
    final url = customUrl ?? SupabaseConfig.url;
    final anonKey = customAnonKey ?? SupabaseConfig.anonKey;

    if (!SupabaseConfig.isConfigured && customUrl == null) {
      if (kDebugMode) {
        debugPrint('[SupabaseService] Belum dikonfigurasi. Aplikasi berjalan murni pada SQLite offline mode.');
      }
      _isInitialized = false;
      return false;
    }

    try {
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
        debug: kDebugMode,
      );
      _isInitialized = true;
      if (kDebugMode) {
        debugPrint('[SupabaseService] Berhasil diinisialisasi: ${SupabaseConfig.safeUrl}');
      }
      return true;
    } catch (e) {
      _isInitialized = false;
      if (kDebugMode) {
        debugPrint('[SupabaseService] Kendala inisialisasi (fallback ke SQLite): $e');
      }
      return false;
    }
  }

  /// Instance SupabaseClient aktif (hanya panggil saat isInitialized bernilai true)
  SupabaseClient get client {
    if (!_isInitialized) {
      throw const SupabaseConnectionException(
        'Supabase client belum diinisialisasi atau belum dikonfigurasi.',
      );
    }
    return Supabase.instance.client;
  }

  /// Instance SupabaseClient yang aman untuk pengecekan null
  SupabaseClient? get clientOrNull => _isInitialized ? Supabase.instance.client : null;

  /// Pengguna yang sedang login saat ini
  User? get currentUser => clientOrNull?.auth.currentUser;

  /// Sesi autentikasi yang sedang aktif saat ini
  Session? get currentSession => clientOrNull?.auth.currentSession;

  /// Memeriksa apakah terdapat sesi user aktif
  bool get isAuthenticated => currentUser != null;

  /// Stream perubahan status autentikasi Supabase
  Stream<AuthState> get authStateChanges {
    if (!_isInitialized) {
      return const Stream.empty();
    }
    return Supabase.instance.client.auth.onAuthStateChange;
  }

  /// Melakukan uji konektivitas yang aman ke Supabase Cloud
  Future<SupabaseConnectionResult> checkConnection() async {
    if (!_isInitialized || !SupabaseConfig.isConfigured) {
      return SupabaseConnectionResult.notConfigured();
    }

    final stopwatch = Stopwatch()..start();
    try {
      // Probe ringan ke PostgREST: membaca 1 baris kategori sistem (tanpa data sensitif)
      await client
          .from('categories')
          .select('id')
          .eq('is_system', true)
          .limit(1)
          .timeout(const Duration(seconds: 5));

      stopwatch.stop();
      return SupabaseConnectionResult.success(
        latencyMs: stopwatch.elapsedMilliseconds,
        userId: currentUser?.id,
      );
    } on TimeoutException {
      stopwatch.stop();
      return SupabaseConnectionResult.failure(
        errorMessage: 'Koneksi ke Supabase Cloud timed out (melebihi 5 detik).',
        latencyMs: stopwatch.elapsedMilliseconds,
        status: SupabaseConnectionStatus.disconnected,
      );
    } on PostgrestException catch (e) {
      stopwatch.stop();
      // Bila tabel belum dimigrasikan tetapi koneksi server tercapai
      if (e.code == '42P01') {
        return SupabaseConnectionResult.failure(
          errorMessage: 'Server Supabase terhubung, namun tabel belum dibuat (jalankan migrasi SQL).',
          latencyMs: stopwatch.elapsedMilliseconds,
          status: SupabaseConnectionStatus.connected,
        );
      }
      return SupabaseConnectionResult.failure(
        errorMessage: 'PostgREST error: ${e.message} (Kode: ${e.code})',
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      stopwatch.stop();
      return SupabaseConnectionResult.failure(
        errorMessage: 'Kendala jaringan/koneksi: $e',
        latencyMs: stopwatch.elapsedMilliseconds,
        status: SupabaseConnectionStatus.disconnected,
      );
    }
  }

  /// Masuk sebagai pengguna anonim (Anonymous Sign-In)
  Future<AuthResponse?> signInAnonymously() async {
    if (!_isInitialized) return null;
    try {
      return await client.auth.signInAnonymously();
    } on AuthException catch (e) {
      throw SupabaseAuthException(e.message, e.statusCode);
    } catch (e) {
      throw SupabaseAuthException('Gagal melakukan sign-in anonim: $e');
    }
  }

  /// Keluar dari sesi saat ini
  Future<void> signOut() async {
    if (!_isInitialized) return;
    try {
      await client.auth.signOut();
    } catch (e) {
      debugPrint('[SupabaseService] Sign out notice: $e');
    }
  }

  /// Mengonversi error Supabase menjadi domain Failure secara konsisten
  static Failure mapError(dynamic error) {
    if (error is PostgrestException) {
      return SupabaseFailure(error.message, error.code);
    } else if (error is AuthException) {
      return SupabaseAuthFailure(error.message, error.statusCode);
    } else if (error is TimeoutException) {
      return const SupabaseConnectionFailure('Koneksi ke server timeout.');
    } else {
      return SupabaseFailure(error.toString());
    }
  }
}
