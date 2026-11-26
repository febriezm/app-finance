import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/categories_dao.dart';
import '../../../../core/database/daos/transactions_dao.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/supabase_service.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';
import '../datasources/category_remote_data_source.dart';
import '../models/category_model.dart';

/// Implementasi CategoryRepository dengan pola Offline-First:
/// - Reaktivitas instan (0 ms) didorong oleh SQLite lokal (Drift)
/// - Sinkronisasi aman & konsisten ke Supabase Cloud PostgreSQL
/// - Proteksi rekursi (_isSyncing) mencegah feedback loop HTTP query
/// - Perlindungan integritas: Kategori sistem (is_system = true) tidak dapat diubah/dihapus
class CategoryRepositoryImpl implements CategoryRepository {
  final CategoriesDao _categoriesDao;
  final TransactionsDao? _transactionsDao;
  final CategoryRemoteDataSource? _remoteDataSource;
  final SupabaseService? _supabaseService;

  final StreamController<void> _cloudSyncEventController =
      StreamController<void>.broadcast();

  CategoryRepositoryImpl(
    this._categoriesDao, {
    TransactionsDao? transactionsDao,
    CategoryRemoteDataSource? remoteDataSource,
    SupabaseService? supabaseService,
  })  : _transactionsDao = transactionsDao,
        _remoteDataSource = remoteDataSource,
        _supabaseService = supabaseService;

  bool get isCloudActive {
    final svc = _supabaseService;
    return svc != null && svc.isAuthenticated && _remoteDataSource != null;
  }

  String? get currentUserId => _supabaseService?.currentUser?.id;

