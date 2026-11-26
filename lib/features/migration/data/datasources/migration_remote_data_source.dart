import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_service.dart';

abstract class MigrationRemoteDataSource {
  Future<void> upsertCategories(List<Map<String, dynamic>> rows);
  Future<void> upsertWallets(List<Map<String, dynamic>> rows);
  Future<void> upsertTransactions(List<Map<String, dynamic>> rows);
  Future<void> upsertAttachments(List<Map<String, dynamic>> rows);
  Future<void> upsertBudgets(List<Map<String, dynamic>> rows);
  Future<void> upsertBudgetLimits(List<Map<String, dynamic>> rows);
  Future<void> upsertSettings(List<Map<String, dynamic>> rows);
  Future<bool> checkHasCloudData(String userId);
  Future<bool> checkCloudMigrationStatus(String userId);
  Future<void> markCloudMigrationCompleted(String userId, String nowIso);
  Future<Map<String, dynamic>> fetchVerificationData(String userId);
}

class MigrationRemoteDataSourceImpl implements MigrationRemoteDataSource {
  final SupabaseService? _supabaseService;
  final sp.SupabaseClient? _customClient;

  MigrationRemoteDataSourceImpl({
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
      'Supabase client belum diinisialisasi untuk MigrationRemoteDataSource.',
    );
  }

  @override
  Future<void> upsertCategories(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    try {
      await _client.from('categories').upsert(rows, onConflict: 'id');
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    }
  }

  @override
  Future<void> upsertWallets(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    try {
      await _client.from('wallets').upsert(rows, onConflict: 'id');
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    }
  }

  @override
  Future<void> upsertTransactions(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    try {
      await _client.from('transactions').upsert(rows, onConflict: 'id');
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    }
  }

  @override
  Future<void> upsertAttachments(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    try {
      await _client.from('transaction_attachments').upsert(rows, onConflict: 'id');
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    }
  }

  @override
  Future<void> upsertBudgets(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    try {
      await _client.from('budgets').upsert(rows, onConflict: 'user_id, month_key');
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    }
  }

  @override
  Future<void> upsertBudgetLimits(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    try {
      await _client.from('budget_category_limits').upsert(rows, onConflict: 'budget_id, category_id');
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    }
  }

  @override
  Future<void> upsertSettings(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    try {
      await _client.from('app_settings').upsert(rows, onConflict: 'user_id, key');
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    }
  }

  @override
  Future<bool> checkHasCloudData(String userId) async {
    try {
      final walletsRes = await _client.from('wallets').select('id').eq('user_id', userId).limit(1);
      final txsRes = await _client.from('transactions').select('id').eq('user_id', userId).limit(1);
      return (walletsRes as List).isNotEmpty || (txsRes as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> checkCloudMigrationStatus(String userId) async {
    try {
      final res = await _client
          .from('app_settings')
          .select('value')
          .eq('user_id', userId)
          .eq('key', 'cloud_migration_status')
          .maybeSingle();

      return res != null && res['value'] == 'completed';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> markCloudMigrationCompleted(String userId, String nowIso) async {
    try {
      await _client.from('app_settings').upsert({
        'user_id': userId,
        'key': 'cloud_migration_status',
        'value': 'completed',
        'updated_at': nowIso,
      }, onConflict: 'user_id, key');
    } catch (_) {}
  }

  @override
  Future<Map<String, dynamic>> fetchVerificationData(String userId) async {
    try {
      final wallets = await _client.from('wallets').select('id, opening_balance').eq('user_id', userId);
      final txs = await _client.from('transactions').select('id, wallet_id, destination_wallet_id, category_id, type, amount, status, occurred_at').eq('user_id', userId);
      final budgets = await _client.from('budgets').select('id, month_key').eq('user_id', userId);
      final limits = await _client.from('budget_category_limits').select('id, budget_id, category_id').eq('user_id', userId);
      final cats = await _client.from('categories').select('id').eq('user_id', userId).eq('is_system', false);
      final attachments = await _client.from('transaction_attachments').select('id, transaction_id').eq('user_id', userId);

      return {
        'wallets': wallets,
        'transactions': txs,
        'budgets': budgets,
        'budgetLimits': limits,
        'customCategories': cats,
        'attachments': attachments,
      };
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    }
  }
}
