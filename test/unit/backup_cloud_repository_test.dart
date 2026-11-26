import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import 'package:myfinance/app/app_providers.dart';
import 'package:myfinance/core/database/app_database.dart';
import 'package:myfinance/core/errors/exceptions.dart';
import 'package:myfinance/core/services/supabase_service.dart';
import 'package:myfinance/features/backup_restore/data/datasources/backup_remote_data_source.dart';
import 'package:myfinance/features/backup_restore/data/repositories/backup_repository_impl.dart';
import 'package:myfinance/features/backup_restore/data/services/backup_validator_service.dart';
import 'package:myfinance/features/backup_restore/domain/entities/backup_archive.dart';

/// Fake BackupRemoteDataSource yang mensimulasikan Supabase PostgreSQL Cloud dengan RLS
class FakeBackupRemoteDataSource implements BackupRemoteDataSource {
  final List<Map<String, dynamic>> cloudWallets = [];
  final List<Map<String, dynamic>> cloudCategories = [];
  final List<Map<String, dynamic>> cloudTransactions = [];
  final List<Map<String, dynamic>> cloudBudgets = [];
  final List<Map<String, dynamic>> cloudLimits = [];
  final List<Map<String, dynamic>> cloudAttachments = [];

  bool shouldThrowError = false;

  @override
  Future<BackupArchive> fetchBackupArchive(String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Network connection timeout', 'PGRST_TIMEOUT');
    }

    // RLS: WHERE user_id = :userId (categories: is_system = true OR user_id = :userId)
    final userWallets = cloudWallets.where((r) => r['user_id'] == userId).toList();
    final userCats = cloudCategories.where((r) => r['is_system'] == true || r['user_id'] == userId).toList();
    final userTxs = cloudTransactions.where((r) => r['user_id'] == userId).toList();
    final userBudgets = cloudBudgets.where((r) => r['user_id'] == userId).toList();
    final userLimits = cloudLimits.where((r) => r['user_id'] == userId).toList();
    final userAttachments = cloudAttachments.where((r) => r['user_id'] == userId).toList();

    return BackupArchive(
      schemaVersion: 1,
      appName: 'MyFinance',
      appVersion: '1.0.0',
      exportedAt: DateTime.now().toUtc().toIso8601String(),
      wallets: userWallets,
      categories: userCats,
      transactions: userTxs,
      budgets: userBudgets,
      budgetCategoryLimits: userLimits,
      transactionAttachments: userAttachments,
    );
  }

  @override
  Future<void> restoreBackupArchive(BackupArchive archive, String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Cloud restore failed', '500');
    }

    // 1. Reset user data in cloud
    await resetUserData(userId);

    // 2. Insert new user data in cloud
    for (final w in archive.wallets) {
      cloudWallets.add({
        ...w,
        'user_id': userId,
      });
    }

    for (final c in archive.categories) {
      if ((c['is_system'] ?? c['isSystem']) != true) {
        cloudCategories.add({
          ...c,
          'user_id': userId,
        });
      }
    }

    for (final t in archive.transactions) {
      cloudTransactions.add({
        ...t,
        'user_id': userId,
      });
    }

    for (final b in archive.budgets) {
      cloudBudgets.add({
        ...b,
        'user_id': userId,
      });
    }

    for (final l in archive.budgetCategoryLimits) {
      cloudLimits.add({
        ...l,
        'user_id': userId,
      });
    }

    for (final a in archive.transactionAttachments) {
      cloudAttachments.add({
        ...a,
        'user_id': userId,
      });
    }
  }

  @override
  Future<void> resetUserData(String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Cloud reset failed', '500');
    }

    cloudAttachments.removeWhere((r) => r['user_id'] == userId);
    cloudLimits.removeWhere((r) => r['user_id'] == userId);
    cloudBudgets.removeWhere((r) => r['user_id'] == userId);
    cloudTransactions.removeWhere((r) => r['user_id'] == userId);
    cloudCategories.removeWhere((r) => r['user_id'] == userId && r['is_system'] != true);
    cloudWallets.removeWhere((r) => r['user_id'] == userId);
  }

  @override
  Future<Map<String, int>> fetchRecordCounts(String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Cloud count failed', '500');
    }

    return {
      'wallets': cloudWallets.where((r) => r['user_id'] == userId).length,
      'categories': cloudCategories.where((r) => r['is_system'] == true || r['user_id'] == userId).length,
      'transactions': cloudTransactions.where((r) => r['user_id'] == userId).length,
      'budgets': cloudBudgets.where((r) => r['user_id'] == userId).length,
      'budgetCategoryLimits': cloudLimits.where((r) => r['user_id'] == userId).length,
      'transactionAttachments': cloudAttachments.where((r) => r['user_id'] == userId).length,
    };
  }
}

