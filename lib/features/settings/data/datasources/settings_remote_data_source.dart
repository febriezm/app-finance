import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_service.dart';
import '../../domain/entities/app_setting.dart';

/// Kontrak Remote Data Source untuk operasi PostgREST tabel `app_settings`
abstract class SettingsRemoteDataSource {
  /// Mengambil semua pengaturan milik user aktif
  Future<List<AppSetting>> getAllSettings(String userId);

  /// Mengambil satu pengaturan berdasarkan key dan user_id
  Future<AppSetting?> getSetting(String key, String userId);

  /// Menyimpan atau memperbarui pengaturan di Supabase Cloud
  Future<void> upsertSetting(AppSetting setting, String userId);

  /// Menghapus pengaturan di Supabase Cloud berdasarkan key
  Future<void> deleteSetting(String key, String userId);

  /// Menghitung jumlah pengaturan aktif milik user
  Future<int> getSettingsCount(String userId);
}

/// Implementasi SettingsRemoteDataSource menggunakan Supabase Client dengan RLS
class SettingsRemoteDataSourceImpl implements SettingsRemoteDataSource {
  final SupabaseService? _supabaseService;
  final sp.SupabaseClient? _customClient;

  SettingsRemoteDataSourceImpl({
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
  Future<List<AppSetting>> getAllSettings(String userId) async {
    try {
      final response = await _client
          .from('app_settings')
          .select()
          .eq('user_id', userId)
          .order('key', ascending: true);

      return (response as List)
          .map((row) => AppSetting.fromSupabaseMap(row as Map<String, dynamic>))
          .toList();
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal mengambil pengaturan dari cloud: $e');
    }
  }

  @override
  Future<AppSetting?> getSetting(String key, String userId) async {
    try {
      final response = await _client
          .from('app_settings')
          .select()
          .eq('user_id', userId)
          .eq('key', key)
          .maybeSingle();

      if (response == null) return null;
      return AppSetting.fromSupabaseMap(response);
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal mengambil detail pengaturan dari cloud: $e');
    }
  }

  @override
  Future<void> upsertSetting(AppSetting setting, String userId) async {
    try {
      final payload = setting.toSupabaseMap(userId);
      await _client.from('app_settings').upsert(payload);
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal menyimpan pengaturan ke cloud: $e');
    }
  }

  @override
  Future<void> deleteSetting(String key, String userId) async {
    try {
      await _client
          .from('app_settings')
          .delete()
          .eq('user_id', userId)
          .eq('key', key);
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal menghapus pengaturan dari cloud: $e');
    }
  }

  @override
  Future<int> getSettingsCount(String userId) async {
    try {
      final response = await _client
          .from('app_settings')
          .select('key')
          .eq('user_id', userId);

      return (response as List).length;
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal menghitung jumlah pengaturan di cloud: $e');
    }
  }
}
