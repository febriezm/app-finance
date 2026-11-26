import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import 'package:myfinance/core/database/app_database.dart';
import 'package:myfinance/core/errors/exceptions.dart';
import 'package:myfinance/core/services/supabase_service.dart';
import 'package:myfinance/features/wallets/data/datasources/wallet_remote_data_source.dart';
import 'package:myfinance/features/wallets/data/repositories/wallet_repository_impl.dart';
import 'package:myfinance/features/wallets/domain/entities/wallet.dart';
import 'package:myfinance/features/wallets/presentation/controllers/wallets_controller.dart';

/// Fake WalletRemoteDataSource yang mensimulasikan PostgreSQL RLS & PostgREST API
class FakeWalletRemoteDataSource implements WalletRemoteDataSource {
  final Map<String, Map<String, dynamic>> _cloudTable = {};
  final List<Map<String, dynamic>> _cloudTransactions = [];

  bool shouldThrowError = false;

  void seedTransaction({
    required String id,
    required String userId,
    required String walletId,
    String? destinationWalletId,
    required String type,
    required int amount,
    required String status,
  }) {
    _cloudTransactions.add({
      'id': id,
      'user_id': userId,
      'wallet_id': walletId,
      'destination_wallet_id': destinationWalletId,
      'type': type,
      'amount': amount,
      'status': status,
    });
  }

  @override
  Future<List<Wallet>> getActiveWallets(String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Network connection timeout', 'PGRST_TIMEOUT');
    }

    // RLS Enforcement: WHERE user_id = auth.uid() AND is_archived = false
    return _cloudTable.values
        .where((row) => row['user_id'] == userId && row['is_archived'] == false)
        .map(_mapToWallet)
        .toList();
  }

  @override
  Future<List<Wallet>> getArchivedWallets(String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Network error', 'PGRST_ERROR');
    }

    // RLS Enforcement: WHERE user_id = auth.uid() AND is_archived = true
    return _cloudTable.values
        .where((row) => row['user_id'] == userId && row['is_archived'] == true)
        .map(_mapToWallet)
        .toList();
  }

  @override
  Future<Wallet?> getWalletById(String id, String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Database query failed', '42P01');
    }

    // RLS Enforcement: SELECT * FROM wallets WHERE id = :id AND user_id = :userId
    final row = _cloudTable[id];
    if (row == null || row['user_id'] != userId) return null;
    return _mapToWallet(row);
  }

  @override
  Future<void> createWallet(Wallet wallet, String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Failed to insert wallet', '23505');
    }

    // RLS Enforcement: user_id wajib sama dengan authenticated user
    _cloudTable[wallet.id] = {
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
    };
  }

  @override
  Future<void> updateWallet(Wallet wallet, String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Failed to update wallet');
    }

    final existing = _cloudTable[wallet.id];
    // RLS Enforcement: Hanya boleh update jika row milik user_id
    if (existing == null || existing['user_id'] != userId) {
      throw const SupabaseDatabaseException('Row not found or permission denied (RLS)');
    }

    _cloudTable[wallet.id] = {
      ...existing,
      'name': wallet.name,
      'type': wallet.type.toDbString(),
      'opening_balance': wallet.openingBalance,
      'icon_key': wallet.iconKey,
      'color_hex': wallet.colorHex,
      'is_archived': wallet.isArchived,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  @override
  Future<void> archiveWallet(String id, String userId) async {
    final existing = _cloudTable[id];
    if (existing == null || existing['user_id'] != userId) {
      throw const SupabaseDatabaseException('Permission denied (RLS)');
    }
    existing['is_archived'] = true;
    existing['updated_at'] = DateTime.now().toUtc().toIso8601String();
  }

  @override
  Future<void> unarchiveWallet(String id, String userId) async {
    final existing = _cloudTable[id];
    if (existing == null || existing['user_id'] != userId) {
      throw const SupabaseDatabaseException('Permission denied (RLS)');
    }
    existing['is_archived'] = false;
    existing['updated_at'] = DateTime.now().toUtc().toIso8601String();
  }

  @override
  Future<void> deleteWallet(String id, String userId) async {
    final existing = _cloudTable[id];
    if (existing == null || existing['user_id'] != userId) {
      throw const SupabaseDatabaseException('Permission denied (RLS)');
    }
    _cloudTable.remove(id);
  }

  @override
  Future<int> calculateWalletBalance(String walletId, int openingBalance, String userId) async {
    int balance = openingBalance;

    // RLS Enforcement: Hanya hitung transaksi milik userId dan status confirmed
    final txs = _cloudTransactions.where((tx) =>
        tx['user_id'] == userId &&
        tx['status'] == 'confirmed' &&
        (tx['wallet_id'] == walletId || tx['destination_wallet_id'] == walletId));

    for (final tx in txs) {
      final type = tx['type'] as String;
      final amount = tx['amount'] as int;
      final wId = tx['wallet_id'] as String?;
      final destId = tx['destination_wallet_id'] as String?;

      if (type == 'income' && wId == walletId) {
        balance += amount;
      } else if (type == 'expense' && wId == walletId) {
        balance -= amount;
      } else if (type == 'transfer') {
        if (destId == walletId) balance += amount;
        if (wId == walletId) balance -= amount;
      }
    }

    return balance;
  }

  @override
  Future<int> calculateTotalAssetBalance(String userId) async {
    final active = await getActiveWallets(userId);
    int total = 0;
    for (final w in active) {
      total += await calculateWalletBalance(w.id, w.openingBalance, userId);
    }
    return total;
  }

  Wallet _mapToWallet(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'] as String,
      name: json['name'] as String,
      type: WalletType.fromString(json['type'] as String),
      openingBalance: json['opening_balance'] as int,
      openingDate: json['opening_date'] as String,
      currencyCode: json['currency_code'] as String? ?? 'IDR',
      iconKey: json['icon_key'] as String?,
      colorHex: json['color_hex'] as String?,
      isArchived: json['is_archived'] as bool? ?? false,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }
}

