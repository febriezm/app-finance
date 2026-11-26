import 'dart:typed_data';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import 'package:myfinance/core/database/app_database.dart';
import 'package:myfinance/core/database/daos/transactions_dao.dart';
import 'package:myfinance/core/errors/exceptions.dart';
import 'package:myfinance/core/services/supabase_service.dart';
import 'package:myfinance/features/receipt_scanner/domain/entities/receipt_metadata.dart';
import 'package:myfinance/features/receipt_scanner/data/datasources/receipt_metadata_remote_data_source.dart';
import 'package:myfinance/features/receipt_scanner/data/repositories/receipt_metadata_repository_impl.dart';

/// Mock Remote Data Source yang mensimulasikan Supabase PostgreSQL & Supabase Storage Private Bucket
class MockSupabaseReceiptStorageRemoteDataSource implements ReceiptMetadataRemoteDataSource {
  final Map<String, Map<String, dynamic>> dbAttachments = {};
  final Map<String, Uint8List> storageBucket = {}; // key: '<userId>/<fileName>'
  bool simulateNetworkFailure = false;

  @override
  Future<List<ReceiptMetadata>> getAllReceiptMetadata(String userId) async {
    if (simulateNetworkFailure) throw const SupabaseDatabaseException('Network error', 'TIMEOUT');
    return dbAttachments.values
        .where((r) => r['user_id'] == userId)
        .map(ReceiptMetadata.fromSupabaseMap)
        .toList();
  }

  @override
  Future<List<ReceiptMetadata>> getReceiptMetadataForTransaction(
    String transactionId,
    String userId,
  ) async {
    if (simulateNetworkFailure) throw const SupabaseDatabaseException('Network error', 'TIMEOUT');
    return dbAttachments.values
        .where((r) => r['user_id'] == userId && r['transaction_id'] == transactionId)
        .map(ReceiptMetadata.fromSupabaseMap)
        .toList();
  }

  @override
  Future<ReceiptMetadata?> getReceiptMetadataById(String id, String userId) async {
    if (simulateNetworkFailure) throw const SupabaseDatabaseException('Network error', 'TIMEOUT');
    final row = dbAttachments[id];
    if (row == null || row['user_id'] != userId) return null;
    return ReceiptMetadata.fromSupabaseMap(row);
  }

  @override
  Future<void> saveReceiptMetadata(
    ReceiptMetadata metadata,
    String userId, {
    Uint8List? imageBytes,
  }) async {
    if (simulateNetworkFailure) throw const SupabaseDatabaseException('Network error', 'TIMEOUT');

    String resolvedPath = metadata.storagePath;
    if (imageBytes != null && imageBytes.isNotEmpty) {
      final uploaded = await uploadReceiptImage(metadata.storagePath, imageBytes, userId);
      if (uploaded != null) resolvedPath = uploaded;
    }

    dbAttachments[metadata.id] =
        metadata.copyWith(storagePath: resolvedPath).toSupabaseMap(userId);
  }

  @override
  Future<void> updateReceiptMetadata(ReceiptMetadata metadata, String userId) async {
    if (simulateNetworkFailure) throw const SupabaseDatabaseException('Network error', 'TIMEOUT');
    dbAttachments[metadata.id] = metadata.toSupabaseMap(userId);
  }

  @override
  Future<void> deleteReceiptMetadata(String id, String userId) async {
    if (simulateNetworkFailure) throw const SupabaseDatabaseException('Network error', 'TIMEOUT');
    final existing = dbAttachments[id];
    if (existing != null && existing['user_id'] == userId) {
      final path = existing['storage_path'] as String?;
      if (path != null) {
        await deleteReceiptImage(path, userId);
      }
      dbAttachments.remove(id);
    }
  }

  @override
  Future<int> getTotalReceiptStorageBytes(String userId) async {
    if (simulateNetworkFailure) throw const SupabaseDatabaseException('Network error', 'TIMEOUT');
    int total = 0;
    for (final row in dbAttachments.values) {
      if (row['user_id'] == userId) {
        total += (row['file_size'] as num).toInt();
      }
    }
    return total;
  }

  @override
  Future<String?> uploadReceiptImage(
    String storagePath,
    Uint8List imageBytes,
    String userId,
  ) async {
    if (simulateNetworkFailure) throw const SupabaseDatabaseException('Upload failed', 'TIMEOUT');
    if (userId.trim().isEmpty) throw ArgumentError('User ID tidak boleh kosong.');

    // Sanitasi path untuk menjamin user scoping & mencegah directory traversal
    final cleanFileName = storagePath.contains('/') ? storagePath.split('/').last : storagePath;
    final targetPath = '$userId/$cleanFileName';
    storageBucket[targetPath] = imageBytes;
    return targetPath;
  }

