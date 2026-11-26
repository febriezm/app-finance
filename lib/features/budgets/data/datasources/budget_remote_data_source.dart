import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_service.dart';
import '../../domain/entities/budget.dart';

/// Kontrak Remote Data Source untuk operasi PostgREST tabel `budgets` dan `budget_category_limits`
abstract class BudgetRemoteDataSource {
  /// Mengambil seluruh data budget milik pengguna
  Future<List<Budget>> getBudgets(String userId);

  /// Mengambil budget berdasarkan month_key (YYYY-MM)
  Future<Budget?> getBudgetByMonthKey(String monthKey, String userId);

  /// Mengambil budget berdasarkan ID
  Future<Budget?> getBudgetById(String id, String userId);

  /// Mengambil limit kategori untuk suatu budget
  Future<List<BudgetCategoryLimit>> getCategoryLimits(String budgetId, String userId);

  /// Menyimpan master budget dan limit kategori ke cloud
  Future<void> saveBudget({
    required Budget budget,
    required List<BudgetCategoryLimit> categoryLimits,
    required String userId,
  });

  /// Menghapus budget beserta limit kategorinya di cloud
  Future<void> deleteBudget(String budgetId, String userId);
}

/// Implementasi BudgetRemoteDataSource menggunakan Supabase Client
class BudgetRemoteDataSourceImpl implements BudgetRemoteDataSource {
  final SupabaseService? _supabaseService;
  final sp.SupabaseClient? _customClient;

  BudgetRemoteDataSourceImpl({
    SupabaseService? supabaseService,
    sp.SupabaseClient? client,
  })  : _supabaseService = supabaseService,
        _customClient = client;

  sp.SupabaseClient get _client {
    if (_customClient != null) return _customClient;
    final svc = _supabaseService;
    if (svc != null && svc.clientOrNull != null) {
      return svc.client;
    }
    throw const SupabaseConnectionException(
      'Supabase client belum diinisialisasi atau belum terhubung.',
    );
  }

  @override
  Future<List<Budget>> getBudgets(String userId) async {
    try {
      final response = await _client
          .from('budgets')
          .select()
          .eq('user_id', userId)
          .order('month_key', ascending: false);

      return (response as List)
          .map((row) => _mapJsonToBudget(row as Map<String, dynamic>))
          .toList();
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal mengambil daftar anggaran dari cloud: $e');
    }
  }

  @override
  Future<Budget?> getBudgetByMonthKey(String monthKey, String userId) async {
    try {
      final response = await _client
          .from('budgets')
          .select()
          .eq('user_id', userId)
          .eq('month_key', monthKey)
          .maybeSingle();

      if (response == null) return null;
      return _mapJsonToBudget(response);
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal mengambil anggaran bulanan dari cloud: $e');
    }
  }

  @override
  Future<Budget?> getBudgetById(String id, String userId) async {
    try {
      final response = await _client
          .from('budgets')
          .select()
          .eq('id', id)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return _mapJsonToBudget(response);
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal mengambil data anggaran dari cloud: $e');
    }
  }

  @override
  Future<List<BudgetCategoryLimit>> getCategoryLimits(String budgetId, String userId) async {
    try {
      final response = await _client
          .from('budget_category_limits')
          .select()
          .eq('user_id', userId)
          .eq('budget_id', budgetId);

      return (response as List)
          .map((row) => _mapJsonToCategoryLimit(row as Map<String, dynamic>))
          .toList();
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal mengambil batas kategori anggaran dari cloud: $e');
    }
  }

  @override
  Future<void> saveBudget({
    required Budget budget,
    required List<BudgetCategoryLimit> categoryLimits,
    required String userId,
  }) async {
    try {
      // 1. Simpan atau perbarui master budget via upsert pada uq_budgets_user_month (user_id, month_key)
      await _client.from('budgets').upsert({
        'id': budget.id,
        'user_id': userId,
        'month_key': budget.monthKey,
        'total_limit': budget.totalLimit,
        'alert_thresholds': budget.alertThresholds,
        'carry_over_enabled': budget.carryOverEnabled,
        'notes': budget.notes,
        'created_at': budget.createdAt,
        'updated_at': budget.updatedAt,
      }, onConflict: 'user_id,month_key');

      // 2. Bersihkan limit kategori lama untuk budget ini
      await _client
          .from('budget_category_limits')
          .delete()
          .eq('budget_id', budget.id)
          .eq('user_id', userId);

      // 3. Masukkan limit kategori baru
      if (categoryLimits.isNotEmpty) {
        await _client.from('budget_category_limits').insert(
          categoryLimits.map((limit) => {
            'id': limit.id,
            'user_id': userId,
            'budget_id': budget.id,
            'category_id': limit.categoryId,
            'limit_amount': limit.limitAmount,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          }).toList(),
        );
      }
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal menyimpan anggaran ke cloud: $e');
    }
  }

  @override
  Future<void> deleteBudget(String budgetId, String userId) async {
    try {
      // Hapus sub-alokasi limit kategori terlebih dahulu
      await _client
          .from('budget_category_limits')
          .delete()
          .eq('budget_id', budgetId)
          .eq('user_id', userId);

      // Hapus master budget
      await _client
          .from('budgets')
          .delete()
          .eq('id', budgetId)
          .eq('user_id', userId);
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal menghapus anggaran di cloud: $e');
    }
  }

  static Budget _mapJsonToBudget(Map<String, dynamic> json) {
    List<int> thresholds = const [75, 90, 100];
    final rawThresholds = json['alert_thresholds'];
    if (rawThresholds is List) {
      thresholds = rawThresholds.map((e) => (e as num).toInt()).toList();
    } else if (rawThresholds is String) {
      thresholds = Budget.parseThresholds(rawThresholds);
    }

    return Budget(
      id: json['id'] as String,
      monthKey: json['month_key'] as String,
      totalLimit: (json['total_limit'] as num).toInt(),
      alertThresholds: thresholds,
      carryOverEnabled: json['carry_over_enabled'] as bool? ?? false,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  static BudgetCategoryLimit _mapJsonToCategoryLimit(Map<String, dynamic> json) {
    return BudgetCategoryLimit(
      id: json['id'] as String,
      budgetId: json['budget_id'] as String,
      categoryId: json['category_id'] as String,
      limitAmount: (json['limit_amount'] as num).toInt(),
    );
  }
}
