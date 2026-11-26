import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';

/// Entitas domain untuk metadata lampiran struk belanja (Receipt Metadata)
class ReceiptMetadata {
  final String id;
  final String transactionId;
  final String storagePath;
  final String mimeType;
  final int fileSize;
  final String createdAt;
  final String? userId;

  const ReceiptMetadata({
    required this.id,
    required this.transactionId,
    required this.storagePath,
    this.mimeType = 'image/jpeg',
    required this.fileSize,
    required this.createdAt,
    this.userId,
  });

  ReceiptMetadata copyWith({
    String? id,
    String? transactionId,
    String? storagePath,
    String? mimeType,
    int? fileSize,
    String? createdAt,
    String? userId,
  }) {
    return ReceiptMetadata(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      storagePath: storagePath ?? this.storagePath,
      mimeType: mimeType ?? this.mimeType,
      fileSize: fileSize ?? this.fileSize,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
    );
  }

  static ReceiptMetadata fromEntry(TransactionAttachmentEntry entry, {String? userId}) {
    return ReceiptMetadata(
      id: entry.id,
      transactionId: entry.transactionId,
      storagePath: entry.localPath,
      mimeType: entry.mimeType,
      fileSize: entry.fileSize,
      createdAt: entry.createdAt,
      userId: userId,
    );
  }

  TransactionAttachmentsTableCompanion toCompanion() {
    return TransactionAttachmentsTableCompanion(
      id: Value(id),
      transactionId: Value(transactionId),
      localPath: Value(storagePath),
      mimeType: Value(mimeType),
      fileSize: Value(fileSize),
      createdAt: Value(createdAt),
    );
  }

  Map<String, dynamic> toSupabaseMap(String authenticatedUserId) {
    return {
      'id': id,
      'user_id': authenticatedUserId,
      'transaction_id': transactionId,
      'storage_path': storagePath,
      'mime_type': mimeType,
      'file_size': fileSize,
      'created_at': createdAt,
    };
  }

  static ReceiptMetadata fromSupabaseMap(Map<String, dynamic> map) {
    return ReceiptMetadata(
      id: map['id'] as String,
      transactionId: map['transaction_id'] as String,
      storagePath: (map['storage_path'] ?? map['local_path'] ?? '') as String,
      mimeType: (map['mime_type'] as String?) ?? 'image/jpeg',
      fileSize: (map['file_size'] as num?)?.toInt() ?? 0,
      createdAt: (map['created_at'] as String?) ?? DateTime.now().toUtc().toIso8601String(),
      userId: map['user_id'] as String?,
    );
  }
}
