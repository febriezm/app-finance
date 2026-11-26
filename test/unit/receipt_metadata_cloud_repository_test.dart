import 'dart:typed_data';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import 'package:myfinance/app/app_providers.dart';
import 'package:myfinance/core/database/app_database.dart';
import 'package:myfinance/core/database/daos/transactions_dao.dart';
import 'package:myfinance/core/errors/exceptions.dart';
import 'package:myfinance/core/services/supabase_service.dart';
import 'package:myfinance/features/receipt_scanner/domain/entities/receipt_metadata.dart';
import 'package:myfinance/features/receipt_scanner/data/datasources/receipt_metadata_remote_data_source.dart';
import 'package:myfinance/features/receipt_scanner/data/repositories/receipt_metadata_repository_impl.dart';
import 'package:myfinance/features/receipt_scanner/data/services/attachment_storage_service.dart';

/// Fake ReceiptMetadataRemoteDataSource yang mensimulasikan Supabase PostgreSQL Cloud dengan RLS
class FakeReceiptMetadataRemoteDataSource implements ReceiptMetadataRemoteDataSource {
  final Map<String, Map<String, dynamic>> cloudAttachmentsTable = {};
  final Map<String, Uint8List> cloudStorageBucket = {};
  bool shouldThrowError = false;

  @override
  Future<List<ReceiptMetadata>> getAllReceiptMetadata(String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Network connection timeout', 'PGRST_TIMEOUT');
    }

    // RLS: WHERE user_id = :userId
    return cloudAttachmentsTable.values
        .where((row) => row['user_id'] == userId)
        .map(ReceiptMetadata.fromSupabaseMap)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<List<ReceiptMetadata>> getReceiptMetadataForTransaction(
    String transactionId,
    String userId,
  ) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Database query failed', '42P01');
    }

    // RLS: WHERE user_id = :userId AND transaction_id = :transactionId
    return cloudAttachmentsTable.values
        .where((row) => row['user_id'] == userId && row['transaction_id'] == transactionId)
        .map(ReceiptMetadata.fromSupabaseMap)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<ReceiptMetadata?> getReceiptMetadataById(String id, String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Database query failed', '42P01');
    }

    final row = cloudAttachmentsTable[id];
    if (row == null || row['user_id'] != userId) return null;
    return ReceiptMetadata.fromSupabaseMap(row);
  }

  @override
  Future<void> saveReceiptMetadata(
    ReceiptMetadata metadata,
    String userId, {
    Uint8List? imageBytes,
  }) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Insert failed', '23505');
    }

    String resolvedPath = metadata.storagePath;
    if (imageBytes != null && imageBytes.isNotEmpty) {
      final uploaded = await uploadReceiptImage(metadata.storagePath, imageBytes, userId);
      if (uploaded != null) resolvedPath = uploaded;
    }

    cloudAttachmentsTable[metadata.id] =
        metadata.copyWith(storagePath: resolvedPath).toSupabaseMap(userId);
  }

  @override
  Future<void> updateReceiptMetadata(ReceiptMetadata metadata, String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Update failed', 'PGRST_UPDATE_ERR');
    }

    final existing = cloudAttachmentsTable[metadata.id];
    if (existing == null || existing['user_id'] != userId) {
      throw const SupabaseDatabaseException('Not found or unauthorized', '404');
    }

    cloudAttachmentsTable[metadata.id] = metadata.toSupabaseMap(userId);
  }

  @override
  Future<void> deleteReceiptMetadata(String id, String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Delete failed', 'PGRST_DEL_ERR');
    }

    final existing = cloudAttachmentsTable[id];
    if (existing != null && existing['user_id'] == userId) {
      final path = existing['storage_path'] as String?;
      if (path != null) {
        await deleteReceiptImage(path, userId);
      }
      cloudAttachmentsTable.remove(id);
    }
  }

  @override
  Future<int> getTotalReceiptStorageBytes(String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Storage calculation failed', '500');
    }

    int total = 0;
    for (final row in cloudAttachmentsTable.values) {
      if (row['user_id'] == userId) {
        final size = row['file_size'];
        if (size is num) total += size.toInt();
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
    final cleanFileName = storagePath.contains('/') ? storagePath.split('/').last : storagePath;
    final targetPath = '$userId/$cleanFileName';
    cloudStorageBucket[targetPath] = imageBytes;
    return targetPath;
  }

  @override
  Future<Uint8List?> downloadReceiptImage(String storagePath, String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Storage download failed', '500');
    }
    final cleanFileName = storagePath.contains('/') ? storagePath.split('/').last : storagePath;
    final targetPath = '$userId/$cleanFileName';
    return cloudStorageBucket[targetPath];
  }

  @override
  Future<String?> getReceiptSignedUrl(
    String storagePath,
    String userId, {
    int expiresInSeconds = 3600,
  }) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Signed URL creation failed', '500');
    }
    final cleanFileName = storagePath.contains('/') ? storagePath.split('/').last : storagePath;
    final targetPath = '$userId/$cleanFileName';
    if (!cloudStorageBucket.containsKey(targetPath)) return null;
    return 'https://supabase.local/storage/v1/object/sign/receipts/$targetPath?token=signed_token&expires=$expiresInSeconds';
  }

  @override
  Future<void> deleteReceiptImage(String storagePath, String userId) async {
    final cleanFileName = storagePath.contains('/') ? storagePath.split('/').last : storagePath;
    final targetPath = '$userId/$cleanFileName';
    cloudStorageBucket.remove(targetPath);
    cloudStorageBucket.remove(storagePath);
  }
}

