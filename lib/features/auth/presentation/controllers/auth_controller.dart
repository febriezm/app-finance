import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/app_providers.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// State representasi status autentikasi pengguna
class AuthState {
  final bool isLoading;
  final AuthUser? user;
  final String? errorMessage;
  final String? successMessage;
  final bool isConfirmationRequired;
  final bool isPasswordResetSent;

  const AuthState({
    this.isLoading = false,
    this.user,
    this.errorMessage,
    this.successMessage,
    this.isConfirmationRequired = false,
    this.isPasswordResetSent = false,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    bool? isLoading,
    AuthUser? user,
    bool clearUser = false,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
    bool? isConfirmationRequired,
    bool? isPasswordResetSent,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: clearUser ? null : (user ?? this.user),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      isConfirmationRequired: isConfirmationRequired ?? this.isConfirmationRequired,
      isPasswordResetSent: isPasswordResetSent ?? this.isPasswordResetSent,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthState &&
          runtimeType == other.runtimeType &&
          isLoading == other.isLoading &&
          user == other.user &&
          errorMessage == other.errorMessage &&
          successMessage == other.successMessage &&
          isConfirmationRequired == other.isConfirmationRequired &&
          isPasswordResetSent == other.isPasswordResetSent;

  @override
  int get hashCode =>
      isLoading.hashCode ^
      user.hashCode ^
      errorMessage.hashCode ^
      successMessage.hashCode ^
      isConfirmationRequired.hashCode ^
      isPasswordResetSent.hashCode;
}

/// Controller StateNotifier untuk fitur autentikasi MyFinance
class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final AppDatabase? _appDatabase;
  final Ref? _ref;
  StreamSubscription<AuthUser?>? _authStateSub;
  String? _lastUserId;

  AuthController({
    required AuthRepository authRepository,
    AppDatabase? appDatabase,
    Ref? ref,
  })  : _authRepository = authRepository,
        _appDatabase = appDatabase,
        _ref = ref,
        _lastUserId = authRepository.currentUser?.id,
        super(AuthState(user: authRepository.currentUser)) {
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authStateSub = _authRepository.authStateChanges.listen((user) async {
      final newUserId = user?.id;
      final userChanged = newUserId != _lastUserId;
      final isSwitchingUser = _lastUserId != null && newUserId != null && _lastUserId != newUserId;
      final isLoggingOut = _lastUserId != null && newUserId == null;
      _lastUserId = newUserId;

      // HANYA bersihkan database lokal jika pengguna berganti akun atau logout.
      // Jangan hapus data lokal jika pengguna baru pertama kali login dari mode offline,
      // agar data SQLite dapat ditawarkan untuk dimigrasikan ke akun cloud.
      if (isSwitchingUser || isLoggingOut) {
        try {
          await _appDatabase?.clearUserData();
        } catch (_) {}
        _invalidateDomainProviders();
      } else if (userChanged) {
        // User baru login: segarkan provider agar menggunakan session terautentikasi
        _invalidateDomainProviders();
      }

      if (mounted) {
        state = state.copyWith(
          user: user,
          clearUser: user == null,
        );
      }
    });
  }

  void _invalidateDomainProviders() {
    final ref = _ref;
    if (ref == null) return;
    ref.invalidate(walletRepositoryProvider);
    ref.invalidate(categoryRepositoryProvider);
    ref.invalidate(transactionRepositoryProvider);
    ref.invalidate(walletsStreamProvider);
    ref.invalidate(walletsWithBalanceStreamProvider);
    ref.invalidate(archivedWalletsWithBalanceStreamProvider);
    ref.invalidate(recentTransactionsStreamProvider);
    ref.invalidate(netOperationalBalanceProvider);
    ref.invalidate(totalAllAssetBalanceProvider);
    ref.invalidate(allCategoriesFutureProvider);
    ref.invalidate(selectedTransactionMonthProvider);
    ref.invalidate(selectedBudgetMonthProvider);
    try {
      ref.read(appLockControllerProvider.notifier).reset();
    } catch (_) {}
    ref.invalidate(settingsRepositoryProvider);
    ref.invalidate(appLockControllerProvider);
  }

  @override
  void dispose() {
    _authStateSub?.cancel();
    super.dispose();
  }

  /// Membersihkan pesan error dan sukses dari state
  void clearMessages() {
    state = state.copyWith(
      clearError: true,
      clearSuccess: true,
    );
  }

  /// Masuk dengan email dan password
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      final user = await _authRepository.signIn(
        email: email,
        password: password,
      );
      _lastUserId = user.id;
      try {
        await _appDatabase?.clearUserData();
      } catch (_) {}
      _invalidateDomainProviders();

      state = state.copyWith(
        isLoading: false,
        user: user,
        successMessage: 'Berhasil masuk.',
      );
      return true;
    } on SupabaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Terjadi kesalahan saat masuk: $e',
      );
      return false;
    }
  }

  /// Mendaftarkan pengguna baru dengan email dan password
  Future<bool> signUp({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
      isConfirmationRequired: false,
    );

    try {
      final user = await _authRepository.signUp(
        email: email,
        password: password,
      );

      final needsConfirm = !user.isEmailConfirmed;
      state = state.copyWith(
        isLoading: false,
        user: user,
        isConfirmationRequired: needsConfirm,
        successMessage: needsConfirm
            ? 'Akun berhasil dibuat! Silakan periksa inbox email Anda untuk verifikasi.'
            : 'Pendaftaran berhasil. Selamat datang di MyFinance!',
      );
      return true;
    } on SupabaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Terjadi kesalahan saat mendaftar: $e',
      );
      return false;
    }
  }

  /// Keluar dari sesi pengguna
  Future<void> signOut() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      await _authRepository.signOut();
      _lastUserId = null;
      try {
        await _appDatabase?.clearUserData();
      } catch (_) {}
      _invalidateDomainProviders();
      state = const AuthState();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal keluar: $e',
      );
    }
  }

  /// Mengirim permintaan reset password ke email
  Future<bool> sendPasswordReset({
    required String email,
    String? redirectTo,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
      isPasswordResetSent: false,
    );

    try {
      await _authRepository.resetPasswordForEmail(
        email: email,
        redirectTo: redirectTo,
      );
      state = state.copyWith(
        isLoading: false,
        isPasswordResetSent: true,
        successMessage: 'Tautan pemulihan kata sandi telah dikirim ke email Anda.',
      );
      return true;
    } on SupabaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal mengirim email reset: $e',
      );
      return false;
    }
  }

  /// Memperbarui kata sandi baru pengguna
  Future<bool> updatePassword({
    required String newPassword,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      await _authRepository.updatePassword(newPassword: newPassword);
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Kata sandi berhasil diperbarui. Silakan gunakan kata sandi baru untuk masuk.',
      );
      return true;
    } on SupabaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memperbarui kata sandi: $e',
      );
      return false;
    }
  }
}
