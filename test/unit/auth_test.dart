import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfinance/core/errors/exceptions.dart';
import 'package:myfinance/features/auth/domain/entities/auth_user.dart';
import 'package:myfinance/features/auth/domain/repositories/auth_repository.dart';
import 'package:myfinance/features/auth/presentation/controllers/auth_controller.dart';

/// Fake repository untuk pengujian unit autentikasi yang deterministik & cepat
class FakeAuthRepository implements AuthRepository {
  AuthUser? _user;
  final StreamController<AuthUser?> _authStreamController =
      StreamController<AuthUser?>.broadcast();

  FakeAuthRepository({AuthUser? initialUser}) : _user = initialUser;

  bool shouldThrowInvalidCredentials = false;
  bool shouldThrowUserExists = false;
  bool shouldRequireEmailConfirmation = false;
  bool shouldThrowNetworkError = false;

  void setMockUser(AuthUser? user) {
    _user = user;
    _authStreamController.add(_user);
  }

  @override
  AuthUser? get currentUser => _user;

  @override
  bool get isAuthenticated => _user != null;

  @override
  Stream<AuthUser?> get authStateChanges => _authStreamController.stream;

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    if (shouldThrowInvalidCredentials) {
      throw const SupabaseAuthException(
        'Email atau kata sandi tidak sesuai. Periksa kembali input Anda.',
        '400',
      );
    }
    if (shouldThrowNetworkError) {
      throw const SupabaseAuthException(
        'Tidak dapat terhubung ke server autentikasi. Periksa koneksi internet Anda.',
      );
    }

    final user = AuthUser(
      id: 'test-user-id-123',
      email: email,
      createdAt: DateTime.now(),
      emailConfirmedAt: DateTime.now(),
    );
    _user = user;
    _authStreamController.add(user);
    return user;
  }

  @override
  Future<AuthUser> signUp({
    required String email,
    required String password,
    String? name,
  }) async {
    if (shouldThrowUserExists) {
      throw const SupabaseAuthException(
        'Email ini sudah terdaftar. Silakan masuk atau gunakan fitur lupa kata sandi.',
        '422',
      );
    }

    final user = AuthUser(
      id: 'test-new-user-id',
      email: email,
      name: name,
      createdAt: DateTime.now(),
      emailConfirmedAt: shouldRequireEmailConfirmation ? null : DateTime.now(),
    );
    _user = user;
    _authStreamController.add(user);
    return user;
  }

  @override
  Future<AuthUser> updateProfile({
    String? name,
    String? phone,
  }) async {
    if (_user == null) {
      throw const SupabaseAuthException('Tidak ada pengguna yang masuk.');
    }
    final updated = _user!.copyWith(
      name: name ?? _user!.name,
      phone: phone ?? _user!.phone,
    );
    _user = updated;
    _authStreamController.add(updated);
    return updated;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _authStreamController.add(null);
  }

  @override
  Future<void> resetPasswordForEmail({
    required String email,
    String? redirectTo,
  }) async {
    if (shouldThrowNetworkError) {
      throw const SupabaseAuthException('Gagal mengirim email reset');
    }
  }

  @override
  Future<void> updatePassword({
    required String newPassword,
  }) async {
    if (shouldThrowNetworkError) {
      throw const SupabaseAuthException('Gagal memperbarui kata sandi');
    }
  }

  void dispose() {
    _authStreamController.close();
  }
}

