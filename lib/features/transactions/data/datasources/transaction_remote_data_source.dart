import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_service.dart';
import '../../domain/entities/transaction.dart';

/// Kontrak Remote Data Source untuk operasi PostgREST tabel `transactions`
abstract class TransactionRemoteDataSource {
  /// Mengambil daftar transaksi terbaru milik user
  Future<List<Transaction>> getRecentTransactions(String userId, {int limit = 50});

  /// Mengambil transaksi yang melibatkan wallet tertentu milik user
  Future<List<Transaction>> getTransactionsForWallet(String walletId, String userId);

  /// Mengambil transaksi dalam rentang tanggal tertentu milik user
  Future<List<Transaction>> getTransactionsInDateRange(
    String userId,
    String startIsoUtc,
    String endIsoUtc, {
    TransactionType? filterType,
  });

  /// Mengambil satu transaksi berdasarkan ID dan user_id
  Future<Transaction?> getTransactionById(String id, String userId);

  /// Menyimpan transaksi baru ke Supabase Cloud
  Future<void> createTransaction(Transaction transaction, String userId);

  /// Memperbarui transaksi di Supabase Cloud
  Future<void> updateTransaction(Transaction transaction, String userId);

  /// Membatalkan (void) transaksi di Supabase Cloud
  Future<void> voidTransaction(String id, String userId, String updatedAtUtcIso);

  /// Menghapus permanen transaksi di Supabase Cloud
  Future<void> deleteTransaction(String id, String userId);

  /// Menghitung total pemasukan terkonfirmasi bulan tertentu milik user
  Future<int> getMonthlyIncome(String userId, int year, int month);

  /// Menghitung total pengeluaran terkonfirmasi bulan tertentu milik user
  Future<int> getMonthlyExpense(String userId, int year, int month);
}

/// Implementasi TransactionRemoteDataSource menggunakan Supabase Client
class TransactionRemoteDataSourceImpl implements TransactionRemoteDataSource {
  final SupabaseService? _supabaseService;
  final sp.SupabaseClient? _customClient;

