import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import 'package:myfinance/core/database/app_database.dart';
import 'package:myfinance/core/errors/exceptions.dart';
import 'package:myfinance/core/errors/failures.dart';
import 'package:myfinance/core/services/supabase_service.dart';
import 'package:myfinance/features/wallets/domain/entities/wallet.dart';
import 'package:myfinance/features/wallets/data/repositories/wallet_repository_impl.dart';
import 'package:myfinance/features/transactions/domain/entities/transaction.dart';
import 'package:myfinance/features/transfers/domain/entities/transfer.dart';
import 'package:myfinance/features/transfers/data/datasources/transfer_remote_data_source.dart';
import 'package:myfinance/features/transfers/data/repositories/transfer_repository_impl.dart';
import 'package:myfinance/features/transfers/presentation/controllers/transfer_controller.dart';

/// Fake TransferRemoteDataSource yang mensimulasikan Supabase PostgreSQL Cloud dengan RLS
class FakeTransferRemoteDataSource implements TransferRemoteDataSource {
  final Map<String, Map<String, dynamic>> _cloudTable = {};
  bool shouldThrowError = false;

  @override
  Future<List<Transfer>> getTransfers(String userId, {int limit = 50}) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Network connection timeout', 'PGRST_TIMEOUT');
    }

    // RLS: WHERE user_id = :userId AND type = 'transfer'
    return _cloudTable.values
        .where((row) => row['user_id'] == userId && row['type'] == 'transfer')
        .map(_mapToTransfer)
        .toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  }

  @override
  Future<Transfer?> getTransferById(String id, String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Database query failed', '42P01');
    }

    final row = _cloudTable[id];
    // RLS: Baris data hanya dapat dibaca jika user_id sama
    if (row == null || row['user_id'] != userId || row['type'] != 'transfer') return null;
    return _mapToTransfer(row);
  }

  @override
  Future<List<Transfer>> getTransfersForWallet(String walletId, String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Database query failed', '42P01');
    }

    // RLS: WHERE user_id = :userId AND type = 'transfer' AND (wallet_id = :wId OR destination_wallet_id = :wId)
    return _cloudTable.values
        .where((row) =>
            row['user_id'] == userId &&
            row['type'] == 'transfer' &&
            (row['wallet_id'] == walletId || row['destination_wallet_id'] == walletId))
        .map(_mapToTransfer)
        .toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  }

  @override
  Future<void> createTransfer(Transfer transfer, String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Failed to insert transfer into cloud', '23505');
    }

    _cloudTable[transfer.id] = {
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
    };
  }

  @override
  Future<void> updateTransfer(Transfer transfer, String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Failed to update transfer in cloud', '42501');
    }

    final existing = _cloudTable[transfer.id];
    if (existing == null || existing['user_id'] != userId) {
      throw const SupabaseDatabaseException('Transfer not found or permission denied', '404');
    }

    existing['amount'] = transfer.amount;
    existing['occurred_at'] = transfer.occurredAt;
    existing['wallet_id'] = transfer.sourceWalletId;
    existing['destination_wallet_id'] = transfer.destinationWalletId;
    existing['merchant'] = transfer.merchant;
    existing['description'] = transfer.description;
    existing['notes'] = transfer.notes;
    existing['status'] = transfer.status.toDbString();
    existing['updated_at'] = DateTime.now().toUtc().toIso8601String();
  }

  @override
  Future<void> voidTransfer(String id, String userId, String updatedAtUtcIso) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Failed to void transfer in cloud', '42501');
    }

    final existing = _cloudTable[id];
    if (existing != null && existing['user_id'] == userId) {
      existing['status'] = 'voided';
      existing['updated_at'] = updatedAtUtcIso;
    }
  }

  @override
  Future<void> deleteTransfer(String id, String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Failed to delete transfer in cloud', '42501');
    }

    final existing = _cloudTable[id];
    if (existing != null && existing['user_id'] == userId) {
      _cloudTable.remove(id);
    }
  }

  Transfer _mapToTransfer(Map<String, dynamic> row) {
    return Transfer(
      id: row['id'] as String,
      amount: row['amount'] as int,
      occurredAt: row['occurred_at'] as String,
      sourceWalletId: row['wallet_id'] as String? ?? '',
      destinationWalletId: row['destination_wallet_id'] as String?,
      merchant: row['merchant'] as String?,
      description: row['description'] as String?,
      notes: row['notes'] as String?,
      source: row['source'] as String? ?? 'manual',
      status: TransactionStatus.fromString(row['status'] as String? ?? 'confirmed'),
      createdAt: row['created_at'] as String? ?? '',
      updatedAt: row['updated_at'] as String? ?? '',
    );
  }
}