  @override
  Future<Uint8List?> downloadReceiptImage(String storagePath, String userId) async {
    if (simulateNetworkFailure) throw const SupabaseDatabaseException('Download failed', 'TIMEOUT');
    if (userId.trim().isEmpty) throw ArgumentError('User ID tidak boleh kosong.');

    final cleanFileName = storagePath.contains('/') ? storagePath.split('/').last : storagePath;
    final targetPath = '$userId/$cleanFileName';
    return storageBucket[targetPath];
  }

  @override
  Future<String?> getReceiptSignedUrl(
    String storagePath,
    String userId, {
    int expiresInSeconds = 3600,
  }) async {
    if (simulateNetworkFailure) throw const SupabaseDatabaseException('Signed URL failed', 'TIMEOUT');
    if (userId.trim().isEmpty) throw ArgumentError('User ID tidak boleh kosong.');

    final cleanFileName = storagePath.contains('/') ? storagePath.split('/').last : storagePath;
    final targetPath = '$userId/$cleanFileName';
    if (!storageBucket.containsKey(targetPath)) return null;

    // Supabase Private Bucket signed URL format
    return 'https://supabase.local/storage/v1/object/sign/receipts/$targetPath?token=signed_token&expires=$expiresInSeconds';
  }

  @override
  Future<void> deleteReceiptImage(String storagePath, String userId) async {
    if (userId.trim().isEmpty) return;
    final cleanFileName = storagePath.contains('/') ? storagePath.split('/').last : storagePath;
    final targetPath = '$userId/$cleanFileName';
    storageBucket.remove(targetPath);
    storageBucket.remove(storagePath);
  }
}

/// Mock SupabaseService
class MockSupabaseAuthService extends SupabaseService {
  final String _activeUserId;
  final bool _authStatus;

  MockSupabaseAuthService({
    String activeUserId = 'user-alice-111',
    bool authStatus = true,
  })  : _activeUserId = activeUserId,
        _authStatus = authStatus;

  @override
  bool get isAuthenticated => _authStatus;

  @override
  sp.User? get currentUser => _authStatus
      ? sp.User(
          id: _activeUserId,
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        )
      : null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late TransactionsDao transactionsDao;
  late MockSupabaseReceiptStorageRemoteDataSource remoteDataSource;
  late MockSupabaseAuthService authService;
  late ReceiptMetadataRepositoryImpl repository;

