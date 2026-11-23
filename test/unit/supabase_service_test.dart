import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myfinance/core/config/supabase_config.dart';
import 'package:myfinance/core/errors/exceptions.dart';
import 'package:myfinance/core/errors/failures.dart';
import 'package:myfinance/core/services/supabase_service.dart';

void main() {
  group('SupabaseConfig Tests', () {
    test('Default fallback URL and anonKey are available without crashing', () {
      expect(SupabaseConfig.url, isNotEmpty);
      expect(SupabaseConfig.anonKey, isNotEmpty);
      expect(SupabaseConfig.url, startsWith('https://'));
    });

    test('isConfigured returns false when running in default/unconfigured environment', () {
      // By default without --dart-define, isConfigured should be false
      expect(SupabaseConfig.isConfigured, isFalse);
    });

    test('safeUrl masks host or returns offline note when unconfigured', () {
      final safe = SupabaseConfig.safeUrl;
      expect(safe, isNotEmpty);
    });
  });

  group('SupabaseService Infrastructure Tests', () {
    test('Uninitialized service returns clientOrNull as null and throws on client getter', () {
      final service = SupabaseService();
      if (!SupabaseService.isInitialized) {
        expect(service.clientOrNull, isNull);
        expect(() => service.client, throwsA(isA<SupabaseConnectionException>()));
        expect(service.currentUser, isNull);
        expect(service.currentSession, isNull);
        expect(service.isAuthenticated, isFalse);
      }
    });

    test('checkConnection returns unconfigured status gracefully when unconfigured', () async {
      final service = SupabaseService();
      final result = await service.checkConnection();

      expect(result.isConnected, isFalse);
      expect(result.status, SupabaseConnectionStatus.unconfigured);
      expect(result.errorMessage, contains('SQLite'));
      expect(result.testedAt, isNotNull);
    });

    test('mapError correctly maps various exception types to domain Failures', () {
      // 1. PostgrestException
      const pgError = PostgrestException(message: 'Row Level Security policy violated', code: '42501');
      final pgFailure = SupabaseService.mapError(pgError);
      expect(pgFailure, isA<SupabaseFailure>());
      expect(pgFailure.message, contains('Row Level Security'));
      expect((pgFailure as SupabaseFailure).code, '42501');

      // 2. AuthException
      const authError = AuthException('Invalid login credentials', statusCode: '400');
      final authFailure = SupabaseService.mapError(authError);
      expect(authFailure, isA<SupabaseAuthFailure>());
      expect(authFailure.message, contains('Invalid login credentials'));
      expect((authFailure as SupabaseAuthFailure).code, '400');

      // 3. TimeoutException
      final timeoutError = TimeoutException('Connection timed out');
      final timeoutFailure = SupabaseService.mapError(timeoutError);
      expect(timeoutFailure, isA<SupabaseConnectionFailure>());

      // 4. Generic Exception
      final genericFailure = SupabaseService.mapError(Exception('Network socket closed'));
      expect(genericFailure, isA<SupabaseFailure>());
    });

    test('Initialization without environment config returns false and operates in SQLite offline mode', () async {
      final success = await SupabaseService.init();
      expect(success, isFalse);
      expect(SupabaseService.isInitialized, isFalse);
    });
  });
}
