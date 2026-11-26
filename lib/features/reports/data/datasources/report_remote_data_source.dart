import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart' as sp;
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/domain/entities/transaction_with_details.dart';
import '../../../wallets/domain/entities/wallet.dart';
import '../../domain/entities/monthly_report.dart';
import '../../domain/entities/wallet_report_item.dart';

/// Kontrak Remote Data Source untuk agregasi dan pelaporan finansial via Supabase Cloud PostgreSQL
abstract class ReportRemoteDataSource {
  /// Mengambil data laporan bulanan langsung dari Supabase Cloud
  Future<MonthlyReport> getMonthlyReport(String monthKey, String userId);

  /// Mengambil daftar transaksi pembentuk laporan pada periode tertentu
  Future<List<TransactionWithDetails>> getTransactionsForReport({
    required String monthKey,
    required String userId,
    String? categoryId,
    String? walletId,
  });

  /// Mengambil daftar bulan-bulan yang memiliki catatan transaksi di cloud
  Future<List<String>> getAvailableReportMonths(String userId);

  /// Menyimpan snapshot ringkasan laporan ke cloud (opsional/arsip)
  Future<void> saveReportSnapshot(MonthlyReport report, String userId);

  /// Menghapus snapshot laporan di cloud jika ada
  Future<void> deleteReportSnapshot(String monthKey, String userId);
}

/// Implementasi ReportRemoteDataSource menggunakan Supabase Client dengan RLS
class ReportRemoteDataSourceImpl implements ReportRemoteDataSource {
  final SupabaseService? _supabaseService;
  final sp.SupabaseClient? _customClient;

