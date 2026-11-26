import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/app_database.dart';
import '../core/database/daos/wallets_dao.dart';
import '../core/database/daos/categories_dao.dart';
import '../core/database/daos/transactions_dao.dart';
import '../core/database/daos/budgets_dao.dart';
import '../core/database/daos/app_settings_dao.dart';
import '../core/formatting/date_formatter.dart';

import '../features/wallets/domain/entities/wallet.dart';
import '../features/wallets/domain/repositories/wallet_repository.dart';
import '../features/wallets/data/datasources/wallet_remote_data_source.dart';
import '../features/wallets/data/repositories/wallet_repository_impl.dart';
import '../features/wallets/presentation/controllers/wallets_controller.dart';

import '../features/categories/domain/entities/category.dart';
import '../features/categories/domain/repositories/category_repository.dart';
import '../features/categories/data/datasources/category_remote_data_source.dart';
import '../features/categories/data/repositories/category_repository_impl.dart';

import '../features/transactions/domain/entities/transaction_with_details.dart';
import '../features/transactions/domain/repositories/transaction_repository.dart';
import '../features/transactions/data/datasources/transaction_remote_data_source.dart';
import '../features/transactions/data/repositories/transaction_repository_impl.dart';
import '../features/transactions/presentation/controllers/transactions_controller.dart';

import '../features/transfers/domain/entities/transfer.dart';
import '../features/transfers/domain/repositories/transfer_repository.dart';
import '../features/transfers/data/datasources/transfer_remote_data_source.dart';
import '../features/transfers/data/repositories/transfer_repository_impl.dart';
import '../features/transfers/presentation/controllers/transfer_controller.dart';

import '../features/budgets/domain/entities/budget.dart';
import '../features/budgets/domain/repositories/budget_repository.dart';
import '../features/budgets/data/datasources/budget_remote_data_source.dart';
import '../features/budgets/data/repositories/budget_repository_impl.dart';
import '../features/budgets/presentation/controllers/budgets_controller.dart';

import '../features/reports/domain/entities/monthly_report.dart';
import '../features/reports/domain/repositories/report_repository.dart';
import '../features/reports/data/datasources/report_remote_data_source.dart';
import '../features/reports/data/repositories/report_repository_impl.dart';
import '../features/reports/domain/usecases/get_monthly_report_usecase.dart';
import '../features/reports/domain/usecases/export_report_csv_usecase.dart';
import '../features/reports/domain/usecases/export_report_pdf_usecase.dart';

import '../features/receipt_scanner/domain/entities/receipt_draft.dart';
import '../features/receipt_scanner/domain/entities/receipt_metadata.dart';
import '../features/receipt_scanner/domain/repositories/receipt_metadata_repository.dart';
import '../features/receipt_scanner/data/datasources/receipt_metadata_remote_data_source.dart';
import '../features/receipt_scanner/data/repositories/receipt_metadata_repository_impl.dart';
import '../features/receipt_scanner/domain/repositories/receipt_ocr_service.dart';
import '../features/receipt_scanner/domain/repositories/receipt_understanding_service.dart';
import '../features/receipt_scanner/data/services/receipt_ocr_service_impl.dart';
import '../features/receipt_scanner/data/services/local_receipt_parser.dart';
import '../features/receipt_scanner/data/services/attachment_storage_service.dart';
import '../features/receipt_scanner/domain/usecases/scan_receipt_usecase.dart';
import '../features/receipt_scanner/domain/usecases/confirm_receipt_transaction_usecase.dart';
import '../features/receipt_scanner/presentation/controllers/receipt_scanner_controller.dart';

import '../features/settings/domain/entities/app_setting.dart';
import '../features/settings/domain/repositories/settings_repository.dart';
import '../features/settings/data/datasources/settings_remote_data_source.dart';
import '../features/settings/data/repositories/settings_repository_impl.dart';

