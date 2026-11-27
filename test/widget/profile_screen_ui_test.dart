import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfinance/app/app_providers.dart';
import 'package:myfinance/features/auth/domain/entities/auth_user.dart';
import 'package:myfinance/features/profile/presentation/screens/profile_screen.dart';
import '../unit/auth_test.dart';

void main() {
  Widget buildTestWidget({AuthUser? user}) {
    final defaultUser = user ??
        AuthUser(
          id: 'test-user-123',
          email: 'bree@myfinance.app',
          name: 'Bree Zidaniro',
          phone: '+628123456789',
          createdAt: DateTime(2026, 1, 1),
          emailConfirmedAt: DateTime(2026, 1, 1),
        );

    final fakeAuth = FakeAuthRepository(initialUser: defaultUser);

    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(fakeAuth),
        totalReceiptStorageBytesProvider.overrideWith((ref) => Stream.value(1024 * 512)), // 512 KB
      ],
      child: const MaterialApp(
        home: ProfileScreen(),
      ),
    );
  }

  group('ProfileScreen User-Centric Tools & UI Tests', () {
    testWidgets('Renders essential user tools: Akun, Penyimpanan, Keamanan, Bantuan & Informasi', (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Header
      expect(find.text('Profil Pengguna'), findsOneWidget);
      expect(find.text('Bree Zidaniro'), findsWidgets);
      expect(find.text('bree@myfinance.app'), findsWidgets);
      expect(find.text('Akun Cloud Terverifikasi'), findsOneWidget);

      // Section 1: Informasi Akun
      expect(find.text('INFORMASI AKUN'), findsOneWidget);
      expect(find.text('Nama Lengkap'), findsOneWidget);
      expect(find.text('Alamat Email'), findsOneWidget);
      expect(find.text('Nomor Telepon'), findsOneWidget);
      expect(find.text('Member Sejak'), findsOneWidget);

      // Section 2: Penyimpanan Cloud
      expect(find.text('PENYIMPANAN CLOUD'), findsOneWidget);
      expect(find.text('Kapasitas Gambar Struk'), findsOneWidget);
      expect(find.text('512.0 KB'), findsOneWidget);
      expect(find.text('Bersihkan Cache Gambar'), findsOneWidget);

      // Section 3: Keamanan & Kredensial
      expect(find.text('KEAMANAN & KREDENSIAL'), findsOneWidget);
      expect(find.text('Kunci Aplikasi'), findsOneWidget);
      expect(find.text('Ubah Kata Sandi'), findsOneWidget);

      // Pastikan tools teknis database yang tidak dibutuhkan user sudah dihilangkan
      expect(find.text('PostgreSQL RLS terisolasi & TLS 1.3'), findsNothing);
      expect(find.text('ID Pengguna (UID)'), findsNothing);
      expect(find.text('Tipe Layanan'), findsNothing);
      expect(find.text('Proteksi Akses Data'), findsNothing);
    });

    testWidgets('Tapping Bersihkan Cache Gambar clears cache and shows snackbar', (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Bersihkan Cache Gambar'), 500);
      await tester.tap(find.text('Bersihkan Cache Gambar'));
      await tester.pumpAndSettle();

      expect(find.text('Cache pratinjau gambar berhasil dibersihkan.'), findsOneWidget);
    });

    testWidgets('Tapping Pusat Bantuan & FAQ opens help modal with questions', (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Pusat Bantuan & FAQ'), 500);
      await tester.tap(find.text('Pusat Bantuan & FAQ'));
      await tester.pumpAndSettle();

      expect(find.text('Pusat Bantuan & Tanya Jawab'), findsOneWidget);
      expect(find.text('Bagaimana cara memindai struk otomatis (OCR)?'), findsOneWidget);
    });

    testWidgets('Tapping Hubungi Dukungan opens support contact modal', (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Hubungi Dukungan'), 500);
      await tester.tap(find.text('Hubungi Dukungan'));
      await tester.pumpAndSettle();

      expect(find.text('Hubungi Dukungan Pengguna'), findsOneWidget);
      expect(find.text('support@myfinance.app'), findsOneWidget);
      expect(find.text('Salin Alamat Email'), findsOneWidget);
    });

    testWidgets('Tapping Tentang Aplikasi opens about modal', (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Tentang Aplikasi'), 200);
      await tester.drag(find.byType(ListView).first, const Offset(0, -200));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tentang Aplikasi'));
      await tester.pumpAndSettle();

      expect(find.text('MyFinance'), findsWidgets);
      expect(find.text('Versi 1.0.0 (Build 2026.11)'), findsOneWidget);
      expect(find.text('Tutup'), findsOneWidget);
    });
  });
}
