import 'dart:typed_data';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import 'package:myfinance/core/database/app_database.dart';
import 'package:myfinance/core/errors/exceptions.dart';
import 'package:myfinance/core/services/supabase_service.dart';
import 'package:myfinance/features/wallets/domain/entities/wallet.dart';
import 'package:myfinance/features/wallets/data/repositories/wallet_repository_impl.dart';
import 'package:myfinance/features/categories/domain/entities/category.dart';
import 'package:myfinance/features/transactions/domain/entities/transaction.dart';
import 'package:myfinance/features/transactions/domain/entities/transaction_with_details.dart';
import 'package:myfinance/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:myfinance/app/app_providers.dart';
import 'package:myfinance/features/reports/domain/entities/monthly_report.dart';
import 'package:myfinance/features/reports/domain/entities/wallet_report_item.dart';
import 'package:myfinance/features/reports/data/datasources/report_remote_data_source.dart';
import 'package:myfinance/features/reports/data/repositories/report_repository_impl.dart';

/// Fake ReportRemoteDataSource yang mensimulasikan Supabase PostgreSQL Cloud dengan RLS
class FakeReportRemoteDataSource implements ReportRemoteDataSource {
  final Map<String, Map<String, dynamic>> cloudTransactionsTable = {};
  final Map<String, Map<String, dynamic>> cloudWalletsTable = {};
  final Map<String, Map<String, dynamic>> cloudCategoriesTable = {};
  final Map<String, Map<String, dynamic>> cloudSnapshotsTable = {};
  bool shouldThrowError = false;

  @override
  Future<MonthlyReport> getMonthlyReport(String monthKey, String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Network connection timeout', 'PGRST_TIMEOUT');
    }

    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    final startOfMonth = DateTime.utc(year, month, 1);
    final endOfMonth = DateTime.utc(year, month + 1, 0, 23, 59, 59, 999);

    // Filter RLS: user_id = userId
    final currentTxs = cloudTransactionsTable.values.where((row) {
      if (row['user_id'] != userId) return false;
      if (row['status'] != 'confirmed') return false;
      final occurredAt = DateTime.parse(row['occurred_at'] as String);
      return !occurredAt.isBefore(startOfMonth) && !occurredAt.isAfter(endOfMonth);
    }).toList();

    final userWallets = cloudWalletsTable.values.where((row) {
      return row['user_id'] == userId && row['is_archived'] != true;
    }).map(_mapToWallet).toList();

    final userCategories = cloudCategoriesTable.values.where((row) {
      return row['user_id'] == userId || row['user_id'] == null;
    }).map(_mapToCategory).toList();

    final catMap = {for (final c in userCategories) c.id: c};

    int totalIncome = 0;
    int totalExpense = 0;
    int confirmedTxCount = 0;

    final expenseCatAmounts = <String, int>{};
    final expenseCatCounts = <String, int>{};
    final incomeCatAmounts = <String, int>{};
    final incomeCatCounts = <String, int>{};

    final walletIncome = <String, int>{};
    final walletExpense = <String, int>{};
    final walletTransferIn = <String, int>{};
    final walletTransferOut = <String, int>{};
    final walletTxCounts = <String, int>{};

    for (final row in currentTxs) {
      confirmedTxCount++;
      final type = row['type'] as String;
      final amount = (row['amount'] as num).toInt();
      final catId = row['category_id'] as String?;
      final walletId = row['wallet_id'] as String?;
      final destWalletId = row['destination_wallet_id'] as String?;

      if (type == 'income') {
        totalIncome += amount;
        if (catId != null) {
          incomeCatAmounts[catId] = (incomeCatAmounts[catId] ?? 0) + amount;
          incomeCatCounts[catId] = (incomeCatCounts[catId] ?? 0) + 1;
        }
        if (walletId != null) {
          walletIncome[walletId] = (walletIncome[walletId] ?? 0) + amount;
          walletTxCounts[walletId] = (walletTxCounts[walletId] ?? 0) + 1;
        }
      } else if (type == 'expense') {
        totalExpense += amount;
        if (catId != null) {
          expenseCatAmounts[catId] = (expenseCatAmounts[catId] ?? 0) + amount;
          expenseCatCounts[catId] = (expenseCatCounts[catId] ?? 0) + 1;
        }
        if (walletId != null) {
          walletExpense[walletId] = (walletExpense[walletId] ?? 0) + amount;
          walletTxCounts[walletId] = (walletTxCounts[walletId] ?? 0) + 1;
        }
      } else if (type == 'transfer') {
        if (walletId != null) {
          walletTransferOut[walletId] = (walletTransferOut[walletId] ?? 0) + amount;
          walletTxCounts[walletId] = (walletTxCounts[walletId] ?? 0) + 1;
        }
        if (destWalletId != null) {
          walletTransferIn[destWalletId] = (walletTransferIn[destWalletId] ?? 0) + amount;
          walletTxCounts[destWalletId] = (walletTxCounts[destWalletId] ?? 0) + 1;
        }
      }
    }