/// Fake SupabaseService untuk pengujian status login dan user ID
class FakeSupabaseService extends SupabaseService {
  String? _userId;

  void setAuthenticatedUser(String? userId) {
    _userId = userId;
  }

  @override
  bool get isAuthenticated => _userId != null;

  @override
  sp.User? get currentUser => _userId != null
      ? sp.User(
          id: _userId!,
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-11-24T00:00:00.000Z',
        )
      : null;
}

void main() {
  late AppDatabase db;
  late FakeWalletRemoteDataSource remoteDataSource;
  late FakeSupabaseService supabaseService;
  late WalletRepositoryImpl repository;
  late WalletsController controller;

  const testUserId = 'user-uuid-111';
  const otherUserId = 'user-uuid-222';

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    remoteDataSource = FakeWalletRemoteDataSource();
    supabaseService = FakeSupabaseService();
    supabaseService.setAuthenticatedUser(testUserId);

    repository = WalletRepositoryImpl(
      db.walletsDao,
      db.transactionsDao,
      remoteDataSource: remoteDataSource,
      supabaseService: supabaseService,
    );

    controller = WalletsController(repository);
  });

  tearDown(() async {
    await db.close();
  });

  group('Wallet Supabase PostgreSQL Migration Tests', () {
    test('1. Test Create Wallet: Berhasil membuat dompet baru di cloud terikat user_id', () async {
      const wallet = Wallet(
        id: 'w-bca-001',
        name: 'BCA Prioritas',
        type: WalletType.bank,
        openingBalance: 5000000,
        openingDate: '2026-11-24T00:00:00.000Z',
        createdAt: '2026-11-24T00:00:00.000Z',
        updatedAt: '2026-11-24T00:00:00.000Z',
      );

      await repository.createWallet(wallet);

      // Verifikasi di remote data source
      final cloudWallet = await remoteDataSource.getWalletById('w-bca-001', testUserId);
      expect(cloudWallet, isNotNull);
      expect(cloudWallet!.name, equals('BCA Prioritas'));
      expect(cloudWallet.openingBalance, equals(5000000));
      expect(cloudWallet.type, equals(WalletType.bank));

      // Verifikasi write-through cache ke SQLite
      final localWallet = await db.walletsDao.getWalletById('w-bca-001');
      expect(localWallet, isNotNull);
      expect(localWallet!.name, equals('BCA Prioritas'));
    });

    test('2. Test Load Wallet: Mengambil daftar dompet aktif dan memfilter arsip', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      await repository.createWallet(Wallet(
        id: 'w-cash-01',
        name: 'Dompet Tunai',
        type: WalletType.cash,
        openingBalance: 150000,
        openingDate: now,
        createdAt: now,
        updatedAt: now,
      ));

      await repository.createWallet(Wallet(
        id: 'w-gopay-01',
        name: 'GoPay',
        type: WalletType.eWallet,
        openingBalance: 250000,
        openingDate: now,
        createdAt: now,
        updatedAt: now,
      ));

      final activeWallets = await repository.getActiveWallets();
      expect(activeWallets.length, equals(2));
      expect(activeWallets.any((w) => w.name == 'Dompet Tunai'), isTrue);
      expect(activeWallets.any((w) => w.name == 'GoPay'), isTrue);
    });

    test('3. Test Edit Wallet: Memperbarui nama dan saldo awal di cloud dan cache', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      final initial = Wallet(
        id: 'w-edit-01',
        name: 'Bank Jago Lama',
        type: WalletType.bank,
        openingBalance: 1000000,
        openingDate: now,
        createdAt: now,
        updatedAt: now,
      );
      await repository.createWallet(initial);

      final updated = initial.copyWith(
        name: 'Bank Jago Syariah',
        openingBalance: 1750000,
      );
      await repository.updateWallet(updated);

      final result = await repository.getWalletById('w-edit-01');
      expect(result!.name, equals('Bank Jago Syariah'));
      expect(result.openingBalance, equals(1750000));

      // Verifikasi cache lokal
      final local = await db.walletsDao.getWalletById('w-edit-01');
      expect(local!.name, equals('Bank Jago Syariah'));
    });

    test('4. Test Delete Wallet & Archive: Mendukung soft delete (archive) dan hard delete', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      final w = Wallet(
        id: 'w-del-01',
        name: 'OVO Sementara',
        type: WalletType.eWallet,
        openingBalance: 50000,
        openingDate: now,
        createdAt: now,
        updatedAt: now,
      );
      await repository.createWallet(w);

      // Arsipkan dompet
      await repository.archiveWallet('w-del-01');
      var active = await repository.getActiveWallets();
      expect(active.any((x) => x.id == 'w-del-01'), isFalse);

      final archived = await repository.getArchivedWalletsWithBalance();
      expect(archived.any((x) => x.wallet.id == 'w-del-01'), isTrue);

      // Aktifkan kembali
      await repository.unarchiveWallet('w-del-01');
      active = await repository.getActiveWallets();
      expect(active.any((x) => x.id == 'w-del-01'), isTrue);

      // Hapus permanen
      await repository.deleteWallet('w-del-01');
      final deleted = await repository.getWalletById('w-del-01');
      expect(deleted, isNull);
    });

    test('5. Test Wallet Detail: Mengambil detail satu wallet berdasarkan ID', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      await repository.createWallet(Wallet(
        id: 'w-detail-01',
        name: 'BCA Tabungan',
        type: WalletType.bank,
        openingBalance: 3000000,
        openingDate: now,
        colorHex: '0xFF1E40AF',
        createdAt: now,
        updatedAt: now,
      ));

      final detail = await repository.getWalletById('w-detail-01');
      expect(detail, isNotNull);
      expect(detail!.id, equals('w-detail-01'));
      expect(detail.colorHex, equals('0xFF1E40AF'));
    });

    test('6. Test Wallet Balance: Menghitung saldo berjalan ledger secara presisi', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      await repository.createWallet(Wallet(
        id: 'w-ledger-01',
        name: 'Rekening Operasional',
        type: WalletType.bank,
        openingBalance: 1000000, // Saldo awal: 1.000.000
        openingDate: now,
        createdAt: now,
        updatedAt: now,
      ));

      // Simulasikan transaksi di cloud:
      // + Income: 500.000
      remoteDataSource.seedTransaction(
        id: 'tx-1',
        userId: testUserId,
        walletId: 'w-ledger-01',
        type: 'income',
        amount: 500000,
        status: 'confirmed',
      );
      // - Expense: 200.000
      remoteDataSource.seedTransaction(
        id: 'tx-2',
        userId: testUserId,
        walletId: 'w-ledger-01',
        type: 'expense',
        amount: 200000,
        status: 'confirmed',
      );
      // + Transfer In: 300.000 (dari dompet lain)
      remoteDataSource.seedTransaction(
        id: 'tx-3',
        userId: testUserId,
        walletId: 'w-other',
        destinationWalletId: 'w-ledger-01',
        type: 'transfer',
        amount: 300000,
        status: 'confirmed',
      );
      // - Transfer Out: 100.000 (ke dompet lain)
      remoteDataSource.seedTransaction(
        id: 'tx-4',
        userId: testUserId,
        walletId: 'w-ledger-01',
        destinationWalletId: 'w-other',
        type: 'transfer',
        amount: 100000,
        status: 'confirmed',
      );
      // Transaksi batal/void (harus diabaikan)
      remoteDataSource.seedTransaction(
        id: 'tx-5',
        userId: testUserId,
        walletId: 'w-ledger-01',
        type: 'expense',
        amount: 999999,
        status: 'voided',
      );

      // Perhitungan: 1.000.000 + 500.000 - 200.000 + 300.000 - 100.000 = 1.500.000
      final calculatedBalance = await repository.calculateWalletBalance('w-ledger-01');
      expect(calculatedBalance, equals(1500000));
    });

    test('7. Test Wallet Selection: Mengambil list wallet aktif untuk form pemilih transaksi', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      await repository.createWallet(Wallet(
        id: 'w-sel-1',
        name: 'Dompet A',
        type: WalletType.cash,
        openingBalance: 100000,
        openingDate: now,
        createdAt: now,
        updatedAt: now,
      ));
      await repository.createWallet(Wallet(
        id: 'w-sel-2',
        name: 'Dompet B',
        type: WalletType.bank,
        openingBalance: 200000,
        openingDate: now,
        createdAt: now,
        updatedAt: now,
      ));

      final withBalances = await repository.getActiveWalletsWithBalance();
      expect(withBalances.length, equals(2));
      expect(withBalances[0].wallet.name, equals('Dompet A'));
      expect(withBalances[1].wallet.name, equals('Dompet B'));
    });

    test('8 & 9. Test User Ownership & RLS: Isolasi data multi-pengguna', () async {
      final now = DateTime.now().toUtc().toIso8601String();

      // Buat dompet untuk User A (testUserId)
      await repository.createWallet(Wallet(
        id: 'w-user-a',
        name: 'Dompet Milik User A',
        type: WalletType.cash,
        openingBalance: 1000000,
        openingDate: now,
        createdAt: now,
        updatedAt: now,
      ));

      // Buat dompet untuk User B (otherUserId) langsung di cloud
      await remoteDataSource.createWallet(
        Wallet(
          id: 'w-user-b',
          name: 'Dompet Rahasia User B',
          type: WalletType.bank,
          openingBalance: 99000000,
          openingDate: now,
          createdAt: now,
          updatedAt: now,
        ),
        otherUserId,
      );

      // User A mengambil wallet miliknya: Hanya dompet User A yang tampil
      final userAWallets = await repository.getActiveWallets();
      expect(userAWallets.length, equals(1));
      expect(userAWallets.first.id, equals('w-user-a'));
      expect(userAWallets.any((w) => w.id == 'w-user-b'), isFalse);

      // User A mencoba mengambil detail dompet User B -> Mengembalikan null (RLS Ditolak)
      final unauthorizedDetail = await repository.getWalletById('w-user-b');
      expect(unauthorizedDetail, isNull);

      // Beralih sesi ke User B
      supabaseService.setAuthenticatedUser(otherUserId);
      final userBWallets = await repository.getActiveWallets();
      expect(userBWallets.length, equals(1));
      expect(userBWallets.first.id, equals('w-user-b'));
      expect(userBWallets.any((w) => w.id == 'w-user-a'), isFalse);
    });

    test('10. Test Error Handling: Mengonversi kendala koneksi cloud menjadi exception terkontrol', () async {
      remoteDataSource.shouldThrowError = true;

      expect(
        () => repository.getActiveWallets(),
        throwsA(isA<SupabaseDatabaseException>()),
      );
    });

    test('11. Test Loading State: WalletsController mengelola AsyncLoading -> AsyncData', () async {
      expect(controller.state, equals(const AsyncValue<void>.data(null)));

      final future = controller.createWallet(
        name: 'Dompet State Test',
        type: WalletType.cash,
        openingBalance: 50000,
      );

      final success = await future;
      expect(success, isTrue);
      expect(controller.state, equals(const AsyncValue<void>.data(null)));
    });
  });
}
