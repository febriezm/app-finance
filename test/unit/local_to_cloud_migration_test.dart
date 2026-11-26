import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myfinance/core/database/app_database.dart';
import 'package:myfinance/core/database/daos/app_settings_dao.dart';
import 'package:myfinance/core/errors/exceptions.dart';
import 'package:myfinance/features/migration/data/datasources/migration_remote_data_source.dart';
import 'package:myfinance/features/migration/data/repositories/migration_repository_impl.dart';
import 'package:myfinance/features/migration/domain/entities/migration_result.dart';

/// Fake MigrationRemoteDataSource yang mengemulasi Supabase PostgreSQL Cloud secara in-memory
class FakeMigrationRemoteDataSource implements MigrationRemoteDataSource {
  final List<Map<String, dynamic>> cloudCategories = [];
  final List<Map<String, dynamic>> cloudWallets = [];
  final List<Map<String, dynamic>> cloudTransactions = [];
  final List<Map<String, dynamic>> cloudAttachments = [];
  final List<Map<String, dynamic>> cloudBudgets = [];
  final List<Map<String, dynamic>> cloudLimits = [];
  final List<Map<String, dynamic>> cloudSettings = [];

  bool shouldThrowError = false;
  bool failOnTransactions = false;

  void _upsertById(List<Map<String, dynamic>> table, List<Map<String, dynamic>> rows) {
    for (final row in rows) {
      final id = row['id'];
      table.removeWhere((r) => r['id'] == id);
      table.add(Map<String, dynamic>.from(row));
    }
  }

  @override
  Future<void> upsertCategories(List<Map<String, dynamic>> rows) async {
    if (shouldThrowError) throw const SupabaseDatabaseException('Network timeout categories', '500');
    _upsertById(cloudCategories, rows);
  }

  @override
  Future<void> upsertWallets(List<Map<String, dynamic>> rows) async {
    if (shouldThrowError) throw const SupabaseDatabaseException('Network timeout wallets', '500');
    _upsertById(cloudWallets, rows);
  }

  @override
  Future<void> upsertTransactions(List<Map<String, dynamic>> rows) async {
    if (shouldThrowError || failOnTransactions) {
      throw const SupabaseDatabaseException('Network timeout transactions', 'PGRST_TIMEOUT');
    }
    _upsertById(cloudTransactions, rows);
  }

  @override
  Future<void> upsertAttachments(List<Map<String, dynamic>> rows) async {
    if (shouldThrowError) throw const SupabaseDatabaseException('Network timeout attachments', '500');
    _upsertById(cloudAttachments, rows);
  }

  @override
  Future<void> upsertBudgets(List<Map<String, dynamic>> rows) async {
    if (shouldThrowError) throw const SupabaseDatabaseException('Network timeout budgets', '500');
    for (final row in rows) {
      cloudBudgets.removeWhere((r) => r['user_id'] == row['user_id'] && r['month_key'] == row['month_key']);
      cloudBudgets.add(Map<String, dynamic>.from(row));
    }
  }

  @override
  Future<void> upsertBudgetLimits(List<Map<String, dynamic>> rows) async {
    if (shouldThrowError) throw const SupabaseDatabaseException('Network timeout limits', '500');
    for (final row in rows) {
      cloudLimits.removeWhere((r) => r['budget_id'] == row['budget_id'] && r['category_id'] == row['category_id']);
      cloudLimits.add(Map<String, dynamic>.from(row));
    }
  }

  @override
  Future<void> upsertSettings(List<Map<String, dynamic>> rows) async {
    if (shouldThrowError) throw const SupabaseDatabaseException('Network timeout settings', '500');
    for (final row in rows) {
      cloudSettings.removeWhere((r) => r['user_id'] == row['user_id'] && r['key'] == row['key']);
      cloudSettings.add(Map<String, dynamic>.from(row));
    }
  }

  @override
  Future<bool> checkHasCloudData(String userId) async {
    return cloudWallets.any((r) => r['user_id'] == userId) ||
        cloudTransactions.any((r) => r['user_id'] == userId);
  }

  @override
  Future<bool> checkCloudMigrationStatus(String userId) async {
    return cloudSettings.any((r) => r['user_id'] == userId && r['key'] == 'cloud_migration_status' && r['value'] == 'completed');
  }