import '../features/backup_restore/domain/repositories/backup_repository.dart';
import '../features/backup_restore/data/datasources/backup_remote_data_source.dart';
import '../features/backup_restore/data/repositories/backup_repository_impl.dart';
import '../features/backup_restore/data/services/backup_validator_service.dart';
import '../features/backup_restore/domain/usecases/create_backup_usecase.dart';
import '../features/backup_restore/domain/usecases/validate_backup_usecase.dart';
import '../features/backup_restore/domain/usecases/restore_backup_usecase.dart';
import '../features/backup_restore/domain/usecases/reset_database_usecase.dart';
import '../features/backup_restore/presentation/controllers/backup_restore_controller.dart';
import '../core/services/app_lock_service.dart';
import '../core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import '../features/security/presentation/controllers/app_lock_controller.dart';
import '../features/auth/domain/entities/auth_user.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/migration/domain/repositories/migration_repository.dart';
import '../features/migration/data/datasources/migration_remote_data_source.dart';
import '../features/migration/data/repositories/migration_repository_impl.dart';
import '../features/migration/presentation/controllers/migration_controller.dart';

/// App Theme Provider
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// Database provider tunggal (Singleton per ProviderScope)
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// DAOs
final walletsDaoProvider = Provider<WalletsDao>((ref) {
  final db = ref.watch(databaseProvider);
  return WalletsDao(db);
});

final categoriesDaoProvider = Provider<CategoriesDao>((ref) {
  final db = ref.watch(databaseProvider);
  return CategoriesDao(db);
});

final transactionsDaoProvider = Provider<TransactionsDao>((ref) {
  final db = ref.watch(databaseProvider);
  return TransactionsDao(db);
});

final budgetsDaoProvider = Provider<BudgetsDao>((ref) {
  final db = ref.watch(databaseProvider);
  return BudgetsDao(db);
});

final appSettingsDaoProvider = Provider<AppSettingsDao>((ref) {
  final db = ref.watch(databaseProvider);
  return AppSettingsDao(db);
});

// Repositories
final walletRemoteDataSourceProvider = Provider<WalletRemoteDataSource>((ref) {
  return WalletRemoteDataSourceImpl(
    supabaseService: ref.watch(supabaseServiceProvider),
  );
});

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  final dao = ref.watch(walletsDaoProvider);
  final txDao = ref.watch(transactionsDaoProvider);
  final remoteDataSource = ref.watch(walletRemoteDataSourceProvider);
  final supabaseService = ref.watch(supabaseServiceProvider);
  return WalletRepositoryImpl(
    dao,
    txDao,
    remoteDataSource: remoteDataSource,
    supabaseService: supabaseService,
  );
});

final categoryRemoteDataSourceProvider = Provider<CategoryRemoteDataSource>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return CategoryRemoteDataSourceImpl(supabaseService: supabaseService);
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final dao = ref.watch(categoriesDaoProvider);
  final txDao = ref.watch(transactionsDaoProvider);
  final remoteDataSource = ref.watch(categoryRemoteDataSourceProvider);
  final supabaseService = ref.watch(supabaseServiceProvider);
  return CategoryRepositoryImpl(
    dao,
    transactionsDao: txDao,
    remoteDataSource: remoteDataSource,
    supabaseService: supabaseService,
  );
});

final transactionRemoteDataSourceProvider = Provider<TransactionRemoteDataSource>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return TransactionRemoteDataSourceImpl(supabaseService: supabaseService);
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final txDao = ref.watch(transactionsDaoProvider);
  final walletDao = ref.watch(walletsDaoProvider);
  final catDao = ref.watch(categoriesDaoProvider);
  final remoteDataSource = ref.watch(transactionRemoteDataSourceProvider);
  final supabaseService = ref.watch(supabaseServiceProvider);
  return TransactionRepositoryImpl(
    txDao,
    walletDao,
    catDao,
    remoteDataSource: remoteDataSource,
    supabaseService: supabaseService,
  );
});

final transferRemoteDataSourceProvider = Provider<TransferRemoteDataSource>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return TransferRemoteDataSourceImpl(supabaseService: supabaseService);
});

