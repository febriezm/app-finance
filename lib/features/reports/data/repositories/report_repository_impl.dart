import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../../../../core/services/supabase_service.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/domain/entities/transaction_with_details.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../../../wallets/domain/repositories/wallet_repository.dart';
import '../../domain/entities/monthly_report.dart';
import '../../domain/entities/wallet_report_item.dart';
import '../../domain/repositories/report_repository.dart';
import '../datasources/report_remote_data_source.dart';
import '../services/csv_export_service.dart';
import '../services/pdf_export_service.dart';

/// Implementasi ReportRepository dengan arsitektur Offline-First Hybrid:
/// - Reaktivitas instan dan kalkulasi offline ditopang oleh SQLite lokal
/// - Sinkronisasi data cloud real-time via Supabase PostgreSQL Remote Data Source
/// - Isolasi mutlak per pengguna aktif (Row Level Security / RLS)
class ReportRepositoryImpl implements ReportRepository {
  final TransactionRepository _transactionRepository;
  final WalletRepository _walletRepository;
  final ReportRemoteDataSource? _remoteDataSource;
  final SupabaseService? _supabaseService;
  final CsvExportService _csvExportService;
  final PdfExportService _pdfExportService;

  final Map<String, MonthlyReport> _reportCache = {};

  ReportRepositoryImpl({
    required TransactionRepository transactionRepository,
    required WalletRepository walletRepository,
    ReportRemoteDataSource? remoteDataSource,
    SupabaseService? supabaseService,
    CsvExportService csvExportService = const CsvExportService(),
    PdfExportService pdfExportService = const PdfExportService(),
  })  : _transactionRepository = transactionRepository,
        _walletRepository = walletRepository,
        _remoteDataSource = remoteDataSource,
        _supabaseService = supabaseService,
        _csvExportService = csvExportService,
        _pdfExportService = pdfExportService;

  bool get isCloudActive {
    final svc = _supabaseService;
    return svc != null && svc.isAuthenticated && _remoteDataSource != null;
  }

  String? get currentUserId => _supabaseService?.currentUser?.id;

  @override
  Future<MonthlyReport> getMonthlyReport(String monthKey) async {
    // 1. Ambil dari cloud jika terautentikasi dan remote data source tersedia
    if (isCloudActive) {
      try {
        final cloudReport = await _remoteDataSource!.getMonthlyReport(
          monthKey,
          currentUserId!,
        );
        _reportCache[monthKey] = cloudReport;
        return cloudReport;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[ReportRepositoryImpl] Cloud report fetch warning, fallback ke lokal: $e');
        }
      }
    }