  @override
  Future<void> markCloudMigrationCompleted(String userId, String nowIso) async {
    cloudSettings.removeWhere((r) => r['user_id'] == userId && r['key'] == 'cloud_migration_status');
    cloudSettings.add({
      'user_id': userId,
      'key': 'cloud_migration_status',
      'value': 'completed',
      'updated_at': nowIso,
    });
  }

  @override
  Future<Map<String, dynamic>> fetchVerificationData(String userId) async {
    return {
      'wallets': cloudWallets.where((r) => r['user_id'] == userId).toList(),
      'transactions': cloudTransactions.where((r) => r['user_id'] == userId).toList(),
      'budgets': cloudBudgets.where((r) => r['user_id'] == userId).toList(),
      'budgetLimits': cloudLimits.where((r) => r['user_id'] == userId).toList(),
      'customCategories': cloudCategories.where((r) => r['user_id'] == userId && r['is_system'] != true).toList(),
      'attachments': cloudAttachments.where((r) => r['user_id'] == userId).toList(),
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late AppSettingsDao appSettingsDao;
  late FakeMigrationRemoteDataSource fakeRemote;
  late MigrationRepositoryImpl migrationRepo;

  const currentUserId = 'user-migrasi-test-123';
  const otherUserId = 'user-intruder-456';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    appSettingsDao = db.appSettingsDao;
    fakeRemote = FakeMigrationRemoteDataSource();

    migrationRepo = MigrationRepositoryImpl(
      db: db,
      appSettingsDao: appSettingsDao,
      remoteDataSource: fakeRemote,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Local SQLite to Supabase Cloud Migration Tests', () {
    test('1. Test migration user dengan data kosong', () async {
      // 1. Cek apakah ada data lokal: SQLite baru hanya memiliki kategori sistem dan default settings
      final hasData = await migrationRepo.checkHasLocalData();
      expect(hasData, isFalse);

      // 2. Summary kosong
      final summary = await migrationRepo.getLocalDataSummary();
      expect(summary.hasData, isFalse);
      expect(summary.totalRecordsCount, equals(0));

      // 3. Jalankan migrasi: harus sukses dengan 0 record dan menandai selesai
      final result = await migrationRepo.migrateLocalToCloud(currentUserId);
      expect(result.status, equals(MigrationStatus.success));
      expect(result.migratedRecordsCount, equals(0));
      expect(result.isVerified, isTrue);

      // 4. Verifikasi status tersimpan
      final isMigrated = await migrationRepo.checkIsAlreadyMigrated(currentUserId);
      expect(isMigrated, isTrue);
    });

    test('2. Test migration dengan data existing', () async {
      // 1. Seed data lokal ke SQLite
      await db.into(db.walletsTable).insert(
            WalletsTableCompanion.insert(
              id: 'w-local-1',
              name: 'BCA Utama',
              type: 'bank',
              openingBalance: 10000000,
              openingDate: '2026-11-01T00:00:00.000Z',
              createdAt: '2026-11-01T00:00:00.000Z',
              updatedAt: '2026-11-01T00:00:00.000Z',
            ),
          );
      await db.into(db.walletsTable).insert(
            WalletsTableCompanion.insert(
              id: 'w-local-2',
              name: 'Dompet Tunai',
              type: 'cash',
              openingBalance: 500000,
              openingDate: '2026-11-01T00:00:00.000Z',
              createdAt: '2026-11-01T00:00:00.000Z',
              updatedAt: '2026-11-01T00:00:00.000Z',
            ),
          );

      await db.into(db.categoriesTable).insert(
            CategoriesTableCompanion.insert(
              id: 'cat-custom-kopi',
              name: 'Ngopi & Kafe',
              type: 'expense',
            ),
          );

      await db.into(db.transactionsTable).insert(
            TransactionsTableCompanion.insert(
              id: 'tx-1-expense',
              type: 'expense',
              amount: 50000,
              occurredAt: '2026-11-10T14:00:00.000Z',
              walletId: const Value('w-local-1'),
              categoryId: const Value('cat-custom-kopi'),
              merchant: const Value('Kedai Kopi'),
              createdAt: '2026-11-10T14:00:00.000Z',
              updatedAt: '2026-11-10T14:00:00.000Z',
            ),
          );

      await db.into(db.transactionsTable).insert(
            TransactionsTableCompanion.insert(
              id: 'tx-2-transfer',
              type: 'transfer',
              amount: 200000,
              occurredAt: '2026-11-12T10:00:00.000Z',
              walletId: const Value('w-local-1'),
              destinationWalletId: const Value('w-local-2'),
              createdAt: '2026-11-12T10:00:00.000Z',
              updatedAt: '2026-11-12T10:00:00.000Z',
            ),
          );

      await db.into(db.budgetsTable).insert(
            BudgetsTableCompanion.insert(
              id: 'b-nov-2026',
              monthKey: '2026-11',
              totalLimit: 5000000,
              createdAt: '2026-11-01T00:00:00.000Z',
              updatedAt: '2026-11-01T00:00:00.000Z',
            ),
          );

      // 2. Deteksi data lokal
      final hasData = await migrationRepo.checkHasLocalData();
      expect(hasData, isTrue);

      final summary = await migrationRepo.getLocalDataSummary();
      expect(summary.walletsCount, equals(2));
      expect(summary.customCategoriesCount, equals(1));
      expect(summary.transactionsCount, equals(2));
      expect(summary.budgetsCount, equals(1));
      expect(summary.totalOpeningBalance, equals(10500000));
      expect(summary.totalLedgerBalance, equals(10450000)); // 10.5jt - 50rb

      // 3. Jalankan migrasi
      final progressSteps = <String>[];
      final result = await migrationRepo.migrateLocalToCloud(
        currentUserId,
        onProgress: (p, s) => progressSteps.add(s),
      );

      expect(result.status, equals(MigrationStatus.success));
      expect(result.isVerified, isTrue);
      expect(result.migratedRecordsCount, equals(6));
      expect(progressSteps, isNotEmpty);

      // 4. Verifikasi data di cloud
      final cloudData = await fakeRemote.fetchVerificationData(currentUserId);
      expect((cloudData['wallets'] as List).length, equals(2));
      expect((cloudData['transactions'] as List).length, equals(2));
      expect((cloudData['customCategories'] as List).length, equals(1));
      expect((cloudData['budgets'] as List).length, equals(1));
    });

    test('3. Test migration gagal: Menangani error jaringan tanpa menghapus data lokal', () async {
      // 1. Seed data lokal
      await db.into(db.walletsTable).insert(
            WalletsTableCompanion.insert(
              id: 'w-fail-test',
              name: 'Dompet Gagal',
              type: 'cash',
              openingBalance: 300000,
              openingDate: '2026-11-01T00:00:00.000Z',
              createdAt: '2026-11-01T00:00:00.000Z',
              updatedAt: '2026-11-01T00:00:00.000Z',
            ),
          );
      await db.into(db.transactionsTable).insert(
            TransactionsTableCompanion.insert(
              id: 'tx-fail-1',
              type: 'expense',
              amount: 10000,
              occurredAt: '2026-11-01T00:00:00.000Z',
              walletId: const Value('w-fail-test'),
              createdAt: '2026-11-01T00:00:00.000Z',
              updatedAt: '2026-11-01T00:00:00.000Z',
            ),
          );

      // 2. Simulasikan cloud error pada step transaksi
      fakeRemote.failOnTransactions = true;

      // 3. Eksekusi migrasi
      final result = await migrationRepo.migrateLocalToCloud(currentUserId);
      expect(result.status, equals(MigrationStatus.failed));
      expect(result.errorMessage, contains('Network timeout transactions'));
      expect(result.isVerified, isFalse);

      // 4. Verifikasi status TIDAK ditandai selesai
      final isMigrated = await migrationRepo.checkIsAlreadyMigrated(currentUserId);
      expect(isMigrated, isFalse);

      // 5. Data lokal SQLite harus 100% AMAN dan utuh
      final localWallets = await db.select(db.walletsTable).get();
      expect(localWallets.length, equals(1));
      expect(localWallets.first.id, equals('w-fail-test'));
    });

    test('4. Test migration retry: Melanjutkan migrasi setelah kegagalan berhasil', () async {
      // 1. Seed data lokal
      await db.into(db.walletsTable).insert(
            WalletsTableCompanion.insert(
              id: 'w-retry-test',
              name: 'Dompet Retry',
              type: 'bank',
              openingBalance: 750000,
              openingDate: '2026-11-01T00:00:00.000Z',
              createdAt: '2026-11-01T00:00:00.000Z',
              updatedAt: '2026-11-01T00:00:00.000Z',
            ),
          );
      await db.into(db.transactionsTable).insert(
            TransactionsTableCompanion.insert(
              id: 'tx-retry-1',
              type: 'income',
              amount: 1500000,
              occurredAt: '2026-11-15T00:00:00.000Z',
              walletId: const Value('w-retry-test'),
              createdAt: '2026-11-15T00:00:00.000Z',
              updatedAt: '2026-11-15T00:00:00.000Z',
            ),
          );

      // 2. Upaya pertama: Error
      fakeRemote.failOnTransactions = true;
      final failResult = await migrationRepo.migrateLocalToCloud(currentUserId);
      expect(failResult.status, equals(MigrationStatus.failed));

      // 3. Upaya kedua (Retry): Error diatasi
      fakeRemote.failOnTransactions = false;
      final retryResult = await migrationRepo.migrateLocalToCloud(currentUserId);

      expect(retryResult.status, equals(MigrationStatus.success));
      expect(retryResult.isVerified, isTrue);

      final cloudData = await fakeRemote.fetchVerificationData(currentUserId);
      expect((cloudData['wallets'] as List).length, equals(1));
      expect((cloudData['transactions'] as List).length, equals(1));
    });

    test('5. Test duplicate prevention: Menjamin tidak terjadi duplikasi saat migrasi dijalankan ulang', () async {
      // 1. Seed data lokal
      await db.into(db.walletsTable).insert(
            WalletsTableCompanion.insert(
              id: 'w-dup-test',
              name: 'Dompet Unik',
              type: 'bank',
              openingBalance: 1000000,
              openingDate: '2026-11-01T00:00:00.000Z',
              createdAt: '2026-11-01T00:00:00.000Z',
              updatedAt: '2026-11-01T00:00:00.000Z',
            ),
          );

      // 2. Jalankan migrasi pertama
      await migrationRepo.migrateLocalToCloud(currentUserId);
      expect(fakeRemote.cloudWallets.length, equals(1));

      // 3. Jalankan migrasi kedua (misal: user retry / force migrate)
      await migrationRepo.migrateLocalToCloud(currentUserId);

      // 4. Record di cloud harus tetap 1 (tidak berlipat ganda)
      expect(fakeRemote.cloudWallets.length, equals(1));
      expect(fakeRemote.cloudWallets.first['id'], equals('w-dup-test'));
    });

    test('6. Test relation: Memverifikasi integritas foreign key di Supabase Cloud', () async {
      // 1. Seed transfer dan dompet
      await db.into(db.walletsTable).insert(
            WalletsTableCompanion.insert(
              id: 'w-source',
              name: 'Dompet Asal',
              type: 'bank',
              openingBalance: 2000000,
              openingDate: '2026-11-01T00:00:00.000Z',
              createdAt: '2026-11-01T00:00:00.000Z',
              updatedAt: '2026-11-01T00:00:00.000Z',
            ),
          );
      await db.into(db.walletsTable).insert(
            WalletsTableCompanion.insert(
              id: 'w-dest',
              name: 'Dompet Tujuan',
              type: 'cash',
              openingBalance: 100000,
              openingDate: '2026-11-01T00:00:00.000Z',
              createdAt: '2026-11-01T00:00:00.000Z',
              updatedAt: '2026-11-01T00:00:00.000Z',
            ),
          );
      await db.into(db.transactionsTable).insert(
            TransactionsTableCompanion.insert(
              id: 'tx-rel-transfer',
              type: 'transfer',
              amount: 500000,
              occurredAt: '2026-11-05T00:00:00.000Z',
              walletId: const Value('w-source'),
              destinationWalletId: const Value('w-dest'),
              createdAt: '2026-11-05T00:00:00.000Z',
              updatedAt: '2026-11-05T00:00:00.000Z',
            ),
          );

      // 2. Jalankan migrasi
      await migrationRepo.migrateLocalToCloud(currentUserId);

      // 3. Verifikasi di cloud
      final tx = fakeRemote.cloudTransactions.firstWhere((t) => t['id'] == 'tx-rel-transfer');
      expect(tx['wallet_id'], equals('w-source'));
      expect(tx['destination_wallet_id'], equals('w-dest'));
      expect(tx['wallet_id'], isNot(equals(tx['destination_wallet_id'])));

      // Pastikan kedua wallet referensi ada di cloud
      expect(fakeRemote.cloudWallets.any((w) => w['id'] == 'w-source'), isTrue);
      expect(fakeRemote.cloudWallets.any((w) => w['id'] == 'w-dest'), isTrue);
    });

    test('7. Test data integrity: Tanggal, nominal, dan saldo tetap presisi', () async {
      const occurredTime = '2026-11-18T16:45:30.123Z';
      const exactAmount = 1875450;

      await db.into(db.walletsTable).insert(
            WalletsTableCompanion.insert(
              id: 'w-integ',
              name: 'Dompet Presisi',
              type: 'bank',
              openingBalance: 5000000,
              openingDate: '2026-11-01T00:00:00.000Z',
              createdAt: '2026-11-01T00:00:00.000Z',
              updatedAt: '2026-11-01T00:00:00.000Z',
            ),
          );
      await db.into(db.transactionsTable).insert(
            TransactionsTableCompanion.insert(
              id: 'tx-integ',
              type: 'expense',
              amount: exactAmount,
              occurredAt: occurredTime,
              walletId: const Value('w-integ'),
              createdAt: occurredTime,
              updatedAt: occurredTime,
            ),
          );

      await migrationRepo.migrateLocalToCloud(currentUserId);

      final cloudTx = fakeRemote.cloudTransactions.firstWhere((t) => t['id'] == 'tx-integ');
      expect(cloudTx['amount'], equals(exactAmount));
      expect(cloudTx['occurred_at'], equals(occurredTime));
      expect(cloudTx['type'], equals('expense'));

      final isVerified = await migrationRepo.verifyMigration(currentUserId);
      expect(isVerified, isTrue);
    });

    test('8. Test migration completion: Status migrasi tersimpan dan terisolasi per user_id', () async {
      await db.into(db.walletsTable).insert(
            WalletsTableCompanion.insert(
              id: 'w-comp',
              name: 'Dompet Komplit',
              type: 'cash',
              openingBalance: 100000,
              openingDate: '2026-11-01T00:00:00.000Z',
              createdAt: '2026-11-01T00:00:00.000Z',
              updatedAt: '2026-11-01T00:00:00.000Z',
            ),
          );

      await migrationRepo.migrateLocalToCloud(currentUserId);

      // Verifikasi status selesai
      expect(await migrationRepo.checkIsAlreadyMigrated(currentUserId), isTrue);

      // User lain tidak boleh terpengaruh
      expect(await migrationRepo.checkIsAlreadyMigrated(otherUserId), isFalse);
    });

    test('9. Test rollback/recovery strategy: Data lokal SQLite tetap utuh sepanjang siklus hidup migrasi', () async {
      await db.into(db.walletsTable).insert(
            WalletsTableCompanion.insert(
              id: 'w-persist-check',
              name: 'Dompet Abadi SQLite',
              type: 'cash',
              openingBalance: 888000,
              openingDate: '2026-11-01T00:00:00.000Z',
              createdAt: '2026-11-01T00:00:00.000Z',
              updatedAt: '2026-11-01T00:00:00.000Z',
            ),
          );

      // 1. Eksekusi migrasi sukses
      await migrationRepo.migrateLocalToCloud(currentUserId);

      // 2. Data lokal di SQLite HARUS TETAP ADA dan TIDAK DIHAPUS (sebagai local backup)
      final localWalletsAfter = await db.select(db.walletsTable).get();
      expect(localWalletsAfter.length, equals(1));
      expect(localWalletsAfter.first.id, equals('w-persist-check'));
      expect(localWalletsAfter.first.name, equals('Dompet Abadi SQLite'));
    });
  });
}
