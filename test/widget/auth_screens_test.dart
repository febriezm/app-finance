import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfinance/app/app_providers.dart';
import 'package:myfinance/features/auth/domain/repositories/auth_repository.dart';
import 'package:myfinance/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:myfinance/features/auth/presentation/screens/login_screen.dart';
import 'package:myfinance/features/auth/presentation/screens/register_screen.dart';
import '../unit/auth_test.dart';

Widget _buildTestApp(Widget child, {AuthRepository? authRepo}) {
  final repo = authRepo ?? FakeAuthRepository();
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

void main() {
  group('Auth UI Screens Widget Tests', () {
    testWidgets('LoginScreen renders UI elements and handles form validation', (tester) async {
      await tester.pumpWidget(_buildTestApp(const LoginScreen()));
      await tester.pumpAndSettle();

      // Memastikan elemen utama ter-render
      expect(find.text('Masuk ke MyFinance'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Kata Sandi'), findsOneWidget);
      expect(find.text('Masuk'), findsOneWidget);
      expect(find.text('Lupa kata sandi?'), findsOneWidget);
      expect(find.text('Daftar Sekarang'), findsOneWidget);

      // Tekan tombol Masuk tanpa mengisi form
      await tester.tap(find.text('Masuk'));
      await tester.pumpAndSettle();

      // Memastikan pesan validasi muncul
      expect(find.text('Email tidak boleh kosong'), findsOneWidget);
      expect(find.text('Kata sandi tidak boleh kosong'), findsOneWidget);
    });

    testWidgets('RegisterScreen renders UI elements and validates password match', (tester) async {
      await tester.pumpWidget(_buildTestApp(const RegisterScreen()));
      await tester.pumpAndSettle();

      // Memastikan elemen utama ter-render
      expect(find.text('Buat Akun Baru'), findsOneWidget);
      expect(find.text('Nama Lengkap'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Kata Sandi'), findsOneWidget);
      expect(find.text('Konfirmasi Kata Sandi'), findsOneWidget);
      expect(find.text('Daftar Akun'), findsOneWidget);

      // Isi form dengan kata sandi yang tidak cocok
      await tester.enterText(find.byType(TextFormField).at(0), 'Budi Investor');
      await tester.enterText(find.byType(TextFormField).at(1), 'test@example.com');
      // Password field
      await tester.enterText(find.byType(TextFormField).at(2), 'password123');
      // Confirm password field
      await tester.enterText(find.byType(TextFormField).at(3), 'mismatch456');

      await tester.ensureVisible(find.text('Daftar Akun'));
      await tester.tap(find.text('Daftar Akun'));
      await tester.pumpAndSettle();

      expect(find.text('Kata sandi tidak cocok'), findsOneWidget);
    });

    testWidgets('ForgotPasswordScreen renders UI elements and handles email validation', (tester) async {
      await tester.pumpWidget(_buildTestApp(const ForgotPasswordScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Lupa Kata Sandi'), findsOneWidget);
      expect(find.text('Email Terdaftar'), findsOneWidget);
      expect(find.text('Kirim Tautan Pemulihan'), findsOneWidget);

      await tester.tap(find.text('Kirim Tautan Pemulihan'));
      await tester.pumpAndSettle();

      expect(find.text('Email tidak boleh kosong'), findsOneWidget);
    });
  });
}