    final netCashflow = totalIncome - totalExpense;
    final savingsRate = (totalIncome > 0 && netCashflow > 0)
        ? (netCashflow / totalIncome)
        : 0.0;

    final expenseBreakdown = expenseCatAmounts.entries.map((e) {
      final cat = catMap[e.key] ?? Category(id: e.key, name: 'Lainnya', type: CategoryType.expense);
      final pct = totalExpense > 0 ? (e.value / totalExpense) : 0.0;
      return CategoryReportItem(
        category: cat,
        amount: e.value,
        percentage: pct,
        transactionCount: expenseCatCounts[e.key] ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    final incomeBreakdown = incomeCatAmounts.entries.map((e) {
      final cat = catMap[e.key] ?? Category(id: e.key, name: 'Lainnya', type: CategoryType.income);
      final pct = totalIncome > 0 ? (e.value / totalIncome) : 0.0;
      return CategoryReportItem(
        category: cat,
        amount: e.value,
        percentage: pct,
        transactionCount: incomeCatCounts[e.key] ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    final walletBreakdown = userWallets.map((w) {
      return WalletReportItem(
        wallet: w,
        incomeAmount: walletIncome[w.id] ?? 0,
        expenseAmount: walletExpense[w.id] ?? 0,
        transferInAmount: walletTransferIn[w.id] ?? 0,
        transferOutAmount: walletTransferOut[w.id] ?? 0,
        transactionCount: walletTxCounts[w.id] ?? 0,
      );
    }).toList()
      ..sort((a, b) => (b.expenseAmount + b.incomeAmount).compareTo(a.expenseAmount + a.incomeAmount));

    // Previous month (MoM)
    final prevDate = DateTime.utc(year, month - 1, 1);
    final prevStart = DateTime.utc(prevDate.year, prevDate.month, 1);
    final prevEnd = DateTime.utc(prevDate.year, prevDate.month + 1, 0, 23, 59, 59, 999);

    final prevTxs = cloudTransactionsTable.values.where((row) {
      if (row['user_id'] != userId) return false;
      if (row['status'] != 'confirmed') return false;
      final occurredAt = DateTime.parse(row['occurred_at'] as String);
      return !occurredAt.isBefore(prevStart) && !occurredAt.isAfter(prevEnd);
    }).toList();

    int prevIncome = 0;
    int prevExpense = 0;
    for (final row in prevTxs) {
      final type = row['type'] as String;
      final amt = (row['amount'] as num).toInt();
      if (type == 'income') {
        prevIncome += amt;
      } else if (type == 'expense') {
        prevExpense += amt;
      }
    }
    final prevNet = prevIncome - prevExpense;

    return MonthlyReport(
      monthKey: monthKey,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netCashflow: netCashflow,
      savingsRate: savingsRate,
      expenseBreakdown: expenseBreakdown,
      incomeBreakdown: incomeBreakdown,
      walletBreakdown: walletBreakdown,
      totalTransactionsCount: confirmedTxCount,
      previousMonthIncome: prevIncome,
      previousMonthExpense: prevExpense,
      previousMonthNetCashflow: prevNet,
    );
  }

  @override
  Future<List<TransactionWithDetails>> getTransactionsForReport({
    required String monthKey,
    required String userId,
    String? categoryId,
    String? walletId,
  }) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Failed to load transaction details', 'PGRST_ERROR');
    }

    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    final startOfMonth = DateTime.utc(year, month, 1);
    final endOfMonth = DateTime.utc(year, month + 1, 0, 23, 59, 59, 999);

    final catMap = {
      for (final row in cloudCategoriesTable.values.where((r) => r['user_id'] == userId || r['user_id'] == null))
        row['id'] as String: _mapToCategory(row)
    };

    final walletMap = {
      for (final row in cloudWalletsTable.values.where((r) => r['user_id'] == userId))
        row['id'] as String: _mapToWallet(row)
    };

    final list = <TransactionWithDetails>[];
    for (final row in cloudTransactionsTable.values) {
      if (row['user_id'] != userId) continue;
      if (row['status'] != 'confirmed') continue;

      final occurredAt = DateTime.parse(row['occurred_at'] as String);
      if (occurredAt.isBefore(startOfMonth) || occurredAt.isAfter(endOfMonth)) continue;

      if (categoryId != null && row['category_id'] != categoryId) continue;
      if (walletId != null) {
        if (row['wallet_id'] != walletId && row['destination_wallet_id'] != walletId) continue;
      }

      final tx = _mapToTransaction(row);
      list.add(
        TransactionWithDetails(
          transaction: tx,
          wallet: tx.walletId != null ? walletMap[tx.walletId!] : null,
          destinationWallet: tx.destinationWalletId != null ? walletMap[tx.destinationWalletId!] : null,
          category: tx.categoryId != null ? catMap[tx.categoryId!] : null,
        ),
      );
    }
    return list;
  }

  @override
  Future<List<String>> getAvailableReportMonths(String userId) async {
    if (shouldThrowError) {
      throw const SupabaseDatabaseException('Network error', 'PGRST_NET');
    }

    final months = <String>{};
    for (final row in cloudTransactionsTable.values) {
      if (row['user_id'] != userId) continue;
      final occurredAt = row['occurred_at'] as String;
      if (occurredAt.length >= 7) {
        months.add(occurredAt.substring(0, 7));
      }
    }
    return months.toList()..sort((a, b) => b.compareTo(a));
  }

  @override
  Future<void> saveReportSnapshot(MonthlyReport report, String userId) async {
    if (shouldThrowError) throw const SupabaseDatabaseException('Failed to save snapshot');
    cloudSnapshotsTable['$userId-${report.monthKey}'] = {
      'user_id': userId,
      'month_key': report.monthKey,
      'total_income': report.totalIncome,
      'total_expense': report.totalExpense,
      'net_cashflow': report.netCashflow,
    };
  }

  @override
  Future<void> deleteReportSnapshot(String monthKey, String userId) async {
    if (shouldThrowError) throw const SupabaseDatabaseException('Failed to delete snapshot');
    cloudSnapshotsTable.remove('$userId-$monthKey');
  }

  Transaction _mapToTransaction(Map<String, dynamic> row) {
    return Transaction(
      id: row['id'] as String,
      type: TransactionType.fromString(row['type'] as String),
      amount: (row['amount'] as num).toInt(),
      occurredAt: row['occurred_at'] as String,
      walletId: row['wallet_id'] as String?,
      destinationWalletId: row['destination_wallet_id'] as String?,
      categoryId: row['category_id'] as String?,
      merchant: row['merchant'] as String?,
      description: row['description'] as String?,
      notes: row['notes'] as String?,
      source: (row['source'] as String?) ?? 'manual',
      status: TransactionStatus.fromString((row['status'] as String?) ?? 'confirmed'),
      createdAt: (row['created_at'] as String?) ?? DateTime.now().toUtc().toIso8601String(),
      updatedAt: (row['updated_at'] as String?) ?? DateTime.now().toUtc().toIso8601String(),
    );
  }

  Wallet _mapToWallet(Map<String, dynamic> row) {
    return Wallet(
      id: row['id'] as String,
      name: row['name'] as String,
      type: WalletType.fromString(row['type'] as String),
      openingBalance: (row['opening_balance'] as num).toInt(),
      openingDate: row['opening_date'] as String,
      currencyCode: (row['currency_code'] as String?) ?? 'IDR',
      iconKey: row['icon_key'] as String?,
      colorHex: row['color_hex'] as String?,
      isArchived: (row['is_archived'] as bool?) ?? false,
      createdAt: row['created_at'] as String,
      updatedAt: row['updated_at'] as String,
    );
  }

  Category _mapToCategory(Map<String, dynamic> row) {
    return Category(
      id: row['id'] as String,
      name: row['name'] as String,
      type: CategoryType.fromString(row['type'] as String),
      iconKey: row['icon_key'] as String?,
      colorHex: row['color_hex'] as String?,
      isSystem: (row['is_system'] as bool?) ?? false,
      isArchived: (row['is_archived'] as bool?) ?? false,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Fake SupabaseService untuk testing autentikasi
class FakeSupabaseService extends SupabaseService {
  final String _mockUserId;
  final bool _mockIsAuthenticated;

  FakeSupabaseService({
    String mockUserId = 'user-owner-123',
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
  late AppDatabase db;
  late WalletRepositoryImpl localWalletRepo;
  late TransactionRepositoryImpl localTxRepo;
  late FakeReportRemoteDataSource fakeRemoteDataSource;
  late FakeSupabaseService fakeSupabaseService;
  late ReportRepositoryImpl hybridReportRepo;

  const currentUserId = 'user-owner-123';
  const otherUserId = 'user-intruder-999';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final walletsDao = db.walletsDao;
    final transactionsDao = db.transactionsDao;
    final categoriesDao = db.categoriesDao;

    localWalletRepo = WalletRepositoryImpl(walletsDao, transactionsDao);
    localTxRepo = TransactionRepositoryImpl(transactionsDao, walletsDao, categoriesDao);

    fakeRemoteDataSource = FakeReportRemoteDataSource();
    fakeSupabaseService = FakeSupabaseService(
      mockUserId: currentUserId,
      mockIsAuthenticated: true,
    );

    hybridReportRepo = ReportRepositoryImpl(
      transactionRepository: localTxRepo,
      walletRepository: localWalletRepo,
      remoteDataSource: fakeRemoteDataSource,
      supabaseService: fakeSupabaseService,
    );

    // Setup Cloud Wallets
    fakeRemoteDataSource.cloudWalletsTable['w-1'] = {
      'id': 'w-1',
      'user_id': currentUserId,
      'name': 'BCA Utama',
      'type': 'bank',
      'opening_balance': 10000000,
      'opening_date': '2026-11-01T00:00:00.000Z',
      'currency_code': 'IDR',
      'is_archived': false,
      'created_at': '2026-11-01T00:00:00.000Z',
      'updated_at': '2026-11-01T00:00:00.000Z',
    };
    fakeRemoteDataSource.cloudWalletsTable['w-2'] = {
      'id': 'w-2',
      'user_id': currentUserId,
      'name': 'Dompet Tunai',
      'type': 'cash',
      'opening_balance': 2000000,
      'opening_date': '2026-11-01T00:00:00.000Z',
      'currency_code': 'IDR',
      'is_archived': false,
      'created_at': '2026-11-01T00:00:00.000Z',
      'updated_at': '2026-11-01T00:00:00.000Z',
    };

    // Setup Cloud Categories
    fakeRemoteDataSource.cloudCategoriesTable['cat-salary'] = {
      'id': 'cat-salary',
      'user_id': null, // Sistem
      'name': 'Gaji',
      'type': 'income',
      'is_system': true,
      'is_archived': false,
    };
    fakeRemoteDataSource.cloudCategoriesTable['cat-food'] = {
      'id': 'cat-food',
      'user_id': null,
      'name': 'Makanan & Minuman',
      'type': 'expense',
      'is_system': true,
      'is_archived': false,
    };
    fakeRemoteDataSource.cloudCategoriesTable['cat-transport'] = {
      'id': 'cat-transport',
      'user_id': currentUserId, // Kustom
      'name': 'Transportasi',
      'type': 'expense',
      'is_system': false,
      'is_archived': false,
    };

    // Setup Cloud Transactions (November 2026)
    fakeRemoteDataSource.cloudTransactionsTable['tx-inc-1'] = {
      'id': 'tx-inc-1',
      'user_id': currentUserId,
      'type': 'income',
      'amount': 15000000,
      'occurred_at': '2026-11-05T08:00:00.000Z',
      'wallet_id': 'w-1',
      'category_id': 'cat-salary',
      'status': 'confirmed',
    };
    fakeRemoteDataSource.cloudTransactionsTable['tx-exp-food'] = {
      'id': 'tx-exp-food',
      'user_id': currentUserId,
      'type': 'expense',
      'amount': 3000000,
      'occurred_at': '2026-11-10T12:00:00.000Z',
      'wallet_id': 'w-1',
      'category_id': 'cat-food',
      'status': 'confirmed',
    };
    fakeRemoteDataSource.cloudTransactionsTable['tx-exp-transport'] = {
      'id': 'tx-exp-transport',
      'user_id': currentUserId,
      'type': 'expense',
      'amount': 1000000,
      'occurred_at': '2026-11-15T15:00:00.000Z',
      'wallet_id': 'w-2',
      'category_id': 'cat-transport',
      'status': 'confirmed',
    };
    fakeRemoteDataSource.cloudTransactionsTable['tx-transfer'] = {
      'id': 'tx-transfer',
      'user_id': currentUserId,
      'type': 'transfer',
      'amount': 500000,
      'occurred_at': '2026-11-20T17:00:00.000Z',
      'wallet_id': 'w-1',
      'destination_wallet_id': 'w-2',
      'status': 'confirmed',
    };
    fakeRemoteDataSource.cloudTransactionsTable['tx-voided'] = {
      'id': 'tx-voided',
      'user_id': currentUserId,
      'type': 'expense',
      'amount': 9999999,
      'occurred_at': '2026-11-21T18:00:00.000Z',
      'wallet_id': 'w-1',
      'category_id': 'cat-food',
      'status': 'voided', // Harus diabaikan
    };

    // Setup Previous Month (Oktober 2026) for MoM comparison
    fakeRemoteDataSource.cloudTransactionsTable['tx-prev-inc'] = {
      'id': 'tx-prev-inc',
      'user_id': currentUserId,
      'type': 'income',
      'amount': 12000000,
      'occurred_at': '2026-10-05T08:00:00.000Z',
      'wallet_id': 'w-1',
      'category_id': 'cat-salary',
      'status': 'confirmed',
    };
    fakeRemoteDataSource.cloudTransactionsTable['tx-prev-exp'] = {
      'id': 'tx-prev-exp',
      'user_id': currentUserId,
      'type': 'expense',
      'amount': 5000000,
      'occurred_at': '2026-10-15T10:00:00.000Z',
      'wallet_id': 'w-1',
      'category_id': 'cat-food',
      'status': 'confirmed',
    };
  });

  tearDown(() async {
    await db.close();
  });

  group('Report Cloud Repository Tests (Supabase PostgreSQL Integration)', () {
    test('1. Test load Reports: Mengambil laporan bulanan dari cloud dan memverifikasi agregasi', () async {
      final report = await hybridReportRepo.getMonthlyReport('2026-11');

      expect(report.monthKey, equals('2026-11'));
      expect(report.totalIncome, equals(15000000));
      expect(report.totalExpense, equals(4000000)); // 3jt + 1jt (voided diabaikan)
      expect(report.netCashflow, equals(11000000)); // 15jt - 4jt
      expect(report.savingsRate, closeTo(11000000 / 15000000, 0.001));
      expect(report.totalTransactionsCount, equals(4)); // 1 inc, 2 exp, 1 transfer
    });

    test('2. Test create Reports: Membuat/menghasilkan laporan baru dan mengekspor ke format CSV & PDF', () async {
      final report = await hybridReportRepo.createOrGenerateReport('2026-11');
      final txs = await hybridReportRepo.getTransactionsForReport(monthKey: '2026-11');

      // Test Ekspor CSV
      final csvString = await hybridReportRepo.exportReportToCsv(report, txs);
      expect(csvString, contains('Laporan Keuangan MyFinance'));
      expect(csvString, contains('2026-11'));
      expect(csvString, contains('15000000'));
      expect(csvString, contains('4000000'));

      // Test Ekspor PDF
      final pdfBytes = await hybridReportRepo.exportReportToPdf(report, txs);
      expect(pdfBytes, isA<Uint8List>());
      expect(pdfBytes.length, greaterThan(100));
    });

    test('3. Test edit Reports: Memperbarui data laporan dengan refreshReport() setelah ada mutasi baru', () async {
      // 1. Ambil laporan awal
      final initialReport = await hybridReportRepo.getMonthlyReport('2026-11');
      expect(initialReport.totalExpense, equals(4000000));

      // 2. Tambah transaksi baru di cloud
      fakeRemoteDataSource.cloudTransactionsTable['tx-exp-bonus'] = {
        'id': 'tx-exp-bonus',
        'user_id': currentUserId,
        'type': 'expense',
        'amount': 2000000,
        'occurred_at': '2026-11-25T14:00:00.000Z',
        'wallet_id': 'w-1',
        'category_id': 'cat-food',
        'status': 'confirmed',
      };

      // 3. Refresh laporan
      final updatedReport = await hybridReportRepo.refreshReport('2026-11');
      expect(updatedReport.totalExpense, equals(6000000));
      expect(updatedReport.netCashflow, equals(9000000));
    });

    test('4. Test delete Reports: Menghapus snapshot dan membersihkan cache laporan bulanan', () async {
      await hybridReportRepo.createOrGenerateReport('2026-11');
      expect(fakeRemoteDataSource.cloudSnapshotsTable.containsKey('$currentUserId-2026-11'), isTrue);

      await hybridReportRepo.clearReportCache(monthKey: '2026-11');
      expect(fakeRemoteDataSource.cloudSnapshotsTable.containsKey('$currentUserId-2026-11'), isFalse);
    });

    test('5. Test Reports detail: Mengambil daftar transaksi pembentuk laporan dengan filter kategori dan dompet', () async {
      // 1. Detail seluruh transaksi laporan
      final allTxs = await hybridReportRepo.getTransactionsForReport(monthKey: '2026-11');
      expect(allTxs.length, equals(4));

      // 2. Filter berdasarkan kategori makanan
      final foodTxs = await hybridReportRepo.getTransactionsForReport(
        monthKey: '2026-11',
        categoryId: 'cat-food',
      );
      expect(foodTxs.length, equals(1));
      expect(foodTxs.first.transaction.amount, equals(3000000));

      // 3. Filter berdasarkan dompet w-2
      final w2Txs = await hybridReportRepo.getTransactionsForReport(
        monthKey: '2026-11',
        walletId: 'w-2',
      );
      // w-2 ada 1 pengeluaran (tx-exp-transport) dan 1 transfer masuk (tx-transfer)
      expect(w2Txs.length, equals(2));
    });

    test('6. Test Reports balance: Kalkulasi net cashflow, savings rate, dan transfer neutrality', () async {
      final report = await hybridReportRepo.getMonthlyReport('2026-11');

      // Net cashflow murni pemasukan dikurangi pengeluaran
      expect(report.netCashflow, equals(report.totalIncome - report.totalExpense));
      expect(report.isSurplus, isTrue);

      // Verifikasi MoM comparison
      expect(report.previousMonthIncome, equals(12000000));
      expect(report.previousMonthExpense, equals(5000000));
      expect(report.incomeChangePercentage, closeTo(25.0, 0.1)); // (15 - 12) / 12 * 100 = +25%
      expect(report.expenseChangePercentage, closeTo(-20.0, 0.1)); // (4 - 5) / 5 * 100 = -20%
    });

    test('7. Test Reports selection: Memilih laporan bulan berbeda menghasilkan data terisolasi', () async {
      final novReport = await hybridReportRepo.getMonthlyReport('2026-11');
      final octReport = await hybridReportRepo.getMonthlyReport('2026-10');

      expect(novReport.totalIncome, equals(15000000));
      expect(octReport.totalIncome, equals(12000000));
      expect(octReport.totalExpense, equals(5000000));

      final availableMonths = await hybridReportRepo.getAvailableReportMonths();
      expect(availableMonths, contains('2026-11'));
      expect(availableMonths, contains('2026-10'));
    });

    test('8. Test user ownership: Data laporan terikat pada user_id pengguna aktif', () async {
      expect(hybridReportRepo.currentUserId, equals(currentUserId));
      await hybridReportRepo.createOrGenerateReport('2026-11');

      final snapshot = fakeRemoteDataSource.cloudSnapshotsTable['$currentUserId-2026-11'];
      expect(snapshot, isNotNull);
      expect(snapshot!['user_id'], equals(currentUserId));
    });

    test('9. Test RLS: Mencegah data transaksi milik pengguna lain masuk ke laporan pengguna aktif', () async {
      // Masukkan transaksi user lain
      fakeRemoteDataSource.cloudTransactionsTable['tx-intruder-inc'] = {
        'id': 'tx-intruder-inc',
        'user_id': otherUserId, // Pengguna lain!
        'type': 'income',
        'amount': 50000000, // 50 juta
        'occurred_at': '2026-11-06T10:00:00.000Z',
        'wallet_id': 'w-1',
        'category_id': 'cat-salary',
        'status': 'confirmed',
      };

      final report = await hybridReportRepo.getMonthlyReport('2026-11');
      // Transaksi 50jt milik intruder tidak boleh dihitung
      expect(report.totalIncome, equals(15000000));
    });

    test('10. Test error handling: Fallback ke kalkulasi lokal saat cloud mengalami error/timeout', () async {
      // 1. Simpan data kategori dan dompet di lokal SQLite
      await db.into(db.categoriesTable).insert(
        CategoriesTableCompanion.insert(
          id: 'cat-salary',
          name: 'Gaji',
          type: 'income',
        ),
      );
      await db.into(db.walletsTable).insert(
        WalletsTableCompanion.insert(
          id: 'w-local',
          name: 'Dompet Lokal',
          type: 'cash',
          openingBalance: 1000000,
          openingDate: '2026-11-01T00:00:00.000Z',
          createdAt: '2026-11-01T00:00:00.000Z',
          updatedAt: '2026-11-01T00:00:00.000Z',
        ),
      );
      await localTxRepo.createTransaction(
        const Transaction(
          id: 'tx-local-1',
          type: TransactionType.income,
          amount: 2500000,
          occurredAt: '2026-11-08T10:00:00.000Z',
          walletId: 'w-local',
          categoryId: 'cat-salary',
          status: TransactionStatus.confirmed,
          createdAt: '2026-11-08T10:00:00.000Z',
          updatedAt: '2026-11-08T10:00:00.000Z',
        ),
      );

      // 2. Set cloud error
      fakeRemoteDataSource.shouldThrowError = true;

      // 3. Request laporan: harus fallback ke SQLite lokal tanpa crash
      final fallbackReport = await hybridReportRepo.getMonthlyReport('2026-11');
      expect(fallbackReport.totalIncome, equals(2500000));
      expect(fallbackReport.totalTransactionsCount, equals(1));
    });

    test('11. Test loading state: Provider Riverpod mengelola AsyncValue secara reaktif', () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          reportRepositoryProvider.overrideWithValue(hybridReportRepo),
        ],
      );
      addTearDown(container.dispose);

      // Baca report via Riverpod
      final asyncReport = container.read(monthlyReportProvider('2026-11'));
      expect(asyncReport, isA<AsyncLoading>());

      final report = await container.read(monthlyReportProvider('2026-11').future);
      expect(report.totalIncome, equals(15000000));
      expect(report.totalExpense, equals(4000000));
    });

    test('12. Test report grouping & ranking: Kategori dan dompet terurut berdasarkan nominal terbesar', () async {
      final report = await hybridReportRepo.getMonthlyReport('2026-11');

      // Kategori pengeluaran: Makanan (3jt) harus di atas Transportasi (1jt)
      expect(report.expenseBreakdown.length, equals(2));
      expect(report.expenseBreakdown.first.category.name, equals('Makanan & Minuman'));
      expect(report.expenseBreakdown.first.amount, equals(3000000));
      expect(report.expenseBreakdown.last.category.name, equals('Transportasi'));
      expect(report.expenseBreakdown.last.amount, equals(1000000));

      // Dompet: w-1 (turnover 18.5jt) harus di atas w-2 (turnover 1.5jt)
      expect(report.walletBreakdown.length, equals(2));
      expect(report.walletBreakdown.first.wallet.name, equals('BCA Utama'));
      expect(report.walletBreakdown.last.wallet.name, equals('Dompet Tunai'));
    });
  });
}