final transferRepositoryProvider = Provider<TransferRepository>((ref) {
  final txDao = ref.watch(transactionsDaoProvider);
  final walletDao = ref.watch(walletsDaoProvider);
  final remoteDataSource = ref.watch(transferRemoteDataSourceProvider);
  final supabaseService = ref.watch(supabaseServiceProvider);
  return TransferRepositoryImpl(
    txDao,
    walletDao,
    remoteDataSource: remoteDataSource,
    supabaseService: supabaseService,
  );
});

final transferControllerProvider =
    StateNotifierProvider<TransferController, AsyncValue<void>>((ref) {
  final repo = ref.watch(transferRepositoryProvider);
  return TransferController(repo);
});

final transfersStreamProvider = StreamProvider<List<Transfer>>((ref) {
  final repo = ref.watch(transferRepositoryProvider);
  return repo.watchTransfers(limit: 100);
});

final transfersForWalletStreamProvider =
    StreamProvider.family<List<Transfer>, String>((ref, walletId) {
  final repo = ref.watch(transferRepositoryProvider);
  return repo.watchTransfersForWallet(walletId);
});

final budgetRemoteDataSourceProvider = Provider<BudgetRemoteDataSource>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return BudgetRemoteDataSourceImpl(supabaseService: supabaseService);
});

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  final budgetsDao = ref.watch(budgetsDaoProvider);
  final txDao = ref.watch(transactionsDaoProvider);
  final catDao = ref.watch(categoriesDaoProvider);
  final remoteDataSource = ref.watch(budgetRemoteDataSourceProvider);
  final supabaseService = ref.watch(supabaseServiceProvider);
  return BudgetRepositoryImpl(
    budgetsDao,
    txDao,
    catDao,
    remoteDataSource: remoteDataSource,
    supabaseService: supabaseService,
  );
});

final allBudgetsStreamProvider = StreamProvider<List<Budget>>((ref) {
  final repo = ref.watch(budgetRepositoryProvider);
  return repo.watchAllBudgets();
});

// Reactive Streams for Wallets
final walletsStreamProvider = StreamProvider<List<Wallet>>((ref) {
  final repo = ref.watch(walletRepositoryProvider);
  return repo.watchActiveWallets();
});

final walletsWithBalanceStreamProvider = StreamProvider<List<WalletWithBalance>>((ref) {
  final repo = ref.watch(walletRepositoryProvider);
  return repo.watchActiveWalletsWithBalance();
});

final archivedWalletsWithBalanceStreamProvider = StreamProvider<List<WalletWithBalance>>((ref) {
  final repo = ref.watch(walletRepositoryProvider);
  return repo.watchArchivedWalletsWithBalance();
});

/// Saldo operasional aktif (hanya dompet aktif - digunakan pada Tab Home "Total Saldo Bersih")
final netOperationalBalanceProvider = Provider<int>((ref) {
  final walletsAsync = ref.watch(walletsWithBalanceStreamProvider);
  return walletsAsync.maybeWhen(
    data: (wallets) => wallets.fold<int>(0, (sum, w) => sum + w.currentBalance),
    orElse: () => 0,
  );
});

/// Total seluruh saldo aset (dompet aktif + dompet diarsipkan - digunakan pada Tab Dompet & Rekening "Total Saldo Aset")
final totalAllAssetBalanceProvider = Provider<int>((ref) {
  final activeAsync = ref.watch(walletsWithBalanceStreamProvider);
  final archivedAsync = ref.watch(archivedWalletsWithBalanceStreamProvider);

  final activeSum = activeAsync.maybeWhen(
    data: (wallets) => wallets.fold<int>(0, (sum, w) => sum + w.currentBalance),
    orElse: () => 0,
  );
  final archivedSum = archivedAsync.maybeWhen(
    data: (wallets) => wallets.fold<int>(0, (sum, w) => sum + w.currentBalance),
    orElse: () => 0,
  );

  return activeSum + archivedSum;
});

final totalAssetBalanceProvider = netOperationalBalanceProvider;

// Reactive Streams for Transactions
final recentTransactionsStreamProvider = StreamProvider<List<TransactionWithDetails>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchRecentTransactions(limit: 250);
});