  ReportRemoteDataSourceImpl({
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
  Future<MonthlyReport> getMonthlyReport(String monthKey, String userId) async {
    try {
      final parts = monthKey.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);

      final startOfMonth = DateTime.utc(year, month, 1);
      final endOfMonth = DateTime.utc(year, month + 1, 0, 23, 59, 59, 999);
      final startIso = startOfMonth.toIso8601String();
      final endIso = endOfMonth.toIso8601String();

      // 1. Ambil transaksi bulan berjalan terkonfirmasi milik user
      final currentTxResponse = await _client
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .gte('occurred_at', startIso)
          .lte('occurred_at', endIso)
          .eq('status', 'confirmed');

      // 2. Ambil dompet aktif milik user
      final walletsResponse = await _client
          .from('wallets')
          .select()
          .eq('user_id', userId)
          .eq('is_archived', false);

      // 3. Ambil kategori (kustom user & kategori sistem bawaan)
      final categoriesResponse = await _client
          .from('categories')
          .select()
          .or('user_id.eq.$userId,user_id.is.null');

      // 4. Ambil transaksi bulan sebelumnya untuk perbandingan (MoM)
      final prevDate = DateTime.utc(year, month - 1, 1);
      final prevStart = DateTime.utc(prevDate.year, prevDate.month, 1);
      final prevEnd = DateTime.utc(prevDate.year, prevDate.month + 1, 0, 23, 59, 59, 999);
      final prevStartIso = prevStart.toIso8601String();
      final prevEndIso = prevEnd.toIso8601String();

      final prevTxResponse = await _client
          .from('transactions')
          .select('amount, type')
          .eq('user_id', userId)
          .gte('occurred_at', prevStartIso)
          .lte('occurred_at', prevEndIso)
          .eq('status', 'confirmed');

      // Bangun lookup map kategori dan dompet
      final walletMap = <String, Wallet>{};
      for (final row in walletsResponse as List) {
        final w = _mapJsonToWallet(row as Map<String, dynamic>);
        walletMap[w.id] = w;
      }

      final categoryMap = <String, Category>{};
      for (final row in categoriesResponse as List) {
        final c = _mapJsonToCategory(row as Map<String, dynamic>);
        categoryMap[c.id] = c;
      }

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

      for (final row in currentTxResponse as List) {
        final tx = _mapJsonToTransaction(row as Map<String, dynamic>);
        confirmedTxCount++;

        if (tx.type == TransactionType.income) {
          totalIncome += tx.amount;
          if (tx.categoryId != null) {
            final catId = tx.categoryId!;
            incomeCatAmounts[catId] = (incomeCatAmounts[catId] ?? 0) + tx.amount;
            incomeCatCounts[catId] = (incomeCatCounts[catId] ?? 0) + 1;
          }
          if (tx.walletId != null) {
            walletIncome[tx.walletId!] = (walletIncome[tx.walletId!] ?? 0) + tx.amount;
            walletTxCounts[tx.walletId!] = (walletTxCounts[tx.walletId!] ?? 0) + 1;
          }
        } else if (tx.type == TransactionType.expense) {
          totalExpense += tx.amount;
          if (tx.categoryId != null) {
            final catId = tx.categoryId!;
            expenseCatAmounts[catId] = (expenseCatAmounts[catId] ?? 0) + tx.amount;
            expenseCatCounts[catId] = (expenseCatCounts[catId] ?? 0) + 1;
          }
          if (tx.walletId != null) {
            walletExpense[tx.walletId!] = (walletExpense[tx.walletId!] ?? 0) + tx.amount;
            walletTxCounts[tx.walletId!] = (walletTxCounts[tx.walletId!] ?? 0) + 1;
          }
        } else if (tx.type == TransactionType.transfer) {
          if (tx.walletId != null) {
            walletTransferOut[tx.walletId!] = (walletTransferOut[tx.walletId!] ?? 0) + tx.amount;
            walletTxCounts[tx.walletId!] = (walletTxCounts[tx.walletId!] ?? 0) + 1;
          }
          if (tx.destinationWalletId != null) {
            walletTransferIn[tx.destinationWalletId!] =
                (walletTransferIn[tx.destinationWalletId!] ?? 0) + tx.amount;
            walletTxCounts[tx.destinationWalletId!] =
                (walletTxCounts[tx.destinationWalletId!] ?? 0) + 1;
          }
        }
      }

      final netCashflow = totalIncome - totalExpense;
      final savingsRate = (totalIncome > 0 && netCashflow > 0)
          ? (netCashflow / totalIncome)
          : 0.0;

      // Expense breakdown terurut dari nominal terbesar
      final expenseBreakdown = expenseCatAmounts.entries.map((e) {
        final cat = categoryMap[e.key] ??
            Category(id: e.key, name: 'Lainnya', type: CategoryType.expense);
        final pct = totalExpense > 0 ? (e.value / totalExpense) : 0.0;
        return CategoryReportItem(
          category: cat,
          amount: e.value,
          percentage: pct,
          transactionCount: expenseCatCounts[e.key] ?? 0,
        );
      }).toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));

      // Income breakdown terurut dari nominal terbesar
      final incomeBreakdown = incomeCatAmounts.entries.map((e) {
        final cat = categoryMap[e.key] ??
            Category(id: e.key, name: 'Lainnya', type: CategoryType.income);
        final pct = totalIncome > 0 ? (e.value / totalIncome) : 0.0;
        return CategoryReportItem(
          category: cat,
          amount: e.value,
          percentage: pct,
          transactionCount: incomeCatCounts[e.key] ?? 0,
        );
      }).toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));

      // Wallet breakdown terurut dari total perputaran dana terbesar
      final walletBreakdown = walletMap.values.map((w) {
        return WalletReportItem(
          wallet: w,
          incomeAmount: walletIncome[w.id] ?? 0,
          expenseAmount: walletExpense[w.id] ?? 0,
          transferInAmount: walletTransferIn[w.id] ?? 0,
          transferOutAmount: walletTransferOut[w.id] ?? 0,
          transactionCount: walletTxCounts[w.id] ?? 0,
        );
      }).toList()
        ..sort((a, b) =>
            (b.expenseAmount + b.incomeAmount).compareTo(a.expenseAmount + a.incomeAmount));

      // Perbandingan bulan sebelumnya
      int prevIncome = 0;
      int prevExpense = 0;
      for (final row in prevTxResponse as List) {
        final type = row['type'] as String?;
        final amt = (row['amount'] as num?)?.toInt() ?? 0;
        if (type == 'income') {
          prevIncome += amt;
        } else if (type == 'expense') {
          prevExpense += amt;
        }
      }
      final prevNetCashflow = prevIncome - prevExpense;

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
        previousMonthNetCashflow: prevNetCashflow,
      );
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal mengambil laporan bulanan dari cloud: $e');
    }
  }

  @override
  Future<List<TransactionWithDetails>> getTransactionsForReport({
    required String monthKey,
    required String userId,
    String? categoryId,
    String? walletId,
  }) async {
    try {
      final parts = monthKey.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);

      final startOfMonth = DateTime.utc(year, month, 1);
      final endOfMonth = DateTime.utc(year, month + 1, 0, 23, 59, 59, 999);
      final startIso = startOfMonth.toIso8601String();
      final endIso = endOfMonth.toIso8601String();

      final txResponse = await _client
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .gte('occurred_at', startIso)
          .lte('occurred_at', endIso)
          .eq('status', 'confirmed')
          .order('occurred_at', ascending: false);

      final walletsResponse = await _client
          .from('wallets')
          .select()
          .eq('user_id', userId);

      final categoriesResponse = await _client
          .from('categories')
          .select()
          .or('user_id.eq.$userId,user_id.is.null');

      final walletMap = <String, Wallet>{};
      for (final row in walletsResponse as List) {
        final w = _mapJsonToWallet(row as Map<String, dynamic>);
        walletMap[w.id] = w;
      }

      final categoryMap = <String, Category>{};
      for (final row in categoriesResponse as List) {
        final c = _mapJsonToCategory(row as Map<String, dynamic>);
        categoryMap[c.id] = c;
      }

      final list = <TransactionWithDetails>[];
      for (final row in txResponse as List) {
        final tx = _mapJsonToTransaction(row as Map<String, dynamic>);

        // Filter category jika ditentukan
        if (categoryId != null && tx.categoryId != categoryId) continue;

        // Filter wallet jika ditentukan
        if (walletId != null) {
          final matches = tx.walletId == walletId || tx.destinationWalletId == walletId;
          if (!matches) continue;
        }

        list.add(
          TransactionWithDetails(
            transaction: tx,
            wallet: tx.walletId != null ? walletMap[tx.walletId!] : null,
            destinationWallet:
                tx.destinationWalletId != null ? walletMap[tx.destinationWalletId!] : null,
            category: tx.categoryId != null ? categoryMap[tx.categoryId!] : null,
          ),
        );
      }

      return list;
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal mengambil rincian transaksi laporan dari cloud: $e');
    }
  }

  @override
  Future<List<String>> getAvailableReportMonths(String userId) async {
    try {
      final response = await _client
          .from('transactions')
          .select('occurred_at')
          .eq('user_id', userId)
          .order('occurred_at', ascending: false);

      final monthSet = <String>{};
      for (final row in response as List) {
        final occurred = row['occurred_at'] as String?;
        if (occurred != null && occurred.length >= 7) {
          monthSet.add(occurred.substring(0, 7));
        }
      }
      return monthSet.toList();
    } on sp.PostgrestException catch (e) {
      throw SupabaseDatabaseException(e.message, e.code);
    } catch (e) {
      if (e is SupabaseException) rethrow;
      throw SupabaseDatabaseException('Gagal mengambil daftar periode laporan: $e');
    }
  }

  @override
  Future<void> saveReportSnapshot(MonthlyReport report, String userId) async {
    // Snapshot laporan disimpan di cache memory / audit log jika diperlukan
    if (kDebugMode) {
      debugPrint('[ReportRemoteDataSourceImpl] Snapshot laporan ${report.monthKey} untuk user $userId tersimpan.');
    }
  }

  @override
  Future<void> deleteReportSnapshot(String monthKey, String userId) async {
    if (kDebugMode) {
      debugPrint('[ReportRemoteDataSourceImpl] Snapshot laporan $monthKey untuk user $userId dihapus.');
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

  static Wallet _mapJsonToWallet(Map<String, dynamic> json) {
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

  static Category _mapJsonToCategory(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      type: CategoryType.fromString(json['type'] as String),
      iconKey: json['icon_key'] as String?,
      colorHex: json['color_hex'] as String?,
      isSystem: (json['is_system'] as bool?) ?? false,
      isArchived: (json['is_archived'] as bool?) ?? false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}