  final sampleImageBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46]);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    transactionsDao = db.transactionsDao;
    remoteDataSource = MockSupabaseReceiptStorageRemoteDataSource();
    authService = MockSupabaseAuthService(activeUserId: 'user-alice-111');

    // Seed wallet untuk FK
    await db.into(db.walletsTable).insert(
      WalletsTableCompanion.insert(
        id: 'w-1',
        name: 'Dompet Utama',
        type: 'cash',
        openingBalance: 1000000,
        openingDate: '2026-11-01T00:00:00.000Z',
        createdAt: '2026-11-01T00:00:00.000Z',
        updatedAt: '2026-11-01T00:00:00.000Z',
      ),
    );

    // Seed parent transactions untuk memenuhi constraint SQLite FK
    for (final txId in ['tx-001', 'tx-002', 'tx-003', 'tx-004', 'tx-005', 'tx-006', 'tx-008', 'tx-alice']) {
      await db.into(db.transactionsTable).insert(
        TransactionsTableCompanion.insert(
          id: txId,
          type: 'expense',
          amount: 50000,
          occurredAt: '2026-11-20T10:00:00.000Z',
          walletId: const Value('w-1'),
          createdAt: '2026-11-20T10:00:00.000Z',
          updatedAt: '2026-11-20T10:00:00.000Z',
        ),
      );
    }

    repository = ReceiptMetadataRepositoryImpl(
      transactionsDao,
      remoteDataSource: remoteDataSource,
      supabaseService: authService,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Supabase Storage Receipt Migration Tests', () {
    test('1. Test upload receipt image ke private bucket user-scoped', () async {
      const attachmentId = 'att-uuid-001';
      const txId = 'tx-001';
      final metadata = ReceiptMetadata(
        id: attachmentId,
        transactionId: txId,
        storagePath: 'receipts/$attachmentId.jpg',
        fileSize: sampleImageBytes.length,
        createdAt: DateTime.now().toUtc().toIso8601String(),
      );

      // Simpan metadata beserta file biner gambar
      await repository.saveReceiptMetadata(metadata, imageBytes: sampleImageBytes);

      // Verifikasi file tersimpan di Supabase Storage bucket 'receipts' dengan path user-scoped
      const expectedStoragePath = 'user-alice-111/$attachmentId.jpg';
      expect(remoteDataSource.storageBucket.containsKey(expectedStoragePath), isTrue);
      expect(remoteDataSource.storageBucket[expectedStoragePath], equals(sampleImageBytes));

      // Verifikasi metadata di PostgreSQL cloud menyimpan storage_path user-scoped
      final cloudMeta = await remoteDataSource.getReceiptMetadataById(attachmentId, 'user-alice-111');
      expect(cloudMeta, isNotNull);
      expect(cloudMeta!.storagePath, equals(expectedStoragePath));
      expect(cloudMeta.userId, equals('user-alice-111'));
    });

    test('2. Test download & preview receipt image (bytes & signed URL)', () async {
      const attachmentId = 'att-uuid-002';
      const txId = 'tx-002';
      final metadata = ReceiptMetadata(
        id: attachmentId,
        transactionId: txId,
        storagePath: 'receipts/$attachmentId.jpg',
        fileSize: sampleImageBytes.length,
        createdAt: DateTime.now().toUtc().toIso8601String(),
      );

      await repository.saveReceiptMetadata(metadata, imageBytes: sampleImageBytes);

      // A. Ambil biner gambar untuk keperluan preview / rendering UI
      final downloadedBytes = await repository.getReceiptImageBytes('user-alice-111/$attachmentId.jpg');
      expect(downloadedBytes, isNotNull);
      expect(downloadedBytes, equals(sampleImageBytes));

      // B. Ambil Signed URL sementara (Private bucket tidak boleh menggunakan public URL)
      final signedUrl = await repository.getReceiptSignedUrl(
        'user-alice-111/$attachmentId.jpg',
        expiresInSeconds: 1800,
      );
      expect(signedUrl, isNotNull);
      expect(signedUrl, contains('https://supabase.local/storage/v1/object/sign/receipts/'));
      expect(signedUrl, contains('user-alice-111/$attachmentId.jpg'));
      expect(signedUrl, contains('expires=1800'));
    });

    test('3. Test delete receipt (metadata dihapus + image di storage dibersihkan)', () async {
      const attachmentId = 'att-uuid-003';
      const txId = 'tx-003';
      final metadata = ReceiptMetadata(
        id: attachmentId,
        transactionId: txId,
        storagePath: 'receipts/$attachmentId.jpg',
        fileSize: sampleImageBytes.length,
        createdAt: DateTime.now().toUtc().toIso8601String(),
      );

      await repository.saveReceiptMetadata(metadata, imageBytes: sampleImageBytes);
      const expectedStoragePath = 'user-alice-111/$attachmentId.jpg';
      expect(remoteDataSource.storageBucket.containsKey(expectedStoragePath), isTrue);

      // Hapus metadata lampiran
      await repository.deleteReceiptMetadata(attachmentId);

      // Verifikasi berkas biner di Storage bucket terhapus (mencegah orphan files)
      expect(remoteDataSource.storageBucket.containsKey(expectedStoragePath), isFalse);

      // Verifikasi metadata di SQLite dan PostgreSQL cloud terhapus
      final local = await transactionsDao.getAttachmentById(attachmentId);
      expect(local, isNull);
      final cloud = await remoteDataSource.getReceiptMetadataById(attachmentId, 'user-alice-111');
      expect(cloud, isNull);
    });

    test('4. Test failed upload handling (graceful fallback ke lokal tanpa crash)', () async {
      // Simulasikan kegagalan jaringan / storage cloud
      remoteDataSource.simulateNetworkFailure = true;

      const attachmentId = 'att-uuid-004';
      const txId = 'tx-004';
      final metadata = ReceiptMetadata(
        id: attachmentId,
        transactionId: txId,
        storagePath: 'receipts/$attachmentId.jpg',
        fileSize: sampleImageBytes.length,
        createdAt: DateTime.now().toUtc().toIso8601String(),
      );

      // Operasi saveReceiptMetadata tidak boleh melempar unhandled exception / crash
      await expectLater(
        repository.saveReceiptMetadata(metadata, imageBytes: sampleImageBytes),
        completes,
      );

      // Data offline di SQLite lokal tetap aman tersimpan
      final local = await transactionsDao.getAttachmentById(attachmentId);
      expect(local, isNotNull);
      expect(local!.id, equals(attachmentId));
    });

    test('5. Test retry upload saat koneksi pulih (retryUploadReceiptImage)', () async {
      // 1. Awalnya gagal upload ke cloud
      remoteDataSource.simulateNetworkFailure = true;

      const attachmentId = 'att-uuid-005';
      const txId = 'tx-005';
      final metadata = ReceiptMetadata(
        id: attachmentId,
        transactionId: txId,
        storagePath: 'receipts/$attachmentId.jpg',
        fileSize: sampleImageBytes.length,
        createdAt: DateTime.now().toUtc().toIso8601String(),
      );

      await repository.saveReceiptMetadata(metadata, imageBytes: sampleImageBytes);
      const expectedStoragePath = 'user-alice-111/$attachmentId.jpg';
      expect(remoteDataSource.storageBucket.containsKey(expectedStoragePath), isFalse);

      // 2. Koneksi pulih
      remoteDataSource.simulateNetworkFailure = false;

      // 3. Eksekusi retry upload
      final retrySuccess = await repository.retryUploadReceiptImage(attachmentId, sampleImageBytes);
      expect(retrySuccess, isTrue);

      // Berkas kini berhasil terunggah ke Supabase Storage
      expect(remoteDataSource.storageBucket.containsKey(expectedStoragePath), isTrue);
      expect(remoteDataSource.storageBucket[expectedStoragePath], equals(sampleImageBytes));
    });

    test('6. Test user ownership (user_id disematkan pada metadata & path folder)', () async {
      const attachmentId = 'att-uuid-006';
      const txId = 'tx-006';
      final metadata = ReceiptMetadata(
        id: attachmentId,
        transactionId: txId,
        storagePath: 'receipts/$attachmentId.jpg',
        fileSize: sampleImageBytes.length,
        createdAt: DateTime.now().toUtc().toIso8601String(),
      );

      await repository.saveReceiptMetadata(metadata, imageBytes: sampleImageBytes);

      // Path selalu berawalan user ID aktif
      const targetPath = 'user-alice-111/$attachmentId.jpg';
      expect(remoteDataSource.storageBucket.containsKey(targetPath), isTrue);

      // Anti-Path-Traversal: Jika storagePath mengandung '../' atau segmen lain
      const evilPath = '../../evil-folder/hacked.jpg';
      final safeUploaded = await remoteDataSource.uploadReceiptImage(
        evilPath,
        sampleImageBytes,
        'user-alice-111',
      );
      expect(safeUploaded, equals('user-alice-111/hacked.jpg'));
      expect(remoteDataSource.storageBucket.containsKey('user-alice-111/hacked.jpg'), isTrue);
    });

    test('7. Test RLS (Mencegah user lain mengakses/mengunduh struk milik user lain)', () async {
      // Alice mengunggah struk
      const aliceAttachmentId = 'att-alice-777';
      final metadata = ReceiptMetadata(
        id: aliceAttachmentId,
        transactionId: 'tx-alice',
        storagePath: 'receipts/$aliceAttachmentId.jpg',
        fileSize: sampleImageBytes.length,
        createdAt: DateTime.now().toUtc().toIso8601String(),
      );
      await repository.saveReceiptMetadata(metadata, imageBytes: sampleImageBytes);

      // Bob (user lain) mencoba mengunduh struk Alice
      const bobUserId = 'user-bob-999';
      final bobDownloaded = await remoteDataSource.downloadReceiptImage(
        'receipts/$aliceAttachmentId.jpg',
        bobUserId, // Bob's scope
      );

      // Bob tidak boleh mendapatkan berkas biner Alice
      expect(bobDownloaded, isNull);

      // Bob mencoba mendapatkan signed URL struk Alice
      final bobSignedUrl = await remoteDataSource.getReceiptSignedUrl(
        'receipts/$aliceAttachmentId.jpg',
        bobUserId,
      );
      expect(bobSignedUrl, isNull);

      // Alice sendiri dapat mengunduh berkas miliknya
      final aliceDownloaded = await remoteDataSource.downloadReceiptImage(
        'receipts/$aliceAttachmentId.jpg',
        'user-alice-111',
      );
      expect(aliceDownloaded, isNotNull);
      expect(aliceDownloaded, equals(sampleImageBytes));
    });

    test('8. Test duplicate upload handling (idempotent upsert)', () async {
      const attachmentId = 'att-uuid-008';
      const txId = 'tx-008';
      final metadata = ReceiptMetadata(
        id: attachmentId,
        transactionId: txId,
        storagePath: 'receipts/$attachmentId.jpg',
        fileSize: sampleImageBytes.length,
        createdAt: DateTime.now().toUtc().toIso8601String(),
      );

      // Upload pertama
      await repository.saveReceiptMetadata(metadata, imageBytes: sampleImageBytes);
      // Upload kedua dengan payload yang sama tidak boleh crash / duplicate conflict
      await repository.saveReceiptMetadata(metadata, imageBytes: sampleImageBytes);

      const targetPath = 'user-alice-111/$attachmentId.jpg';
      expect(remoteDataSource.storageBucket.containsKey(targetPath), isTrue);
      expect(remoteDataSource.storageBucket[targetPath], equals(sampleImageBytes));
    });
  });
}