/// Bulan yang dipilih pada Tab Riwayat Transaksi (format: DateTime(year, month, 1))
final selectedTransactionMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

// Categories Stream
final activeCategoriesStreamProvider = StreamProvider.family<List<Category>, CategoryType>((ref, type) {
  final repo = ref.watch(categoryRepositoryProvider);
  return repo.watchActiveCategoriesByType(type);
});

final allCategoriesFutureProvider = FutureProvider<List<Category>>((ref) {
  final repo = ref.watch(categoryRepositoryProvider);
  return repo.getAllActiveCategories();
});

// Budgets Streams & Providers
final selectedBudgetMonthProvider = StateProvider<String>((ref) {
  return AppDateFormatter.toMonthKey(DateTime.now());
});

final budgetProgressStreamProvider = StreamProvider.family<BudgetProgress, String>((ref, monthKey) {
  final repo = ref.watch(budgetRepositoryProvider);
  return repo.watchBudgetProgress(monthKey);
});

final monthlyIncomeProvider = StreamProvider.family<int, String>((ref, monthKey) {
  final parts = monthKey.split('-');
  final year = int.parse(parts[0]);
  final month = int.parse(parts[1]);
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchMonthlyIncome(year, month);
});

final monthlyExpenseProvider = StreamProvider.family<int, String>((ref, monthKey) {
  final parts = monthKey.split('-');
  final year = int.parse(parts[0]);
  final month = int.parse(parts[1]);
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchMonthlyExpense(year, month);
});

// Reports Providers
final selectedReportMonthProvider = StateProvider<String>((ref) {
  return AppDateFormatter.toMonthKey(DateTime.now());
});

final reportRemoteDataSourceProvider = Provider<ReportRemoteDataSource?>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  if (supabaseService.clientOrNull == null) return null;
  return ReportRemoteDataSourceImpl(
    supabaseService: supabaseService,
  );
});

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  final txRepo = ref.watch(transactionRepositoryProvider);
  final walletRepo = ref.watch(walletRepositoryProvider);
  final remoteDataSource = ref.watch(reportRemoteDataSourceProvider);
  final supabaseService = ref.watch(supabaseServiceProvider);
  return ReportRepositoryImpl(
    transactionRepository: txRepo,
    walletRepository: walletRepo,
    remoteDataSource: remoteDataSource,
    supabaseService: supabaseService,
  );
});

final availableReportMonthsProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.watch(reportRepositoryProvider);
  return repo.getAvailableReportMonths();
});

final getMonthlyReportUseCaseProvider = Provider<GetMonthlyReportUseCase>((ref) {
  return GetMonthlyReportUseCase(ref.watch(reportRepositoryProvider));
});

final exportReportCsvUseCaseProvider = Provider<ExportReportCsvUseCase>((ref) {
  return ExportReportCsvUseCase(ref.watch(reportRepositoryProvider));
});

final exportReportPdfUseCaseProvider = Provider<ExportReportPdfUseCase>((ref) {
  return ExportReportPdfUseCase(ref.watch(reportRepositoryProvider));
});

final monthlyReportProvider = FutureProvider.family<MonthlyReport, String>((ref, monthKey) async {
  // Re-run report when recent transactions change
  ref.watch(recentTransactionsStreamProvider);
  final useCase = ref.watch(getMonthlyReportUseCaseProvider);
  return useCase.execute(monthKey);
});

// Controllers
final walletsControllerProvider = StateNotifierProvider<WalletsController, AsyncValue<void>>((ref) {
  final repo = ref.watch(walletRepositoryProvider);
  return WalletsController(repo);
});

final transactionsControllerProvider = StateNotifierProvider<TransactionsController, AsyncValue<void>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return TransactionsController(repo);
});

final budgetsControllerProvider = StateNotifierProvider<BudgetsController, AsyncValue<void>>((ref) {
  final repo = ref.watch(budgetRepositoryProvider);
  return BudgetsController(repo);
});