    // 2. Kalkulasi lokal (Offline-First) menggunakan repositori transaksi & dompet
    final localReport = await _calculateLocalMonthlyReport(monthKey);
    _reportCache[monthKey] = localReport;
    return localReport;
  }

  Future<MonthlyReport> _calculateLocalMonthlyReport(String monthKey) async {
    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59, 999);

    // Ambil transaksi periode bulan terpilih
    final currentTransactions = await _transactionRepository.getTransactionsInDateRange(
      startOfMonth,
      endOfMonth,
    );

    // Ambil daftar dompet aktif
    final wallets = await _walletRepository.getActiveWallets();

    int totalIncome = 0;
    int totalExpense = 0;
    int confirmedTxCount = 0;

    final expenseCatAmounts = <String, int>{};
    final expenseCatCounts = <String, int>{};
    final expenseCatMap = <String, Category>{};

    final incomeCatAmounts = <String, int>{};
    final incomeCatCounts = <String, int>{};
    final incomeCatMap = <String, Category>{};

    // Tracking per wallet
    final walletIncome = <String, int>{};
    final walletExpense = <String, int>{};
    final walletTransferIn = <String, int>{};
    final walletTransferOut = <String, int>{};
    final walletTxCounts = <String, int>{};

    for (final item in currentTransactions) {
      if (item.transaction.status != TransactionStatus.confirmed) continue;
      confirmedTxCount++;

      final t = item.transaction;

      if (t.type == TransactionType.income) {
        totalIncome += t.amount;
        if (item.category != null) {
          final catId = item.category!.id;
          incomeCatAmounts[catId] = (incomeCatAmounts[catId] ?? 0) + t.amount;
          incomeCatCounts[catId] = (incomeCatCounts[catId] ?? 0) + 1;
          incomeCatMap[catId] = item.category!;
        }
        if (t.walletId != null) {
          walletIncome[t.walletId!] = (walletIncome[t.walletId!] ?? 0) + t.amount;
          walletTxCounts[t.walletId!] = (walletTxCounts[t.walletId!] ?? 0) + 1;
        }
      } else if (t.type == TransactionType.expense) {
        totalExpense += t.amount;
        if (item.category != null) {
          final catId = item.category!.id;
          expenseCatAmounts[catId] = (expenseCatAmounts[catId] ?? 0) + t.amount;
          expenseCatCounts[catId] = (expenseCatCounts[catId] ?? 0) + 1;
          expenseCatMap[catId] = item.category!;
        }
        if (t.walletId != null) {
          walletExpense[t.walletId!] = (walletExpense[t.walletId!] ?? 0) + t.amount;
          walletTxCounts[t.walletId!] = (walletTxCounts[t.walletId!] ?? 0) + 1;
        }
      } else if (t.type == TransactionType.transfer) {
        if (t.walletId != null) {
          walletTransferOut[t.walletId!] = (walletTransferOut[t.walletId!] ?? 0) + t.amount;
          walletTxCounts[t.walletId!] = (walletTxCounts[t.walletId!] ?? 0) + 1;
        }
        if (t.destinationWalletId != null) {
          walletTransferIn[t.destinationWalletId!] =
              (walletTransferIn[t.destinationWalletId!] ?? 0) + t.amount;
          walletTxCounts[t.destinationWalletId!] =
              (walletTxCounts[t.destinationWalletId!] ?? 0) + 1;
        }
      }
    }

    final netCashflow = totalIncome - totalExpense;
    final savingsRate = (totalIncome > 0 && netCashflow > 0)
        ? (netCashflow / totalIncome)
        : 0.0;

    // Expense breakdown terurut dari nominal terbesar
    final expenseBreakdown = expenseCatAmounts.entries.map((e) {
      final cat = expenseCatMap[e.key]!;
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
      final cat = incomeCatMap[e.key]!;
      final pct = totalIncome > 0 ? (e.value / totalIncome) : 0.0;
      return CategoryReportItem(
        category: cat,
        amount: e.value,
        percentage: pct,
        transactionCount: incomeCatCounts[e.key] ?? 0,
      );
    }).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    // Wallet breakdown terurut dari total mutasi dana terbesar
    final walletBreakdown = wallets.map((w) {
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

    // Ambil data bulan sebelumnya untuk komparasi
    final prevDate = DateTime(year, month - 1, 1);
    final prevStart = DateTime(prevDate.year, prevDate.month, 1);
    final prevEnd = DateTime(prevDate.year, prevDate.month + 1, 0, 23, 59, 59, 999);

    final prevTransactions = await _transactionRepository.getTransactionsInDateRange(
      prevStart,
      prevEnd,
    );

    int prevIncome = 0;
    int prevExpense = 0;
    for (final item in prevTransactions) {
      if (item.transaction.status != TransactionStatus.confirmed) continue;
      if (item.transaction.type == TransactionType.income) {
        prevIncome += item.transaction.amount;
      } else if (item.transaction.type == TransactionType.expense) {
        prevExpense += item.transaction.amount;
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
  }

  @override
  Future<List<TransactionWithDetails>> getTransactionsForReport({
    required String monthKey,
    String? categoryId,
    String? walletId,
  }) async {
    if (isCloudActive) {
      try {
        final cloudTx = await _remoteDataSource!.getTransactionsForReport(
          monthKey: monthKey,
          userId: currentUserId!,
          categoryId: categoryId,
          walletId: walletId,
        );
        return cloudTx;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[ReportRepositoryImpl] Cloud details fetch warning, fallback ke lokal: $e');
        }
      }
    }

    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59, 999);

    final all = await _transactionRepository.getTransactionsInDateRange(
      startOfMonth,
      endOfMonth,
    );

    return all.where((item) {
      if (item.transaction.status != TransactionStatus.confirmed) return false;
      if (categoryId != null && item.category?.id != categoryId) return false;
      if (walletId != null) {
        final matchWallet = item.wallet?.id == walletId ||
            item.destinationWallet?.id == walletId;
        if (!matchWallet) return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<List<String>> getAvailableReportMonths() async {
    if (isCloudActive) {
      try {
        final cloudMonths = await _remoteDataSource!.getAvailableReportMonths(currentUserId!);
        if (cloudMonths.isNotEmpty) return cloudMonths;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[ReportRepositoryImpl] Cloud months fetch warning: $e');
        }
      }
    }

    // Default ke bulan-bulan dari cache atau bulan saat ini
    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final months = _reportCache.keys.toSet();
    months.add(currentMonth);
    return months.toList()..sort((a, b) => b.compareTo(a));
  }

  @override
  Future<MonthlyReport> refreshReport(String monthKey) async {
    _reportCache.remove(monthKey);
    return getMonthlyReport(monthKey);
  }

  @override
  Future<void> clearReportCache({String? monthKey}) async {
    if (monthKey != null) {
      _reportCache.remove(monthKey);
      if (isCloudActive) {
        try {
          await _remoteDataSource!.deleteReportSnapshot(monthKey, currentUserId!);
        } catch (_) {}
      }
    } else {
      _reportCache.clear();
    }
  }

  @override
  Future<MonthlyReport> createOrGenerateReport(String monthKey) async {
    final report = await getMonthlyReport(monthKey);
    if (isCloudActive) {
      try {
        await _remoteDataSource!.saveReportSnapshot(report, currentUserId!);
      } catch (_) {}
    }
    return report;
  }

  @override
  Future<String> exportReportToCsv(
    MonthlyReport report,
    List<TransactionWithDetails> transactions,
  ) async {
    return _csvExportService.generateReportCsv(report, transactions);
  }

  @override
  Future<Uint8List> exportReportToPdf(
    MonthlyReport report,
    List<TransactionWithDetails> transactions,
  ) async {
    return _pdfExportService.generateReportPdf(report, transactions);
  }
}
