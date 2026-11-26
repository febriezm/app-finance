import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint, kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../../core/database/daos/transactions_dao.dart';
import '../../../../core/services/supabase_service.dart';
import '../../domain/entities/receipt_metadata.dart';
import '../../domain/repositories/receipt_metadata_repository.dart';
import '../datasources/receipt_metadata_remote_data_source.dart';

/// Implementasi ReceiptMetadataRepository dengan pola Offline-First Hybrid:
/// - Reaktivitas instan lokal ditopang oleh SQLite (TransactionsDao)
/// - Sinkronisasi atomik ke Supabase Cloud PostgreSQL (tabel `transaction_attachments`)
/// - Isolasi mutlak per pengguna aktif (Row Level Security / RLS)
class ReceiptMetadataRepositoryImpl implements ReceiptMetadataRepository {
  final TransactionsDao _transactionsDao;
  final ReceiptMetadataRemoteDataSource? _remoteDataSource;
  final SupabaseService? _supabaseService;

  ReceiptMetadataRepositoryImpl(
    this._transactionsDao, {
    ReceiptMetadataRemoteDataSource? remoteDataSource,
    SupabaseService? supabaseService,
  })  : _remoteDataSource = remoteDataSource,
        _supabaseService = supabaseService;

  bool get isCloudActive {
    final svc = _supabaseService;
    return svc != null && svc.isAuthenticated && _remoteDataSource != null;
  }

  String? get currentUserId => _supabaseService?.currentUser?.id;

