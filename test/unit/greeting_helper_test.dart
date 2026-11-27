import 'package:flutter_test/flutter_test.dart';
import 'package:myfinance/core/formatting/date_formatter.dart';
import 'package:myfinance/core/utils/greeting_helper.dart';

void main() {
  group('GreetingHelper & Dynamic Greeting Unit Tests', () {
    test('Pukul 06:00 menghasilkan Selamat Pagi', () {
      final time = DateTime(2026, 11, 22, 6, 0);
      expect(GreetingHelper.getGreeting(time), equals('Selamat Pagi'));
      expect(AppDateFormatter.getGreeting(time), equals('Selamat Pagi'));
    });

    test('Pukul 12:00 menghasilkan Selamat Siang', () {
      final time = DateTime(2026, 11, 22, 12, 0);
      expect(GreetingHelper.getGreeting(time), equals('Selamat Siang'));
      expect(AppDateFormatter.getGreeting(time), equals('Selamat Siang'));
    });

    test('Pukul 16:00 menghasilkan Selamat Sore', () {
      final time = DateTime(2026, 11, 22, 16, 0);
      expect(GreetingHelper.getGreeting(time), equals('Selamat Sore'));
      expect(AppDateFormatter.getGreeting(time), equals('Selamat Sore'));
    });

    test('Pukul 21:00 menghasilkan Selamat Malam', () {
      final time = DateTime(2026, 11, 22, 21, 0);
      expect(GreetingHelper.getGreeting(time), equals('Selamat Malam'));
      expect(AppDateFormatter.getGreeting(time), equals('Selamat Malam'));
    });

    test('Pukul 00:00 (tengah malam) menghasilkan Selamat Malam', () {
      final time = DateTime(2026, 11, 22, 0, 0);
      expect(GreetingHelper.getGreeting(time), equals('Selamat Malam'));
      expect(AppDateFormatter.getGreeting(time), equals('Selamat Malam'));
    });

    test('Pukul 03:00 (dini hari) menghasilkan Selamat Malam', () {
      final time = DateTime(2026, 11, 22, 3, 0);
      expect(GreetingHelper.getGreeting(time), equals('Selamat Malam'));
      expect(AppDateFormatter.getGreeting(time), equals('Selamat Malam'));
    });

    test('Uji batas rentang (Boundary conditions)', () {
      // 03:59:59 -> Selamat Malam
      expect(GreetingHelper.getGreeting(DateTime(2026, 11, 22, 3, 59, 59)), equals('Selamat Malam'));

      // 04:00:00 -> Selamat Pagi (tepat batas pagi)
      expect(GreetingHelper.getGreeting(DateTime(2026, 11, 22, 4, 0, 0)), equals('Selamat Pagi'));

      // 10:59:59 -> Selamat Pagi (akhir batas pagi)
      expect(GreetingHelper.getGreeting(DateTime(2026, 11, 22, 10, 59, 59)), equals('Selamat Pagi'));

      // 11:00:00 -> Selamat Siang (tepat batas siang)
      expect(GreetingHelper.getGreeting(DateTime(2026, 11, 22, 11, 0, 0)), equals('Selamat Siang'));

      // 14:59:59 -> Selamat Siang (akhir batas siang)
      expect(GreetingHelper.getGreeting(DateTime(2026, 11, 22, 14, 59, 59)), equals('Selamat Siang'));

      // 15:00:00 -> Selamat Sore (tepat batas sore)
      expect(GreetingHelper.getGreeting(DateTime(2026, 11, 22, 15, 0, 0)), equals('Selamat Sore'));

      // 18:59:59 -> Selamat Sore (akhir batas sore)
      expect(GreetingHelper.getGreeting(DateTime(2026, 11, 22, 18, 59, 59)), equals('Selamat Sore'));

      // 19:00:00 -> Selamat Malam (tepat batas malam)
      expect(GreetingHelper.getGreeting(DateTime(2026, 11, 22, 19, 0, 0)), equals('Selamat Malam'));

      // 23:59:59 -> Selamat Malam (akhir batas malam hari ini)
      expect(GreetingHelper.getGreeting(DateTime(2026, 11, 22, 23, 59, 59)), equals('Selamat Malam'));
    });

    test('Uji durasi hingga periode berikutnya (durationUntilNextPeriod)', () {
      // Jika saat ini 10:55, batas berikutnya adalah 11:00 (5 menit + 1 detik)
      final at1055 = DateTime(2026, 11, 22, 10, 55, 0);
      final duration = GreetingHelper.durationUntilNextPeriod(at1055);
      expect(duration.inMinutes, equals(5));

      // Jika saat ini 14:30, batas berikutnya adalah 15:00 (30 menit + 1 detik)
      final at1430 = DateTime(2026, 11, 22, 14, 30, 0);
      final durationSiang = GreetingHelper.durationUntilNextPeriod(at1430);
      expect(durationSiang.inMinutes, equals(30));

      // Jika saat ini 23:00, batas berikutnya adalah 04:00 esok hari (5 jam + 1 detik)
      final at2300 = DateTime(2026, 11, 22, 23, 0, 0);
      final durationMalam = GreetingHelper.durationUntilNextPeriod(at2300);
      expect(durationMalam.inHours, equals(5));
    });

    test('Waktu UTC otomatis dikonversi ke waktu lokal perangkat', () {
      // Ambil waktu sekarang dalam UTC dan Local
      final nowUtc = DateTime.now().toUtc();
      final expectedGreeting = GreetingHelper.getGreeting(DateTime.now());
      // GreetingHelper.getGreeting(nowUtc) harus sama dengan expectedGreeting karena di-toLocal()
      expect(GreetingHelper.getGreeting(nowUtc), equals(expectedGreeting));
    });
  });
}