  @override
  Future<List<Category>> getActiveCategoriesByType(CategoryType type) async {
    if (isCloudActive) {
      try {
        final cloudCategories = await _remoteDataSource!
            .getActiveCategoriesByType(type, currentUserId!);
        for (final c in cloudCategories) {
          await _syncCategoryToLocalCache(c);
        }
        return cloudCategories;
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              '[CategoryRepositoryImpl] Cloud fetch warning, fallback ke cache lokal: $e');
        }
        // Fallback ke cache lokal saat offline atau gangguan jaringan
        final entries =
            await _categoriesDao.getActiveCategoriesByType(type.toDbString());
        if (entries.isNotEmpty) {
          return entries.map(CategoryModel.fromEntry).toList();
        }
        rethrow;
      }
    }

    final entries =
        await _categoriesDao.getActiveCategoriesByType(type.toDbString());
    return entries.map(CategoryModel.fromEntry).toList();
  }

  @override
  Stream<List<Category>> watchActiveCategoriesByType(CategoryType type) {
    if (isCloudActive) {
      late StreamController<List<Category>> controller;
      StreamSubscription? subLocal;
      StreamSubscription? subSync;

      void emitFromCache() async {
        try {
          final entries =
              await _categoriesDao.getActiveCategoriesByType(type.toDbString());
          final localData = entries.map(CategoryModel.fromEntry).toList();
          if (!controller.isClosed) {
            controller.add(localData);
          }
        } catch (_) {}
      }

      bool isFetching = false;
      void syncAndRefresh() async {
        if (isFetching) return;
        isFetching = true;
        try {
          final cloudCategories = await _remoteDataSource!
              .getActiveCategoriesByType(type, currentUserId!);
          for (final c in cloudCategories) {
            await _syncCategoryToLocalCache(c);
          }
          if (!controller.isClosed) {
            controller.add(cloudCategories);
          }
        } catch (e) {
          emitFromCache();
        } finally {
          isFetching = false;
        }
      }

      controller = StreamController<List<Category>>(
        onListen: () {
          // 1. Emit langsung dari SQLite lokal (0 ms)
          emitFromCache();

          // 2. Sinkronkan dengan Supabase Cloud di latar belakang
          syncAndRefresh();

          // 3. Dengarkan mutasi lokal & sync event tanpa rekursi
          subLocal = _categoriesDao
              .watchActiveCategoriesByType(type.toDbString())
              .listen((_) => emitFromCache());
          subSync = _cloudSyncEventController.stream
              .listen((_) => syncAndRefresh());
        },
        onCancel: () {
          subLocal?.cancel();
          subSync?.cancel();
          controller.close();
        },
      );

      return controller.stream;
    }

    return _categoriesDao.watchActiveCategoriesByType(type.toDbString()).map(
          (entries) => entries.map(CategoryModel.fromEntry).toList(),
        );
  }

  @override
  Future<List<Category>> getAllActiveCategories() async {
    if (isCloudActive) {
      try {
        final cloudCategories =
            await _remoteDataSource!.getAllActiveCategories(currentUserId!);
        for (final c in cloudCategories) {
          await _syncCategoryToLocalCache(c);
        }
        return cloudCategories;
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              '[CategoryRepositoryImpl] Cloud fetch all warning, fallback lokal: $e');
        }
        final entries = await _categoriesDao.getAllActiveCategories();
        if (entries.isNotEmpty) {
          return entries.map(CategoryModel.fromEntry).toList();
        }
        rethrow;
      }
    }

    final entries = await _categoriesDao.getAllActiveCategories();
    return entries.map(CategoryModel.fromEntry).toList();
  }

  @override
  Future<Category?> getCategoryById(String id) async {
    // 1. Cek cache lokal terlebih dahulu (0 ms)
    final localEntry = await _categoriesDao.getCategoryById(id);
    if (localEntry != null) {
      return CategoryModel.fromEntry(localEntry);
    }

    // 2. Ambil dari cloud jika belum ada di lokal
    if (isCloudActive) {
      final cloudCategory =
          await _remoteDataSource!.getCategoryById(id, currentUserId!);
      if (cloudCategory != null) {
        await _syncCategoryToLocalCache(cloudCategory);
        return cloudCategory;
      }
    }

    return null;
  }

  @override
  Future<void> createCategory(Category category) async {
    if (category.isSystem) {
      throw const ValidationFailure(
          'Tidak dapat membuat kategori sistem bawaan baru.');
    }

    // 1. Simpan ke SQLite lokal secara instan
    await _syncCategoryToLocalCache(category);

    // 2. Simpan ke Supabase Cloud
    if (isCloudActive) {
      await _remoteDataSource!.createCategory(category, currentUserId!);
    }

    _cloudSyncEventController.add(null);
  }

  @override
  Future<void> updateCategory(Category category) async {
    final existing = await getCategoryById(category.id);
    if (existing == null) {
      throw const NotFoundFailure('Kategori tidak ditemukan.');
    }
    if (existing.isSystem) {
      throw const ValidationFailure(
          'Kategori sistem bawaan tidak dapat diubah.');
    }

    // 1. Simpan ke SQLite lokal
    await _categoriesDao.updateCategory(
      CategoriesTableCompanion(
        id: Value(category.id),
        name: Value(category.name),
        type: Value(category.type.toDbString()),
        iconKey: Value(category.iconKey),
        colorHex: Value(category.colorHex),
        sortOrder: Value(category.sortOrder),
      ),
    );

    // 2. Simpan ke Supabase Cloud
    if (isCloudActive) {
      await _remoteDataSource!.updateCategory(category, currentUserId!);
    }

    _cloudSyncEventController.add(null);
  }

  @override
  Future<void> archiveCategory(String id) async {
    final existing = await getCategoryById(id);
    if (existing == null) {
      throw const NotFoundFailure('Kategori tidak ditemukan.');
    }
    if (existing.isSystem) {
      throw const ValidationFailure(
          'Kategori sistem bawaan tidak dapat diarsipkan atau dihapus.');
    }

    // 1. Arsipkan di SQLite lokal
    await _categoriesDao.archiveCategory(id);

    // 2. Arsipkan di Supabase Cloud
    if (isCloudActive) {
      await _remoteDataSource!.archiveCategory(id, currentUserId!);
    }

    _cloudSyncEventController.add(null);
  }

  @override
  Future<void> deleteCategory(String id) async {
    final existing = await getCategoryById(id);
    if (existing == null) {
      throw const NotFoundFailure('Kategori tidak ditemukan.');
    }
    if (existing.isSystem) {
      throw const ValidationFailure(
          'Kategori sistem bawaan tidak dapat diarsipkan atau dihapus.');
    }

    // 1. Hapus di SQLite lokal
    await _categoriesDao.deleteCategory(id);

    // 2. Hapus di Supabase Cloud
    if (isCloudActive) {
      await _remoteDataSource!.deleteCategory(id, currentUserId!);
    }

    _cloudSyncEventController.add(null);
  }

  @override
  Future<int> calculateCategorySpending(
    String categoryId, {
    String? startIsoUtc,
    String? endIsoUtc,
  }) async {
    if (isCloudActive) {
      return await _remoteDataSource!.calculateCategorySpending(
        categoryId,
        currentUserId!,
        startIsoUtc: startIsoUtc,
        endIsoUtc: endIsoUtc,
      );
    }

    // Kalkulasi lokal dari SQLite Drift
    if (_transactionsDao != null) {
      // Ambil transaksi confirmed
      final entries = await _transactionsDao.watchRecentTransactions(limit: 5000).first;
      int total = 0;
      for (final tx in entries) {
        if (tx.status != 'confirmed') continue;
        if (tx.categoryId != categoryId) continue;
        if (startIsoUtc != null && tx.occurredAt.compareTo(startIsoUtc) < 0) continue;
        if (endIsoUtc != null && tx.occurredAt.compareTo(endIsoUtc) > 0) continue;
        total += tx.amount;
      }
      return total;
    }

    return 0;
  }

  Future<void> _syncCategoryToLocalCache(Category category) async {
    await _categoriesDao.insertOrReplaceCategory(
      CategoriesTableCompanion.insert(
        id: category.id,
        name: category.name,
        type: category.type.toDbString(),
        iconKey: Value(category.iconKey),
        colorHex: Value(category.colorHex),
        isSystem: Value(category.isSystem),
        isArchived: Value(category.isArchived),
        sortOrder: Value(category.sortOrder),
      ),
    );
  }
}
