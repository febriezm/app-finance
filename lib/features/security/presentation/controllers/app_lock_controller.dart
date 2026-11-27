import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/daos/app_settings_dao.dart';
import '../../../../core/services/app_lock_service.dart';
import '../../../settings/domain/repositories/settings_repository.dart';

class AppLockState {
  final bool isAppLockEnabled;
  final bool isUnlocked;
  final bool hasPinSet;
  final bool isBiometricsAvailable;
  final bool isBiometricsEnabled;
  final bool isAuthenticating;
  final String? errorMessage;
  final int failedPinAttempts;
  final String biometricLabel;

  const AppLockState({
    this.isAppLockEnabled = false,
    this.isUnlocked = true,
    this.hasPinSet = false,
    this.isBiometricsAvailable = false,
    this.isBiometricsEnabled = false,
    this.isAuthenticating = false,
    this.errorMessage,
    this.failedPinAttempts = 0,
    this.biometricLabel = 'Biometrik',
  });

  AppLockState copyWith({
    bool? isAppLockEnabled,
    bool? isUnlocked,
    bool? hasPinSet,
    bool? isBiometricsAvailable,
    bool? isBiometricsEnabled,
    bool? isAuthenticating,
    String? errorMessage,
    int? failedPinAttempts,
    String? biometricLabel,
  }) {
    return AppLockState(
      isAppLockEnabled: isAppLockEnabled ?? this.isAppLockEnabled,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      hasPinSet: hasPinSet ?? this.hasPinSet,
      isBiometricsAvailable: isBiometricsAvailable ?? this.isBiometricsAvailable,
      isBiometricsEnabled: isBiometricsEnabled ?? this.isBiometricsEnabled,
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
      errorMessage: errorMessage,
      failedPinAttempts: failedPinAttempts ?? this.failedPinAttempts,
      biometricLabel: biometricLabel ?? this.biometricLabel,
    );
  }
}

class AppLockController extends StateNotifier<AppLockState> {
  static const String keyAppLockEnabled = 'app_lock_enabled';
  static const String keyAppLockPinHash = 'app_lock_pin_hash';
  static const String keyAppLockBiometricsEnabled = 'app_lock_biometrics_enabled';

  final AppLockService _lockService;
  final AppSettingsDao? _appSettingsDao;
  final SettingsRepository? _settingsRepository;

  AppLockController({
    required AppLockService lockService,
    AppSettingsDao? appSettingsDao,
    SettingsRepository? settingsRepository,
    bool initialLockEnabled = false,
    bool initialHasPin = false,
  })  : _lockService = lockService,
        _appSettingsDao = appSettingsDao,
        _settingsRepository = settingsRepository,
        super(AppLockState(
          isAppLockEnabled: initialLockEnabled,
          isUnlocked: !initialLockEnabled,
          hasPinSet: initialHasPin,
        )) {
    init();
  }

  Future<String?> _getSetting(String key) async {
    if (_settingsRepository != null) {
      return await _settingsRepository.getSetting(key);
    }
    if (_appSettingsDao != null) {
      return await _appSettingsDao.getSetting(key);
    }
    return null;
  }

  Future<void> _setSetting(String key, String value) async {
    if (_settingsRepository != null) {
      await _settingsRepository.setSetting(key, value);
    } else if (_appSettingsDao != null) {
      await _appSettingsDao.setSetting(key, value);
    }
  }

  Future<void> init() async {
    try {
      final bioAvailable = await _lockService.isBiometricsAvailable();
      final bioLabel = await _lockService.getBiometricTypeLabel();

      String? enabledStr;
      String? pinHash;
      String? bioEnabledStr;

      if (_settingsRepository != null || _appSettingsDao != null) {
        try {
          enabledStr = await _getSetting(keyAppLockEnabled);
          pinHash = await _getSetting(keyAppLockPinHash);
          bioEnabledStr = await _getSetting(keyAppLockBiometricsEnabled);
        } catch (e) {
          debugPrint('AppLockController: error reading settings: $e');
        }
      }

      final hasStorage = _settingsRepository != null || _appSettingsDao != null;
      final isEnabled = hasStorage
          ? (enabledStr == 'true')
          : state.isAppLockEnabled;
      final hasPin = hasStorage
          ? (pinHash != null && pinHash.isNotEmpty)
          : state.hasPinSet;
      final isBioEnabled = bioEnabledStr == 'true' || (bioAvailable && bioEnabledStr == null);

      state = state.copyWith(
        isAppLockEnabled: isEnabled,
        isUnlocked: !isEnabled,
        hasPinSet: hasPin,
        isBiometricsAvailable: bioAvailable,
        isBiometricsEnabled: isBioEnabled,
        biometricLabel: bioLabel,
      );
    } catch (e, st) {
      debugPrint('AppLockController init error: $e\n$st');
    }
  }

  /// Menyiapkan PIN 6-digit baru dan mengaktifkan Kunci Aplikasi
  Future<bool> setupPin(String pin, {bool enableBiometrics = true}) async {
    if (pin.length != 6) {
      state = state.copyWith(errorMessage: 'PIN harus terdiri dari 6 digit angka.');
      return false;
    }

    state = state.copyWith(isAuthenticating: true, errorMessage: null);
    final hash = AppLockService.hashPin(pin);

    await _setSetting(keyAppLockPinHash, hash);
    await _setSetting(keyAppLockEnabled, 'true');
    await _setSetting(
      keyAppLockBiometricsEnabled,
      enableBiometrics ? 'true' : 'false',
    );

    state = state.copyWith(
      isAppLockEnabled: true,
      isUnlocked: true,
      hasPinSet: true,
      isBiometricsEnabled: enableBiometrics,
      isAuthenticating: false,
      errorMessage: null,
      failedPinAttempts: 0,
    );
    return true;
  }

