import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/database/daos/transactions_dao.dart';
import '../../domain/entities/receipt_metadata.dart';
import '../../domain/repositories/receipt_metadata_repository.dart';

/// Layanan penyimpanan lampiran struk lokal dan sinkronisasi cloud (Blueprint Section 7.4).
/// Menyimpan file di direktori sandboxed Documents/Application Support aplikasi serta cloud.
class AttachmentStorageService {
  final TransactionsDao _transactionsDao;
  final ReceiptMetadataRepository? _metadataRepository;

  AttachmentStorageService(
    this._transactionsDao, {
    ReceiptMetadataRepository? metadataRepository,
  }) : _metadataRepository = metadataRepository;

  /// Menyalin atau menyimpan file gambar struk ke sandbox lokal dan mencatatnya ke database
  Future<String> saveReceiptAttachment({
    required String transactionId,
    required String originalPath,
    Uint8List? imageBytes,
  }) async {
    final attachmentId = const Uuid().v4();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    String relativePath = 'receipts/$attachmentId.jpg';
    int fileSize = imageBytes?.lengthInBytes ?? 1024;

    try {
      if (!kIsWeb) {
        final docsDir = await getApplicationDocumentsDirectory();
        final receiptsDir = Directory(p.join(docsDir.path, 'receipts'));
        if (!await receiptsDir.exists()) {
          await receiptsDir.create(recursive: true);
        }

        final targetFile = File(p.join(receiptsDir.path, '$attachmentId.jpg'));

        if (imageBytes != null && imageBytes.isNotEmpty) {
          await targetFile.writeAsBytes(imageBytes);
          fileSize = imageBytes.lengthInBytes;
        } else if (originalPath.isNotEmpty && !originalPath.startsWith('sample:')) {
          final src = File(originalPath);
          if (await src.exists()) {
            await src.copy(targetFile.path);
            fileSize = await targetFile.length();
            imageBytes = await targetFile.readAsBytes();
          }
        }
        relativePath = p.join('receipts', '$attachmentId.jpg').replaceAll(r'\', '/');
      }
    } catch (e) {
      debugPrint('Warning: Could not copy attachment file physically: $e');
    }

    final metadata = ReceiptMetadata(
      id: attachmentId,
      transactionId: transactionId,
      storagePath: relativePath,
      fileSize: fileSize,
      createdAt: nowIso,
    );

    // 1. Catat ke SQLite lokal
    await _transactionsDao.insertOrReplaceAttachment(metadata.toCompanion());

    // 2. Sinkronkan via ReceiptMetadataRepository jika tersedia
    if (_metadataRepository != null) {
      try {
        await _metadataRepository.saveReceiptMetadata(
          metadata,
          imageBytes: imageBytes,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AttachmentStorageService] Metadata repo save warning: $e');
        }
      }
    }

    return relativePath;
  }
}
