import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_service.dart';
import '../../domain/entities/receipt_metadata.dart';

/// Kontrak Remote Data Source untuk operasi PostgREST tabel `transaction_attachments`
/// dan Supabase Storage bucket `receipts`.
abstract class ReceiptMetadataRemoteDataSource {
  /// Mengambil seluruh metadata lampiran milik user aktif
  Future<List<ReceiptMetadata>> getAllReceiptMetadata(String userId);

  /// Mengambil daftar lampiran untuk transaksi tertentu milik user aktif
  Future<List<ReceiptMetadata>> getReceiptMetadataForTransaction(
    String transactionId,
    String userId,
  );

  /// Mengambil satu metadata lampiran berdasarkan ID dan user_id
  Future<ReceiptMetadata?> getReceiptMetadataById(String id, String userId);

  /// Menyimpan metadata lampiran ke Supabase Cloud (dan opsional upload biner ke Supabase Storage)
  Future<void> saveReceiptMetadata(
    ReceiptMetadata metadata,
    String userId, {
    Uint8List? imageBytes,
  });

  /// Memperbarui metadata lampiran di Supabase Cloud
  Future<void> updateReceiptMetadata(ReceiptMetadata metadata, String userId);

  /// Menghapus metadata lampiran di Supabase Cloud (beserta file gambar di storage jika ada)
  Future<void> deleteReceiptMetadata(String id, String userId);

  /// Menghitung total pemakaian penyimpanan lampiran dalam bytes
  Future<int> getTotalReceiptStorageBytes(String userId);

  /// Mengunggah berkas gambar struk ke Supabase Storage bucket `receipts`
  Future<String?> uploadReceiptImage(
    String storagePath,
    Uint8List imageBytes,
    String userId,
  );

  /// Mengunduh berkas biner gambar struk dari Supabase Storage bucket `receipts`
  Future<Uint8List?> downloadReceiptImage(String storagePath, String userId);

  /// Mendapatkan URL bertanda tangan (Signed URL) berbatas waktu untuk berkas private di Supabase Storage
  Future<String?> getReceiptSignedUrl(
    String storagePath,
    String userId, {
    int expiresInSeconds = 3600,
  });

  /// Menghapus berkas gambar struk dari Supabase Storage
  Future<void> deleteReceiptImage(String storagePath, String userId);
}

/// Implementasi ReceiptMetadataRemoteDataSource menggunakan Supabase Client
class ReceiptMetadataRemoteDataSourceImpl implements ReceiptMetadataRemoteDataSource {
  final SupabaseService? _supabaseService;
  final sp.SupabaseClient? _customClient;

  ReceiptMetadataRemoteDataSourceImpl({
    SupabaseService? supabaseService,
    sp.SupabaseClient? client,
  })  : _supabaseService = supabaseService,
        _customClient = client;

  sp.SupabaseClient get _client {
    if (_customClient != null) return _customClient;
    final svc = _supabaseService;
    if (svc != null && svc.clientOrNull != null) {
      return svc.client;
    }
    throw const SupabaseConnectionException(
      'Supabase client belum diinisialisasi atau belum terhubung.',
    );
  }

  @override
  Future<List<ReceiptMetadata>> getAllReceiptMetadata(String userId) async {
    try {
      final response = await _client
          .from('transaction_attachments')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((row) => ReceiptMetadata.fromSupabaseMap(row as Map<String, dynamic>))
          .toList();
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal mengambil daftar lampiran struk dari cloud: $e');
    }
  }

