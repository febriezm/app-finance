import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../app/app_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Modal Bottom Sheet interaktif untuk prompt persetujuan migrasi data dari SQLite lokal ke Supabase Cloud
class MigrationPromptSheet extends ConsumerWidget {
  final String userId;

  const MigrationPromptSheet({
    super.key,
    required this.userId,
  });

  static Future<bool?> show(BuildContext context, {required String userId}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MigrationPromptSheet(userId: userId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final migrationState = ref.watch(migrationControllerProvider);
    final controller = ref.read(migrationControllerProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.surfaceModalDark : AppColors.surfaceModalLight;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final summary = migrationState.summary;

    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Header Icon & Title
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.cloud_upload_rounded,
                    color: AppColors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pindahkan Data ke Akun Cloud',
                        style: AppTypography.title2.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ditemukan data offline pada perangkat Anda',
                        style: AppTypography.caption.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Deskripsi Penjelasan
            Text(
              'Anda memiliki data keuangan yang tercatat di perangkat ini. Apakah Anda ingin menyinkronkan dan memindahkannya ke akun cloud Anda agar data aman dan dapat diakses dari mana saja?',
              style: AppTypography.body.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Ringkasan Data (Cards)
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceElevatedDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 0.8),
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  _buildSummaryRow(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Dompet & Rekening',
                    value: '${summary.walletsCount} akun',
                    isDark: isDark,
                  ),
                  const Divider(height: 16),
                  _buildSummaryRow(
                    icon: Icons.receipt_long_outlined,
                    label: 'Riwayat Transaksi',
                    value: '${summary.transactionsCount} catatan',
                    isDark: isDark,
                  ),
                  const Divider(height: 16),
                  _buildSummaryRow(
                    icon: Icons.pie_chart_outline_rounded,
                    label: 'Rencana Anggaran',
                    value: '${summary.budgetsCount} bulan',
                    isDark: isDark,
                  ),
                  if (summary.customCategoriesCount > 0) ...[
                    const Divider(height: 16),
                    _buildSummaryRow(
                      icon: Icons.category_outlined,
                      label: 'Kategori Kustom',
                      value: '${summary.customCategoriesCount} kategori',
                      isDark: isDark,
                    ),
                  ],
                  const Divider(height: 16),
                  _buildSummaryRow(
                    icon: Icons.payments_outlined,
                    label: 'Total Saldo Tercatat',
                    value: currencyFormatter.format(summary.totalLedgerBalance),
                    isDark: isDark,
                    valueColor: isDark ? AppColors.incomeDark : AppColors.incomeLight,
                    isBold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Progress Bar saat sedang migrasi
            if (migrationState.isMigrating) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: migrationState.progress,
                      backgroundColor: isDark ? Colors.white12 : Colors.black12,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    migrationState.currentStep,
                    style: AppTypography.caption.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ],

            // Pesan Error jika gagal
            if (migrationState.isFailed && migrationState.errorMessage != null) ...[
              Container(
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                padding: const EdgeInsets.all(AppSpacing.sm),
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: isDark ? AppColors.expenseDark : AppColors.expenseLight, size: 20),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        migrationState.errorMessage!,
                        style: AppTypography.caption.copyWith(color: isDark ? AppColors.expenseDark : AppColors.expenseLight),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Tombol Tindakan
            if (migrationState.isSuccess) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                label: const Text('Selesai (Data Sudah Termigrasi)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.incomeDark : AppColors.incomeLight,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
              ),
            ] else ...[
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: migrationState.isMigrating
                    ? null
                    : () async {
                        final success = await controller.startMigration(userId);
                        if (success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Seluruh data lokal berhasil dipindahkan ke cloud.'),
                              backgroundColor: isDark ? AppColors.incomeDark : AppColors.incomeLight,
                            ),
                          );
                        }
                      },
                child: migrationState.isMigrating
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                          SizedBox(width: 10),
                          Text('Memindahkan Data...'),
                        ],
                      )
                    : Text(
                        migrationState.isFailed ? 'Coba Lagi Migrasi Data' : 'Mulai Migrasi Data',
                        style: AppTypography.bodyBold.copyWith(color: Colors.white),
                      ),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: migrationState.isMigrating
                    ? null
                    : () async {
                        await controller.skipMigration(userId);
                        if (context.mounted) {
                          Navigator.of(context).pop(false);
                        }
                      },
                child: Text(
                  'Nanti Saja (Pertahankan di Perangkat)',
                  style: AppTypography.bodyBold.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            label,
            style: AppTypography.body.copyWith(
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
        ),
        Text(
          value,
          style: AppTypography.body.copyWith(
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: valueColor ?? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
          ),
        ),
      ],
    );
  }
}

