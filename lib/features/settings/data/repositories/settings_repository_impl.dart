import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../../../../core/database/daos/app_settings_dao.dart';
import '../../../../core/services/supabase_service.dart';
import '../../domain/entities/app_setting.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/settings_remote_data_source.dart';

/// Implementasi SettingsRepository dengan pola Offline-First Hybrid:
/// - Reaktivitas instan lokal (0 ms) ditopang oleh AppSettingsDao
/// - Sinkronisasi atomik ke Supabase Cloud PostgreSQL (tabel `app_settings`)
/// - Isolasi mutlak per pengguna aktif (Row Level Security / RLS)
class SettingsRepositoryImpl implements SettingsRepository {
  final AppSettingsDao _appSettingsDao;
  final SettingsRemoteDataSource? _remoteDataSource;
  final SupabaseService? _supabaseService;

  SettingsRepositoryImpl(
    this._appSettingsDao, {
    SettingsRemoteDataSource? remoteDataSource,
    SupabaseService? supabaseService,
  })  : _remoteDataSource = remoteDataSource,
        _supabaseService = supabaseService;

  bool get isCloudActive {
    final svc = _supabaseService;
    return svc != null && svc.isAuthenticated && _remoteDataSource != null;
  }

  String? get currentUserId => _supabaseService?.currentUser?.id;

  Future<void> _syncToLocalCache(AppSetting setting) async {
    try {
      await _appSettingsDao.setSetting(setting.key, setting.value);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SettingsRepositoryImpl] Local sync warning: $e');
      }
    }
  }

  @override
  Future<List<AppSetting>> getAllSettings() async {
    if (isCloudActive) {
      try {
        final cloudList = await _remoteDataSource!.getAllSettings(currentUserId!);
        for (final item in cloudList) {
          await _syncToLocalCache(item);
        }
        return cloudList;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[SettingsRepositoryImpl] Cloud fetch all warning, fallback ke lokal: $e');
        }
      }
    }

    final entries = await _appSettingsDao.getAllSettings();
    return entries.map((e) => AppSetting.fromEntry(e, userId: currentUserId)).toList();
  }

  @override
  Future<String?> getSetting(String key) async {
    if (isCloudActive) {
      try {
        final cloudItem = await _remoteDataSource!.getSetting(key, currentUserId!);
        if (cloudItem != null) {
          await _syncToLocalCache(cloudItem);
          return cloudItem.value;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[SettingsRepositoryImpl] Cloud fetch key warning, fallback ke lokal: $e');
        }
      }
    }

    final localVal = await _appSettingsDao.getSetting(key);
    return localVal;
  }

  @override
  Future<AppSetting?> getSettingDetail(String key) async {
    if (isCloudActive) {
      try {
        final cloudItem = await _remoteDataSource!.getSetting(key, currentUserId!);
        if (cloudItem != null) {
          await _syncToLocalCache(cloudItem);
          return cloudItem;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[SettingsRepositoryImpl] Cloud fetch detail warning: $e');
        }
      }
    }

    final localVal = await _appSettingsDao.getSetting(key);
    if (localVal != null) {
      return AppSetting(
        key: key,
        value: localVal,
        updatedAt: DateTime.now().toUtc().toIso8601String(),
        userId: currentUserId,
      );
    }

    return null;
  }

  @override
  Future<void> setSetting(String key, String value) async {
    // 1. Simpan ke SQLite lokal (0 ms)
    await _appSettingsDao.setSetting(key, value);

    // 2. Sinkronkan ke cloud jika aktif
    if (isCloudActive) {
      try {
        final setting = AppSetting(
          key: key,
          value: value,
          updatedAt: DateTime.now().toUtc().toIso8601String(),
          userId: currentUserId,
        );
        await _remoteDataSource!.upsertSetting(setting, currentUserId!);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[SettingsRepositoryImpl] Cloud upsert warning: $e');
        }
      }
    }
  }

  @override
  Future<void> deleteSetting(String key) async {
    await _appSettingsDao.deleteSetting(key);

    if (isCloudActive) {
      try {
        await _remoteDataSource!.deleteSetting(key, currentUserId!);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[SettingsRepositoryImpl] Cloud delete warning: $e');
        }
      }
    }
  }

  @override
  Future<int> getSettingsCount() async {
    if (isCloudActive) {
      try {
        return await _remoteDataSource!.getSettingsCount(currentUserId!);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[SettingsRepositoryImpl] Cloud count warning: $e');
        }
      }
    }

    final localList = await _appSettingsDao.getAllSettings();
    return localList.length;
  }

  @override
  Stream<String?> watchSetting(String key) {
    return _appSettingsDao.watchSetting(key);
  }

  @override
  Stream<List<AppSetting>> watchAllSettings() {
    return _appSettingsDao.watchAllSettings().map(
          (list) => list.map((e) => AppSetting.fromEntry(e, userId: currentUserId)).toList(),
        );
  }
}
