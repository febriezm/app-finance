import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/app_settings_dao.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_service.dart';
import '../../domain/entities/migration_result.dart';
import '../../domain/entities/migration_summary.dart';
import '../../domain/repositories/migration_repository.dart';
import '../datasources/migration_remote_data_source.dart';

class MigrationRepositoryImpl implements MigrationRepository {
  final AppDatabase _db;
  final AppSettingsDao _appSettingsDao;
  final MigrationRemoteDataSource? _remoteDataSource;
  final SupabaseService? _supabaseService;

  MigrationRepositoryImpl({
    required AppDatabase db,
    required AppSettingsDao appSettingsDao,
    MigrationRemoteDataSource? remoteDataSource,
    SupabaseService? supabaseService,
  })  : _db = db,
        _appSettingsDao = appSettingsDao,
        _remoteDataSource = remoteDataSource,
        _supabaseService = supabaseService;

  MigrationRemoteDataSource get _remote {
    if (_remoteDataSource != null) return _remoteDataSource;
    if (_supabaseService != null && _supabaseService.clientOrNull != null) {
      return MigrationRemoteDataSourceImpl(supabaseService: _supabaseService);
    }
    throw const SupabaseConnectionException(
      'Koneksi Supabase Cloud belum aktif untuk operasi migrasi data.',
    );
  }

  @override
  Future<bool> checkHasLocalData() async {
    final wallets = await _db.select(_db.walletsTable).get();
    final txs = await _db.select(_db.transactionsTable).get();
    final budgets = await _db.select(_db.budgetsTable).get();
    final customCats = await (_db.select(_db.categoriesTable)..where((c) => c.isSystem.equals(false))).get();

    return wallets.isNotEmpty || txs.isNotEmpty || budgets.isNotEmpty || customCats.isNotEmpty;
  }

  @override
  Future<bool> checkIsAlreadyMigrated(String userId) async {
    final status = await _appSettingsDao.getSetting('cloud_migration_status');
    final migratedUserId = await _appSettingsDao.getSetting('cloud_migration_user_id');

    if (status == 'completed' && migratedUserId == userId) {
      return true;
    }

    // Periksa juga di cloud jika user pernah migrasi dari sesi sebelumnya
    try {
      final isMigratedInCloud = await _remote.checkCloudMigrationStatus(userId);
      if (isMigratedInCloud) {
        await _appSettingsDao.setSetting('cloud_migration_status', 'completed');
        await _appSettingsDao.setSetting('cloud_migration_user_id', userId);
        return true;
      }
    } catch (_) {}

    return false;
  }

