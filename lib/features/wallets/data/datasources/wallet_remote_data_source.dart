import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_service.dart';
import '../../domain/entities/wallet.dart';

/// Kontrak Remote Data Source untuk operasi PostgREST tabel `wallets`
abstract class WalletRemoteDataSource {
  /// Mengambil semua wallet aktif milik user
  Future<List<Wallet>> getActiveWallets(String userId);

  /// Mengambil semua wallet diarsipkan milik user
  Future<List<Wallet>> getArchivedWallets(String userId);

  /// Mengambil satu wallet berdasarkan ID dan user_id
  Future<Wallet?> getWalletById(String id, String userId);

  /// Menyimpan wallet baru ke Supabase
  Future<void> createWallet(Wallet wallet, String userId);

  /// Memperbarui informasi wallet di Supabase
  Future<void> updateWallet(Wallet wallet, String userId);

  /// Mengarsipkan wallet di Supabase (soft delete)
  Future<void> archiveWallet(String id, String userId);

  /// Mengaktifkan kembali wallet di Supabase
  Future<void> unarchiveWallet(String id, String userId);

  /// Menghapus permanen wallet di Supabase
  Future<void> deleteWallet(String id, String userId);

  /// Menghitung saldo berjalan wallet dari ledger transaksi terkonfirmasi di cloud
  Future<int> calculateWalletBalance(String walletId, int openingBalance, String userId);

  /// Menghitung total saldo seluruh aset aktif milik user di cloud
  Future<int> calculateTotalAssetBalance(String userId);
}

/// Implementasi WalletRemoteDataSource menggunakan Supabase Client
class WalletRemoteDataSourceImpl implements WalletRemoteDataSource {
  final SupabaseService? _supabaseService;
  final sp.SupabaseClient? _customClient;

  WalletRemoteDataSourceImpl({
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
  Future<List<Wallet>> getActiveWallets(String userId) async {
    try {
      final response = await _client
          .from('wallets')
          .select()
          .eq('user_id', userId)
          .eq('is_archived', false)
          .order('created_at', ascending: true);

      return (response as List)
          .map((row) => _mapJsonToWallet(row as Map<String, dynamic>))
          .toList();
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal mengambil daftar dompet dari cloud: $e');
    }
  }

  @override
  Future<List<Wallet>> getArchivedWallets(String userId) async {
    try {
      final response = await _client
          .from('wallets')
          .select()
          .eq('user_id', userId)
          .eq('is_archived', true)
          .order('created_at', ascending: true);

      return (response as List)
          .map((row) => _mapJsonToWallet(row as Map<String, dynamic>))
          .toList();
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal mengambil daftar arsip dompet dari cloud: $e');
    }
  }

  @override
  Future<Wallet?> getWalletById(String id, String userId) async {
    try {
      final response = await _client
          .from('wallets')
          .select()
          .eq('id', id)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return _mapJsonToWallet(response);
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal mengambil data dompet: $e');
    }
  }

  @override
  Future<void> createWallet(Wallet wallet, String userId) async {
    try {
      await _client.from('wallets').insert({
        'id': wallet.id,
        'user_id': userId,
        'name': wallet.name,
        'type': wallet.type.toDbString(),
        'opening_balance': wallet.openingBalance,
        'opening_date': wallet.openingDate,
        'currency_code': wallet.currencyCode,
        'icon_key': wallet.iconKey,
        'color_hex': wallet.colorHex,
        'is_archived': wallet.isArchived,
        'created_at': wallet.createdAt,
        'updated_at': wallet.updatedAt,
      });
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal membuat dompet baru di cloud: $e');
    }
  }

  @override
  Future<void> updateWallet(Wallet wallet, String userId) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _client
          .from('wallets')
          .update({
            'name': wallet.name,
            'type': wallet.type.toDbString(),
            'opening_balance': wallet.openingBalance,
            'opening_date': wallet.openingDate,
            'currency_code': wallet.currencyCode,
            'icon_key': wallet.iconKey,
            'color_hex': wallet.colorHex,
            'is_archived': wallet.isArchived,
            'updated_at': now,
          })
          .eq('id', wallet.id)
          .eq('user_id', userId);
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal memperbarui dompet di cloud: $e');
    }
  }

  @override
  Future<void> archiveWallet(String id, String userId) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _client
          .from('wallets')
          .update({
            'is_archived': true,
            'updated_at': now,
          })
          .eq('id', id)
          .eq('user_id', userId);
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal mengarsipkan dompet di cloud: $e');
    }
  }

  @override
  Future<void> unarchiveWallet(String id, String userId) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      await _client
          .from('wallets')
          .update({
            'is_archived': false,
            'updated_at': now,
          })
          .eq('id', id)
          .eq('user_id', userId);
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal mengaktifkan kembali dompet di cloud: $e');
    }
  }

  @override
  Future<void> deleteWallet(String id, String userId) async {
    try {
      await _client
          .from('wallets')
          .delete()
          .eq('id', id)
          .eq('user_id', userId);
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal menghapus dompet di cloud: $e');
    }
  }

  @override
  Future<int> calculateWalletBalance(String walletId, int openingBalance, String userId) async {
    int balance = openingBalance;
    try {
      final response = await _client
          .from('transactions')
          .select('id, type, amount, status, wallet_id, destination_wallet_id')
          .eq('user_id', userId)
          .eq('status', 'confirmed')
          .or('wallet_id.eq.$walletId,destination_wallet_id.eq.$walletId');

      for (final tx in (response as List)) {
        final row = tx as Map<String, dynamic>;
        final type = row['type'] as String;
        final amount = (row['amount'] as num).toInt();
        final wId = row['wallet_id'] as String?;
        final destId = row['destination_wallet_id'] as String?;

        if (type == 'income' && wId == walletId) {
          balance += amount;
        } else if (type == 'expense' && wId == walletId) {
          balance -= amount;
        } else if (type == 'transfer') {
          if (destId == walletId) balance += amount;
          if (wId == walletId) balance -= amount;
        }
      }
    } on sp.PostgrestException catch (e) {
      // Jika tabel transactions belum dibuat di database (e.g. 42P01), gunakan opening balance
      if (e.code == '42P01' || e.code == 'PGRST205') {
        return openingBalance;
      }
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal menghitung saldo buku besar di cloud: $e');
    }
    return balance;
  }

  @override
  Future<int> calculateTotalAssetBalance(String userId) async {
    final activeWallets = await getActiveWallets(userId);
    int total = 0;
    for (final wallet in activeWallets) {
      final balance = await calculateWalletBalance(wallet.id, wallet.openingBalance, userId);
      total += balance;
    }
    return total;
  }

  Wallet _mapJsonToWallet(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'] as String,
      name: json['name'] as String,
      type: WalletType.fromString(json['type'] as String),
      openingBalance: (json['opening_balance'] as num).toInt(),
      openingDate: json['opening_date'] as String,
      currencyCode: (json['currency_code'] as String?) ?? 'IDR',
      iconKey: json['icon_key'] as String?,
      colorHex: json['color_hex'] as String?,
      isArchived: (json['is_archived'] as bool?) ?? false,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }
}
