import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/budgets_dao.dart';
import '../../../../core/database/daos/transactions_dao.dart';
import '../../../../core/database/daos/categories_dao.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/supabase_service.dart';
import '../../domain/entities/budget.dart';
import '../../domain/repositories/budget_repository.dart';
import '../datasources/budget_remote_data_source.dart';
import '../models/budget_model.dart';
import '../../../categories/data/models/category_model.dart';

/// Implementasi BudgetRepository dengan pola Offline-First Hybrid:
/// - Reaktivitas instan (0 ms) didorong oleh SQLite lokal (Drift)
/// - Sinkronisasi atomik master budget & category limits ke Supabase Cloud PostgreSQL
/// - Evaluasi isolasi data per pengguna aktif (user_id) sesuai Row Level Security (RLS)
/// - Perhitungan status anggaran (Aman, Warning, Kritis, Melebihi) berdasarkan confirmed expenses
class BudgetRepositoryImpl implements BudgetRepository {
  final BudgetsDao _budgetsDao;
  final TransactionsDao _transactionsDao;
  final CategoriesDao _categoriesDao;
  final BudgetRemoteDataSource? _remoteDataSource;
  final SupabaseService? _supabaseService;

  final StreamController<void> _cloudSyncEventController =
      StreamController<void>.broadcast();

  bool _isFetchingCloud = false;

  BudgetRepositoryImpl(
    this._budgetsDao,
    this._transactionsDao,
    this._categoriesDao, {
    BudgetRemoteDataSource? remoteDataSource,
    SupabaseService? supabaseService,
  })  : _remoteDataSource = remoteDataSource,
        _supabaseService = supabaseService;

  bool get isCloudActive {
    final svc = _supabaseService;
    return svc != null && svc.isAuthenticated && _remoteDataSource != null;
  }

  String? get currentUserId => _supabaseService?.currentUser?.id;

  Future<void> _syncBudgetToLocal(Budget budget) async {
    await _budgetsDao.insertOrReplaceBudget(
      BudgetsTableCompanion(
        id: Value(budget.id),
        monthKey: Value(budget.monthKey),
        totalLimit: Value(budget.totalLimit),
        alertThresholds: Value(budget.alertThresholdsJson),
        carryOverEnabled: Value(budget.carryOverEnabled),
        notes: Value(budget.notes),
        createdAt: Value(budget.createdAt),
        updatedAt: Value(budget.updatedAt),
      ),
    );
  }

  Future<void> _syncCategoryLimitsToLocal(
    String budgetId,
    List<BudgetCategoryLimit> limits,
  ) async {
    await _budgetsDao.deleteCategoryLimitsForBudget(budgetId);
    for (final limit in limits) {
      await _budgetsDao.insertOrReplaceCategoryLimit(
        BudgetCategoryLimitsTableCompanion(
          id: Value(limit.id),
          budgetId: Value(limit.budgetId),
          categoryId: Value(limit.categoryId),
          limitAmount: Value(limit.limitAmount),
        ),
      );
    }
  }

  @override
  Future<List<Budget>> getAllBudgets() async {
    if (isCloudActive) {
      try {
        final cloudBudgets = await _remoteDataSource!.getBudgets(currentUserId!);
        for (final b in cloudBudgets) {
          await _syncBudgetToLocal(b);
        }
        return cloudBudgets;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[BudgetRepositoryImpl] Cloud getAllBudgets warning, fallback lokal: $e');
        }
      }
    }