  @override
  Future<bool> checkHasCloudData(String userId) async {
    try {
      return await _remote.checkHasCloudData(userId);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<MigrationSummary> getLocalDataSummary() async {
    final wallets = await _db.select(_db.walletsTable).get();
    final customCats = await (_db.select(_db.categoriesTable)..where((c) => c.isSystem.equals(false))).get();
    final txs = await _db.select(_db.transactionsTable).get();
    final budgets = await _db.select(_db.budgetsTable).get();
    final limits = await _db.select(_db.budgetCategoryLimitsTable).get();
    final attachments = await _db.select(_db.transactionAttachmentsTable).get();

    int totalOpening = 0;
    for (final w in wallets) {
      totalOpening += w.openingBalance;
    }

    int totalLedger = totalOpening;
    for (final tx in txs) {
      if (tx.status != 'confirmed') continue;
      if (tx.type == 'income') {
        totalLedger += tx.amount;
      } else if (tx.type == 'expense') {
        totalLedger -= tx.amount;
      }
    }

    return MigrationSummary(
      walletsCount: wallets.length,
      customCategoriesCount: customCats.length,
      transactionsCount: txs.length,
      budgetsCount: budgets.length,
      budgetLimitsCount: limits.length,
      attachmentsCount: attachments.length,
      totalOpeningBalance: totalOpening,
      totalLedgerBalance: totalLedger,
    );
  }

  @override
  Future<MigrationResult> migrateLocalToCloud(
    String userId, {
    void Function(double progress, String step)? onProgress,
  }) async {
    onProgress?.call(0.05, 'Mempersiapkan data lokal...');

    try {
      // 1. Ambil seluruh data dari SQLite lokal
      final wallets = await _db.select(_db.walletsTable).get();
      final customCats = await (_db.select(_db.categoriesTable)..where((c) => c.isSystem.equals(false))).get();
      final txs = await _db.select(_db.transactionsTable).get();
      final budgets = await _db.select(_db.budgetsTable).get();
      final limits = await _db.select(_db.budgetCategoryLimitsTable).get();
      final attachments = await _db.select(_db.transactionAttachmentsTable).get();
      final settings = await _appSettingsDao.getAllSettings();

      final totalRecords = wallets.length +
          customCats.length +
          txs.length +
          budgets.length +
          limits.length +
          attachments.length;

      if (totalRecords == 0) {
        await markMigrationCompleted(userId);
        return MigrationResult(
          status: MigrationStatus.success,
          migratedRecordsCount: 0,
          completedAt: DateTime.now(),
          isVerified: true,
        );
      }

      // 2. Unggah Kategori Kustom terlebih dahulu (Dependency Level 1)
      if (customCats.isNotEmpty) {
        onProgress?.call(0.15, 'Mengunggah kategori kustom...');
        final catRows = customCats.map((c) => {
              'id': c.id,
              'user_id': userId,
              'name': c.name,
              'type': c.type,
              'icon_key': c.iconKey,
              'color_hex': c.colorHex,
              'is_system': false,
              'is_archived': c.isArchived,
              'sort_order': c.sortOrder,
              'created_at': DateTime.now().toUtc().toIso8601String(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            }).toList();

        await _remote.upsertCategories(catRows);
      }

      // 3. Unggah Dompet / Rekening (Dependency Level 2)
      if (wallets.isNotEmpty) {
        onProgress?.call(0.30, 'Mengunggah akun dompet & rekening...');
        final walletRows = wallets.map((w) => {
              'id': w.id,
              'user_id': userId,
              'name': w.name,
              'type': w.type,
              'opening_balance': w.openingBalance,
              'opening_date': w.openingDate,
              'currency_code': w.currencyCode,
              'icon_key': w.iconKey,
              'color_hex': w.colorHex,
              'is_archived': w.isArchived,
              'created_at': w.createdAt,
              'updated_at': w.updatedAt,
            }).toList();

        await _remote.upsertWallets(walletRows);
      }

      // 4. Unggah Transaksi Buku Besar (Dependency Level 3)
      if (txs.isNotEmpty) {
        onProgress?.call(0.55, 'Mengunggah mutasi transaksi & transfer...');
        final txRows = txs.map((t) => {
              'id': t.id,
              'user_id': userId,
              'type': t.type,
              'amount': t.amount,
              'occurred_at': t.occurredAt,
              'wallet_id': t.walletId,
              'destination_wallet_id': t.destinationWalletId,
              'category_id': t.categoryId,
              'merchant': t.merchant,
              'description': t.description,
              'notes': t.notes,
              'source': t.source,
              'status': t.status,
              'created_at': t.createdAt,
              'updated_at': t.updatedAt,
            }).toList();

        await _remote.upsertTransactions(txRows);
      }

      // 5. Unggah Lampiran Transaksi (Dependency Level 4)
      if (attachments.isNotEmpty) {
        onProgress?.call(0.70, 'Mengunggah metadata struk transaksi...');
        final attachmentRows = attachments.map((a) => {
              'id': a.id,
              'user_id': userId,
              'transaction_id': a.transactionId,
              'storage_path': a.localPath,
              'mime_type': a.mimeType,
              'file_size': a.fileSize,
              'created_at': a.createdAt,
            }).toList();

        await _remote.upsertAttachments(attachmentRows);
      }

      // 6. Unggah Anggaran Bulanan (Dependency Level 5)
      if (budgets.isNotEmpty) {
        onProgress?.call(0.80, 'Mengunggah master anggaran...');
        final budgetRows = budgets.map((b) => {
              'id': b.id,
              'user_id': userId,
              'month_key': b.monthKey,
              'total_limit': b.totalLimit,
              'alert_thresholds': b.alertThresholds,
              'carry_over_enabled': b.carryOverEnabled,
              'notes': b.notes,
              'created_at': b.createdAt,
              'updated_at': b.updatedAt,
            }).toList();

        await _remote.upsertBudgets(budgetRows);
      }

      // 7. Unggah Batas Kategori Anggaran (Dependency Level 6)
      if (limits.isNotEmpty) {
        onProgress?.call(0.85, 'Mengunggah alokasi kategori anggaran...');
        final limitRows = limits.map((l) => {
              'id': l.id,
              'user_id': userId,
              'budget_id': l.budgetId,
              'category_id': l.categoryId,
              'limit_amount': l.limitAmount,
              'created_at': DateTime.now().toUtc().toIso8601String(),
            }).toList();

        await _remote.upsertBudgetLimits(limitRows);
      }

      // 8. Unggah Pengaturan Aplikasi (Dependency Level 7)
      if (settings.isNotEmpty) {
        onProgress?.call(0.90, 'Menyinkronkan preferensi aplikasi...');
        final settingRows = settings
            .where((s) => !s.key.startsWith('cloud_migration_'))
            .map((s) => {
                  'user_id': userId,
                  'key': s.key,
                  'value': s.value,
                  'updated_at': s.updatedAt,
                })
            .toList();

        if (settingRows.isNotEmpty) {
          await _remote.upsertSettings(settingRows);
        }
      }

      // 9. Verifikasi Konsistensi & Integritas Data
      onProgress?.call(0.95, 'Memverifikasi integritas data di cloud...');
      final isVerified = await verifyMigration(userId);

      if (!isVerified) {
        throw const SupabaseDatabaseException(
          'Verifikasi integritas migrasi data gagal. Beberapa data belum tersinkron dengan lengkap.',
          'MIGRATION_VERIFICATION_FAILED',
        );
      }

      // 10. Tandai status migrasi selesai
      await markMigrationCompleted(userId);
      onProgress?.call(1.0, 'Migrasi berhasil diselesaikan!');

      return MigrationResult(
        status: MigrationStatus.success,
        migratedRecordsCount: totalRecords,
        completedAt: DateTime.now(),
        isVerified: true,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[MigrationRepositoryImpl] Error saat migrasi: $e');
      }
      return MigrationResult(
        status: MigrationStatus.failed,
        errorMessage: 'Gagal melakukan migrasi data ke cloud: $e',
        completedAt: DateTime.now(),
        isVerified: false,
      );
    }
  }

  @override
  Future<bool> verifyMigration(String userId) async {
    try {
      final localSummary = await getLocalDataSummary();
      final cloudData = await _remote.fetchVerificationData(userId);

      final cloudWallets = (cloudData['wallets'] as List? ?? []);
      final cloudTxs = (cloudData['transactions'] as List? ?? []);
      final cloudBudgets = (cloudData['budgets'] as List? ?? []);
      final cloudCustomCats = (cloudData['customCategories'] as List? ?? []);

      // Verifikasi kuantitas
      if (cloudWallets.length < localSummary.walletsCount) return false;
      if (cloudTxs.length < localSummary.transactionsCount) return false;
      if (cloudBudgets.length < localSummary.budgetsCount) return false;
      if (cloudCustomCats.length < localSummary.customCategoriesCount) return false;

      // Verifikasi saldo pembukaan
      int cloudOpening = 0;
      for (final w in cloudWallets) {
        cloudOpening += (w['opening_balance'] ?? 0) as int;
      }
      if (cloudOpening < localSummary.totalOpeningBalance) return false;

      // Verifikasi saldo buku besar total
      int cloudLedger = cloudOpening;
      for (final t in cloudTxs) {
        if (t['status'] != 'confirmed') continue;
        final type = t['type'];
        final amount = (t['amount'] ?? 0) as int;
        if (type == 'income') {
          cloudLedger += amount;
        } else if (type == 'expense') {
          cloudLedger -= amount;
        }
      }
      if (cloudLedger != localSummary.totalLedgerBalance) return false;

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[MigrationRepositoryImpl] Verify error: $e');
      }
      return false;
    }
  }

  @override
  Future<void> markMigrationCompleted(String userId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _appSettingsDao.setSetting('cloud_migration_status', 'completed');
    await _appSettingsDao.setSetting('cloud_migration_user_id', userId);
    await _appSettingsDao.setSetting('cloud_migration_completed_at', now);

    try {
      await _remote.markCloudMigrationCompleted(userId, now);
    } catch (_) {}
  }

  @override
  Future<void> skipMigration(String userId) async {
    await _appSettingsDao.setSetting('cloud_migration_status', 'skipped');
    await _appSettingsDao.setSetting('cloud_migration_user_id', userId);
  }
}