  TransactionRemoteDataSourceImpl({
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
  Future<List<Transaction>> getRecentTransactions(String userId, {int limit = 50}) async {
    try {
      final response = await _client
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .order('occurred_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((row) => _mapJsonToTransaction(row as Map<String, dynamic>))
          .toList();
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal mengambil daftar transaksi dari cloud: $e');
    }
  }

  @override
  Future<List<Transaction>> getTransactionsForWallet(String walletId, String userId) async {
    try {
      final response = await _client
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .or('wallet_id.eq.$walletId,destination_wallet_id.eq.$walletId')
          .order('occurred_at', ascending: false);

      return (response as List)
          .map((row) => _mapJsonToTransaction(row as Map<String, dynamic>))
          .toList();
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal mengambil mutasi dompet dari cloud: $e');
    }
  }

  @override
  Future<List<Transaction>> getTransactionsInDateRange(
    String userId,
    String startIsoUtc,
    String endIsoUtc, {
    TransactionType? filterType,
  }) async {
    try {
      var query = _client
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .gte('occurred_at', startIsoUtc)
          .lte('occurred_at', endIsoUtc);

      if (filterType != null) {
        query = query.eq('type', filterType.toDbString());
      }

      final response = await query.order('occurred_at', ascending: false);

      return (response as List)
          .map((row) => _mapJsonToTransaction(row as Map<String, dynamic>))
          .toList();
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal mengambil transaksi rentang tanggal dari cloud: $e');
    }
  }

  @override
  Future<Transaction?> getTransactionById(String id, String userId) async {
    try {
      final response = await _client
          .from('transactions')
          .select()
          .eq('id', id)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return _mapJsonToTransaction(response);
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal mengambil data transaksi dari cloud: $e');
    }
  }

  @override
  Future<void> createTransaction(Transaction transaction, String userId) async {
    try {
      await _client.from('transactions').insert({
        'id': transaction.id,
        'user_id': userId,
        'type': transaction.type.toDbString(),
        'amount': transaction.amount,
        'occurred_at': transaction.occurredAt,
        'wallet_id': transaction.walletId,
        'destination_wallet_id': transaction.destinationWalletId,
        'category_id': transaction.categoryId,
        'merchant': transaction.merchant,
        'description': transaction.description,
        'notes': transaction.notes,
        'source': transaction.source,
        'status': transaction.status.toDbString(),
        'created_at': transaction.createdAt,
        'updated_at': transaction.updatedAt,
      });
    } on sp.PostgrestException catch (e) {
      if (e.code == '23514' && transaction.type == TransactionType.transfer && transaction.destinationWalletId == null) {
        if (kDebugMode) {
          debugPrint(
            '[TransactionRemoteDataSourceImpl] Constraint 23514 warning on external transfer: $e. '
            'Tersimpan di offline cache lokal. Jalankan migrasi chk_transactions_transfer_wallets di Supabase SQL Editor.',
          );
        }
        return;
      }
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal mencatat transaksi di cloud: $e');
    }
  }

  @override
  Future<void> updateTransaction(Transaction transaction, String userId) async {
    try {
      await _client
          .from('transactions')
          .update({
            'type': transaction.type.toDbString(),
            'amount': transaction.amount,
            'occurred_at': transaction.occurredAt,
            'wallet_id': transaction.walletId,
            'destination_wallet_id': transaction.destinationWalletId,
            'category_id': transaction.categoryId,
            'merchant': transaction.merchant,
            'description': transaction.description,
            'notes': transaction.notes,
            'source': transaction.source,
            'status': transaction.status.toDbString(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', transaction.id)
          .eq('user_id', userId);
    } on sp.PostgrestException catch (e) {
      if (e.code == '23514' && transaction.type == TransactionType.transfer && transaction.destinationWalletId == null) {
        if (kDebugMode) {
          debugPrint(
            '[TransactionRemoteDataSourceImpl] Constraint 23514 warning on external transfer update: $e. '
            'Tersimpan di offline cache lokal.',
          );
        }
        return;
      }
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal memperbarui transaksi di cloud: $e');
    }
  }

  @override
  Future<void> voidTransaction(String id, String userId, String updatedAtUtcIso) async {
    try {
      await _client
          .from('transactions')
          .update({
            'status': 'voided',
            'updated_at': updatedAtUtcIso,
          })
          .eq('id', id)
          .eq('user_id', userId);
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal membatalkan transaksi di cloud: $e');
    }
  }

  @override
  Future<void> deleteTransaction(String id, String userId) async {
    try {
      // 1. Bersihkan berkas fisik struk di Supabase Storage bucket 'receipts' sebelum menghapus transaksi
      try {
        final attsRes = await _client
            .from('transaction_attachments')
            .select('storage_path')
            .eq('transaction_id', id)
            .eq('user_id', userId);
        for (final row in attsRes as List) {
          final storagePath = row['storage_path'] as String?;
          if (storagePath != null && storagePath.isNotEmpty) {
            final cleanFileName = storagePath.contains('/')
                ? storagePath.split('/').last
                : storagePath;
            final targetPath = '$userId/$cleanFileName';
            await _client.storage.from('receipts').remove([targetPath]);
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[TransactionRemoteDataSourceImpl] Supabase Storage cleanup warning: $e');
        }
      }

      // 2. Hapus baris transaksi (PostgreSQL ON DELETE CASCADE akan membersihkan baris di transaction_attachments)
      await _client
          .from('transactions')
          .delete()
          .eq('id', id)
          .eq('user_id', userId);
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal menghapus transaksi di cloud: $e');
    }
  }

  @override
  Future<int> getMonthlyIncome(String userId, int year, int month) async {
    try {
      final start = DateTime(year, month, 1).toUtc().toIso8601String();
      final end = DateTime(year, month + 1, 0, 23, 59, 59, 999).toUtc().toIso8601String();

      final response = await _client
          .from('transactions')
          .select('amount')
          .eq('user_id', userId)
          .eq('type', 'income')
          .eq('status', 'confirmed')
          .gte('occurred_at', start)
          .lte('occurred_at', end);

      int total = 0;
      for (final row in response as List) {
        final amt = row['amount'];
        if (amt is num) total += amt.toInt();
      }
      return total;
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal menghitung pemasukan bulanan: $e');
    }
  }

  @override
  Future<int> getMonthlyExpense(String userId, int year, int month) async {
    try {
      final start = DateTime(year, month, 1).toUtc().toIso8601String();
      final end = DateTime(year, month + 1, 0, 23, 59, 59, 999).toUtc().toIso8601String();

      final response = await _client
          .from('transactions')
          .select('amount')
          .eq('user_id', userId)
          .eq('type', 'expense')
          .eq('status', 'confirmed')
          .gte('occurred_at', start)
          .lte('occurred_at', end);

      int total = 0;
      for (final row in response as List) {
        final amt = row['amount'];
        if (amt is num) total += amt.toInt();
      }
      return total;
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal menghitung pengeluaran bulanan: $e');
    }
  }

  static Transaction _mapJsonToTransaction(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      type: TransactionType.fromString(json['type'] as String),
      amount: (json['amount'] as num).toInt(),
      occurredAt: json['occurred_at'] as String,
      walletId: json['wallet_id'] as String?,
      destinationWalletId: json['destination_wallet_id'] as String?,
      categoryId: json['category_id'] as String?,
      merchant: json['merchant'] as String?,
      description: json['description'] as String?,
      notes: json['notes'] as String?,
      source: (json['source'] as String?) ?? 'manual',
      status: TransactionStatus.fromString((json['status'] as String?) ?? 'confirmed'),
      createdAt: (json['created_at'] as String?) ?? DateTime.now().toUtc().toIso8601String(),
      updatedAt: (json['updated_at'] as String?) ?? DateTime.now().toUtc().toIso8601String(),
    );
  }
}
