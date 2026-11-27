import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myfinance/features/auth/presentation/screens/landing_screen.dart';

void main() {
  Widget buildTestWidget({Size size = const Size(390, 844)}) {
    return ProviderScope(
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: const LandingScreen(),
        ),
      ),
    );
  }

  group('LandingScreen UI & Responsive Tests', () {
    testWidgets('Renders all modern elements: Brand Badge, PageView, Indicators, and Action Buttons', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Brand & Badges
      expect(find.text('my.'), findsOneWidget);
      expect(find.text('fin'), findsOneWidget);
      expect(find.text('MyFinance'), findsOneWidget);
      expect(find.text('Full Cloud Supabase & Ledger Invariance'), findsOneWidget);

      // Slide 0 Content
      expect(find.text('Buku Besar Presisi'), findsOneWidget);
      expect(find.text('Kelola Keuangan Pribadi\nJadi Lebih Teratur.'), findsOneWidget);

      // Buttons
      expect(find.text('Mulai Sekarang'), findsOneWidget);
      expect(find.text('Sudah Memiliki Akun? Masuk'), findsOneWidget);
      expect(find.text('Term of Use • Privacy & Cookies • Version 1.0.0'), findsOneWidget);

      // Top info icon button
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Tapping Info icon button opens modal sheet with details', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.info_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Tutup'), findsOneWidget);
      expect(find.text('Zero Rounding Error', skipOffstage: false), findsWidgets);

      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();

      expect(find.text('Tutup'), findsNothing);
    });

    testWidgets('Swiping PageView changes slide and updates category pill and headline', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Initially on Slide 0
      expect(find.text('Buku Besar Presisi'), findsOneWidget);

      // Drag left to Slide 1
      await tester.drag(find.text('Kelola Keuangan Pribadi\nJadi Lebih Teratur.'), const Offset(-300, 0));
      await tester.pumpAndSettle();

      // Slide 1 Content
      expect(find.text('Pemindai Struk OCR'), findsOneWidget);
      expect(find.text('Ekstraksi Struk Belanja\nOtomatis & Cepat.'), findsOneWidget);
    });

    testWidgets('Renders properly without overflow on small screens (320x568)', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(size: const Size(320, 568)));
      await tester.pumpAndSettle();

      expect(find.text('Mulai Sekarang'), findsOneWidget);
      expect(find.text('Sudah Memiliki Akun? Masuk'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