/// Fake SupabaseService untuk autentikasi user aktif
class FakeSupabaseService extends SupabaseService {
  final String _mockUserId;
  final bool _mockIsAuthenticated;

  FakeSupabaseService({
    String mockUserId = 'user-backup-owner-123',
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
  late FakeBackupRemoteDataSource fakeRemoteDataSource;
  late FakeSupabaseService fakeSupabaseService;
  late BackupRepositoryImpl hybridRepo;

  const currentUserId = 'user-backup-owner-123';
  const otherUserId = 'user-intruder-999';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    fakeRemoteDataSource = FakeBackupRemoteDataSource();
    fakeSupabaseService = FakeSupabaseService(
      mockUserId: currentUserId,
      mockIsAuthenticated: true,
    );

    hybridRepo = BackupRepositoryImpl(
      db,
      validatorService: const BackupValidatorService(),
      remoteDataSource: fakeRemoteDataSource,
      supabaseService: fakeSupabaseService,
    );

    // Seed mock cloud data untuk current user
    fakeRemoteDataSource.cloudWallets.add({
      'id': 'w-cloud-1',
      'user_id': currentUserId,
      'name': 'BCA Prioritas',
      'type': 'bank',
      'opening_balance': 25000000,
      'opening_date': '2026-11-01T00:00:00.000Z',
      'currency_code': 'IDR',
      'is_archived': false,
    });
    fakeRemoteDataSource.cloudWallets.add({
      'id': 'w-cloud-2',
      'user_id': currentUserId,
      'name': 'Dompet Kas Fisik',
      'type': 'cash',
      'opening_balance': 500000,
      'opening_date': '2026-11-01T00:00:00.000Z',
      'currency_code': 'IDR',
      'is_archived': false,
    });

    fakeRemoteDataSource.cloudCategories.add({
      'id': 'cat-food',
      'name': 'Makanan & Minuman',
      'type': 'expense',
      'is_system': true,
      'sort_order': 1,
    });
    fakeRemoteDataSource.cloudCategories.add({
      'id': 'cat-custom-hobi',
      'user_id': currentUserId,
      'name': 'Hobi & Fotografi',
      'type': 'expense',
      'is_system': false,
      'sort_order': 10,
    });

    fakeRemoteDataSource.cloudTransactions.add({
      'id': 'tx-cloud-1',
      'user_id': currentUserId,
      'type': 'expense',
      'amount': 75000,
      'occurred_at': '2026-11-20T12:00:00.000Z',
      'wallet_id': 'w-cloud-1',
      'category_id': 'cat-food',
      'merchant': 'Restoran Sedap',
      'source': 'manual',
      'status': 'confirmed',
    });

    fakeRemoteDataSource.cloudBudgets.add({
      'id': 'b-cloud-1',
      'user_id': currentUserId,
      'month_key': '2026-11',
      'total_limit': 10000000,
      'carry_over_enabled': false,
    });

    fakeRemoteDataSource.cloudLimits.add({
      'id': 'l-cloud-1',
      'user_id': currentUserId,
      'budget_id': 'b-cloud-1',
      'category_id': 'cat-food',
      'limit_amount': 3000000,
    });

    fakeRemoteDataSource.cloudAttachments.add({
      'id': 'att-cloud-1',
      'user_id': currentUserId,
      'transaction_id': 'tx-cloud-1',
      'storage_path': 'receipts/$currentUserId/att-cloud-1.jpg',
      'mime_type': 'image/jpeg',
      'file_size': 102400,
    });
  });

  tearDown(() async {
    await db.close();
  });