/// Fake SupabaseService untuk autentikasi user aktif
class FakeSupabaseService extends SupabaseService {
  final String _mockUserId;
  final bool _mockIsAuthenticated;

  FakeSupabaseService({
    String mockUserId = 'user-receipt-owner-123',
    bool mockIsAuthenticated = true,
  })  : _mockUserId = mockUserId,
        _mockIsAuthenticated = mockIsAuthenticated;

  @override
  bool get isAuthenticated => _mockIsAuthenticated;

  @override
  sp.User? get currentUser => _mockIsAuthenticated
      ? sp.User(
          id: _mockUserId,
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
  late FakeReceiptMetadataRemoteDataSource fakeRemoteDataSource;
  late FakeSupabaseService fakeSupabaseService;
  late ReceiptMetadataRepositoryImpl hybridRepo;

  const currentUserId = 'user-receipt-owner-123';
  const otherUserId = 'user-intruder-456';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    transactionsDao = db.transactionsDao;
    fakeRemoteDataSource = FakeReceiptMetadataRemoteDataSource();
    fakeSupabaseService = FakeSupabaseService(
      mockUserId: currentUserId,
      mockIsAuthenticated: true,
    );

    hybridRepo = ReceiptMetadataRepositoryImpl(
      transactionsDao,
      remoteDataSource: fakeRemoteDataSource,
      supabaseService: fakeSupabaseService,
    );

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
    for (final txId in ['tx-100', 'tx-200', 'tx-300', 'tx-999', 'tx-service-test']) {
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

    // Seed mock cloud data untuk current user
    fakeRemoteDataSource.cloudAttachmentsTable['att-1'] = {
      'id': 'att-1',
      'user_id': currentUserId,
      'transaction_id': 'tx-100',
      'storage_path': 'receipts/$currentUserId/att-1.jpg',
      'mime_type': 'image/jpeg',
      'file_size': 204800, // 200 KB
      'created_at': '2026-11-20T10:00:00.000Z',
    };
    fakeRemoteDataSource.cloudAttachmentsTable['att-2'] = {
      'id': 'att-2',
      'user_id': currentUserId,
      'transaction_id': 'tx-100',
      'storage_path': 'receipts/$currentUserId/att-2.jpg',
      'mime_type': 'image/jpeg',
      'file_size': 307200, // 300 KB
      'created_at': '2026-11-20T10:05:00.000Z',
    };
    fakeRemoteDataSource.cloudAttachmentsTable['att-3'] = {
      'id': 'att-3',
      'user_id': currentUserId,
      'transaction_id': 'tx-200',
      'storage_path': 'receipts/$currentUserId/att-3.jpg',
      'mime_type': 'image/png',
      'file_size': 512000, // 500 KB
      'created_at': '2026-11-21T14:00:00.000Z',
    };
  });

  tearDown(() async {
    await db.close();
  });

