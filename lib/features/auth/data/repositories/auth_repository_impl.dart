import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_service.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Implementasi AuthRepository menggunakan Supabase Auth (GoTrue SDK)
class AuthRepositoryImpl implements AuthRepository {
  final SupabaseService _supabaseService;

  AuthRepositoryImpl({
    required SupabaseService supabaseService,
  }) : _supabaseService = supabaseService;

  sp.SupabaseClient get _client => _supabaseService.client;

  @override
  AuthUser? get currentUser {
    final user = _supabaseService.currentUser;
    return user != null ? _mapSupabaseUserToAuthUser(user) : null;
  }

  @override
  bool get isAuthenticated => _supabaseService.isAuthenticated;

  @override
  Stream<AuthUser?> get authStateChanges {
    return _supabaseService.authStateChanges.map((authState) {
      final user = authState.session?.user;
      return user != null ? _mapSupabaseUserToAuthUser(user) : null;
    });
  }

  @override
  Future<AuthUser> signUp({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      final trimmedEmail = email.trim();
      final response = await _client.auth.signUp(
        email: trimmedEmail,
        password: password,
        data: name != null && name.trim().isNotEmpty
            ? {
                'name': name.trim(),
                'full_name': name.trim(),
              }
            : null,
      );

      final user = response.user;
      if (user == null) {
        throw const SupabaseAuthException('Pendaftaran gagal. Silakan coba beberapa saat lagi.');
      }

      return _mapSupabaseUserToAuthUser(user);
    } on sp.AuthException catch (e) {
      throw SupabaseAuthException(_mapAuthErrorMessage(e), e.statusCode);
    } catch (e) {
      if (e is SupabaseAuthException) rethrow;
      throw SupabaseAuthException('Terjadi kendala saat mendaftar: $e');
    }
  }

  @override
  Future<AuthUser> updateProfile({
    String? name,
    String? phone,
  }) async {
    try {
      final currentMeta = _client.auth.currentUser?.userMetadata ?? {};
      final updatedData = Map<String, dynamic>.from(currentMeta);
      if (name != null) {
        updatedData['name'] = name.trim();
        updatedData['full_name'] = name.trim();
      }
      if (phone != null) {
        updatedData['phone'] = phone.trim();
      }

      final response = await _client.auth.updateUser(
        sp.UserAttributes(
          data: updatedData,
        ),
      );

      final user = response.user;
      if (user == null) {
        throw const SupabaseAuthException('Gagal memperbarui profil pengguna.');
      }

      return _mapSupabaseUserToAuthUser(user);
    } on sp.AuthException catch (e) {
      throw SupabaseAuthException(_mapAuthErrorMessage(e), e.statusCode);
    } catch (e) {
      if (e is SupabaseAuthException) rethrow;
      throw SupabaseAuthException('Terjadi kendala saat memperbarui profil: $e');
    }
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final trimmedEmail = email.trim();
      final response = await _client.auth.signInWithPassword(
        email: trimmedEmail,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw const SupabaseAuthException('Gagal masuk. Periksa kembali email dan kata sandi Anda.');
      }

      return _mapSupabaseUserToAuthUser(user);
    } on sp.AuthException catch (e) {
      throw SupabaseAuthException(_mapAuthErrorMessage(e), e.statusCode);
    } catch (e) {
      if (e is SupabaseAuthException) rethrow;
      throw SupabaseAuthException('Terjadi kendala saat masuk: $e');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _supabaseService.signOut();
    } on sp.AuthException catch (e) {
      throw SupabaseAuthException(_mapAuthErrorMessage(e), e.statusCode);
    } catch (e) {
      debugPrint('[AuthRepositoryImpl] Gagal sign out: $e');
    }
  }

  @override
  Future<void> resetPasswordForEmail({
    required String email,
    String? redirectTo,
  }) async {
    try {
      final trimmedEmail = email.trim();
      await _client.auth.resetPasswordForEmail(
        trimmedEmail,
        redirectTo: redirectTo,
      );
    } on sp.AuthException catch (e) {
      throw SupabaseAuthException(_mapAuthErrorMessage(e), e.statusCode);
    } catch (e) {
      if (e is SupabaseAuthException) rethrow;
      throw SupabaseAuthException('Gagal mengirim email pemulihan: $e');
    }
  }

  @override
  Future<void> updatePassword({
    required String newPassword,
  }) async {
    try {
      await _client.auth.updateUser(
        sp.UserAttributes(password: newPassword),
      );
    } on sp.AuthException catch (e) {
      throw SupabaseAuthException(_mapAuthErrorMessage(e), e.statusCode);
    } catch (e) {
      if (e is SupabaseAuthException) rethrow;
      throw SupabaseAuthException('Gagal memperbarui kata sandi: $e');
    }
  }

  /// Memetakan Supabase User model ke domain AuthUser entity
  AuthUser _mapSupabaseUserToAuthUser(sp.User user) {
    final meta = user.userMetadata;
    final name = (meta?['name'] as String?) ?? (meta?['full_name'] as String?);
    final phone = (meta?['phone'] as String?) ?? (user.phone != null && user.phone!.isNotEmpty ? user.phone : null);
    return AuthUser(
      id: user.id,
      email: user.email ?? '',
      name: name,
      phone: phone,
      createdAt: DateTime.tryParse(user.createdAt),
      emailConfirmedAt: user.emailConfirmedAt != null
          ? DateTime.tryParse(user.emailConfirmedAt!)
          : null,
      userMetadata: meta,
    );
  }

  /// Menerjemahkan pesan error GoTrue/Supabase ke bahasa Indonesia yang ramah pengguna
  String _mapAuthErrorMessage(sp.AuthException e) {
    final msg = e.message.toLowerCase();
    final code = e.code?.toLowerCase() ?? '';

    if (code == 'invalid_credentials' ||
        msg.contains('invalid login credentials') ||
        msg.contains('invalid grant')) {
      return 'Email atau kata sandi tidak sesuai. Periksa kembali input Anda.';
    }
    if (code == 'email_not_confirmed' || msg.contains('email not confirmed')) {
      return 'Email belum dikonfirmasi. Silakan periksa inbox email Anda untuk verifikasi.';
    }
    if (code == 'user_already_exists' || msg.contains('already registered') || msg.contains('already in use')) {
      return 'Email ini sudah terdaftar. Silakan masuk atau gunakan fitur lupa kata sandi.';
    }
    if (msg.contains('password should be at least') || msg.contains('weak password')) {
      return 'Kata sandi terlalu pendek. Gunakan minimal 6 karakter.';
    }
    if (code == 'over_email_send_rate_limit' || msg.contains('rate limit')) {
      return 'Terlalu sering mengirim permintaan. Silakan tunggu beberapa saat lagi.';
    }
    if (msg.contains('network') || msg.contains('connection')) {
      return 'Tidak dapat terhubung ke server autentikasi. Periksa koneksi internet Anda.';
    }

    return e.message;
  }
}