void main() {
  late FakeAuthRepository fakeRepo;
  late AuthController controller;

  setUp(() {
    fakeRepo = FakeAuthRepository();
    controller = AuthController(authRepository: fakeRepo);
  });

  tearDown(() {
    controller.dispose();
    fakeRepo.dispose();
  });

  group('Supabase Auth MVP Tests', () {
    test('1. Test Register: Berhasil mendaftar dan memicu status konfirmasi email', () async {
      fakeRepo.shouldRequireEmailConfirmation = true;

      final success = await controller.signUp(
        email: 'investor@myfinance.id',
        password: 'securePassword123',
      );

      expect(success, isTrue);
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.user?.email, equals('investor@myfinance.id'));
      expect(controller.state.isConfirmationRequired, isTrue);
      expect(controller.state.successMessage, contains('verifikasi'));
      expect(controller.state.errorMessage, isNull);
    });

    test('1b. Test Register: Gagal ketika email sudah terdaftar', () async {
      fakeRepo.shouldThrowUserExists = true;

      final success = await controller.signUp(
        email: 'existing@myfinance.id',
        password: 'securePassword123',
      );

      expect(success, isFalse);
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.errorMessage, contains('sudah terdaftar'));
      expect(controller.state.user, isNull);
    });

    test('2. Test Login: Berhasil masuk dengan email dan password valid', () async {
      final success = await controller.signIn(
        email: 'user@myfinance.id',
        password: 'password123',
      );

      expect(success, isTrue);
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.isAuthenticated, isTrue);
      expect(controller.state.user?.email, equals('user@myfinance.id'));
      expect(controller.state.successMessage, contains('Berhasil masuk'));
      expect(controller.state.errorMessage, isNull);
    });

    test('3. Test Logout: Berhasil keluar dan membersihkan sesi authenticated', () async {
      // Login terlebih dahulu
      await controller.signIn(
        email: 'user@myfinance.id',
        password: 'password123',
      );
      expect(controller.state.isAuthenticated, isTrue);

      // Lakukan logout
      await controller.signOut();

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.isAuthenticated, isFalse);
      expect(controller.state.user, isNull);
      expect(fakeRepo.currentUser, isNull);
    });

    test('4. Test Invalid Credentials: Menampilkan pesan error spesifik dan tidak membuat sesi', () async {
      fakeRepo.shouldThrowInvalidCredentials = true;

      final success = await controller.signIn(
        email: 'wrong@myfinance.id',
        password: 'wrongPassword',
      );

      expect(success, isFalse);
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.isAuthenticated, isFalse);
      expect(controller.state.user, isNull);
      expect(controller.state.errorMessage, contains('tidak sesuai'));
    });

    test('5. Test Forgot Password: Mengirim tautan reset dan mengubah state isPasswordResetSent', () async {
      final success = await controller.sendPasswordReset(
        email: 'forgot@myfinance.id',
      );

      expect(success, isTrue);
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.isPasswordResetSent, isTrue);
      expect(controller.state.successMessage, contains('Tautan pemulihan'));
      expect(controller.state.errorMessage, isNull);
    });

    test('6. Test Session Persistence: Membaca currentUser yang sudah tersimpan saat inisialisasi', () {
      final existingUser = AuthUser(
        id: 'persisted-user-999',
        email: 'persisted@myfinance.id',
        createdAt: DateTime.now(),
        emailConfirmedAt: DateTime.now(),
      );
      fakeRepo.setMockUser(existingUser);

      // Inisialisasi controller baru dengan repositori yang sudah memiliki user aktif
      final freshController = AuthController(authRepository: fakeRepo);

      expect(freshController.state.isAuthenticated, isTrue);
      expect(freshController.state.user?.id, equals('persisted-user-999'));
      expect(freshController.state.user?.email, equals('persisted@myfinance.id'));

      freshController.dispose();
    });

    test('7. Test Authentication State: Stream listener bereaksi otomatis terhadap perubahan sesi', () async {
      expect(controller.state.user, isNull);

      final newUser = AuthUser(
        id: 'stream-user-777',
        email: 'stream@myfinance.id',
        createdAt: DateTime.now(),
        emailConfirmedAt: DateTime.now(),
      );

      // Simulasikan sign-in eksternal (misal lewat token refresh / tab lain)
      fakeRepo.setMockUser(newUser);

      // Beri sedikit delay untuk pengiriman event stream asynchronous
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller.state.user?.id, equals('stream-user-777'));
      expect(controller.state.user?.email, equals('stream@myfinance.id'));

      // Simulasikan session expired / sign-out
      fakeRepo.setMockUser(null);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller.state.user, isNull);
      expect(controller.state.isAuthenticated, isFalse);
    });

    test('8. Test Update Password: Berhasil memperbarui kata sandi baru', () async {
      final success = await controller.updatePassword(
        newPassword: 'BrandNewPassword123',
      );

      expect(success, isTrue);
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.successMessage, contains('berhasil diperbarui'));
      expect(controller.state.errorMessage, isNull);
    });
  });
}