  group('Receipt Metadata Cloud Repository Tests (Supabase PostgreSQL Integration)', () {
    test('1. Test load Receipt metadata: Mengambil metadata dari cloud dan menyinkronkan ke cache lokal', () async {
      final list = await hybridRepo.getAllReceiptMetadata();

      expect(list.length, equals(3));
      expect(list.map((e) => e.id), containsAll(['att-1', 'att-2', 'att-3']));

      // Verifikasi tersinkron ke SQLite lokal
      final localEntries = await transactionsDao.getAllAttachments();
      expect(localEntries.length, equals(3));
      expect(localEntries.map((e) => e.id), containsAll(['att-1', 'att-2', 'att-3']));
    });

    test('2. Test create Receipt metadata: Menyimpan metadata baru dan upload biner gambar ke cloud & lokal', () async {
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      const newMetadata = ReceiptMetadata(
        id: 'att-new',
        transactionId: 'tx-300',
        storagePath: 'receipts/att-new.jpg',
        mimeType: 'image/jpeg',
        fileSize: 8,
        createdAt: '2026-11-25T12:00:00.000Z',
      );

      await hybridRepo.saveReceiptMetadata(newMetadata, imageBytes: dummyBytes);

      // Verifikasi di cloud database
      final cloudRecord = fakeRemoteDataSource.cloudAttachmentsTable['att-new'];
      expect(cloudRecord, isNotNull);
      expect(cloudRecord!['user_id'], equals(currentUserId));
      expect(cloudRecord['storage_path'], equals('$currentUserId/att-new.jpg'));

      // Verifikasi di cloud storage bucket
      expect(fakeRemoteDataSource.cloudStorageBucket['$currentUserId/att-new.jpg'], equals(dummyBytes));

      // Verifikasi di SQLite lokal
      final localEntry = await transactionsDao.getAttachmentById('att-new');
      expect(localEntry, isNotNull);
      expect(localEntry!.transactionId, equals('tx-300'));
    });

    test('3. Test edit Receipt metadata: Memperbarui metadata lampiran di cloud dan lokal', () async {
      final existing = await hybridRepo.getReceiptMetadataById('att-1');
      expect(existing, isNotNull);

      final updated = existing!.copyWith(
        storagePath: 'receipts/$currentUserId/att-1-edited.jpg',
        fileSize: 250000,
      );

      await hybridRepo.updateReceiptMetadata(updated);

      // Verifikasi di cloud
      final cloudRecord = fakeRemoteDataSource.cloudAttachmentsTable['att-1'];
      expect(cloudRecord!['storage_path'], equals('receipts/$currentUserId/att-1-edited.jpg'));
      expect(cloudRecord['file_size'], equals(250000));

      // Verifikasi di lokal SQLite
      final localEntry = await transactionsDao.getAttachmentById('att-1');
      expect(localEntry!.localPath, equals('receipts/$currentUserId/att-1-edited.jpg'));
      expect(localEntry.fileSize, equals(250000));
    });

    test('4. Test delete Receipt metadata: Menghapus metadata dan file storage dari cloud serta cache lokal', () async {
      // Simpan file di storage
      fakeRemoteDataSource.cloudStorageBucket['receipts/$currentUserId/att-1.jpg'] =
          Uint8List.fromList([1, 2, 3]);

      await hybridRepo.deleteReceiptMetadata('att-1');

      // Verifikasi terhapus di cloud table
      expect(fakeRemoteDataSource.cloudAttachmentsTable.containsKey('att-1'), isFalse);
      // Verifikasi terhapus di cloud storage
      expect(
        fakeRemoteDataSource.cloudStorageBucket.containsKey('receipts/$currentUserId/att-1.jpg'),
        isFalse,
      );
      // Verifikasi terhapus di lokal SQLite
      final local = await transactionsDao.getAttachmentById('att-1');
      expect(local, isNull);
    });

    test('5. Test Receipt metadata detail: Mengambil detail satu lampiran berdasarkan ID', () async {
      final detail = await hybridRepo.getReceiptMetadataById('att-2');

      expect(detail, isNotNull);
      expect(detail!.id, equals('att-2'));
      expect(detail.transactionId, equals('tx-100'));
      expect(detail.fileSize, equals(307200));
      expect(detail.mimeType, equals('image/jpeg'));
    });

    test('6. Test Receipt metadata balance: Menghitung total akumulasi ukuran penyimpanan (storage bytes)', () async {
      final totalBytes = await hybridRepo.getTotalReceiptStorageBytes();

      // att-1 (204800) + att-2 (307200) + att-3 (512000) = 1,024,000 bytes (1 MB)
      expect(totalBytes, equals(1024000));
    });

    test('7. Test Receipt metadata selection: Mengambil daftar lampiran untuk transaksi tertentu', () async {
      final tx100List = await hybridRepo.getReceiptMetadataForTransaction('tx-100');
      expect(tx100List.length, equals(2));
      expect(tx100List.map((e) => e.id), containsAll(['att-1', 'att-2']));

      final tx200List = await hybridRepo.getReceiptMetadataForTransaction('tx-200');
      expect(tx200List.length, equals(1));
      expect(tx200List.first.id, equals('att-3'));

      final txNonExistent = await hybridRepo.getReceiptMetadataForTransaction('tx-none');
      expect(txNonExistent, isEmpty);
    });

    test('8. Test user ownership: Metadata lampiran terikat pada user_id pengguna aktif', () async {
      expect(hybridRepo.currentUserId, equals(currentUserId));

      const meta = ReceiptMetadata(
        id: 'att-user-test',
        transactionId: 'tx-999',
        storagePath: 'receipts/att-user-test.jpg',
        fileSize: 1024,
        createdAt: '2026-11-25T15:00:00.000Z',
      );

      await hybridRepo.saveReceiptMetadata(meta);

      final cloudRecord = fakeRemoteDataSource.cloudAttachmentsTable['att-user-test'];
      expect(cloudRecord!['user_id'], equals(currentUserId));
    });

    test('9. Test RLS: Mencegah akses ke metadata lampiran milik pengguna lain', () async {
      // Masukkan metadata milik pengguna lain
      fakeRemoteDataSource.cloudAttachmentsTable['att-intruder'] = {
        'id': 'att-intruder',
        'user_id': otherUserId, // User lain!
        'transaction_id': 'tx-100',
        'storage_path': 'receipts/$otherUserId/att-intruder.jpg',
        'mime_type': 'image/jpeg',
        'file_size': 999999,
        'created_at': '2026-11-20T10:00:00.000Z',
      };

      // 1. getAllReceiptMetadata tidak boleh menyertakan lampiran orang lain
      final all = await hybridRepo.getAllReceiptMetadata();
      expect(all.any((e) => e.id == 'att-intruder'), isFalse);

      // 2. getReceiptMetadataById tidak boleh mengakses lampiran orang lain
      final detail = await hybridRepo.getReceiptMetadataById('att-intruder');
      expect(detail, isNull);

      // 3. getTotalReceiptStorageBytes tidak boleh memasukkan file size orang lain
      final totalBytes = await hybridRepo.getTotalReceiptStorageBytes();
      expect(totalBytes, equals(1024000));
    });

    test('10. Test error handling: Fallback ke cache SQLite lokal ketika cloud mengalami error/timeout', () async {
      // 1. Sinkronkan dulu data awal ke lokal
      await hybridRepo.getAllReceiptMetadata();

      // 2. Simulasikan cloud down
      fakeRemoteDataSource.shouldThrowError = true;

      // 3. Baca daftar lampiran: harus berhasil membaca dari SQLite lokal
      final fallbackList = await hybridRepo.getAllReceiptMetadata();
      expect(fallbackList.length, equals(3));

      // 4. Baca total storage: harus berhasil menghitung dari SQLite lokal
      final fallbackBytes = await hybridRepo.getTotalReceiptStorageBytes();
      expect(fallbackBytes, equals(1024000));
    });

    test('11. Test loading state & stream: watchReceiptMetadataForTransaction memancarkan stream secara reaktif', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          receiptMetadataRepositoryProvider.overrideWithValue(hybridRepo),
        ],
      );
      addTearDown(container.dispose);

      // Inisialisasi stream
      final stream = container.read(receiptMetadataForTransactionStreamProvider('tx-100').stream);

      // Simpan item baru ke transaksi tx-100
      const newMeta = ReceiptMetadata(
        id: 'att-stream-test',
        transactionId: 'tx-100',
        storagePath: 'receipts/att-stream-test.jpg',
        fileSize: 1000,
        createdAt: '2026-11-25T16:00:00.000Z',
      );
      await hybridRepo.saveReceiptMetadata(newMeta);

      // Stream harus memancarkan item yang baru ditambahkan
      final emitted = await stream.first;
      expect(emitted.any((e) => e.id == 'att-stream-test'), isTrue);
    });

    test('12. Test integration with AttachmentStorageService: Menyimpan lampiran via service mendistribusikan ke cloud & lokal', () async {
      final service = AttachmentStorageService(
        transactionsDao,
        metadataRepository: hybridRepo,
      );

      final dummyBytes = Uint8List.fromList([10, 20, 30, 40]);
      final relativePath = await service.saveReceiptAttachment(
        transactionId: 'tx-service-test',
        originalPath: 'sample:test.jpg',
        imageBytes: dummyBytes,
      );

      expect(relativePath, startsWith('receipts/'));

      // Verifikasi di SQLite lokal
      final localEntries = await transactionsDao.getAttachmentsForTransaction('tx-service-test');
      expect(localEntries.length, equals(1));
      expect(localEntries.first.fileSize, equals(4));

      // Verifikasi tersinkron ke cloud repository
      final cloudEntries =
          await fakeRemoteDataSource.getReceiptMetadataForTransaction('tx-service-test', currentUserId);
      expect(cloudEntries.length, equals(1));
      expect(cloudEntries.first.fileSize, equals(4));
    });
  });
}