// Receipt Scanner Providers
final receiptOcrServiceProvider = Provider<ReceiptOcrService>((ref) {
  return const ReceiptOcrServiceImpl();
});

final receiptUnderstandingServiceProvider = Provider<ReceiptUnderstandingService>((ref) {
  return const LocalReceiptParser();
});

final receiptMetadataRemoteDataSourceProvider = Provider<ReceiptMetadataRemoteDataSource?>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  if (supabaseService.clientOrNull == null) return null;
  return ReceiptMetadataRemoteDataSourceImpl(
    supabaseService: supabaseService,
  );
});

final receiptMetadataRepositoryProvider = Provider<ReceiptMetadataRepository>((ref) {
  final dao = ref.watch(transactionsDaoProvider);
  final remoteDataSource = ref.watch(receiptMetadataRemoteDataSourceProvider);
  final supabaseService = ref.watch(supabaseServiceProvider);
  return ReceiptMetadataRepositoryImpl(
    dao,
    remoteDataSource: remoteDataSource,
    supabaseService: supabaseService,
  );
});

final receiptMetadataForTransactionStreamProvider =
    StreamProvider.family<List<ReceiptMetadata>, String>((ref, transactionId) {
  final repo = ref.watch(receiptMetadataRepositoryProvider);
  return repo.watchReceiptMetadataForTransaction(transactionId);
});

final totalReceiptStorageBytesProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(receiptMetadataRepositoryProvider);
  return repo.getTotalReceiptStorageBytes();
});

final attachmentStorageServiceProvider = Provider<AttachmentStorageService>((ref) {
  final dao = ref.watch(transactionsDaoProvider);
  final repo = ref.watch(receiptMetadataRepositoryProvider);
  return AttachmentStorageService(dao, metadataRepository: repo);
});

final scanReceiptUseCaseProvider = Provider<ScanReceiptUseCase>((ref) {
  return ScanReceiptUseCase(
    ref.watch(receiptOcrServiceProvider),
    ref.watch(receiptUnderstandingServiceProvider),
  );
});

final confirmReceiptTransactionUseCaseProvider = Provider<ConfirmReceiptTransactionUseCase>((ref) {
  return ConfirmReceiptTransactionUseCase(
    ref.watch(transactionRepositoryProvider),
    ref.watch(attachmentStorageServiceProvider),
  );
});

final receiptScannerControllerProvider = StateNotifierProvider<ReceiptScannerController, AsyncValue<ReceiptDraft?>>((ref) {
  return ReceiptScannerController(
    ref.watch(scanReceiptUseCaseProvider),
    ref.watch(confirmReceiptTransactionUseCaseProvider),
  );
});

// Backup & Restore Providers
final backupValidatorServiceProvider = Provider<BackupValidatorService>((ref) {
  return const BackupValidatorService();
});

final backupRemoteDataSourceProvider = Provider<BackupRemoteDataSource?>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  if (supabaseService.clientOrNull == null) return null;
  return BackupRemoteDataSourceImpl(supabaseService: supabaseService);
});

final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final validator = ref.watch(backupValidatorServiceProvider);
  final remoteDataSource = ref.watch(backupRemoteDataSourceProvider);
  final supabaseService = ref.watch(supabaseServiceProvider);
  return BackupRepositoryImpl(
    db,
    validatorService: validator,
    remoteDataSource: remoteDataSource,
    supabaseService: supabaseService,
  );
});

final createBackupUseCaseProvider = Provider<CreateBackupUseCase>((ref) {
  return CreateBackupUseCase(ref.watch(backupRepositoryProvider));
});

final validateBackupUseCaseProvider = Provider<ValidateBackupUseCase>((ref) {
  return ValidateBackupUseCase(ref.watch(backupRepositoryProvider));
});

final restoreBackupUseCaseProvider = Provider<RestoreBackupUseCase>((ref) {
  return RestoreBackupUseCase(ref.watch(backupRepositoryProvider));
});

final resetDatabaseUseCaseProvider = Provider<ResetDatabaseUseCase>((ref) {
  return ResetDatabaseUseCase(ref.watch(backupRepositoryProvider));
});

