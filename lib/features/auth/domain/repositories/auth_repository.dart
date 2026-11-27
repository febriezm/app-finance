import 'dart:async';
import '../entities/auth_user.dart';

/// Kontrak Repository Autentikasi untuk MyFinance
abstract class AuthRepository {
  /// Mendaftarkan pengguna baru dengan email dan password serta nama opsional
  Future<AuthUser> signUp({
    required String email,
    required String password,
    String? name,
  });

  /// Masuk dengan email dan password
  Future<AuthUser> signIn({
    required String email,
    required String password,
  });

  /// Memperbarui data profil pengguna (nama, nomor telepon)
  Future<AuthUser> updateProfile({
    String? name,
    String? phone,
  });

  /// Keluar dari sesi pengguna
  Future<void> signOut();

  /// Mengirim tautan pemulihan kata sandi ke email pengguna
  Future<void> resetPasswordForEmail({
    required String email,
    String? redirectTo,
  });

  /// Memperbarui kata sandi pengguna yang sedang dalam sesi pemulihan/aktif
  Future<void> updatePassword({
    required String newPassword,
  });

  /// Pengguna yang sedang masuk saat ini (null jika belum login)
  AuthUser? get currentUser;

  /// Memeriksa apakah ada sesi aktif
  bool get isAuthenticated;

  /// Stream perubahan status autentikasi pengguna
  Stream<AuthUser?> get authStateChanges;
}
