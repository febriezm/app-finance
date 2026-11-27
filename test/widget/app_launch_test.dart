import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:myfinance/app/app.dart';
import 'package:myfinance/app/app_providers.dart';
import 'package:myfinance/core/database/app_database.dart';
import 'package:myfinance/features/auth/domain/entities/auth_user.dart';
import 'package:myfinance/features/settings/presentation/screens/settings_screen.dart';
import 'package:myfinance/features/profile/presentation/screens/profile_screen.dart';
import '../unit/auth_test.dart';

void main() {
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase inMemoryDb;

  setUp(() {
    inMemoryDb = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() {
    // In-memory db garbage collected
  });

  group('Full Cloud Supabase App Launch & Navigation Scenarios', () {
    testWidgets('Skenario 1: Aplikasi pertama kali dibuka tanpa sesi -> diarahkan ke LandingScreen & bisa navigasi ke Login/Daftar', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeAuth = FakeAuthRepository(); // unauthenticated

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(inMemoryDb),
            authRepositoryProvider.overrideWithValue(fakeAuth),
          ],
          child: const MyFinanceApp(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Memastikan user langsung diarahkan ke Landing Page
      expect(find.text('MyFinance'), findsWidgets);
      expect(find.text('Full Cloud Supabase & Ledger Invariance'), findsOneWidget);
      expect(find.text('Buku Besar Presisi'), findsOneWidget);
      expect(find.text('Mulai Sekarang'), findsOneWidget);
      expect(find.text('Sudah Memiliki Akun? Masuk'), findsOneWidget);

      // Klik Sudah Memiliki Akun? Masuk -> menuju ke LoginScreen
      await tester.tap(find.text('Sudah Memiliki Akun? Masuk'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Masuk ke MyFinance'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Kata Sandi'), findsOneWidget);
      expect(find.text('Masuk'), findsOneWidget);
      expect(find.text('Belum memiliki akun? '), findsOneWidget);
      expect(find.text('Daftar Sekarang'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Skenario 2: Sudah login sebelumnya -> otomatis langsung masuk ke Dashboard utama', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final loggedInUser = AuthUser(
        id: 'usr-cloud-999',
        email: 'user@myfinance.cloud',
        createdAt: DateTime(2026, 1, 1),
        emailConfirmedAt: DateTime(2026, 1, 1),
      );
      final fakeAuth = FakeAuthRepository(initialUser: loggedInUser);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(inMemoryDb),
            authRepositoryProvider.overrideWithValue(fakeAuth),
          ],
          child: const MyFinanceApp(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Memastikan langsung masuk ke Dashboard tanpa tertahan di Login
      expect(find.text('TOTAL SALDO BERSIH'), findsOneWidget);
      expect(find.text('Rp 0'), findsWidgets);

      // Verify Bottom Navigation Bar items: Home, Transaksi, Dompet, Profil
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Transaksi'), findsOneWidget);
      expect(find.text('Dompet'), findsOneWidget);
      expect(find.text('Profil'), findsOneWidget);
      expect(find.text('Laporan'), findsNothing); // Laporan dipindah ke Quick Action & Dashboard AppBar

      // Verify Laporan Keuangan icon button in Dashboard AppBar
      expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Skenario 3: Menu Pengaturan: Tampilan paling atas, Umum gabung mata uang & kategori, hilangkan MyFinance/profile/manajemen dompet/data', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final loggedInUser = AuthUser(
        id: 'usr-cloud-999',
        email: 'user@myfinance.cloud',
        createdAt: DateTime(2026, 1, 1),
      );
      final fakeAuth = FakeAuthRepository(initialUser: loggedInUser);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(inMemoryDb),
            authRepositoryProvider.overrideWithValue(fakeAuth),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Memastikan title Pengaturan ter-render
      expect(find.text('Pengaturan'), findsOneWidget);

      // 1. Tampilan & Tema paling atas
      expect(find.text('TAMPILAN & TEMA'), findsOneWidget);
      expect(find.text('Tema Aplikasi'), findsOneWidget);

      // 2. Umum disatukan dengan Mata Uang & Kategori
      expect(find.text('UMUM'), findsOneWidget);
      expect(find.text('Mata Uang Utama'), findsOneWidget);
      expect(find.text('Daftar Kategori'), findsOneWidget);
      expect(find.text('Format Wilayah & Bahasa'), findsOneWidget);

      // 3. Memastikan MyFinance app header, Profil, Manajemen Dompet, Manajemen Data DIHILANGKAN
      expect(find.text('Profil Pengguna'), findsNothing);
      expect(find.text('MANAJEMEN DOMPET'), findsNothing);
      expect(find.text('MANAJEMEN DATA'), findsNothing);
      expect(find.text('Status Cloud (Supabase)'), findsNothing);

      // 4. Memastikan fitur offline / local sqlite TIDAK ADA di Pengaturan
      expect(find.text('Cadangkan & Pulihkan (Backup & Restore)'), findsNothing);
      expect(find.text('Migrasi Data Lokal ke Cloud'), findsNothing);
      expect(find.text('100% Offline • Penyimpanan Lokal Privat'), findsNothing);
      expect(find.text('Jaminan Privasi Offline-First'), findsNothing);

      // 5. Keamanan & Privasi telah dipindahkan ke menu Profile (KEAMANAN & KREDENSIAL)
      expect(find.text('KEAMANAN & PRIVASI'), findsNothing);

      // 6. Test klik Daftar Kategori -> Sheet terbuka dan memuat kategori secara reaktif
      await tester.tap(find.text('Daftar Kategori'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Kategori Transaksi'), findsOneWidget);
      expect(find.text('Kategori Pengeluaran'), findsOneWidget);
      expect(find.text('Kategori Pemasukan'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Skenario 4: Menu Profil Pengguna minimalis, bersih, dan menampilkan data cloud', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final loggedInUser = AuthUser(
        id: 'usr-cloud-999-profile',
        email: 'hallo@cloud.com',
        createdAt: DateTime(2026, 1, 15),
      );
      final fakeAuth = FakeAuthRepository(initialUser: loggedInUser);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(inMemoryDb),
            authRepositoryProvider.overrideWithValue(fakeAuth),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Memastikan elemen profil ter-render
      expect(find.text('Profil Pengguna'), findsOneWidget);
      expect(find.text('hallo@cloud.com'), findsWidgets);
      expect(find.text('Sesi Cloud Aktif'), findsOneWidget);
      expect(find.text('INFORMASI AKUN'), findsOneWidget);
      expect(find.text('Nama Lengkap'), findsOneWidget);
      expect(find.text('Nomor Telepon'), findsOneWidget);
      // Memastikan ID Pengguna, Tipe Layanan, dan Proteksi Akses Data dihilangkan
      expect(find.text('ID Pengguna (UID)'), findsNothing);
      expect(find.text('Tipe Layanan'), findsNothing);
      expect(find.text('Proteksi Akses Data'), findsNothing);
      expect(find.text('PENYIMPANAN CLOUD'), findsOneWidget);
      expect(find.text('KEAMANAN & KREDENSIAL'), findsOneWidget);
      expect(find.text('Kunci Aplikasi'), findsOneWidget);
      expect(find.text('Keluar dari Akun'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Skenario 5: Navigasi bolak-balik Login <-> Register <-> ForgotPassword berfungsi mulus', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeAuth = FakeAuthRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(inMemoryDb),
            authRepositoryProvider.overrideWithValue(fakeAuth),
          ],
          child: const MyFinanceApp(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 0. Mulai dari Landing Page -> tap Sudah Memiliki Akun? Masuk
      expect(find.text('Sudah Memiliki Akun? Masuk'), findsOneWidget);
      await tester.tap(find.text('Sudah Memiliki Akun? Masuk'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 1. Berada di Login
      expect(find.text('Masuk ke MyFinance'), findsOneWidget);
      expect(find.text('Daftar Sekarang'), findsOneWidget);

      // 2. Klik Daftar Sekarang -> menuju ke Register
      await tester.tap(find.text('Daftar Sekarang'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Buat Akun Baru'), findsOneWidget);
      expect(find.text('Sudah memiliki akun? '), findsOneWidget);
      final registerMasukButton = find.widgetWithText(TextButton, 'Masuk');
      expect(registerMasukButton, findsOneWidget);

      // 3. Klik Masuk pada Register -> kembali ke Login
      await tester.tap(registerMasukButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Masuk ke MyFinance'), findsOneWidget);

      // 4. Klik Lupa kata sandi? -> menuju ke ForgotPassword
      await tester.tap(find.text('Lupa kata sandi?'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Lupa Kata Sandi'), findsOneWidget);
      expect(find.text('Kembali ke Masuk'), findsOneWidget);

      // 5. Klik Kembali ke Masuk pada ForgotPassword -> kembali ke Login
      await tester.tap(find.text('Kembali ke Masuk'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Masuk ke MyFinance'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    test('Skenario 6: Logout me-reset AppLock state dan membersihkan cache kredensial akun', () async {
      final loggedInUser = AuthUser(
        id: 'usr-cloud-lock-test',
        email: 'lock@myfinance.cloud',
        createdAt: DateTime(2026, 1, 1),
      );
      final fakeAuth = FakeAuthRepository(initialUser: loggedInUser);

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(inMemoryDb),
          authRepositoryProvider.overrideWithValue(fakeAuth),
        ],
      );
      addTearDown(container.dispose);

      // Verify lock controller initial
      expect(container.read(appLockControllerProvider).isAppLockEnabled, isFalse);

      // Sign out via authController
      await container.read(authControllerProvider.notifier).signOut();

      // Ensure user is signed out
      expect(container.read(authCurrentUserProvider), isNull);
      // Ensure lock is reset
      expect(container.read(appLockControllerProvider).isAppLockEnabled, isFalse);
      expect(container.read(appLockControllerProvider).isUnlocked, isTrue);
    });
  });
}