    final entries = await _budgetsDao.getAllBudgets();
    return entries.map(BudgetModel.fromEntry).toList();
  }

  @override
  Stream<List<Budget>> watchAllBudgets() {
    if (isCloudActive) {
      late StreamController<List<Budget>> controller;
      StreamSubscription? subLocal;
      StreamSubscription? subSync;

      void emitFromCache() async {
        try {
          final entries = await _budgetsDao.getAllBudgets();
          final budgets = entries.map(BudgetModel.fromEntry).toList();
          if (!controller.isClosed) {
            controller.add(budgets);
          }
        } catch (_) {}
      }

      void syncAndRefresh() async {
        if (_isFetchingCloud) return;
        _isFetchingCloud = true;
        try {
          final cloudBudgets = await _remoteDataSource!.getBudgets(currentUserId!);
          for (final b in cloudBudgets) {
            await _syncBudgetToLocal(b);
          }
          if (!controller.isClosed) {
            controller.add(cloudBudgets);
          }
        } catch (e) {
          emitFromCache();
        } finally {
          _isFetchingCloud = false;
        }
      }

      controller = StreamController<List<Budget>>(
        onListen: () {
          emitFromCache();
          syncAndRefresh();

          subLocal = _budgetsDao.watchAllBudgets().listen((_) => emitFromCache());
          subSync = _cloudSyncEventController.stream.listen((_) => syncAndRefresh());
        },
        onCancel: () {
          subLocal?.cancel();
          subSync?.cancel();
          controller.close();
        },
      );

      return controller.stream;
    }

    return _budgetsDao.watchAllBudgets().map(
          (entries) => entries.map(BudgetModel.fromEntry).toList(),
        );
  }

  @override
  Future<Budget?> getBudgetByMonthKey(String monthKey) async {
    // 1. Cek cache lokal terlebih dahulu (0 ms)
    final localEntry = await _budgetsDao.getBudgetByMonthKey(monthKey);
    if (localEntry != null) {
      return BudgetModel.fromEntry(localEntry);
    }

    // 2. Ambil dari cloud jika belum ada di lokal
    if (isCloudActive) {
      try {
        final cloudBudget = await _remoteDataSource!.getBudgetByMonthKey(
          monthKey,
          currentUserId!,
        );
        if (cloudBudget != null) {
          await _syncBudgetToLocal(cloudBudget);
          final cloudLimits = await _remoteDataSource.getCategoryLimits(
            cloudBudget.id,
            currentUserId!,
          );
          await _syncCategoryLimitsToLocal(cloudBudget.id, cloudLimits);
          return cloudBudget;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[BudgetRepositoryImpl] Cloud fetch warning by monthKey: $e');
        }
      }
    }

    return null;
  }

  @override
  Stream<Budget?> watchBudgetByMonthKey(String monthKey) {
    if (isCloudActive) {
      late StreamController<Budget?> controller;
      StreamSubscription? subLocal;
      StreamSubscription? subSync;

      void emitFromCache() async {
        try {
          final entry = await _budgetsDao.getBudgetByMonthKey(monthKey);
          if (!controller.isClosed) {
            controller.add(entry != null ? BudgetModel.fromEntry(entry) : null);
          }
        } catch (_) {}
      }

      void syncAndRefresh() async {
        if (_isFetchingCloud) return;
        _isFetchingCloud = true;
        try {
          final cloudBudget = await _remoteDataSource!.getBudgetByMonthKey(
            monthKey,
            currentUserId!,
          );
          if (cloudBudget != null) {
            await _syncBudgetToLocal(cloudBudget);
            final cloudLimits = await _remoteDataSource.getCategoryLimits(
              cloudBudget.id,
              currentUserId!,
            );
            await _syncCategoryLimitsToLocal(cloudBudget.id, cloudLimits);
            if (!controller.isClosed) {
              controller.add(cloudBudget);
            }
          }
        } catch (e) {
          emitFromCache();
        } finally {
          _isFetchingCloud = false;
        }
      }

      controller = StreamController<Budget?>(
        onListen: () {
          emitFromCache();
          syncAndRefresh();

          subLocal = _budgetsDao.watchBudgetByMonthKey(monthKey).listen((entry) {
            if (!controller.isClosed) {
              controller.add(entry != null ? BudgetModel.fromEntry(entry) : null);
            }
          });
          subSync = _cloudSyncEventController.stream.listen((_) => syncAndRefresh());
        },
        onCancel: () {
          subLocal?.cancel();
          subSync?.cancel();
          controller.close();
        },
      );

      return controller.stream;
    }

    return _budgetsDao.watchBudgetByMonthKey(monthKey).map(
          (entry) => entry != null ? BudgetModel.fromEntry(entry) : null,
        );
  }

  @override
  Future<Budget?> getBudgetById(String id) async {
    final localEntry = await _budgetsDao.getBudgetById(id);
    if (localEntry != null) {
      return BudgetModel.fromEntry(localEntry);
    }

    if (isCloudActive) {
      try {
        final cloudBudget = await _remoteDataSource!.getBudgetById(id, currentUserId!);
        if (cloudBudget != null) {
          await _syncBudgetToLocal(cloudBudget);
          return cloudBudget;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[BudgetRepositoryImpl] Cloud fetch warning by ID: $e');
        }
      }
    }

    return null;
  }

  @override
  Future<List<BudgetCategoryLimit>> getCategoryLimits(String budgetId) async {
    final localEntries = await _budgetsDao.getCategoryLimitsForBudget(budgetId);
    if (localEntries.isNotEmpty) {
      return localEntries.map(BudgetModel.categoryLimitFromEntry).toList();
    }

    if (isCloudActive) {
      try {
        final cloudLimits = await _remoteDataSource!.getCategoryLimits(
          budgetId,
          currentUserId!,
        );
        if (cloudLimits.isNotEmpty) {
          await _syncCategoryLimitsToLocal(budgetId, cloudLimits);
          return cloudLimits;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[BudgetRepositoryImpl] Cloud category limits warning: $e');
        }
      }
    }

    return [];
  }

  @override
  Stream<List<BudgetCategoryLimit>> watchCategoryLimits(String budgetId) {
    return _budgetsDao.watchCategoryLimitsForBudget(budgetId).map(
          (entries) => entries.map(BudgetModel.categoryLimitFromEntry).toList(),
        );
  }

  @override
  Future<BudgetProgress> getBudgetProgress(String monthKey) async {
    // 1. Parse month key (YYYY-MM)
    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    // Batas waktu awal dan akhir bulan lokal dikonversi ke ISO UTC
    final startIso = DateTime(year, month, 1).toUtc().toIso8601String();
    final endIso = DateTime(year, month + 1, 0, 23, 59, 59, 999).toUtc().toIso8601String();

    // 2. Ambil transaksi pengeluaran (confirmed expense) saja (Transfer & Income excluded)
    final expenses = await _transactionsDao.getConfirmedExpensesInDateRange(startIso, endIso);

    int totalSpent = 0;
    final categorySpentMap = <String, int>{};

    for (final exp in expenses) {
      totalSpent += exp.amount;
      if (exp.categoryId != null) {
        categorySpentMap[exp.categoryId!] = (categorySpentMap[exp.categoryId!] ?? 0) + exp.amount;
      }
    }

    // 3. Ambil budget master bulan ini (dari lokal atau cloud jika belum ada)
    final budget = await getBudgetByMonthKey(monthKey);
    int totalLimit = 0;
    int remaining = 0;
    double percentage = 0.0;
    BudgetStatus status = BudgetStatus.normal;
    bool hasConfigurationWarning = false;
    final categoryProgresses = <BudgetCategoryProgress>[];

    if (budget != null) {
      totalLimit = budget.totalLimit;
      remaining = totalLimit - totalSpent;
      percentage = totalLimit > 0 ? (totalSpent / totalLimit) : 0.0;
      status = BudgetStatus.fromPercentage(percentage);

      // 4. Ambil limits per kategori
      final limits = await getCategoryLimits(budget.id);
      int sumCategoryLimits = 0;

      for (final limit in limits) {
        sumCategoryLimits += limit.limitAmount;
        final catEntry = await _categoriesDao.getCategoryById(limit.categoryId);
        if (catEntry != null) {
          final cat = CategoryModel.fromEntry(catEntry);
          final spent = categorySpentMap[limit.categoryId] ?? 0;
          final rem = limit.limitAmount - spent;
          final pct = limit.limitAmount > 0 ? (spent / limit.limitAmount) : 0.0;
          categoryProgresses.add(
            BudgetCategoryProgress(
              category: cat,
              limitAmount: limit.limitAmount,
              spentAmount: spent,
              remainingAmount: rem,
              percentage: pct,
              status: BudgetStatus.fromPercentage(pct),
            ),
          );
        }
      }

      // Deteksi peringatan jika total alokasi kategori melebihi total plafon anggaran
      if (sumCategoryLimits > totalLimit) {
        hasConfigurationWarning = true;
      }
    }

    return BudgetProgress(
      budget: budget,
      monthKey: monthKey,
      totalLimit: totalLimit,
      totalSpent: totalSpent,
      remaining: remaining,
      percentage: percentage,
      status: status,
      hasConfigurationWarning: hasConfigurationWarning,
      categoryProgresses: categoryProgresses,
    );
  }

  @override
  Stream<BudgetProgress> watchBudgetProgress(String monthKey) {
    late StreamController<BudgetProgress> controller;
    StreamSubscription? subBudget;
    StreamSubscription? subCategoryLimits;
    StreamSubscription? subTransactions;
    StreamSubscription? subSync;

    bool isRefreshing = false;
    bool pendingRefresh = false;

    void refresh() async {
      if (isRefreshing) {
        pendingRefresh = true;
        return;
      }
      isRefreshing = true;
      try {
        do {
          pendingRefresh = false;
          final progress = await getBudgetProgress(monthKey);
          if (!controller.isClosed) {
            controller.add(progress);
          }
        } while (pendingRefresh);
      } catch (e, st) {
        if (!controller.isClosed) {
          controller.addError(e, st);
        }
      } finally {
        isRefreshing = false;
      }
    }

    controller = StreamController<BudgetProgress>(
      onListen: () {
        refresh();
        subBudget = _budgetsDao.watchBudgetByMonthKey(monthKey).listen((_) => refresh());
        subCategoryLimits = _budgetsDao.watchAllCategoryLimits().listen((_) => refresh());
        subTransactions = _transactionsDao.watchRecentTransactions(limit: 1).listen((_) => refresh());
        subSync = _cloudSyncEventController.stream.listen((_) => refresh());
      },
      onCancel: () {
        subBudget?.cancel();
        subCategoryLimits?.cancel();
        subTransactions?.cancel();
        subSync?.cancel();
        controller.close();
      },
    );

    return controller.stream;
  }

  @override
  Future<void> saveBudget({
    required Budget budget,
    required List<BudgetCategoryLimit> categoryLimits,
  }) async {
    // 1. Validasi
    if (budget.totalLimit <= 0) {
      throw const ValidationFailure('Total limit budget bulanan harus lebih dari 0.');
    }
    if (!RegExp(r'^[0-9]{4}-[0-9]{2}$').hasMatch(budget.monthKey)) {
      throw const ValidationFailure('Format bulan tidak valid. Gunakan format YYYY-MM.');
    }

    final validCategoryLimits = categoryLimits.where((l) => l.limitAmount > 0).toList();

    // 2. Simpan master budget dan limit kategori dalam satu transaksi atomik lokal
    final existing = await _budgetsDao.getBudgetByMonthKey(budget.monthKey);
    final now = DateTime.now().toUtc().toIso8601String();
    final effectiveBudgetId = existing?.id ?? budget.id;
    final isUpdate = existing != null;

    final budgetCompanion = isUpdate
        ? BudgetsTableCompanion(
            id: Value(existing.id),
            monthKey: Value(budget.monthKey),
            totalLimit: Value(budget.totalLimit),
            alertThresholds: Value(budget.alertThresholdsJson),
            carryOverEnabled: Value(budget.carryOverEnabled),
            notes: Value(budget.notes),
            createdAt: Value(existing.createdAt),
            updatedAt: Value(now),
          )
        : BudgetsTableCompanion.insert(
            id: budget.id,
            monthKey: budget.monthKey,
            totalLimit: budget.totalLimit,
            alertThresholds: Value(budget.alertThresholdsJson),
            carryOverEnabled: Value(budget.carryOverEnabled),
            notes: Value(budget.notes),
            createdAt: now,
            updatedAt: now,
          );

    final limitCompanions = validCategoryLimits.map((limit) {
      return BudgetCategoryLimitsTableCompanion.insert(
        id: limit.id,
        budgetId: effectiveBudgetId,
        categoryId: limit.categoryId,
        limitAmount: limit.limitAmount,
      );
    }).toList();

    // Commit ke SQLite lokal
    await _budgetsDao.saveBudgetWithLimits(
      budget: budgetCompanion,
      isUpdate: isUpdate,
      effectiveBudgetId: effectiveBudgetId,
      limits: limitCompanions,
    );

    // 3. Simpan ke Supabase Cloud jika sesi aktif
    if (isCloudActive) {
      final cloudBudget = budget.copyWith(
        id: effectiveBudgetId,
        createdAt: isUpdate ? existing.createdAt : budget.createdAt,
        updatedAt: now,
      );
      final cloudLimits = validCategoryLimits.map((l) {
        return BudgetCategoryLimit(
          id: l.id,
          budgetId: effectiveBudgetId,
          categoryId: l.categoryId,
          limitAmount: l.limitAmount,
        );
      }).toList();

      await _remoteDataSource!.saveBudget(
        budget: cloudBudget,
        categoryLimits: cloudLimits,
        userId: currentUserId!,
      );
    }

    _cloudSyncEventController.add(null);
  }

  @override
  Future<void> deleteBudget(String budgetId) async {
    // 1. Hapus dari SQLite lokal
    await _budgetsDao.deleteCategoryLimitsForBudget(budgetId);
    await _budgetsDao.deleteBudget(budgetId);

    // 2. Hapus dari Supabase Cloud
    if (isCloudActive) {
      await _remoteDataSource!.deleteBudget(budgetId, currentUserId!);
    }

    _cloudSyncEventController.add(null);
  }
}