  /// Membuka kunci menggunakan verifikasi PIN 6-digit
  Future<bool> unlockWithPin(String pin) async {
    final storedHash = await _getSetting(keyAppLockPinHash);

    // Jika belum ada hash di DB, periksa state hasPinSet
    if (storedHash == null) {
      if (!state.hasPinSet) {
        state = state.copyWith(isUnlocked: true, errorMessage: null);
        return true;
      }
      state = state.copyWith(
        isUnlocked: false,
        errorMessage: 'Kode sandi belum dikonfigurasi.',
      );
      return false;
    }

    final isValid = AppLockService.verifyPin(pin, storedHash);
    if (isValid) {
      state = state.copyWith(
        isUnlocked: true,
        errorMessage: null,
        failedPinAttempts: 0,
      );
      return true;
    } else {
      final attempts = state.failedPinAttempts + 1;
      state = state.copyWith(
        isUnlocked: false,
        failedPinAttempts: attempts,
        errorMessage: 'Kode sandi salah. Silakan coba lagi.',
      );
      return false;
    }
  }

  /// Membuka kunci menggunakan Biometrik / Face ID
  Future<bool> unlockWithBiometrics() async {
    if (!state.isBiometricsAvailable || !state.isBiometricsEnabled) {
      return false;
    }

    state = state.copyWith(isAuthenticating: true, errorMessage: null);
    final success = await _lockService.authenticate(
      reason: 'Buka kunci MyFinance untuk mengakses data keuangan Anda',
    );

    if (success) {
      state = state.copyWith(
        isUnlocked: true,
        isAuthenticating: false,
        errorMessage: null,
        failedPinAttempts: 0,
      );
      return true;
    } else {
      state = state.copyWith(
        isAuthenticating: false,
        errorMessage: 'Verifikasi ${state.biometricLabel} tidak berhasil. Gunakan PIN.',
      );
      return false;
    }
  }

  /// Buka kunci umum (mencoba biometrik terlebih dahulu jika tersedia)
  Future<bool> unlock() async {
    if (!state.isAppLockEnabled || state.isUnlocked) {
      state = state.copyWith(isUnlocked: true);
      return true;
    }

    if (state.isBiometricsAvailable && state.isBiometricsEnabled) {
      final bioSuccess = await unlockWithBiometrics();
      if (bioSuccess) return true;
    }

    return false;
  }

  /// Menonaktifkan Kunci Aplikasi setelah verifikasi PIN yang benar
  Future<bool> disableAppLock(String pin) async {
    final storedHash = await _getSetting(keyAppLockPinHash);

    if (storedHash != null && !AppLockService.verifyPin(pin, storedHash)) {
      state = state.copyWith(errorMessage: 'Kode sandi salah.');
      return false;
    }

    await _setSetting(keyAppLockEnabled, 'false');

    state = state.copyWith(
      isAppLockEnabled: false,
      isUnlocked: true,
      errorMessage: null,
    );
    return true;
  }

  /// Mengubah PIN setelah verifikasi PIN lama
  Future<bool> changePin({required String oldPin, required String newPin}) async {
    final storedHash = await _getSetting(keyAppLockPinHash);

    if (storedHash != null && !AppLockService.verifyPin(oldPin, storedHash)) {
      state = state.copyWith(errorMessage: 'Kode sandi lama salah.');
      return false;
    }

    if (newPin.length != 6) {
      state = state.copyWith(errorMessage: 'Kode sandi baru harus 6 digit.');
      return false;
    }

    final newHash = AppLockService.hashPin(newPin);
    await _setSetting(keyAppLockPinHash, newHash);

    state = state.copyWith(errorMessage: null);
    return true;
  }

  /// Toggle biometrik on/off
  Future<void> setBiometricsEnabled(bool enable) async {
    await _setSetting(
      keyAppLockBiometricsEnabled,
      enable ? 'true' : 'false',
    );
    state = state.copyWith(isBiometricsEnabled: enable);
  }

  /// Mengunci aplikasi secara manual
  void lock() {
    if (state.isAppLockEnabled) {
      state = state.copyWith(isUnlocked: false, errorMessage: null);
    }
  }

  /// Dipanggil saat aplikasi masuk ke background
  void onAppPaused() {
    // Kunci Aplikasi hanya berlaku saat aplikasi di-refresh atau pertama kali dibuka.
  }

  /// Dipanggil saat aplikasi kembali ke foreground
  Future<void> onAppResumed() async {
    // Sesuai aturan: Kunci Aplikasi hanya berlaku saat aplikasi di-refresh atau pertama kali dibuka.
    // Tidak mengunci saat navigasi internal, Scan Struk OCR, atau membuka kamera/picker.
  }

  /// Reset seluruh state kunci saat pengguna keluar (logout) atau berganti akun
  void reset() {
    state = const AppLockState(
      isAppLockEnabled: false,
      isUnlocked: true,
      hasPinSet: false,
      isBiometricsAvailable: false,
      isBiometricsEnabled: false,
      isAuthenticating: false,
      errorMessage: null,
      failedPinAttempts: 0,
    );
  }

  /// Kompatibilitas mundur dengan toggleAppLock lama
  Future<bool> toggleAppLock(bool enable) async {
    if (!enable) {
      await _setSetting(keyAppLockEnabled, 'false');
      state = state.copyWith(isAppLockEnabled: false, isUnlocked: true);
      return true;
    }
    return false;
  }
}
