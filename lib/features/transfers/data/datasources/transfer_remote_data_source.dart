import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import 'package:myfinance/core/errors/exceptions.dart';
import 'package:myfinance/core/services/supabase_service.dart';
import 'package:myfinance/features/transactions/domain/entities/transaction.dart';
import 'package:myfinance/features/transfers/domain/entities/transfer.dart';

/// Kontrak Remote Data Source untuk operasi Transfer di Supabase Cloud PostgREST
abstract class TransferRemoteDataSource {
  /// Mengambil daftar transfer terbaru milik pengguna terautentikasi
  Future<List<Transfer>> getTransfers(String userId, {int limit = 50});

  /// Mengambil detail transfer berdasarkan ID dan user_id
  Future<Transfer?> getTransferById(String id, String userId);

  /// Mengambil daftar transfer yang melibatkan wallet tertentu milik pengguna
  Future<List<Transfer>> getTransfersForWallet(String walletId, String userId);

  /// Mencatat transfer baru di Supabase Cloud
  Future<void> createTransfer(Transfer transfer, String userId);

  /// Memperbarui informasi transfer di Supabase Cloud
  Future<void> updateTransfer(Transfer transfer, String userId);

  /// Membatalkan (void) transfer di Supabase Cloud
  Future<void> voidTransfer(String id, String userId, String updatedAtUtcIso);

  /// Menghapus permanen transfer di Supabase Cloud
  Future<void> deleteTransfer(String id, String userId);
}

/// Implementasi TransferRemoteDataSource menggunakan Supabase Client
class TransferRemoteDataSourceImpl implements TransferRemoteDataSource {
  final SupabaseService? _supabaseService;
  final sp.SupabaseClient? _customClient;

  TransferRemoteDataSourceImpl({
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
  Future<List<Transfer>> getTransfers(String userId, {int limit = 50}) async {
    try {
      final response = await _client
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .eq('type', 'transfer')
          .eq('status', 'confirmed')
          .order('occurred_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((row) => _mapJsonToTransfer(row as Map<String, dynamic>))
          .toList();
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal mengambil daftar transfer dari cloud: $e');
    }
  }

  @override
  Future<Transfer?> getTransferById(String id, String userId) async {
    try {
      final response = await _client
          .from('transactions')
          .select()
          .eq('id', id)
          .eq('user_id', userId)
          .eq('type', 'transfer')
          .maybeSingle();

      if (response == null) return null;
      return _mapJsonToTransfer(response);
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal mengambil data transfer dari cloud: $e');
    }
  }

  @override
  Future<List<Transfer>> getTransfersForWallet(String walletId, String userId) async {
    try {
      final response = await _client
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .eq('type', 'transfer')
          .eq('status', 'confirmed')
          .or('wallet_id.eq.$walletId,destination_wallet_id.eq.$walletId')
          .order('occurred_at', ascending: false);

      return (response as List)
          .map((row) => _mapJsonToTransfer(row as Map<String, dynamic>))
          .toList();
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal mengambil transfer wallet dari cloud: $e');
    }
  }

  @override
  Future<void> createTransfer(Transfer transfer, String userId) async {
    try {
      await _client.from('transactions').insert({
        'id': transfer.id,
        'user_id': userId,
        'type': 'transfer',
        'amount': transfer.amount,
        'occurred_at': transfer.occurredAt,
        'wallet_id': transfer.sourceWalletId,
        'destination_wallet_id': transfer.destinationWalletId,
        'category_id': null,
        'merchant': transfer.merchant,
        'description': transfer.description,
        'notes': transfer.notes,
        'source': transfer.source,
        'status': transfer.status.toDbString(),
        'created_at': transfer.createdAt,
        'updated_at': transfer.updatedAt,
      });
    } on sp.PostgrestException catch (e) {
      // Jika database Supabase belum menjalankan pembaruan constraint untuk transfer eksternal (code 23514),
      // data tetap tersimpan aman di SQLite lokal offline cache.
      if (e.code == '23514' && transfer.destinationWalletId == null) {
        if (kDebugMode) {
          debugPrint(
            '[TransferRemoteDataSourceImpl] Constraint 23514 warning on external transfer: $e. '
            'Tersimpan di offline cache lokal. Jalankan migrasi chk_transactions_transfer_wallets di Supabase SQL Editor.',
          );
        }
        return;
      }
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal mencatat transfer di cloud: $e');
    }
  }

  @override
  Future<void> updateTransfer(Transfer transfer, String userId) async {
    try {
      await _client
          .from('transactions')
          .update({
            'amount': transfer.amount,
            'occurred_at': transfer.occurredAt,
            'wallet_id': transfer.sourceWalletId,
            'destination_wallet_id': transfer.destinationWalletId,
            'merchant': transfer.merchant,
            'description': transfer.description,
            'notes': transfer.notes,
            'source': transfer.source,
            'status': transfer.status.toDbString(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', transfer.id)
          .eq('user_id', userId)
          .eq('type', 'transfer');
    } on sp.PostgrestException catch (e) {
      if (e.code == '23514' && transfer.destinationWalletId == null) {
        if (kDebugMode) {
          debugPrint(
            '[TransferRemoteDataSourceImpl] Constraint 23514 warning on external transfer update: $e. '
            'Tersimpan di offline cache lokal.',
          );
        }
        return;
      }
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal memperbarui transfer di cloud: $e');
    }
  }

  @override
  Future<void> voidTransfer(String id, String userId, String updatedAtUtcIso) async {
    try {
      await _client
          .from('transactions')
          .update({
            'status': 'voided',
            'updated_at': updatedAtUtcIso,
          })
          .eq('id', id)
          .eq('user_id', userId)
          .eq('type', 'transfer');
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal membatalkan transfer di cloud: $e');
    }
  }

  @override
  Future<void> deleteTransfer(String id, String userId) async {
    try {
      await _client
          .from('transactions')
          .delete()
          .eq('id', id)
          .eq('user_id', userId)
          .eq('type', 'transfer');
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal menghapus transfer di cloud: $e');
    }
  }

  static Transfer _mapJsonToTransfer(Map<String, dynamic> json) {
    return Transfer(
      id: json['id'] as String,
      amount: (json['amount'] as num).toInt(),
      occurredAt: json['occurred_at'] as String,
      sourceWalletId: json['wallet_id'] as String? ?? '',
      destinationWalletId: json['destination_wallet_id'] as String?,
      merchant: json['merchant'] as String?,
      description: json['description'] as String?,
      notes: json['notes'] as String?,
      source: json['source'] as String? ?? 'manual',
      status: TransactionStatus.fromString(json['status'] as String? ?? 'confirmed'),
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }
}