final backupRestoreControllerProvider = StateNotifierProvider.autoDispose<BackupRestoreController, BackupRestoreState>((ref) {
  return BackupRestoreController(
    createBackupUseCase: ref.watch(createBackupUseCaseProvider),
    validateBackupUseCase: ref.watch(validateBackupUseCaseProvider),
    restoreBackupUseCase: ref.watch(restoreBackupUseCaseProvider),
    resetDatabaseUseCase: ref.watch(resetDatabaseUseCaseProvider),
    ref: ref,
  );
});

final settingsRemoteDataSourceProvider = Provider<SettingsRemoteDataSource?>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  if (supabaseService.clientOrNull == null) return null;
  return SettingsRemoteDataSourceImpl(
    supabaseService: supabaseService,
  );
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final dao = ref.watch(appSettingsDaoProvider);
  final remoteDataSource = ref.watch(settingsRemoteDataSourceProvider);
  final supabaseService = ref.watch(supabaseServiceProvider);
  return SettingsRepositoryImpl(
    dao,
    remoteDataSource: remoteDataSource,
    supabaseService: supabaseService,
  );
});

final appSettingStreamProvider = StreamProvider.family<String?, String>((ref, key) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.watchSetting(key);
});

final allSettingsStreamProvider = StreamProvider<List<AppSetting>>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.watchAllSettings();
});

// App Lock & Biometrics
final appLockServiceProvider = Provider<AppLockService>((ref) {
  return AppLockService();
});

final appLockControllerProvider = StateNotifierProvider<AppLockController, AppLockState>((ref) {
  return AppLockController(
    lockService: ref.watch(appLockServiceProvider),
    appSettingsDao: ref.watch(appSettingsDaoProvider),
    settingsRepository: ref.watch(settingsRepositoryProvider),
  );
});

// ============================================================================
// Supabase Infrastructure Providers
// ============================================================================
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

final supabaseClientProvider = Provider<sp.SupabaseClient?>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return service.clientOrNull;
});

final supabaseAuthStateProvider = StreamProvider<sp.AuthState>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return service.authStateChanges;
});

final supabaseCurrentUserProvider = Provider<sp.User?>((ref) {
  final authStateAsync = ref.watch(supabaseAuthStateProvider);
  return authStateAsync.maybeWhen(
    data: (state) => state.session?.user,
    orElse: () => ref.watch(supabaseServiceProvider).currentUser,
  );
});

final supabaseConnectionStatusProvider = FutureProvider<SupabaseConnectionResult>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return service.checkConnection();
});

// ============================================================================
// Supabase Authentication Providers
// ============================================================================
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    supabaseService: ref.watch(supabaseServiceProvider),
  );
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    authRepository: ref.watch(authRepositoryProvider),
    appDatabase: ref.watch(databaseProvider),
    ref: ref,
  );
});

final authCurrentUserProvider = Provider<AuthUser?>((ref) {
  return ref.watch(authControllerProvider).user;
});

final authStateChangesProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

// ============================================================================
// Data Migration Providers (SQLite to Supabase Cloud)
// ============================================================================
final migrationRemoteDataSourceProvider = Provider<MigrationRemoteDataSource?>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  if (supabaseService.clientOrNull == null) return null;
  return MigrationRemoteDataSourceImpl(supabaseService: supabaseService);
});

final migrationRepositoryProvider = Provider<MigrationRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final appSettingsDao = ref.watch(appSettingsDaoProvider);
  final remoteDataSource = ref.watch(migrationRemoteDataSourceProvider);
  final supabaseService = ref.watch(supabaseServiceProvider);
  return MigrationRepositoryImpl(
    db: db,
    appSettingsDao: appSettingsDao,
    remoteDataSource: remoteDataSource,
    supabaseService: supabaseService,
  );
});

final migrationControllerProvider =
    StateNotifierProvider<MigrationController, MigrationState>((ref) {
  final repo = ref.watch(migrationRepositoryProvider);
  return MigrationController(repo, ref);
});
