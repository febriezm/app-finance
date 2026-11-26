import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import 'package:myfinance/core/database/app_database.dart';
import 'package:myfinance/core/database/daos/app_settings_dao.dart';
import 'package:myfinance/core/errors/exceptions.dart';
import 'package:myfinance/core/services/app_lock_service.dart';
import 'package:myfinance/core/services/supabase_service.dart';
import 'package:myfinance/features/security/presentation/controllers/app_lock_controller.dart';
import 'package:myfinance/features/settings/domain/entities/app_setting.dart';
import 'package:myfinance/features/settings/data/datasources/settings_remote_data_source.dart';
import 'package:myfinance/features/settings/data/repositories/settings_repository_impl.dart';

/// Fake SettingsRemoteDataSource yang mensimulasikan Supabase PostgreSQL Cloud dengan RLS
class FakeSettingsRemoteDataSource implements SettingsRemoteDataSource {
  final Map<String, Map<String, dynamic>> cloudSettingsTable = {};
  bool shouldThrowError = false;

  @override
  Future<List<AppSetting>> getAllSettings(String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Network connection timeout', 'PGRST_TIMEOUT');
    }

    // RLS: WHERE user_id = :userId
    return cloudSettingsTable.values
        .where((row) => row['user_id'] == userId)
        .map(AppSetting.fromSupabaseMap)
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
  }

  @override
  Future<AppSetting?> getSetting(String key, String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Database query failed', '42P01');
    }

    final row = cloudSettingsTable['$userId-$key'];
    if (row == null || row['user_id'] != userId) return null;
    return AppSetting.fromSupabaseMap(row);
  }

  @override
  Future<void> upsertSetting(AppSetting setting, String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Upsert failed', '23505');
    }

    cloudSettingsTable['$userId-${setting.key}'] = setting.toSupabaseMap(userId);
  }

  @override
  Future<void> deleteSetting(String key, String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Delete failed', 'PGRST_DEL_ERR');
    }

    cloudSettingsTable.remove('$userId-$key');
  }

  @override
  Future<int> getSettingsCount(String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Count query failed', '500');
    }

    return cloudSettingsTable.values.where((row) => row['user_id'] == userId).length;
  }
}

/// Fake SupabaseService untuk autentikasi user aktif
class FakeSupabaseService extends SupabaseService {
  final String _mockUserId;
  final bool _mockIsAuthenticated;

  FakeSupabaseService({
    String mockUserId = 'user-settings-owner-123',
    bool mockIsAuthenticated = true,
  })  : _mockUserId = mockUserId,
        _mockIsAuthenticated = mockIsAuthenticated;

  @override
  bool get isAuthenticated => _mockIsAuthenticated;

  @override
  sp.User? get currentUser => _mockIsAuthenticated
      ? sp.User(
          id: _mockUserId,
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        )
      : null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late AppSettingsDao appSettingsDao;
  late FakeSettingsRemoteDataSource fakeRemoteDataSource;
  late FakeSupabaseService fakeSupabaseService;
  late SettingsRepositoryImpl hybridRepo;

  const currentUserId = 'user-settings-owner-123';
  const otherUserId = 'user-intruder-789';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    appSettingsDao = db.appSettingsDao;
    fakeRemoteDataSource = FakeSettingsRemoteDataSource();
    fakeSupabaseService = FakeSupabaseService(
      mockUserId: currentUserId,
      mockIsAuthenticated: true,
    );

    hybridRepo = SettingsRepositoryImpl(
      appSettingsDao,
      remoteDataSource: fakeRemoteDataSource,
      supabaseService: fakeSupabaseService,
    );

