import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/app_providers.dart';
import '../../../../core/formatting/currency_formatter.dart';
import '../../../../core/formatting/date_formatter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../categories/domain/entities/category.dart';
import '../../domain/entities/budget.dart';

class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  void _changeMonth(int delta) {
    final currentKey = ref.read(selectedBudgetMonthProvider);
    final parts = currentKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final newDate = DateTime(year, month + delta);
    ref.read(selectedBudgetMonthProvider.notifier).state = AppDateFormatter.toMonthKey(newDate);
  }

  void _openSetBudgetModal(BuildContext context, BudgetProgress progress) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SetBudgetModal(
        monthKey: progress.monthKey,
        currentProgress: progress,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentMonthKey = ref.watch(selectedBudgetMonthProvider);
    final budgetProgressAsync = ref.watch(budgetProgressStreamProvider(currentMonthKey));

    // Parse month name for display
    final parts = currentMonthKey.split('-');
    final currentMonthDate = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    final monthDisplay = AppDateFormatter.formatMonthYear(currentMonthDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anggaran Bulanan'),
        actions: [
          budgetProgressAsync.maybeWhen(
            data: (progress) => IconButton(
              icon: const Icon(Icons.tune_rounded),
              tooltip: 'Atur Anggaran',
              onPressed: () => _openSetBudgetModal(context, progress),
            ),
            orElse: () => const SizedBox(),
          ),
        ],
      ),
      body: budgetProgressAsync.when(
        data: (progress) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // 1. Month Navigation Header
              _buildMonthNavigator(context, monthDisplay, isDark),

              const SizedBox(height: 16),

              // 2. Configuration Warning Banner if category limits > total budget
              if (progress.hasConfigurationWarning) ...[
                _buildConfigurationWarning(isDark),
                const SizedBox(height: 16),
              ],

              // 3. Main Budget Overview Card
              if (progress.hasBudget)
                _buildMainBudgetCard(context, progress, isDark)
              else
                _buildEmptyBudgetCard(context, progress, isDark),

              const SizedBox(height: 24),

              // 4. Category Limits Section
              _buildCategoryLimitsSection(context, progress, isDark),

              const SizedBox(height: 32),
            ],
          );
        },
        loading: () => const Center(child: LoadingIndicator(message: 'Memuat data anggaran...')),
        error: (e, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Belum dapat memuat data anggaran. Silakan muat ulang.', style: AppTypography.subhead),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthNavigator(BuildContext context, String monthDisplay, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Bulan Sebelumnya',
            onPressed: () => _changeMonth(-1),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_month_outlined, size: 20, color: AppColors.primaryNavyLight),
              const SizedBox(width: 8),
              Text(
                monthDisplay,
                style: AppTypography.headline.copyWith(fontSize: 16),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Bulan Berikutnya',
            onPressed: () => _changeMonth(1),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationWarning(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.warningContainerDark : AppColors.warningContainerLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (isDark ? AppColors.warningDark : AppColors.warningLight).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: isDark ? AppColors.warningDark : AppColors.warningLight,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Perhatian Konfigurasi Anggaran',
                  style: AppTypography.caption1.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.warningDark : AppColors.warningLight,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Jumlah alokasi limit kategori melebihi total anggaran bulanan. Pengeluaran aktual tetap dihitung akurat.',
                  style: AppTypography.caption2.copyWith(
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainBudgetCard(BuildContext context, BudgetProgress progress, bool isDark) {
    final statusColor = _getStatusColor(progress.status, isDark);
    final clampedPercentage = progress.percentage.clamp(0.0, 1.0);
    final percentLabel = (progress.percentage * 100).toStringAsFixed(0);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  progress.remaining >= 0 ? 'Sisa Anggaran' : 'Defisit Anggaran',
                  style: AppTypography.subhead.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  progress.status.displayName,
                  style: AppTypography.caption2.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.formatRupiah(progress.remaining),
            style: AppTypography.balanceLarge.copyWith(
              color: progress.remaining >= 0
                  ? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)
                  : (isDark ? AppColors.expenseDark : AppColors.expenseLight),
            ),
          ),
          const SizedBox(height: 14),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: clampedPercentage,
              minHeight: 10,
              backgroundColor: isDark ? AppColors.borderDark : AppColors.borderLight,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),

          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Terpakai ($percentLabel%)',
                      style: AppTypography.caption2.copyWith(
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.formatRupiah(progress.totalSpent),
                      style: AppTypography.headline.copyWith(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Total Batas Anggaran',
                      style: AppTypography.caption2.copyWith(
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.formatRupiah(progress.totalLimit),
                      style: AppTypography.headline.copyWith(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBudgetCard(BuildContext context, BudgetProgress progress, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 0.8,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (isDark ? AppColors.transferContainerDark : AppColors.transferContainerLight),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.pie_chart_outline_rounded,
              size: 40,
              color: AppColors.transferLight,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum Ada Anggaran',
            style: AppTypography.title3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Tetapkan batas pengeluaran bulanan dan kategori untuk menjaga stabilitas keuangan Anda.',
            style: AppTypography.footnote.copyWith(
              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'Atur Anggaran Bulan Ini',
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            onPressed: () => _openSetBudgetModal(context, progress),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryLimitsSection(BuildContext context, BudgetProgress progress, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Alokasi Kategori',
                style: AppTypography.headline.copyWith(fontSize: 18),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              onPressed: () => _openSetBudgetModal(context, progress),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Sesuaikan'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (progress.categoryProgresses.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.grey, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Belum ada limit spesifik kategori. Seluruh pengeluaran dihitung pada total anggaran bulanan.',
                    style: AppTypography.footnote.copyWith(
                      color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: progress.categoryProgresses.map((catProgress) {
              final catColor = AppIcons.parseColor(catProgress.category.colorHex);
              final statusColor = _getStatusColor(catProgress.status, isDark);
              final catPercent = (catProgress.percentage * 100).toStringAsFixed(0);
              final clampedPct = catProgress.percentage.clamp(0.0, 1.0);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceCardDark : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    width: 0.8,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: catColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            AppIcons.getIcon(catProgress.category.iconKey),
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                catProgress.category.name,
                                style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                catProgress.remainingAmount >= 0
                                    ? 'Sisa ${CurrencyFormatter.formatRupiah(catProgress.remainingAmount)}'
                                    : 'Melebihi ${CurrencyFormatter.formatRupiah(catProgress.remainingAmount.abs())}',
                                style: AppTypography.caption1.copyWith(
                                  color: catProgress.remainingAmount >= 0
                                      ? (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight)
                                      : (isDark ? AppColors.expenseDark : AppColors.expenseLight),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$catPercent%',
                              style: AppTypography.headline.copyWith(
                                fontSize: 14,
                                color: statusColor,
                              ),
                            ),
                            Text(
                              '${CurrencyFormatter.formatCompact(catProgress.spentAmount)} / ${CurrencyFormatter.formatCompact(catProgress.limitAmount)}',
                              style: AppTypography.caption2.copyWith(
                                color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: clampedPct,
                        minHeight: 6,
                        backgroundColor: isDark ? AppColors.borderDark : AppColors.borderLight,
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Color _getStatusColor(BudgetStatus status, bool isDark) {
    switch (status) {
      case BudgetStatus.normal:
        return isDark ? AppColors.incomeDark : AppColors.incomeLight;
      case BudgetStatus.warning:
        return isDark ? AppColors.warningDark : AppColors.warningLight;
      case BudgetStatus.critical:
        return const Color(0xFFE17055);
      case BudgetStatus.exceeded:
        return isDark ? AppColors.expenseDark : AppColors.expenseLight;
    }
  }
}

/// Modal Sheet untuk mengatur Total Budget & Limit Kategori
class _SetBudgetModal extends ConsumerStatefulWidget {
  final String monthKey;
  final BudgetProgress currentProgress;

  const _SetBudgetModal({
    required this.monthKey,
    required this.currentProgress,
  });

  @override
  ConsumerState<_SetBudgetModal> createState() => _SetBudgetModalState();
}

class _SetBudgetModalState extends ConsumerState<_SetBudgetModal> {
  final TextEditingController _totalBudgetController = TextEditingController();
  final Map<String, TextEditingController> _categoryControllers = {};
  final Map<String, int> _categoryAmounts = {};

  int _totalBudget = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _totalBudget = widget.currentProgress.totalLimit;
    if (_totalBudget > 0) {
      _totalBudgetController.text = CurrencyFormatter.formatRupiah(_totalBudget);
    }

    // Inisialisasi limit kategori yang tersimpan sebelumnya
    for (final cp in widget.currentProgress.categoryProgresses) {
      _categoryAmounts[cp.category.id] = cp.limitAmount;
    }
  }

  @override
  void dispose() {
    _totalBudgetController.dispose();
    for (final c in _categoryControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onTotalBudgetChanged(String val) {
    final clean = val.replaceAll(RegExp(r'[^0-9]'), '');
    final num = int.tryParse(clean) ?? 0;
    setState(() {
      _totalBudget = num;
    });
    final formatted = num > 0 ? CurrencyFormatter.formatRupiah(num) : '';
    if (_totalBudgetController.text != formatted) {
      _totalBudgetController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  void _onCategoryLimitChanged(String catId, String val) {
    final clean = val.replaceAll(RegExp(r'[^0-9]'), '');
    final num = int.tryParse(clean) ?? 0;
    setState(() {
      if (num > 0) {
        _categoryAmounts[catId] = num;
      } else {
        _categoryAmounts.remove(catId);
      }
    });

    final controller = _categoryControllers[catId];
    if (controller != null) {
      final formatted = num > 0 ? CurrencyFormatter.formatRupiah(num) : '';
      if (controller.text != formatted) {
        controller.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    }
  }

  int get _sumCategoryLimits {
    return _categoryAmounts.values.fold<int>(0, (sum, val) => sum + val);
  }

  Future<void> _save() async {
    if (_totalBudget <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Total batas anggaran harus lebih besar dari Rp 0.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final success = await ref.read(budgetsControllerProvider.notifier).saveBudget(
          monthKey: widget.monthKey,
          totalLimit: _totalBudget,
          categoryLimitsMap: _categoryAmounts,
        );
    setState(() => _isSaving = false);

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anggaran bulanan berhasil disimpan.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan anggaran. Silakan periksa data.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoriesAsync = ref.watch(activeCategoriesStreamProvider(CategoryType.expense));
    final sumCategories = _sumCategoryLimits;
    final isOverAllocated = sumCategories > _totalBudget && _totalBudget > 0;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isMobile = MediaQuery.of(context).size.width < 600 ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
    // Di iOS Safari pada Flutter Web, viewInsets.bottom bernilai 0 karena keyboard berupa overlay.
    // Minimal 380px memastikan seluruh kategori (Kesehatan, Pengeluaran Lainnya, dan tombol Simpan)
    // dapat digulir bebas ke atas papan keyboard dan toolbar browser.
    final effectiveBottomPadding = isMobile
        ? math.max(bottomInset + 120, 380.0)
        : math.max(bottomInset + 20, 40.0);
    final fieldScrollPadding = isMobile
        ? const EdgeInsets.only(bottom: 380)
        : const EdgeInsets.all(20);

    // Format month for title
    final parts = widget.monthKey.split('-');
    final monthDate = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    final monthTitle = AppDateFormatter.formatMonthYear(monthDate);

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                Text(
                  'Atur Anggaran ($monthTitle)',
                  style: AppTypography.headline.copyWith(fontSize: 16),
                ),
                TextButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable Form
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.opaque,
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  effectiveBottomPadding,
                ),
                children: [
                  // Total Limit Input
                  Text(
                    'TOTAL ANGGARAN BULANAN',
                    style: AppTypography.caption1.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AppTextField(
                    controller: _totalBudgetController,
                    label: 'Batas Pengeluaran Keseluruhan',
                    keyboardType: TextInputType.number,
                    hintText: 'Rp 0',
                    scrollPadding: fieldScrollPadding,
                    onChanged: _onTotalBudgetChanged,
                  ),

                const SizedBox(height: 20),

                // Live Allocation Status
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isOverAllocated
                        ? (isDark ? AppColors.warningContainerDark : AppColors.warningContainerLight)
                        : (isDark ? AppColors.surfaceCardDark : AppColors.backgroundLight),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isOverAllocated
                          ? (isDark ? AppColors.warningDark : AppColors.warningLight)
                          : (isDark ? AppColors.borderDark : AppColors.borderLight),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Alokasi Kategori:', style: AppTypography.caption1),
                          Text(
                            CurrencyFormatter.formatRupiah(sumCategories),
                            style: AppTypography.caption1.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (isOverAllocated) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: isDark ? AppColors.warningDark : AppColors.warningLight,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Alokasi kategori melebihi total anggaran. Data tetap dapat disimpan.',
                                style: AppTypography.caption2.copyWith(
                                  color: isDark ? AppColors.warningDark : AppColors.warningLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Category Limits List
                Text(
                  'BATAS PENGELUARAN PER KATEGORI (OPSIONAL)',
                  style: AppTypography.caption1.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tentukan batas maksimal untuk kategori tertentu. Kosongkan jika tidak ada batas khusus.',
                  style: AppTypography.caption2.copyWith(
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  ),
                ),
                const SizedBox(height: 14),

                categoriesAsync.when(
                  data: (categories) {
                    if (categories.isEmpty) {
                      return const Center(child: Text('Belum ada kategori pengeluaran aktif.'));
                    }

                    return Column(
                      children: categories.map((cat) {
                        final catColor = AppIcons.parseColor(cat.colorHex);

                        // Buat controller jika belum ada
                        if (!_categoryControllers.containsKey(cat.id)) {
                          final savedAmount = _categoryAmounts[cat.id] ?? 0;
                          _categoryControllers[cat.id] = TextEditingController(
                            text: savedAmount > 0 ? CurrencyFormatter.formatRupiah(savedAmount) : '',
                          );
                        }
                        final ctrl = _categoryControllers[cat.id]!;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: catColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  AppIcons.getIcon(cat.iconKey),
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  cat.name,
                                  style: AppTypography.body.copyWith(fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 4,
                                child: TextField(
                                  controller: ctrl,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.end,
                                  scrollPadding: fieldScrollPadding,
                                  style: AppTypography.body.copyWith(fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: 'Tanpa batas',
                                    hintStyle: TextStyle(
                                      color: isDark ? AppColors.textDisabledDark : AppColors.textDisabledLight,
                                      fontSize: 13,
                                    ),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                                      ),
                                    ),
                                  ),
                                  onChanged: (val) => _onCategoryLimitChanged(cat.id, val),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Gagal memuat kategori anggaran. Silakan muat ulang.',
                      style: TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Simpan Button
                AppButton(
                  label: 'Simpan Anggaran',
                  isLoading: _isSaving,
                  onPressed: _save,
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
}
