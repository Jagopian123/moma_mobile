import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/hive/models/budget_model.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_circular_progress.dart';
import '../../../shared/widgets/app_progress_bar.dart';
import '../providers/budget_provider.dart';
import '../widgets/budget_form_sheet.dart';

class BudgetPage extends ConsumerWidget {
  const BudgetPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(budgetProvider);
    final notifier = ref.read(budgetProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Budget', style: AppTextStyles.h3),
        centerTitle: false,
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Tambah Budget',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: budgets.isEmpty
          ? AppEmptyState(
              emoji: '💰',
              title: 'Belum ada budget',
              description: 'Tambahkan budget untuk mengontrol pengeluaranmu',
              actionLabel: 'Tambah Budget',
              onAction: () => _showForm(context),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                100,
              ),
              children: [
                // ── Dashboard Keseluruhan ────────────────────────
                _OverallDashboard(notifier: notifier),
                const SizedBox(height: AppSpacing.lg),

                // ── Kategori Budget ──────────────────────────────
                const Text('Kategori Budget', style: AppTextStyles.h4),
                const SizedBox(height: AppSpacing.sm),

                ...budgets.map((budget) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _BudgetCategoryCard(
                        budget: budget,
                        notifier: notifier,
                        onEdit: () => _showForm(context, budget),
                        onDelete: () => _confirmDelete(context, ref, budget),
                      ),
                    )),
              ],
            ),
    );
  }

  void _showForm(BuildContext context, [BudgetModel? budget]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BudgetFormSheet(budget: budget),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, BudgetModel budget) async {
    final confirm = await showConfirmSheet(
      context: context,
      title: 'Hapus Budget',
      description: 'Hapus budget "${budget.categoryName}"?',
      confirmLabel: 'Ya, Hapus',
    );
    if (confirm == true) {
      ref.read(budgetProvider.notifier).delete(budget.id);
    }
  }
}

// ── Overall Dashboard ─────────────────────────────────────────────────────────

class _OverallDashboard extends StatelessWidget {
  final BudgetNotifier notifier;

  const _OverallDashboard({required this.notifier});

  Color get _healthColor {
    switch (notifier.overallHealth) {
      case BudgetHealth.aman:
        return AppColors.safe;
      case BudgetHealth.waspada:
        return AppColors.warning;
      case BudgetHealth.boros:
        return AppColors.danger;
    }
  }

  String get _healthLabel {
    switch (notifier.overallHealth) {
      case BudgetHealth.aman:
        return 'Aman';
      case BudgetHealth.waspada:
        return 'Waspada';
      case BudgetHealth.boros:
        return 'Boros';
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct = notifier.overallPercentage.clamp(0.0, 1.0);
    final time = notifier.timePercentage.clamp(0.0, 1.0);

    if (notifier.state.isEmpty) return const SizedBox.shrink();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Penggunaan Budget',
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(pct * 100).toStringAsFixed(0)}%',
                      style: AppTextStyles.h2,
                    ),
                    Text(
                      '${CurrencyFormatter.formatCompact(notifier.totalSpent)} '
                      'dari ${CurrencyFormatter.formatCompact(notifier.totalLimit)}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _healthColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  _healthLabel,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _healthColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Progress bar overall
          AppProgressBar(value: pct),
          const SizedBox(height: AppSpacing.sm),

          // Timeline progress bar
          AppTimelineProgressBar(
            budgetPercentage: pct,
            timePercentage: time,
          ),
        ],
      ),
    );
  }
}

// ── Budget Category Card ──────────────────────────────────────────────────────

class _BudgetCategoryCard extends StatelessWidget {
  final BudgetModel budget;
  final BudgetNotifier notifier;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BudgetCategoryCard({
    required this.budget,
    required this.notifier,
    required this.onEdit,
    required this.onDelete,
  });

  Color get _statusColor {
    switch (notifier.getStatus(budget)) {
      case BudgetStatus.spendingFast:
        return AppColors.danger;
      case BudgetStatus.slightlyFast:
        return AppColors.warning;
      case BudgetStatus.safe:
        return AppColors.safe;
    }
  }

  String get _statusLabel {
    switch (notifier.getStatus(budget)) {
      case BudgetStatus.spendingFast:
        return 'Spending Fast';
      case BudgetStatus.slightlyFast:
        return 'Slightly Fast';
      case BudgetStatus.safe:
        return 'Safe';
    }
  }

  @override
  Widget build(BuildContext context) {
    final spent = notifier.getSpent(budget);
    final remaining = (budget.limitAmount - spent).clamp(0.0, double.infinity);
    final percentage = notifier.getPercentage(budget);
    final timePerc = notifier.timePercentage;

    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              // Circular progress
              AppCircularProgress(
                value: percentage.clamp(0.0, 1.0),
                size: 64,
                strokeWidth: 6,
                // color tidak diisi → otomatis hijau→orange→merah sesuai persentase
                center: Text(
                  budget.categoryIcon,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(budget.categoryName, style: AppTextStyles.bodyMedium),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            _statusLabel,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _statusColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          budget.period == 'monthly' ? 'Bulanan' : 'Mingguan',
                          style: AppTextStyles.small,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: AppColors.textHint,
                  size: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded, size: 16),
                        SizedBox(width: 8),
                        Text('Edit', style: TextStyle(fontFamily: 'Poppins')),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_rounded,
                            size: 16, color: AppColors.danger),
                        SizedBox(width: 8),
                        Text('Hapus',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: AppColors.danger,
                            )),
                      ],
                    ),
                  ),
                ],
                onSelected: (val) {
                  if (val == 'edit') onEdit();
                  if (val == 'delete') onDelete();
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Data row: spent / limit / remaining
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _DataItem(
                label: 'Spent',
                value: CurrencyFormatter.formatCompact(spent),
                color: AppColors.expense,
              ),
              _DataItem(
                label: 'Limit',
                value: CurrencyFormatter.formatCompact(budget.limitAmount),
                color: AppColors.textSecondary,
              ),
              _DataItem(
                label: 'Remaining',
                value: CurrencyFormatter.formatCompact(remaining),
                color: AppColors.safe,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Progress bulanan
          AppTimelineProgressBar(
            budgetPercentage: percentage.clamp(0.0, 1.0),
            timePercentage: timePerc,
          ),
        ],
      ),
    );
  }
}

class _DataItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DataItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10,
            color: AppColors.textHint,
          ),
        ),
      ],
    );
  }
}
