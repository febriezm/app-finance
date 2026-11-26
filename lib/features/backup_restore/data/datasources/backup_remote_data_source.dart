import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_service.dart';
import '../../domain/entities/backup_archive.dart';

/// Kontrak Remote Data Source untuk operasi pencadangan dan pemulihan data pada Supabase Cloud
abstract class BackupRemoteDataSource {
  /// Mengambil seluruh data user dari Supabase Cloud dan merangkumnya ke dalam BackupArchive
  Future<BackupArchive> fetchBackupArchive(String userId);

  /// Memulihkan data dari BackupArchive ke tabel-tabel Supabase Cloud untuk user tertentu
  Future<void> restoreBackupArchive(BackupArchive archive, String userId);

  /// Menghapus seluruh data finansial user dari tabel-tabel Supabase Cloud (Danger Zone Reset)
  Future<void> resetUserData(String userId);

  /// Mengambil jumlah record data finansial per domain/tabel di Supabase Cloud
  Future<Map<String, int>> fetchRecordCounts(String userId);
}

/// Implementasi BackupRemoteDataSource menggunakan Supabase PostgREST Client
class BackupRemoteDataSourceImpl implements BackupRemoteDataSource {
  final SupabaseService? _supabaseService;
  final sp.SupabaseClient? _customClient;

  BackupRemoteDataSourceImpl({
    SupabaseService? supabaseService,
    sp.SupabaseClient? customClient,
  })  : _supabaseService = supabaseService,
        _customClient = customClient;

  sp.SupabaseClient get _client {
    if (_customClient != null) return _customClient;
    if (_supabaseService != null && _supabaseService.clientOrNull != null) {
      return _supabaseService.clientOrNull!;
    }
    throw const SupabaseConnectionException(
      'Supabase client belum diinisialisasi untuk BackupRemoteDataSource.',
    );
  }

