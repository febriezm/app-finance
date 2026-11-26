import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_service.dart';
import '../../domain/entities/category.dart';

/// Kontrak Remote Data Source untuk operasi PostgREST tabel `categories`
abstract class CategoryRemoteDataSource {
  /// Mengambil semua kategori aktif berdasarkan jenis (income/expense)
  /// Sesuai RLS: mengembalikan kategori sistem (user_id IS NULL) + kategori kustom user
  Future<List<Category>> getActiveCategoriesByType(CategoryType type, String userId);

  /// Mengambil semua kategori aktif (income & expense)
  Future<List<Category>> getAllActiveCategories(String userId);

  /// Mengambil satu kategori berdasarkan ID
  Future<Category?> getCategoryById(String id, String userId);

  /// Menyimpan kategori kustom baru ke Supabase Cloud (is_system = false, user_id = auth.uid)
  Future<void> createCategory(Category category, String userId);

  /// Memperbarui informasi kategori kustom di Supabase Cloud
  Future<void> updateCategory(Category category, String userId);

  /// Mengarsipkan kategori kustom di Supabase Cloud (soft delete)
  Future<void> archiveCategory(String id, String userId);

  /// Menghapus permanen kategori kustom di Supabase Cloud
  Future<void> deleteCategory(String id, String userId);

  /// Menghitung akumulasi transaksi terkonfirmasi untuk kategori ini (balance / spending)
  Future<int> calculateCategorySpending(
    String categoryId,
    String userId, {
    String? startIsoUtc,
    String? endIsoUtc,
  });
}

/// Implementasi CategoryRemoteDataSource menggunakan Supabase Client
class CategoryRemoteDataSourceImpl implements CategoryRemoteDataSource {
  final SupabaseService? _supabaseService;
  final sp.SupabaseClient? _customClient;

  CategoryRemoteDataSourceImpl({
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
  Future<List<Category>> getActiveCategoriesByType(CategoryType type, String userId) async {
    try {
      // RLS Policy 'categories_select_system_and_own' secara otomatis memfilter
      // WHERE (user_id IS NULL OR user_id = auth.uid())
      final response = await _client
          .from('categories')
          .select()
          .eq('type', type.toDbString())
          .eq('is_archived', false)
          .order('sort_order', ascending: true)
          .order('name', ascending: true);

      return (response as List)
          .map((row) => _mapJsonToCategory(row as Map<String, dynamic>))
          .toList();
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal mengambil daftar kategori dari cloud: $e');
    }
  }

  @override
  Future<List<Category>> getAllActiveCategories(String userId) async {
    try {
      final response = await _client
          .from('categories')
          .select()
          .eq('is_archived', false)
          .order('sort_order', ascending: true)
          .order('name', ascending: true);

      return (response as List)
          .map((row) => _mapJsonToCategory(row as Map<String, dynamic>))
          .toList();
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal mengambil seluruh kategori dari cloud: $e');
    }
  }

  @override
  Future<Category?> getCategoryById(String id, String userId) async {
    try {
      final response = await _client
          .from('categories')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return _mapJsonToCategory(response);
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal mengambil data kategori: $e');
    }
  }

  @override
  Future<void> createCategory(Category category, String userId) async {
    try {
      // Mematuhi constraint chk_categories_user_or_system:
      // Kategori pengguna: is_system = FALSE, user_id NOT NULL
      await _client.from('categories').insert({
        'id': category.id,
        'user_id': userId,
        'name': category.name,
        'type': category.type.toDbString(),
        'icon_key': category.iconKey,
        'color_hex': category.colorHex,
        'is_system': false,
        'is_archived': category.isArchived,
        'sort_order': category.sortOrder,
      });
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal membuat kategori baru di cloud: $e');
    }
  }

  @override
  Future<void> updateCategory(Category category, String userId) async {
    try {
      // RLS Policy 'categories_update_own': hanya boleh mengedit kategori kustom milik sendiri
      await _client
          .from('categories')
          .update({
            'name': category.name,
            'type': category.type.toDbString(),
            'icon_key': category.iconKey,
            'color_hex': category.colorHex,
            'is_archived': category.isArchived,
            'sort_order': category.sortOrder,
          })
          .eq('id', category.id)
          .eq('user_id', userId)
          .eq('is_system', false);
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal memperbarui kategori di cloud: $e');
    }
  }

  @override
  Future<void> archiveCategory(String id, String userId) async {
    try {
      await _client
          .from('categories')
          .update({'is_archived': true})
          .eq('id', id)
          .eq('user_id', userId)
          .eq('is_system', false);
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal mengarsipkan kategori di cloud: $e');
    }
  }

  @override
  Future<void> deleteCategory(String id, String userId) async {
    try {
      await _client
          .from('categories')
          .delete()
          .eq('id', id)
          .eq('user_id', userId)
          .eq('is_system', false);
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal menghapus kategori di cloud: $e');
    }
  }

  @override
  Future<int> calculateCategorySpending(
    String categoryId,
    String userId, {
    String? startIsoUtc,
    String? endIsoUtc,
  }) async {
    try {
      var query = _client
          .from('transactions')
          .select('amount')
          .eq('user_id', userId)
          .eq('category_id', categoryId)
          .eq('status', 'confirmed');

      if (startIsoUtc != null) {
        query = query.gte('occurred_at', startIsoUtc);
      }
      if (endIsoUtc != null) {
        query = query.lte('occurred_at', endIsoUtc);
      }

      final response = await query;
      int total = 0;
      for (final row in response as List) {
        final amount = row['amount'];
        if (amount is num) {
          total += amount.toInt();
        }
      }
      return total;
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal menghitung akumulasi transaksi kategori: $e');
    }
  }

  static Category _mapJsonToCategory(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      type: CategoryType.fromString(json['type'] as String),
      iconKey: json['icon_key'] as String?,
      colorHex: json['color_hex'] as String?,
      isSystem: json['is_system'] as bool? ?? false,
      isArchived: json['is_archived'] as bool? ?? false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}