  @override
  Future<List<ReceiptMetadata>> getReceiptMetadataForTransaction(
    String transactionId,
    String userId,
  ) async {
    try {
      final response = await _client
          .from('transaction_attachments')
          .select()
          .eq('user_id', userId)
          .eq('transaction_id', transactionId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((row) => ReceiptMetadata.fromSupabaseMap(row as Map<String, dynamic>))
          .toList();
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal mengambil lampiran struk transaksi dari cloud: $e');
    }
  }

  @override
  Future<ReceiptMetadata?> getReceiptMetadataById(String id, String userId) async {
    try {
      final response = await _client
          .from('transaction_attachments')
          .select()
          .eq('user_id', userId)
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return ReceiptMetadata.fromSupabaseMap(response);
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal mengambil metadata lampiran dari cloud: $e');
    }
  }

  @override
  Future<void> saveReceiptMetadata(
    ReceiptMetadata metadata,
    String userId, {
    Uint8List? imageBytes,
  }) async {
    try {
      String resolvedPath = metadata.storagePath;

      // 1. Upload biner gambar ke Supabase Storage bucket 'receipts' jika data biner tersedia
      if (imageBytes != null && imageBytes.isNotEmpty) {
        final uploadedPath = await uploadReceiptImage(metadata.storagePath, imageBytes, userId);
        if (uploadedPath != null && uploadedPath.isNotEmpty) {
          resolvedPath = uploadedPath;
        }
      }

      // 2. Simpan metadata ke tabel PostgreSQL
      final payload = metadata.copyWith(storagePath: resolvedPath).toSupabaseMap(userId);
      await _client.from('transaction_attachments').upsert(payload, onConflict: 'id');
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal menyimpan lampiran struk ke cloud: $e');
    }
  }

  @override
  Future<void> updateReceiptMetadata(ReceiptMetadata metadata, String userId) async {
    try {
      final payload = metadata.toSupabaseMap(userId);
      await _client
          .from('transaction_attachments')
          .update(payload)
          .eq('id', metadata.id)
          .eq('user_id', userId);
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal memperbarui lampiran struk di cloud: $e');
    }
  }

  @override
  Future<void> deleteReceiptMetadata(String id, String userId) async {
    try {
      // 1. Ambil metadata untuk mengetahui storage path
      final existing = await getReceiptMetadataById(id, userId);

      // 2. Hapus baris dari tabel
      await _client
          .from('transaction_attachments')
          .delete()
          .eq('id', id)
          .eq('user_id', userId);

      // 3. Hapus file dari Supabase Storage jika ada
      if (existing != null && existing.storagePath.isNotEmpty) {
        await deleteReceiptImage(existing.storagePath, userId);
      }
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal menghapus lampiran struk dari cloud: $e');
    }
  }

  @override
  Future<int> getTotalReceiptStorageBytes(String userId) async {
    try {
      final response = await _client
          .from('transaction_attachments')
          .select('file_size')
          .eq('user_id', userId);

      int total = 0;
      for (final row in response as List) {
        final size = row['file_size'];
        if (size is num) total += size.toInt();
      }
      return total;
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal menghitung ukuran penyimpanan lampiran: $e');
    }
  }

  @override
  Future<String?> uploadReceiptImage(
    String storagePath,
    Uint8List imageBytes,
    String userId,
  ) async {
    try {
      if (userId.trim().isEmpty) {
        throw ArgumentError('User ID tidak boleh kosong.');
      }
      // Format path terisolasi RLS storage: <userId>/<filename>
      // Sanitasi path untuk mencegah directory traversal dan menjamin user scoping
      final cleanFileName = storagePath.contains('/')
          ? storagePath.split('/').last
          : storagePath;
      final targetPath = '$userId/$cleanFileName';

      await _client.storage.from('receipts').uploadBinary(
            targetPath,
            imageBytes,
            fileOptions: const sp.FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      return targetPath;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ReceiptMetadataRemoteDataSourceImpl] Supabase Storage upload warning: $e');
      }
      // Kembalikan storagePath awal jika upload storage gagal/mock
      return storagePath;
    }
  }

  @override
  Future<Uint8List?> downloadReceiptImage(
    String storagePath,
    String userId,
  ) async {
    try {
      if (userId.trim().isEmpty) {
        throw ArgumentError('User ID tidak boleh kosong.');
      }
      final cleanFileName = storagePath.contains('/')
          ? storagePath.split('/').last
          : storagePath;
      final targetPath = '$userId/$cleanFileName';

      final bytes = await _client.storage.from('receipts').download(targetPath);
      return bytes;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ReceiptMetadataRemoteDataSourceImpl] Supabase Storage download warning: $e');
      }
      return null;
    }
  }

  @override
  Future<String?> getReceiptSignedUrl(
    String storagePath,
    String userId, {
    int expiresInSeconds = 3600,
  }) async {
    try {
      if (userId.trim().isEmpty) {
        throw ArgumentError('User ID tidak boleh kosong.');
      }
      final cleanFileName = storagePath.contains('/')
          ? storagePath.split('/').last
          : storagePath;
      final targetPath = '$userId/$cleanFileName';

      final signedUrl = await _client.storage
          .from('receipts')
          .createSignedUrl(targetPath, expiresInSeconds);
      return signedUrl;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ReceiptMetadataRemoteDataSourceImpl] Supabase Storage signed URL warning: $e');
      }
      return null;
    }
  }

  @override
  Future<void> deleteReceiptImage(String storagePath, String userId) async {
    try {
      if (userId.trim().isEmpty) return;
      final cleanFileName = storagePath.contains('/')
          ? storagePath.split('/').last
          : storagePath;
      final targetPath = '$userId/$cleanFileName';

      final pathsToRemove = {targetPath, storagePath}.toList();
      await _client.storage.from('receipts').remove(pathsToRemove);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ReceiptMetadataRemoteDataSourceImpl] Supabase Storage remove warning: $e');
      }
    }
  }
}