  @override
  Future<BackupArchive> fetchBackupArchive(String userId) async {
    try {
      // 1. Wallets
      final walletsRes = await _client
          .from('wallets')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true);
      final wallets = List<Map<String, dynamic>>.from(walletsRes);

      // 2. Categories (kategori sistem global ATAU kategori kustom milik user)
      final categoriesRes = await _client
          .from('categories')
          .select()
          .or('is_system.eq.true,user_id.eq.$userId')
          .order('sort_order', ascending: true);
      final categories = List<Map<String, dynamic>>.from(categoriesRes);

      // 3. Transactions
      final transactionsRes = await _client
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .order('occurred_at', ascending: true);
      final transactions = List<Map<String, dynamic>>.from(transactionsRes);

      // 4. Budgets
      final budgetsRes = await _client
          .from('budgets')
          .select()
          .eq('user_id', userId)
          .order('month_key', ascending: true);
      final budgets = List<Map<String, dynamic>>.from(budgetsRes);

      // 5. Budget Category Limits
      final limitsRes = await _client
          .from('budget_category_limits')
          .select()
          .eq('user_id', userId);
      final limits = List<Map<String, dynamic>>.from(limitsRes);

      // 6. Transaction Attachments
      final attachmentsRes = await _client
          .from('transaction_attachments')
          .select()
          .eq('user_id', userId);
      final attachments = List<Map<String, dynamic>>.from(attachmentsRes);

      return BackupArchive(
        schemaVersion: 1,
        appName: 'MyFinance',
        appVersion: '1.0.0',
        exportedAt: DateTime.now().toUtc().toIso8601String(),
        wallets: wallets,
        categories: categories,
        transactions: transactions,
        budgets: budgets,
        budgetCategoryLimits: limits,
        transactionAttachments: attachments,
      );
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(
        e.message,
        e.code,
      );
    } catch (e) {
      if (e is SupabaseDatabaseException) rethrow;
      throw SupabaseDatabaseException(
        'Gagal mengambil arsip cadangan dari cloud: $e',
        'UNKNOWN_BACKUP_FETCH_ERROR',
      );
    }
  }

  @override
  Future<void> restoreBackupArchive(BackupArchive archive, String userId) async {
    try {
      // 1. Kosongkan data existing user di cloud secara berurutan (child ke parent)
      await resetUserData(userId);

      // 2. Masukkan data arsip ke Supabase Cloud (parent ke child)

      // a. Wallets
      if (archive.wallets.isNotEmpty) {
        final walletRows = archive.wallets.map((w) {
          return {
            'id': w['id'],
            'user_id': userId,
            'name': w['name'],
            'type': w['type'],
            'opening_balance': (w['openingBalance'] ?? w['opening_balance'] ?? 0) as int,
            'opening_date': (w['openingDate'] ?? w['opening_date'] ?? DateTime.now().toUtc().toIso8601String()).toString(),
            'currency_code': (w['currencyCode'] ?? w['currency_code'] ?? 'IDR').toString(),
            'icon_key': w['iconKey'] ?? w['icon_key'],
            'color_hex': w['colorHex'] ?? w['color_hex'],
            'is_archived': (w['isArchived'] ?? w['is_archived'] ?? false) as bool,
            'created_at': (w['createdAt'] ?? w['created_at'] ?? DateTime.now().toUtc().toIso8601String()).toString(),
            'updated_at': (w['updatedAt'] ?? w['updated_at'] ?? DateTime.now().toUtc().toIso8601String()).toString(),
          };
        }).toList();

        await _client.from('wallets').insert(walletRows);
      }

      // b. Kategori kustom pengguna (jangan duplikasi kategori sistem)
      final customCats = archive.categories.where((c) {
        final isSys = c['isSystem'] ?? c['is_system'] ?? false;
        return isSys == false;
      }).toList();

      if (customCats.isNotEmpty) {
        final catRows = customCats.map((c) {
          return {
            'id': c['id'],
            'user_id': userId,
            'name': c['name'],
            'type': c['type'],
            'icon_key': c['iconKey'] ?? c['icon_key'],
            'color_hex': c['colorHex'] ?? c['color_hex'],
            'is_system': false,
            'is_archived': (c['isArchived'] ?? c['is_archived'] ?? false) as bool,
            'sort_order': (c['sortOrder'] ?? c['sort_order'] ?? 0) as int,
            'created_at': (c['createdAt'] ?? c['created_at'] ?? DateTime.now().toUtc().toIso8601String()).toString(),
            'updated_at': (c['updatedAt'] ?? c['updated_at'] ?? DateTime.now().toUtc().toIso8601String()).toString(),
          };
        }).toList();

        await _client.from('categories').insert(catRows);
      }

      // c. Transactions
      if (archive.transactions.isNotEmpty) {
        final txRows = archive.transactions.map((t) {
          return {
            'id': t['id'],
            'user_id': userId,
            'type': t['type'],
            'amount': (t['amount'] ?? 0) as int,
            'occurred_at': (t['occurredAt'] ?? t['occurred_at'] ?? DateTime.now().toUtc().toIso8601String()).toString(),
            'wallet_id': t['walletId'] ?? t['wallet_id'],
            'destination_wallet_id': t['destinationWalletId'] ?? t['destination_wallet_id'],
            'category_id': t['categoryId'] ?? t['category_id'],
            'merchant': t['merchant'],
            'description': t['description'],
            'notes': t['notes'],
            'source': (t['source'] ?? 'manual').toString(),
            'status': (t['status'] ?? 'confirmed').toString(),
            'created_at': (t['createdAt'] ?? t['created_at'] ?? DateTime.now().toUtc().toIso8601String()).toString(),
            'updated_at': (t['updatedAt'] ?? t['updated_at'] ?? DateTime.now().toUtc().toIso8601String()).toString(),
          };
        }).toList();

        await _client.from('transactions').insert(txRows);
      }

      // d. Budgets
      if (archive.budgets.isNotEmpty) {
        final budgetRows = archive.budgets.map((b) {
          return {
            'id': b['id'],
            'user_id': userId,
            'month_key': (b['monthKey'] ?? b['month_key']).toString(),
            'total_limit': (b['totalLimit'] ?? b['total_limit'] ?? 0) as int,
            'alert_thresholds': b['alertThresholds'] ?? b['alert_thresholds'] ?? [75, 90, 100],
            'carry_over_enabled': (b['carryOverEnabled'] ?? b['carry_over_enabled'] ?? false) as bool,
            'notes': b['notes'],
            'created_at': (b['createdAt'] ?? b['created_at'] ?? DateTime.now().toUtc().toIso8601String()).toString(),
            'updated_at': (b['updatedAt'] ?? b['updated_at'] ?? DateTime.now().toUtc().toIso8601String()).toString(),
          };
        }).toList();

        await _client.from('budgets').insert(budgetRows);
      }

      // e. Budget Category Limits
      if (archive.budgetCategoryLimits.isNotEmpty) {
        final limitRows = archive.budgetCategoryLimits.map((l) {
          return {
            'id': l['id'],
            'user_id': userId,
            'budget_id': l['budgetId'] ?? l['budget_id'],
            'category_id': l['categoryId'] ?? l['category_id'],
            'limit_amount': (l['limitAmount'] ?? l['limit_amount'] ?? 0) as int,
            'created_at': (l['createdAt'] ?? l['created_at'] ?? DateTime.now().toUtc().toIso8601String()).toString(),
          };
        }).toList();

        await _client.from('budget_category_limits').insert(limitRows);
      }

      // f. Transaction Attachments
      if (archive.transactionAttachments.isNotEmpty) {
        final attachmentRows = archive.transactionAttachments.map((a) {
          return {
            'id': a['id'],
            'user_id': userId,
            'transaction_id': a['transactionId'] ?? a['transaction_id'],
            'storage_path': (a['storagePath'] ?? a['storage_path'] ?? a['localPath'] ?? a['local_path'] ?? '').toString(),
            'mime_type': (a['mimeType'] ?? a['mime_type'] ?? 'image/jpeg').toString(),
            'file_size': (a['fileSize'] ?? a['file_size'] ?? 0) as int,
            'created_at': (a['createdAt'] ?? a['created_at'] ?? DateTime.now().toUtc().toIso8601String()).toString(),
          };
        }).toList();

        await _client.from('transaction_attachments').insert(attachmentRows);
      }
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(
        e.message,
        e.code,
      );
    } catch (e) {
      if (e is SupabaseDatabaseException) rethrow;
      throw SupabaseDatabaseException(
        'Gagal memulihkan arsip cadangan ke cloud: $e',
        'UNKNOWN_BACKUP_RESTORE_ERROR',
      );
    }
  }

  @override
  Future<void> resetUserData(String userId) async {
    try {
      // Hapus data child ke parent
      await _client.from('transaction_attachments').delete().eq('user_id', userId);
      await _client.from('budget_category_limits').delete().eq('user_id', userId);
      await _client.from('budgets').delete().eq('user_id', userId);
      await _client.from('transactions').delete().eq('user_id', userId);
      await _client.from('categories').delete().eq('user_id', userId).eq('is_system', false);
      await _client.from('wallets').delete().eq('user_id', userId);
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(
        e.message,
        e.code,
      );
    } catch (e) {
      if (e is SupabaseDatabaseException) rethrow;
      throw SupabaseDatabaseException(
        'Gagal mengosongkan data user di cloud: $e',
        'UNKNOWN_BACKUP_RESET_ERROR',
      );
    }
  }

  @override
  Future<Map<String, int>> fetchRecordCounts(String userId) async {
    try {
      final walletsRes = await _client.from('wallets').select('id').eq('user_id', userId);
      final categoriesRes = await _client.from('categories').select('id').or('is_system.eq.true,user_id.eq.$userId');
      final txRes = await _client.from('transactions').select('id').eq('user_id', userId);
      final budgetsRes = await _client.from('budgets').select('id').eq('user_id', userId);
      final limitsRes = await _client.from('budget_category_limits').select('id').eq('user_id', userId);
      final attachmentsRes = await _client.from('transaction_attachments').select('id').eq('user_id', userId);

      return {
        'wallets': (walletsRes as List).length,
        'categories': (categoriesRes as List).length,
        'transactions': (txRes as List).length,
        'budgets': (budgetsRes as List).length,
        'budgetCategoryLimits': (limitsRes as List).length,
        'transactionAttachments': (attachmentsRes as List).length,
      };
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(
        e.message,
        e.code,
      );
    } catch (e) {
      if (e is SupabaseDatabaseException) rethrow;
      throw SupabaseDatabaseException(
        'Gagal menghitung jumlah record di cloud: $e',
        'UNKNOWN_BACKUP_COUNT_ERROR',
      );
    }
  }
}
