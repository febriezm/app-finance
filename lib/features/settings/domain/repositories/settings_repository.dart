import '../entities/app_setting.dart';

/// Kontrak repositori domain untuk operasi konfigurasi dan preferensi pengguna
abstract interface class SettingsRepository {
  /// Mengambil semua pengaturan milik user aktif
  Future<List<AppSetting>> getAllSettings();

  /// Mengambil nilai satu pengaturan berdasarkan key
  Future<String?> getSetting(String key);

  /// Mengambil entitas detail satu pengaturan berdasarkan key
  Future<AppSetting?> getSettingDetail(String key);

  /// Menyimpan atau memperbarui pengaturan (Upsert)
  Future<void> setSetting(String key, String value);

  /// Menghapus pengaturan berdasarkan key
  Future<void> deleteSetting(String key);

  /// Menghitung total entri konfigurasi tersimpan
  Future<int> getSettingsCount();

  /// Watch nilai pengaturan secara reaktif (Stream)
  Stream<String?> watchSetting(String key);

  /// Watch seluruh pengaturan milik user (Stream)
  Stream<List<AppSetting>> watchAllSettings();
}
