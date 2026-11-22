import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:myfinance/app/app_providers.dart';
import 'package:myfinance/core/database/app_database.dart';
import 'package:myfinance/features/wallets/domain/entities/wallet.dart';
import 'package:myfinance/features/wallets/presentation/screens/wallets_screen.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase inMemoryDb;

  setUp(() async {
    inMemoryDb = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await inMemoryDb.close();
  });

  Widget buildTestWidget({
    required List<WalletWithBalance> activeWallets,
    List<WalletWithBalance> archivedWallets = const [],
    Brightness brightness = Brightness.light,
  }) {
    final activeTotal = activeWallets.fold<int>(0, (sum, w) => sum + w.currentBalance);
    final archivedTotal = archivedWallets.fold<int>(0, (sum, w) => sum + w.currentBalance);
    final totalAll = activeTotal + archivedTotal;

    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(inMemoryDb),
        totalAllAssetBalanceProvider.overrideWith((ref) => totalAll),
        walletsWithBalanceStreamProvider.overrideWith(
          (ref) => Stream.value(activeWallets),
        ),
        archivedWalletsWithBalanceStreamProvider.overrideWith(
          (ref) => Stream.value(archivedWallets),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: const WalletsScreen(),
      ),
    );
  }

  group('WalletsScreen Dedicated Asset Balance Card Tests', () {
    testWidgets('Renders Dedicated Asset Balance Card as prominent focal point with total asset, breakdown, and wallet count', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime.now().toUtc().toIso8601String();
      final sampleBank = Wallet(
        id: 'w-bank',
        name: 'Bank BCA',
        type: WalletType.bank,
        openingBalance: 30000000,
        openingDate: now,
        createdAt: now,
        updatedAt: now,
      );
      final sampleCash = Wallet(
        id: 'w-cash',
        name: 'Dompet Tunai',
        type: WalletType.cash,
        openingBalance: 5000000,
        openingDate: now,
        createdAt: now,
        updatedAt: now,
      );
      final sampleEWallet = Wallet(
        id: 'w-gopay',
        name: 'GoPay',
        type: WalletType.eWallet,
        openingBalance: 2500000,
        openingDate: now,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(buildTestWidget(
        activeWallets: [
          WalletWithBalance(wallet: sampleBank, currentBalance: 30000000),
          WalletWithBalance(wallet: sampleCash, currentBalance: 5000000),
          WalletWithBalance(wallet: sampleEWallet, currentBalance: 2500000),
        ],
      ));
      await tester.pumpAndSettle();

      final cardFinder = find.byKey(const Key('dedicated_asset_balance_card'));
      expect(cardFinder, findsOneWidget);

      // Card Header
      expect(find.descendant(of: cardFinder, matching: find.text('TOTAL SALDO ASET')), findsOneWidget);
      expect(find.descendant(of: cardFinder, matching: find.byIcon(Icons.visibility_outlined)), findsOneWidget);
      expect(find.descendant(of: cardFinder, matching: find.text('3 Dompet Aktif')), findsOneWidget);

      // Hero Total Balance (30M + 5M + 2.5M = 37.5M)
      expect(find.descendant(of: cardFinder, matching: find.text('Rp 37.500.000')), findsOneWidget);

      // Compact Asset Breakdown
      // Kas & Bank (30M + 5M = 35M)
      expect(find.descendant(of: cardFinder, matching: find.text('Kas & Bank')), findsOneWidget);
      expect(find.descendant(of: cardFinder, matching: find.text('Rp 35.000.000')), findsOneWidget);

      // E-Wallet & Lainnya (2.5M)
      expect(find.descendant(of: cardFinder, matching: find.text('E-Wallet & Lainnya')), findsOneWidget);
      expect(find.descendant(of: cardFinder, matching: find.text('Rp 2.500.000')), findsOneWidget);
    });

    testWidgets('Toggling visibility hides and reveals asset nominals with masked dots', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime.now().toUtc().toIso8601String();
      final sampleBank = Wallet(
        id: 'w-bank',
        name: 'Bank Mandiri',
        type: WalletType.bank,
        openingBalance: 10000000,
        openingDate: now,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(buildTestWidget(
        activeWallets: [
          WalletWithBalance(wallet: sampleBank, currentBalance: 10000000),
        ],
      ));
      await tester.pumpAndSettle();

      final cardFinder = find.byKey(const Key('dedicated_asset_balance_card'));

      // Initially visible
      expect(find.descendant(of: cardFinder, matching: find.text('Rp 10.000.000')), findsNWidgets(2)); // Hero + Kas & Bank
      expect(find.descendant(of: cardFinder, matching: find.byIcon(Icons.visibility_outlined)), findsOneWidget);

      // Tap toggle button to hide balance
      await tester.tap(find.descendant(of: cardFinder, matching: find.byIcon(Icons.visibility_outlined)));
      await tester.pumpAndSettle();

      // Masked dots shown in card
      expect(find.descendant(of: cardFinder, matching: find.byIcon(Icons.visibility_off_outlined)), findsOneWidget);
      expect(find.descendant(of: cardFinder, matching: find.text('Rp ••••••••')), findsOneWidget);
      expect(find.descendant(of: cardFinder, matching: find.text('Rp ••••••')), findsNWidgets(2)); // Kas & Bank + E-Wallet
      expect(find.descendant(of: cardFinder, matching: find.text('Rp 10.000.000')), findsNothing);

      // Tap toggle button to restore balance
      await tester.tap(find.descendant(of: cardFinder, matching: find.byIcon(Icons.visibility_off_outlined)));
      await tester.pumpAndSettle();

      // Visible again
      expect(find.descendant(of: cardFinder, matching: find.byIcon(Icons.visibility_outlined)), findsOneWidget);
      expect(find.descendant(of: cardFinder, matching: find.text('Rp 10.000.000')), findsNWidgets(2));
    });

    testWidgets('Renders properly in Dark Mode and on narrow screens (320x568) without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime.now().toUtc().toIso8601String();
      final sampleBank = Wallet(
        id: 'w-bank',
        name: 'Bank Central Asia',
        type: WalletType.bank,
        openingBalance: 2500000000, // 2.5 Milyar
        openingDate: now,
        createdAt: now,
        updatedAt: now,
      );
      final sampleArchived = Wallet(
        id: 'w-old',
        name: 'Rekening Lama',
        type: WalletType.bank,
        openingBalance: 500000000, // 500 Juta
        openingDate: now,
        createdAt: now,
        updatedAt: now,
        isArchived: true,
      );

      await tester.pumpWidget(buildTestWidget(
        activeWallets: [
          WalletWithBalance(wallet: sampleBank, currentBalance: 2500000000),
        ],
        archivedWallets: [
          WalletWithBalance(wallet: sampleArchived, currentBalance: 500000000),
        ],
        brightness: Brightness.dark,
      ));
      await tester.pumpAndSettle();

      final cardFinder = find.byKey(const Key('dedicated_asset_balance_card'));
      expect(cardFinder, findsOneWidget);
      expect(find.descendant(of: cardFinder, matching: find.text('TOTAL SALDO ASET')), findsOneWidget);
      expect(find.descendant(of: cardFinder, matching: find.byIcon(Icons.visibility_outlined)), findsOneWidget);
      expect(find.descendant(of: cardFinder, matching: find.text('1 Aktif • 1 Arsip')), findsOneWidget);
      expect(find.descendant(of: cardFinder, matching: find.text('Rp 3.000.000.000')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