  group('Backup / Restore Cloud Repository Tests (Supabase PostgreSQL Integration)', () {
    test('1. Test load Backup / Restore: Mengambil arsip cadangan dari cloud untuk pengguna aktif', () async {
      final archive = await hybridRepo.getBackupArchive();

      expect(archive, isNotNull);
      expect(archive.wallets.length, equals(2));
      expect(archive.categories.length, equals(2));
      expect(archive.transactions.length, equals(1));
      expect(archive.budgets.length, equals(1));
      expect(archive.budgetCategoryLimits.length, equals(1));
      expect(archive.transactionAttachments.length, equals(1));
      expect(archive.totalRecordsCount, equals(8));
    });

    test('2. Test create Backup / Restore: Mengenerate berkas string JSON cadangan terstruktur', () async {
      final jsonString = await hybridRepo.exportBackupJson();

      expect(jsonString, isNotEmpty);
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      expect(decoded.containsKey('metadata'), isTrue);
      expect(decoded.containsKey('data'), isTrue);
      expect(decoded['metadata']['appName'], equals('MyFinance'));
      expect(decoded['metadata']['schemaVersion'], equals(1));
      expect(decoded['metadata']['totalRecords'], equals(8));
    });

    test('3. Test edit Backup / Restore: Memperbarui data pengguna dari arsip cadangan (updateFromArchive)', () async {
      // Modifikasi arsip dengan dompet baru
      final currentArchive = await hybridRepo.getBackupArchive();
      final updatedWallets = List<Map<String, dynamic>>.from(currentArchive.wallets)
        ..add({
          'id': 'w-cloud-3',
          'user_id': currentUserId,
          'name': 'Gojek Gopay',
          'type': 'e_wallet',
          'opening_balance': 250000,
          'opening_date': '2026-11-22T00:00:00.000Z',
          'currency_code': 'IDR',
          'is_archived': false,
        });

      final updatedArchive = BackupArchive(
        schemaVersion: 1,
        exportedAt: DateTime.now().toUtc().toIso8601String(),
        wallets: updatedWallets,
        categories: currentArchive.categories,
        transactions: currentArchive.transactions,
        budgets: currentArchive.budgets,
        budgetCategoryLimits: currentArchive.budgetCategoryLimits,
        transactionAttachments: currentArchive.transactionAttachments,
      );

      await hybridRepo.updateFromArchive(updatedArchive);

      // Verifikasi di cloud data bertambah
      final counts = await fakeRemoteDataSource.fetchRecordCounts(currentUserId);
      expect(counts['wallets'], equals(3));

      // Verifikasi di lokal SQLite juga tersinkron
      final localWallets = await db.select(db.walletsTable).get();
      expect(localWallets.length, equals(3));
      expect(localWallets.any((w) => w.id == 'w-cloud-3'), isTrue);
    });

    test('4. Test delete Backup / Restore: Mengosongkan data transaksi dan dompet di cloud dan lokal (resetAllData)', () async {
      await hybridRepo.resetAllData();

      // Cloud user data harus kosong (kecuali kategori sistem)
      final counts = await fakeRemoteDataSource.fetchRecordCounts(currentUserId);
      expect(counts['wallets'], equals(0));
      expect(counts['transactions'], equals(0));
      expect(counts['budgets'], equals(0));
      expect(counts['budgetCategoryLimits'], equals(0));
      expect(counts['transactionAttachments'], equals(0));

      // Lokal SQLite juga harus kosong
      final localWallets = await db.select(db.walletsTable).get();
      expect(localWallets.isEmpty, isTrue);
      final localTxs = await db.select(db.transactionsTable).get();
      expect(localTxs.isEmpty, isTrue);
    });

    test('5. Test Backup / Restore detail: Mengambil rincian jumlah record tiap domain (getBackupRecordCounts)', () async {
      final counts = await hybridRepo.getBackupRecordCounts();

      expect(counts['wallets'], equals(2));
      expect(counts['categories'], equals(2));
      expect(counts['transactions'], equals(1));
      expect(counts['budgets'], equals(1));
      expect(counts['budgetCategoryLimits'], equals(1));
      expect(counts['transactionAttachments'], equals(1));
    });

    test('6. Test Backup / Restore balance: Menghitung total seluruh record dan total saldo awal dompet arsip', () async {
      final totalRecords = await hybridRepo.getTotalRecordsCount();
      expect(totalRecords, equals(8));

      final archive = await hybridRepo.getBackupArchive();
      final totalBalance = hybridRepo.calculateArchiveTotalOpeningBalance(archive);
      // w-cloud-1: 25,000,000 + w-cloud-2: 500,000 = 25,500,000
      expect(totalBalance, equals(25500000));
    });

    test('7. Test Backup / Restore selection: Mengambil subset data cadangan berdasarkan jenis entitas', () async {
      final wallets = await hybridRepo.getBackupEntitiesByType('wallets');
      expect(wallets.length, equals(2));
      expect(wallets.first['name'], equals('BCA Prioritas'));

      final transactions = await hybridRepo.getBackupEntitiesByType('transactions');
      expect(transactions.length, equals(1));
      expect(transactions.first['merchant'], equals('Restoran Sedap'));

      final unknown = await hybridRepo.getBackupEntitiesByType('non_existent');
      expect(unknown.isEmpty, isTrue);
    });

    test('8. Test user ownership: Seluruh data yang disimpan atau dipulihkan terikat pada user_id pengguna aktif', () async {
      expect(hybridRepo.currentUserId, equals(currentUserId));

      final archive = await hybridRepo.getBackupArchive();
      for (final w in archive.wallets) {
        expect(w['user_id'], equals(currentUserId));
      }
      for (final t in archive.transactions) {
        expect(t['user_id'], equals(currentUserId));
      }
    });

    test('9. Test RLS: Mencegah kebocoran data pengguna lain saat export dan mencegah modifikasi data orang lain saat restore/reset', () async {
      // Masukkan data milik pengguna lain ke dalam tabel cloud
      fakeRemoteDataSource.cloudWallets.add({
        'id': 'w-other-user',
        'user_id': otherUserId,
        'name': 'Rekening Rahasia Orang Lain',
        'type': 'bank',
        'opening_balance': 999999999,
      });
      fakeRemoteDataSource.cloudTransactions.add({
        'id': 'tx-other-user',
        'user_id': otherUserId,
        'amount': 1000000,
        'type': 'income',
      });

      // 1. Ekspor cadangan user aktif tidak boleh mengandung data user lain
      final archive = await hybridRepo.getBackupArchive();
      expect(archive.wallets.any((w) => w['id'] == 'w-other-user'), isFalse);
      expect(archive.transactions.any((t) => t['id'] == 'tx-other-user'), isFalse);

      // 2. Reset data user aktif tidak boleh menghapus data user lain
      await hybridRepo.resetAllData();
      final otherWallets = fakeRemoteDataSource.cloudWallets.where((w) => w['user_id'] == otherUserId).toList();
      expect(otherWallets.length, equals(1));
      expect(otherWallets.first['id'], equals('w-other-user'));
    });

    test('10. Test error handling: Fallback ke cache SQLite lokal ketika cloud mengalami error/timeout jaringan', () async {
      // Seed data ke SQLite lokal
      await db.into(db.walletsTable).insert(
            WalletsTableCompanion.insert(
              id: 'w-local-offline',
              name: 'Dompet Offline',
              type: 'cash',
              openingBalance: 150000,
              openingDate: '2026-11-20T00:00:00.000Z',
              createdAt: '2026-11-20T00:00:00.000Z',
              updatedAt: '2026-11-20T00:00:00.000Z',
            ),
          );

      // Simulasikan cloud error/down
      fakeRemoteDataSource.shouldThrowError = true;

      // Pengambilan arsip cadangan harus tetap berhasil tanpa crash via fallback SQLite
      final fallbackArchive = await hybridRepo.getBackupArchive();
      expect(fallbackArchive, isNotNull);
      expect(fallbackArchive.wallets.any((w) => w['id'] == 'w-local-offline'), isTrue);
    });

    test('11. Test loading state: BackupRestoreController mengelola status loading dan pesan sukses/error secara tepat', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          backupRepositoryProvider.overrideWithValue(hybridRepo),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(backupRestoreControllerProvider.notifier);
      final initialState = container.read(backupRestoreControllerProvider);

      expect(initialState.isLoading, isFalse);
      expect(initialState.errorMessage, isNull);

      // Eksekusi reset data
      final success = await controller.resetAllData();
      expect(success, isTrue);

      final afterState = container.read(backupRestoreControllerProvider);
      expect(afterState.isLoading, isFalse);
      expect(afterState.successMessage, contains('berhasil direset'));
    });

    test('12. Test integration with controller & validation: Memvalidasi integritas JSON sebelum dipulihkan', () async {
      // 1. JSON valid
      final validArchive = await hybridRepo.getBackupArchive();
      final validJson = jsonEncode(validArchive.toJson());
      final validResult = hybridRepo.validateBackupJson(validJson);
      expect(validResult.isValid, isTrue);

      // 2. JSON rusak / invalid format
      const invalidJson = '{"metadata": {"schemaVersion": 1';
      final invalidResult = hybridRepo.validateBackupJson(invalidJson);
      expect(invalidResult.isValid, isFalse);
      expect(invalidResult.errorMessage, contains('Format JSON tidak valid'));

      // 3. Pelanggaran foreign key integritas (transaksi merujuk wallet yang tidak ada)
      final brokenFkJson = jsonEncode({
        'metadata': {'schemaVersion': 1, 'appName': 'MyFinance'},
        'data': {
          'wallets': [{'id': 'w-1', 'name': 'Tunai', 'type': 'cash'}],
          'categories': [{'id': 'c-1', 'name': 'Makan', 'type': 'expense'}],
          'transactions': [
            {
              'id': 'tx-broken',
              'type': 'expense',
              'amount': 50000,
              'wallet_id': 'w-non-existent', // Foreign key violation!
              'category_id': 'c-1',
            }
          ],
          'budgets': [],
          'budgetCategoryLimits': [],
          'transactionAttachments': [],
        },
      });

      final brokenResult = hybridRepo.validateBackupJson(brokenFkJson);
      expect(brokenResult.isValid, isFalse);
      expect(brokenResult.errorMessage, contains('Pelanggaran relasi integritas'));
    });
  });
}
