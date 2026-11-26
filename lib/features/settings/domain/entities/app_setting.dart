import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';

/// Entitas domain untuk satu item pengaturan aplikasi (Key-Value)
class AppSetting {
  final String key;
  final String value;
  final String updatedAt;
  final String? userId;

  const AppSetting({
    required this.key,
    required this.value,
    required this.updatedAt,
    this.userId,
  });

  AppSetting copyWith({
    String? key,
    String? value,
    String? updatedAt,
    String? userId,
  }) {
    return AppSetting(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
    );
  }

  static AppSetting fromEntry(AppSettingEntry entry, {String? userId}) {
    return AppSetting(
      key: entry.key,
      value: entry.value,
      updatedAt: entry.updatedAt,
      userId: userId,
    );
  }

  AppSettingsTableCompanion toCompanion() {
    return AppSettingsTableCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  Map<String, dynamic> toSupabaseMap(String authenticatedUserId) {
    return {
      'user_id': authenticatedUserId,
      'key': key,
      'value': value,
      'updated_at': updatedAt,
    };
  }

  static AppSetting fromSupabaseMap(Map<String, dynamic> map) {
    return AppSetting(
      key: map['key'] as String,
      value: map['value'] as String,
      updatedAt: (map['updated_at'] as String?) ?? DateTime.now().toUtc().toIso8601String(),
      userId: map['user_id'] as String?,
    );
  }
}