/// Fake SupabaseService untuk mock authenticated user session
class FakeSupabaseService extends SupabaseService {
  String? _fakeUid;
  bool _fakeIsAuth = false;

  void setAuthenticatedUser(String uid) {
    _fakeUid = uid;
    _fakeIsAuth = true;
  }

  void clearSession() {
    _fakeUid = null;
    _fakeIsAuth = false;
  }

  @override
  bool get isAuthenticated => _fakeIsAuth;

  @override
  sp.User? get currentUser => _fakeIsAuth && _fakeUid != null
      ? sp.User(
          id: _fakeUid!,
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        )
      : null;
}

void main() {
  late AppDatabase db;
  late WalletRepositoryImpl walletRepo;
  late FakeTransferRemoteDataSource fakeRemoteDataSource;
  late FakeSupabaseService fakeSupabaseService;
  late TransferRepositoryImpl transferRepo;

  const testUserId = 'user-uuid-111';
  const otherUserId = 'user-uuid-222';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    walletRepo = WalletRepositoryImpl(db.walletsDao, db.transactionsDao);
    fakeRemoteDataSource = FakeTransferRemoteDataSource();
    fakeSupabaseService = FakeSupabaseService();
    fakeSupabaseService.setAuthenticatedUser(testUserId);

    transferRepo = TransferRepositoryImpl(
      db.transactionsDao,
      db.walletsDao,
      remoteDataSource: fakeRemoteDataSource,
      supabaseService: fakeSupabaseService,
    );

    // Setup dompet uji
    final now = DateTime.now().toUtc().toIso8601String();
    await walletRepo.createWallet(
      Wallet(
        id: 'w-cash',
        name: 'Dompet Tunai',
        type: WalletType.cash,
        openingBalance: 1000000,
        openingDate: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await walletRepo.createWallet(
      Wallet(
        id: 'w-bank',
        name: 'Bank BCA',
        type: WalletType.bank,
        openingBalance: 5000000,
        openingDate: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Domain Transfers — 12 Poin Pengujian Komprehensif', () {
    // 1. Test load Transfers
    test('1. Test load Transfers: berhasil mengambil daftar transfer dari cloud dan memperkaya data dompet', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      final transfer = Transfer(
        id: 'tr-load-1',
        amount: 250000,
        occurredAt: now,
        sourceWalletId: 'w-bank',
        destinationWalletId: 'w-cash',
        description: 'Tarik tunai ATM',
        createdAt: now,
        updatedAt: now,
      );

      await fakeRemoteDataSource.createTransfer(transfer, testUserId);

      final list = await transferRepo.getTransfers();
      expect(list.length, equals(1));
      expect(list.first.id, equals('tr-load-1'));
      expect(list.first.amount, equals(250000));
      expect(list.first.sourceWallet?.name, equals('Bank BCA'));
      expect(list.first.destinationWallet?.name, equals('Dompet Tunai'));
      expect(list.first.displaySubtitle, equals('Bank BCA → Dompet Tunai'));
    });

    // 2. Test create Transfers
    test('2. Test create Transfers: mencatat transfer internal dan eksternal ke SQLite dan Supabase', () async {
      final now = DateTime.now().toUtc().toIso8601String();

      // Transfer Internal
      final internalTransfer = Transfer(
        id: 'tr-create-int',
        amount: 500000,
        occurredAt: now,
        sourceWalletId: 'w-bank',
        destinationWalletId: 'w-cash',
        description: 'Pindah dana ke dompet',
        createdAt: now,
        updatedAt: now,
      );
      await transferRepo.createTransfer(internalTransfer);

      // Verifikasi SQLite lokal
      final localTx = await db.transactionsDao.getTransactionById('tr-create-int');
      expect(localTx, isNotNull);
      expect(localTx!.type, equals('transfer'));
      expect(localTx.amount, equals(500000));
      expect(localTx.walletId, equals('w-bank'));
      expect(localTx.destinationWalletId, equals('w-cash'));

      // Verifikasi Cloud Supabase
      final cloudTx = await fakeRemoteDataSource.getTransferById('tr-create-int', testUserId);
      expect(cloudTx, isNotNull);
      expect(cloudTx!.amount, equals(500000));

      // Transfer Eksternal
      final externalTransfer = Transfer(
        id: 'tr-create-ext',
        amount: 150000,
        occurredAt: now,
        sourceWalletId: 'w-cash',
        destinationWalletId: null,
        merchant: 'Mandiri - Budi Santoso',
        description: 'Bayar hutang',
        createdAt: now,
        updatedAt: now,
      );
      await transferRepo.createTransfer(externalTransfer);

      final localExt = await db.transactionsDao.getTransactionById('tr-create-ext');
      expect(localExt, isNotNull);
      expect(localExt!.destinationWalletId, isNull);
      expect(localExt.merchant, equals('Mandiri - Budi Santoso'));
    });

    // 3. Test edit Transfers
    test('3. Test edit Transfers: memperbarui nominal dan keterangan transfer di lokal dan cloud', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      final transfer = Transfer(
        id: 'tr-edit-1',
        amount: 100000,
        occurredAt: now,
        sourceWalletId: 'w-cash',
        destinationWalletId: 'w-bank',
        description: 'Setor tunai',
        createdAt: now,
        updatedAt: now,
      );
      await transferRepo.createTransfer(transfer);

      // Edit nominal menjadi 200.000
      final updated = transfer.copyWith(
        amount: 200000,
        description: 'Setor tunai revisi',
      );
      await transferRepo.updateTransfer(updated);

      final resultLocal = await db.transactionsDao.getTransactionById('tr-edit-1');
      expect(resultLocal!.amount, equals(200000));
      expect(resultLocal.description, equals('Setor tunai revisi'));

      final resultCloud = await fakeRemoteDataSource.getTransferById('tr-edit-1', testUserId);
      expect(resultCloud!.amount, equals(200000));
    });

    // 4. Test delete Transfers
    test('4. Test delete Transfers: menghapus mutasi transfer dari cache lokal dan cloud', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      final transfer = Transfer(
        id: 'tr-del-1',
        amount: 75000,
        occurredAt: now,
        sourceWalletId: 'w-cash',
        destinationWalletId: 'w-bank',
        createdAt: now,
        updatedAt: now,
      );
      await transferRepo.createTransfer(transfer);

      await transferRepo.deleteTransfer('tr-del-1');

      final localEntry = await db.transactionsDao.getTransactionById('tr-del-1');
      expect(localEntry, isNull);

      final cloudEntry = await fakeRemoteDataSource.getTransferById('tr-del-1', testUserId);
      expect(cloudEntry, isNull);
    });

    // 5. Test Transfers detail
    test('5. Test Transfers detail: mengambil entitas transfer detail dengan resolusi wallet nama', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      final transfer = Transfer(
        id: 'tr-detail-1',
        amount: 300000,
        occurredAt: now,
        sourceWalletId: 'w-bank',
        destinationWalletId: 'w-cash',
        notes: 'Catatan penting transfer',
        createdAt: now,
        updatedAt: now,
      );
      await transferRepo.createTransfer(transfer);

      final detail = await transferRepo.getTransferById('tr-detail-1');
      expect(detail, isNotNull);
      expect(detail!.displayTitle, equals('Transfer ke Dompet Tunai'));
      expect(detail.sourceWallet?.id, equals('w-bank'));
      expect(detail.destinationWallet?.id, equals('w-cash'));
      expect(detail.notes, equals('Catatan penting transfer'));
    });

    // 6. Test Transfers balance
    test('6. Test Transfers balance: saldo dompet sumber berkurang, dompet tujuan bertambah, total aset tetap', () async {
      final now = DateTime.now().toUtc().toIso8601String();

      // Saldo awal: w-cash = 1.000.000, w-bank = 5.000.000. Total Aset = 6.000.000
      final initialCashBalance = await walletRepo.calculateWalletBalance('w-cash');
      final initialBankBalance = await walletRepo.calculateWalletBalance('w-bank');
      final initialTotalAssets = await walletRepo.calculateTotalAssetBalance();
      expect(initialCashBalance, equals(1000000));
      expect(initialBankBalance, equals(5000000));
      expect(initialTotalAssets, equals(6000000));

      // Transfer 500.000 dari w-bank ke w-cash
      final transfer = Transfer(
        id: 'tr-bal-1',
        amount: 500000,
        occurredAt: now,
        sourceWalletId: 'w-bank',
        destinationWalletId: 'w-cash',
        createdAt: now,
        updatedAt: now,
      );
      await transferRepo.createTransfer(transfer);

      // Verifikasi saldo setelah transfer
      final afterBankBalance = await walletRepo.calculateWalletBalance('w-bank');
      final afterCashBalance = await walletRepo.calculateWalletBalance('w-cash');
      final afterTotalAssets = await walletRepo.calculateTotalAssetBalance();

      expect(afterBankBalance, equals(4500000)); // 5.000.000 - 500.000
      expect(afterCashBalance, equals(1500000)); // 1.000.000 + 500.000
      expect(afterTotalAssets, equals(6000000)); // Delta = 0, invariant terjaga!

      // Verifikasi calculateWalletTransferBalance
      final bankTransferNet = await transferRepo.calculateWalletTransferBalance('w-bank');
      final cashTransferNet = await transferRepo.calculateWalletTransferBalance('w-cash');
      expect(bankTransferNet, equals(-500000)); // Transfer Keluar
      expect(cashTransferNet, equals(500000));  // Transfer Masuk
    });

    // 7. Test Transfers selection
    test('7. Test Transfers selection: mengambil mutasi yang hanya melibatkan wallet tertentu', () async {
      final now = DateTime.now().toUtc().toIso8601String();

      // Tambah dompet ke-3
      await walletRepo.createWallet(
        Wallet(
          id: 'w-ewallet',
          name: 'GoPay',
          type: WalletType.eWallet,
          openingBalance: 100000,
          openingDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Transfer 1: w-bank -> w-cash
      await transferRepo.createTransfer(
        Transfer(
          id: 'tr-sel-1',
          amount: 100000,
          occurredAt: now,
          sourceWalletId: 'w-bank',
          destinationWalletId: 'w-cash',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Transfer 2: w-bank -> w-ewallet
      await transferRepo.createTransfer(
        Transfer(
          id: 'tr-sel-2',
          amount: 50000,
          occurredAt: now,
          sourceWalletId: 'w-bank',
          destinationWalletId: 'w-ewallet',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Selection untuk w-cash harus hanya mendapatkan tr-sel-1
      final cashTransfers = await transferRepo.getTransfersForWallet('w-cash');
      expect(cashTransfers.length, equals(1));
      expect(cashTransfers.first.id, equals('tr-sel-1'));

      // Selection untuk w-bank harus mendapatkan kedua transfer (tr-sel-1 dan tr-sel-2)
      final bankTransfers = await transferRepo.getTransfersForWallet('w-bank');
      expect(bankTransfers.length, equals(2));
    });

    // 8. Test user ownership
    test('8. Test user ownership: seluruh transfer cloud terasosiasi dengan user_id pengguna terautentikasi', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      final transfer = Transfer(
        id: 'tr-owner-1',
        amount: 200000,
        occurredAt: now,
        sourceWalletId: 'w-bank',
        destinationWalletId: 'w-cash',
        createdAt: now,
        updatedAt: now,
      );
      await transferRepo.createTransfer(transfer);

      final cloudRow = fakeRemoteDataSource._cloudTable['tr-owner-1'];
      expect(cloudRow, isNotNull);
      expect(cloudRow!['user_id'], equals(testUserId));
    });

    // 9. Test RLS
    test('9. Test RLS: user tidak dapat mengakses atau memodifikasi transfer milik user lain', () async {
      final now = DateTime.now().toUtc().toIso8601String();

      // User lain membuat transfer di cloud
      final otherTransfer = Transfer(
        id: 'tr-other-user',
        amount: 999000,
        occurredAt: now,
        sourceWalletId: 'w-other-1',
        destinationWalletId: 'w-other-2',
        createdAt: now,
        updatedAt: now,
      );
      await fakeRemoteDataSource.createTransfer(otherTransfer, otherUserId);

      // Pengguna aktif mencoba mengambil data
      final fetched = await fakeRemoteDataSource.getTransferById('tr-other-user', testUserId);
      expect(fetched, isNull); // Terblokir oleh RLS

      final list = await fakeRemoteDataSource.getTransfers(testUserId);
      expect(list.any((t) => t.id == 'tr-other-user'), isFalse);
    });

    // 10. Test error handling
    test('10. Test error handling: validasi gagal jika nominal <= 0, wallet sama, atau wallet tidak ditemukan', () async {
      final now = DateTime.now().toUtc().toIso8601String();

      // Nominal 0
      expect(
        () => transferRepo.createTransfer(
          Transfer(
            id: 'err-1',
            amount: 0,
            occurredAt: now,
            sourceWalletId: 'w-bank',
            destinationWalletId: 'w-cash',
            createdAt: now,
            updatedAt: now,
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );

      // Dompet sumber dan tujuan sama
      expect(
        () => transferRepo.createTransfer(
          Transfer(
            id: 'err-2',
            amount: 100000,
            occurredAt: now,
            sourceWalletId: 'w-bank',
            destinationWalletId: 'w-bank',
            createdAt: now,
            updatedAt: now,
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );

      // Dompet sumber tidak ditemukan
      expect(
        () => transferRepo.createTransfer(
          Transfer(
            id: 'err-3',
            amount: 100000,
            occurredAt: now,
            sourceWalletId: 'w-non-existent',
            destinationWalletId: 'w-cash',
            createdAt: now,
            updatedAt: now,
          ),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    // 11. Test loading state
    test('11. Test loading state: TransferController menangani state loading dan error dengan mulus', () async {
      final controller = TransferController(transferRepo);
      expect(controller.state.isLoading, isFalse);

      final success = await controller.createTransfer(
        amount: 250000,
        occurredAt: DateTime.now(),
        sourceWalletId: 'w-bank',
        destinationWalletId: 'w-cash',
        description: 'Transfer via controller',
      );

      expect(success, isTrue);
      expect(controller.state.hasError, isFalse);
      expect(controller.state.isLoading, isFalse);
    });

    // 12. Test Void Transfer
    test('12. Test Void Transfer: pembatalan transfer mengembalikan dampak saldo buku besar', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      final transfer = Transfer(
        id: 'tr-void-1',
        amount: 1000000,
        occurredAt: now,
        sourceWalletId: 'w-bank',
        destinationWalletId: 'w-cash',
        createdAt: now,
        updatedAt: now,
      );
      await transferRepo.createTransfer(transfer);

      // Sebelum void: w-bank = 4.000.000, w-cash = 2.000.000
      expect(await walletRepo.calculateWalletBalance('w-bank'), equals(4000000));
      expect(await walletRepo.calculateWalletBalance('w-cash'), equals(2000000));

      // Batalkan (void) transfer
      await transferRepo.voidTransfer('tr-void-1');

      // Setelah void: saldo kedua dompet kembali seperti semula
      expect(await walletRepo.calculateWalletBalance('w-bank'), equals(5000000));
      expect(await walletRepo.calculateWalletBalance('w-cash'), equals(1000000));

      // Verifikasi status di cloud
      final cloudTx = await fakeRemoteDataSource.getTransferById('tr-void-1', testUserId);
      expect(cloudTx!.status, equals(TransactionStatus.voided));
    });
  });
}