    // Seed mock cloud data untuk current user
    fakeRemoteDataSource.cloudSettingsTable['$currentUserId-theme_mode'] = {
      'user_id': currentUserId,
      'key': 'theme_mode',
      'value': 'dark',
      'updated_at': '2026-11-20T10:00:00.000Z',
    };
    fakeRemoteDataSource.cloudSettingsTable['$currentUserId-currency_code'] = {
      'user_id': currentUserId,
      'key': 'currency_code',
      'value': 'IDR',
      'updated_at': '2026-11-20T10:05:00.000Z',
    };
    fakeRemoteDataSource.cloudSettingsTable['$currentUserId-app_lock_enabled'] = {
      'user_id': currentUserId,
      'key': 'app_lock_enabled',
      'value': 'true',
      'updated_at': '2026-11-20T10:10:00.000Z',
    };
  });

  tearDown(() async {
    await db.close();
  });

  group('Settings Cloud Repository Tests (Supabase PostgreSQL Integration)', () {
    test('1. Test load Settings: Mengambil semua pengaturan dari cloud dan menyinkronkan ke SQLite lokal', () async {
      final list = await hybridRepo.getAllSettings();

      expect(list.length, equals(3));
      expect(list.map((e) => e.key), containsAll(['theme_mode', 'currency_code', 'app_lock_enabled']));

      // Verifikasi tersinkron ke SQLite lokal
      final localEntries = await appSettingsDao.getAllSettings();
      expect(localEntries.length, equals(3));
      expect(localEntries.map((e) => e.key), containsAll(['theme_mode', 'currency_code', 'app_lock_enabled']));
    });

    test('2. Test create Settings: Menyimpan pengaturan baru ke cloud dan lokal secara atomik', () async {
      await hybridRepo.setSetting('notifications_enabled', 'true');

      // Verifikasi di cloud
      final cloudRecord = fakeRemoteDataSource.cloudSettingsTable['$currentUserId-notifications_enabled'];
      expect(cloudRecord, isNotNull);
      expect(cloudRecord!['value'], equals('true'));
      expect(cloudRecord['user_id'], equals(currentUserId));

      // Verifikasi di lokal SQLite
      final localVal = await appSettingsDao.getSetting('notifications_enabled');
      expect(localVal, equals('true'));
    });

    test('3. Test edit Settings: Memperbarui nilai pengaturan yang ada di cloud dan lokal', () async {
      await hybridRepo.setSetting('theme_mode', 'light');

      // Verifikasi di cloud
      final cloudRecord = fakeRemoteDataSource.cloudSettingsTable['$currentUserId-theme_mode'];
      expect(cloudRecord!['value'], equals('light'));

      // Verifikasi di lokal SQLite
      final localVal = await appSettingsDao.getSetting('theme_mode');
      expect(localVal, equals('light'));
    });

    test('4. Test delete Settings: Menghapus pengaturan dari cloud dan lokal', () async {
      await hybridRepo.deleteSetting('app_lock_enabled');

      // Verifikasi di cloud
      expect(fakeRemoteDataSource.cloudSettingsTable.containsKey('$currentUserId-app_lock_enabled'), isFalse);

      // Verifikasi di lokal SQLite
      final localVal = await appSettingsDao.getSetting('app_lock_enabled');
      expect(localVal, isNull);
    });

    test('5. Test Settings detail: Mengambil detail satu entitas pengaturan (key, value, updatedAt)', () async {
      final detail = await hybridRepo.getSettingDetail('currency_code');

      expect(detail, isNotNull);
      expect(detail!.key, equals('currency_code'));
      expect(detail.value, equals('IDR'));
      expect(detail.updatedAt, equals('2026-11-20T10:05:00.000Z'));
    });

    test('6. Test Settings balance: Menghitung total entri konfigurasi tersimpan', () async {
      final count = await hybridRepo.getSettingsCount();
      expect(count, equals(3));

      await hybridRepo.setSetting('new_setting', '123');
      final newCount = await hybridRepo.getSettingsCount();
      expect(newCount, equals(4));
    });

    test('7. Test Settings selection: Mengambil nilai satu pengaturan berdasarkan key', () async {
      final theme = await hybridRepo.getSetting('theme_mode');
      expect(theme, equals('dark'));

      final nonExistent = await hybridRepo.getSetting('non_existent_key');
      expect(nonExistent, isNull);
    });

    test('8. Test user ownership: Pengaturan terikat pada user_id pengguna aktif', () async {
      expect(hybridRepo.currentUserId, equals(currentUserId));

      await hybridRepo.setSetting('locale', 'id_ID');
      final record = fakeRemoteDataSource.cloudSettingsTable['$currentUserId-locale'];
      expect(record!['user_id'], equals(currentUserId));
    });

    test('9. Test RLS: Mencegah akses ke pengaturan milik pengguna lain', () async {
      // Masukkan pengaturan milik pengguna lain
      fakeRemoteDataSource.cloudSettingsTable['$otherUserId-secret_token'] = {
        'user_id': otherUserId, // User lain!
        'key': 'secret_token',
        'value': 'confidential_12345',
        'updated_at': '2026-11-20T10:00:00.000Z',
      };

      // 1. getAllSettings tidak boleh menyertakan milik user lain
      final all = await hybridRepo.getAllSettings();
      expect(all.any((e) => e.key == 'secret_token'), isFalse);

      // 2. getSetting tidak boleh membaca milik user lain
      final secret = await hybridRepo.getSetting('secret_token');
      expect(secret, isNull);

      // 3. getSettingsCount tidak boleh menghitung entri orang lain
      final count = await hybridRepo.getSettingsCount();
      expect(count, equals(3));
    });

    test('10. Test error handling: Fallback ke cache SQLite lokal ketika cloud mengalami error/timeout', () async {
      // 1. Sinkronkan dulu data awal ke lokal
      await hybridRepo.getAllSettings();

      // 2. Simulasikan cloud error/down
      fakeRemoteDataSource.shouldThrowError = true;

      // 3. Baca setting: harus berhasil membaca dari SQLite lokal tanpa crash
      final fallbackVal = await hybridRepo.getSetting('theme_mode');
      expect(fallbackVal, equals('dark'));

      final fallbackList = await hybridRepo.getAllSettings();
      expect(fallbackList.length, equals(3));
    });

    test('11. Test loading state & stream: watchSetting memancarkan pembaruan nilai secara reaktif', () async {
      final stream = hybridRepo.watchSetting('theme_mode');

      // Update nilai
      await hybridRepo.setSetting('theme_mode', 'light');

      final emitted = await stream.first;
      expect(emitted, equals('light'));
    });

    test('12. Test integration with AppLockController: Mengelola status PIN dan App Lock via SettingsRepository', () async {
      final lockService = AppLockService();
      final controller = AppLockController(
        lockService: lockService,
        settingsRepository: hybridRepo,
      );

      // 1. Setup PIN 6-digit
      final success = await controller.setupPin('123456');
      expect(success, isTrue);
      expect(controller.state.hasPinSet, isTrue);
      expect(controller.state.isAppLockEnabled, isTrue);

      // Verifikasi tersimpan via SettingsRepository ke cloud & lokal
      final pinHashVal = await hybridRepo.getSetting(AppLockController.keyAppLockPinHash);
      expect(pinHashVal, isNotNull);
      expect(pinHashVal!.length, equals(64)); // SHA-256 hash 64 karakter

      final enabledVal = await hybridRepo.getSetting(AppLockController.keyAppLockEnabled);
      expect(enabledVal, equals('true'));

      // 2. Verifikasi PIN benar membuka kunci
      final unlockSuccess = await controller.unlockWithPin('123456');
      expect(unlockSuccess, isTrue);
      expect(controller.state.isUnlocked, isTrue);

      // 3. Verifikasi PIN salah gagal membuka kunci
      final wrongUnlock = await controller.unlockWithPin('999999');
      expect(wrongUnlock, isFalse);
      expect(controller.state.isUnlocked, isFalse);
    });
  });
}