  Future<void> _syncToLocalCache(ReceiptMetadata metadata) async {
    try {
      await _transactionsDao.insertOrReplaceAttachment(metadata.toCompanion());
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ReceiptMetadataRepositoryImpl] Local sync warning: $e');
      }
    }
  }

  @override
  Future<List<ReceiptMetadata>> getAllReceiptMetadata() async {
    if (isCloudActive) {
      try {
        final cloudList = await _remoteDataSource!.getAllReceiptMetadata(currentUserId!);
        for (final item in cloudList) {
          await _syncToLocalCache(item);
        }
        return cloudList;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[ReceiptMetadataRepositoryImpl] Cloud fetch all warning, fallback ke lokal: $e');
        }
      }
    }

    final entries = await _transactionsDao.getAllAttachments();
    return entries.map((e) => ReceiptMetadata.fromEntry(e, userId: currentUserId)).toList();
  }

  @override
  Future<List<ReceiptMetadata>> getReceiptMetadataForTransaction(String transactionId) async {
    if (isCloudActive) {
      try {
        final cloudList = await _remoteDataSource!.getReceiptMetadataForTransaction(
          transactionId,
          currentUserId!,
        );
        for (final item in cloudList) {
          await _syncToLocalCache(item);
        }
        return cloudList;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[ReceiptMetadataRepositoryImpl] Cloud fetch for tx warning, fallback ke lokal: $e');
        }
      }
    }

    final entries = await _transactionsDao.getAttachmentsForTransaction(transactionId);
    return entries.map((e) => ReceiptMetadata.fromEntry(e, userId: currentUserId)).toList();
  }

  @override
  Future<ReceiptMetadata?> getReceiptMetadataById(String id) async {
    final localEntry = await _transactionsDao.getAttachmentById(id);
    if (localEntry != null) {
      return ReceiptMetadata.fromEntry(localEntry, userId: currentUserId);
    }

    if (isCloudActive) {
      try {
        final cloudItem = await _remoteDataSource!.getReceiptMetadataById(id, currentUserId!);
        if (cloudItem != null) {
          await _syncToLocalCache(cloudItem);
          return cloudItem;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[ReceiptMetadataRepositoryImpl] Cloud fetch by id warning: $e');
        }
      }
    }

    return null;
  }

  @override
  Future<void> saveReceiptMetadata(ReceiptMetadata metadata, {Uint8List? imageBytes}) async {
    // 1. Simpan ke SQLite lokal (0 ms)
    await _syncToLocalCache(metadata);

    // 2. Sinkronkan ke cloud jika aktif
    if (isCloudActive) {
      try {
        await _remoteDataSource!.saveReceiptMetadata(
          metadata,
          currentUserId!,
          imageBytes: imageBytes,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[ReceiptMetadataRepositoryImpl] Cloud save warning: $e');
        }
      }
    }
  }

  @override
  Future<void> updateReceiptMetadata(ReceiptMetadata metadata) async {
    await _syncToLocalCache(metadata);

    if (isCloudActive) {
      try {
        await _remoteDataSource!.updateReceiptMetadata(metadata, currentUserId!);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[ReceiptMetadataRepositoryImpl] Cloud update warning: $e');
        }
      }
    }
  }

  @override
  Future<void> deleteReceiptMetadata(String id) async {
    // 1. Ambil metadata terlebih dahulu untuk mendapatkan storage path
    final existing = await getReceiptMetadataById(id);

    // 2. Hapus baris dari SQLite lokal
    await _transactionsDao.deleteAttachment(id);

    // 3. Bersihkan berkas fisik lokal jika ada dan bukan di web
    if (!kIsWeb && existing != null && existing.storagePath.isNotEmpty) {
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        final cleanFileName = existing.storagePath.contains('/')
            ? existing.storagePath.split('/').last
            : existing.storagePath;
        final localFile = File(p.join(docsDir.path, 'receipts', cleanFileName));
        if (await localFile.exists()) {
          await localFile.delete();
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[ReceiptMetadataRepositoryImpl] Local file delete warning: $e');
        }
      }
    }

    // 4. Hapus dari Supabase PostgreSQL dan Supabase Storage bucket 'receipts'
    if (isCloudActive) {
      try {
        await _remoteDataSource!.deleteReceiptMetadata(id, currentUserId!);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[ReceiptMetadataRepositoryImpl] Cloud delete warning: $e');
        }
      }
    }
  }

  @override
  Future<int> getTotalReceiptStorageBytes() async {
    if (isCloudActive) {
      try {
        return await _remoteDataSource!.getTotalReceiptStorageBytes(currentUserId!);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[ReceiptMetadataRepositoryImpl] Cloud total storage warning: $e');
        }
      }
    }

    final localEntries = await _transactionsDao.getAllAttachments();
    int total = 0;
    for (final e in localEntries) {
      total += e.fileSize;
    }
    return total;
  }

  @override
  Stream<List<ReceiptMetadata>> watchReceiptMetadataForTransaction(String transactionId) {
    return _transactionsDao
        .watchAttachmentsForTransaction(transactionId)
        .map((list) => list.map((e) => ReceiptMetadata.fromEntry(e, userId: currentUserId)).toList());
  }

  @override
  Future<Uint8List?> getReceiptImageBytes(String storagePath) async {
    // 1. Cek penyimpanan berkas lokal jika bukan web (0 ms response)
    if (!kIsWeb) {
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        final cleanFileName = storagePath.contains('/')
            ? storagePath.split('/').last
            : storagePath;
        final localFile = File(p.join(docsDir.path, 'receipts', cleanFileName));
        if (await localFile.exists()) {
          final bytes = await localFile.readAsBytes();
          if (bytes.isNotEmpty) return bytes;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[ReceiptMetadataRepositoryImpl] Local file read warning: $e');
        }
      }
    }

    // 2. Jika berkas lokal belum ada atau di web, unduh dari Supabase Storage private bucket
    if (isCloudActive && currentUserId != null) {
      try {
        final cloudBytes = await _remoteDataSource!.downloadReceiptImage(
          storagePath,
          currentUserId!,
        );
        if (cloudBytes != null && cloudBytes.isNotEmpty) {
          // Cache ke berkas lokal untuk akses offline instan berikutnya jika bukan web
          if (!kIsWeb) {
            try {
              final docsDir = await getApplicationDocumentsDirectory();
              final receiptsDir = Directory(p.join(docsDir.path, 'receipts'));
              if (!await receiptsDir.exists()) {
                await receiptsDir.create(recursive: true);
              }
              final cleanFileName = storagePath.contains('/')
                  ? storagePath.split('/').last
                  : storagePath;
              await File(p.join(receiptsDir.path, cleanFileName)).writeAsBytes(cloudBytes);
            } catch (_) {}
          }
          return cloudBytes;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[ReceiptMetadataRepositoryImpl] Cloud download warning: $e');
        }
      }
    }

    return null;
  }

  @override
  Future<String?> getReceiptSignedUrl(String storagePath, {int expiresInSeconds = 3600}) async {
    if (isCloudActive && currentUserId != null) {
      try {
        return await _remoteDataSource!.getReceiptSignedUrl(
          storagePath,
          currentUserId!,
          expiresInSeconds: expiresInSeconds,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[ReceiptMetadataRepositoryImpl] Signed URL warning: $e');
        }
      }
    }
    return null;
  }

  @override
  Future<bool> retryUploadReceiptImage(String id, Uint8List imageBytes) async {
    final uid = currentUserId;
    final rds = _remoteDataSource;
    if (!isCloudActive || uid == null || rds == null) return false;
    try {
      final metadata = await getReceiptMetadataById(id);
      if (metadata == null) return false;

      final uploadedPath = await rds.uploadReceiptImage(
        metadata.storagePath,
        imageBytes,
        uid,
      );

      if (uploadedPath != null && uploadedPath.isNotEmpty) {
        final updated = metadata.copyWith(storagePath: uploadedPath);
        await rds.saveReceiptMetadata(
          updated,
          uid,
          imageBytes: null, // Berkas fisik sudah diunggah
        );
        await _syncToLocalCache(updated);
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ReceiptMetadataRepositoryImpl] Retry upload failed: $e');
      }
      return false;
    }
  }
}
