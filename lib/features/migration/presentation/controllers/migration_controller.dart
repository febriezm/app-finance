import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/app_providers.dart';
import '../../domain/entities/migration_result.dart';
import '../../domain/entities/migration_summary.dart';
import '../../domain/repositories/migration_repository.dart';

class MigrationState {
  final bool isLoading;
  final MigrationStatus status;
  final double progress;
  final String currentStep;
  final MigrationSummary summary;
  final MigrationResult? result;
  final String? errorMessage;

  const MigrationState({
    this.isLoading = false,
    this.status = MigrationStatus.idle,
    this.progress = 0.0,
    this.currentStep = '',
    this.summary = MigrationSummary.empty,
    this.result,
    this.errorMessage,
  });

  bool get shouldShowPrompt => status == MigrationStatus.promptReady;
  bool get isMigrating => status == MigrationStatus.inProgress;
  bool get isSuccess => status == MigrationStatus.success;
  bool get isFailed => status == MigrationStatus.failed;

  MigrationState copyWith({
    bool? isLoading,
    MigrationStatus? status,
    double? progress,
    String? currentStep,
    MigrationSummary? summary,
    MigrationResult? result,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MigrationState(
      isLoading: isLoading ?? this.isLoading,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      currentStep: currentStep ?? this.currentStep,
      summary: summary ?? this.summary,
      result: result ?? this.result,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class MigrationController extends StateNotifier<MigrationState> {
  final MigrationRepository _repository;
  final Ref _ref;

  MigrationController(this._repository, this._ref) : super(const MigrationState());

  /// Memeriksa apakah user saat ini memiliki data lokal yang perlu dimigrasikan ke cloud
  Future<bool> checkMigrationNeeded(String userId) async {
    state = state.copyWith(status: MigrationStatus.checking, clearError: true);

    try {
      // 1. Cek apakah user sudah pernah melakukan migrasi
      final isAlreadyMigrated = await _repository.checkIsAlreadyMigrated(userId);
      if (isAlreadyMigrated) {
        state = state.copyWith(status: MigrationStatus.idle);
        return false;
      }

      // 2. Cek apakah ada data lokal di SQLite
      final hasLocalData = await _repository.checkHasLocalData();
      if (!hasLocalData) {
        // Tandai selesai agar tidak perlu dicek ulang
        await _repository.markMigrationCompleted(userId);
        state = state.copyWith(status: MigrationStatus.idle);
        return false;
      }

      // 3. Ambil ringkasan data lokal
      final summary = await _repository.getLocalDataSummary();
      if (!summary.hasData) {
        await _repository.markMigrationCompleted(userId);
        state = state.copyWith(status: MigrationStatus.idle);
        return false;
      }

      // 4. Data ditemukan dan siap ditawarkan ke pengguna
      state = state.copyWith(
        status: MigrationStatus.promptReady,
        summary: summary,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: MigrationStatus.idle,
        errorMessage: 'Gagal memeriksa status migrasi: $e',
      );
      return false;
    }
  }

  /// Memulai proses migrasi data dari SQLite lokal ke Supabase PostgreSQL Cloud
  Future<bool> startMigration(String userId) async {
    state = state.copyWith(
      isLoading: true,
      status: MigrationStatus.inProgress,
      progress: 0.05,
      currentStep: 'Memulai proses migrasi...',
      clearError: true,
    );

    try {
      final result = await _repository.migrateLocalToCloud(
        userId,
        onProgress: (p, step) {
          state = state.copyWith(
            progress: p,
            currentStep: step,
          );
        },
      );

      if (result.isSuccess) {
        // Segarkan seluruh provider domain agar aplikasi langsung menampilkan data cloud terbaru
        _ref.invalidate(walletRepositoryProvider);
        _ref.invalidate(categoryRepositoryProvider);
        _ref.invalidate(transactionRepositoryProvider);
        _ref.invalidate(budgetRepositoryProvider);
        _ref.invalidate(walletsWithBalanceStreamProvider);
        _ref.invalidate(recentTransactionsStreamProvider);
        _ref.invalidate(totalAssetBalanceProvider);

        state = state.copyWith(
          isLoading: false,
          status: MigrationStatus.success,
          progress: 1.0,
          currentStep: 'Migrasi berhasil diselesaikan!',
          result: result,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          status: MigrationStatus.failed,
          errorMessage: result.errorMessage ?? 'Migrasi gagal dilakukan.',
          result: result,
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        status: MigrationStatus.failed,
        errorMessage: 'Terjadi kesalahan saat migrasi: $e',
      );
      return false;
    }
  }

  /// Menandai migrasi dilewati (pengguna memilih "Nanti Saja")
  Future<void> skipMigration(String userId) async {
    await _repository.skipMigration(userId);
    state = state.copyWith(status: MigrationStatus.skipped);
  }

  /// Reset status ke idle
  void reset() {
    state = const MigrationState();
  }
}
