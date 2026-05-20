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
import '../../../shared/providers/plan_limits_provider.dart';
import '../../../shared/widgets/plan_limit_sheet.dart';

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
        onPressed: () {
          final limits = ref.read(planLimitsProvider);
          if (!limits.canAddBudgets(budgets.length)) {
            showPlanLimitSheet(context,
                featureName: 'Budget', freeLimit: limits.maxBudgets);
            return;
          }
          _showForm(context);
        },
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
              imagePath: 'assets/images/mascot-budget.png',
              title: 'Belum ada budget',
              description: 'Tambahkan budget untuk mengontrol pengeluaranmu',
              actionLabel: 'Tambah Budget',
              onAction: () {
                final limits = ref.read(planLimitsProvider);
                if (!limits.canAddBudgets(budgets.length)) {
                  showPlanLimitSheet(context,
                      featureName: 'Budget', freeLimit: limits.maxBudgets);
                  return;
                }
                _showForm(context);
              },
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

  Widget? _buildInsight(
      int overCount, int fastCount, int slightlyCount, int safeCount) {
    if (overCount > 0) {
      return _InsightRow(
        emoji: '😬',
        text: '$overCount kategori sudah melampaui budget bulan ini. '
            'Cek dan kurangi pengeluaran!',
        color: AppColors.danger,
      );
    }
    if (fastCount > 0) {
      return _InsightRow(
        emoji: '🧐',
        text: '$fastCount kategori nyaris habis — hati-hati di sisa bulan ini!',
        color: AppColors.danger,
      );
    }
    if (slightlyCount > 0) {
      return _InsightRow(
        emoji: '⚠️',
        text: '$slightlyCount kategori perlu lebih diperhatikan minggu ini',
        color: AppColors.warning,
      );
    }
    if (safeCount > 0) {
      return const _InsightRow(
        emoji: '🎉',
        text: 'Semua kategori berjalan on track, pertahankan!',
        color: AppColors.safe,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final pct     = notifier.overallPercentage;
    final time    = notifier.timePercentage.clamp(0.0, 1.0);
    final budgets = notifier.state;

    if (budgets.isEmpty) return const SizedBox.shrink();

    // Count by status
    int amanCount = 0, slightlyCount = 0, fastCount = 0, overCount = 0;
    for (final b in budgets) {
      switch (notifier.getStatus(b)) {
        case BudgetStatus.safe:
          amanCount++;
        case BudgetStatus.slightlyFast:
          slightlyCount++;
        case BudgetStatus.spendingFast:
          fastCount++;
        case BudgetStatus.overBudget:
          overCount++;
      }
    }

    final pctColor = pct >= 1.0
        ? AppColors.danger
        : pct >= 0.7
            ? AppColors.warning
            : AppColors.safe;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────────────
          Row(
            children: [
              const Expanded(
                child: Text('Ringkasan Budget Bulan Ini',
                    style: AppTextStyles.caption),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _healthColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  _healthLabel,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _healthColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Ring + Info ──────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Circular ring
              AppCircularProgress(
                value: pct.clamp(0.0, 1.0),
                size: 72,
                strokeWidth: 7,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(pct * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: pctColor,
                      ),
                    ),
                    const Text(
                      'terpakai',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 8,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Right: spent/limit + status chips
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontFamily: 'Poppins'),
                        children: [
                          TextSpan(
                            text: CurrencyFormatter.formatCompact(
                                notifier.totalSpent),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          TextSpan(
                            text:
                                ' / ${CurrencyFormatter.formatCompact(notifier.totalLimit)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (amanCount > 0)
                          _StatusChip(
                              label: '$amanCount Aman',
                              color: AppColors.safe),
                        if (slightlyCount > 0)
                          _StatusChip(
                              label: '$slightlyCount Waspada',
                              color: AppColors.warning),
                        if (fastCount > 0)
                          _StatusChip(
                              label: '$fastCount Nyaris Habis',
                              color: AppColors.danger),
                        if (overCount > 0)
                          _StatusChip(
                              label: '$overCount Sudah Habis',
                              color: AppColors.danger),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Timeline bar ─────────────────────────────────────────
          AppTimelineProgressBar(
            budgetPercentage: pct,
            timePercentage: time,
          ),

          // ── Overall insight ──────────────────────────────────────
          Builder(builder: (_) {
            final insight =
                _buildInsight(overCount, fastCount, slightlyCount, amanCount);
            if (insight == null) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.sm),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.sm),
                insight,
              ],
            );
          }),
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
      case BudgetStatus.overBudget:
        return AppColors.danger;
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
      case BudgetStatus.overBudget:
        return 'Sudah Habis';
      case BudgetStatus.spendingFast:
        return 'Nyaris Habis';
      case BudgetStatus.slightlyFast:
        return 'Perlu Hemat';
      case BudgetStatus.safe:
        return 'Aman';
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
                            color: _statusColor.withValues(alpha: 0.1),
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
            budgetPercentage: percentage,
            timePercentage: timePerc,
          ),

          // Insight
          Builder(builder: (_) {
            final insight = _buildInsights(spent, percentage, timePerc);
            if (insight == null) return const SizedBox.shrink();
            return Column(
              children: [
                const SizedBox(height: AppSpacing.sm),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.sm),
                insight,
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget? _buildInsights(double spent, double percentage, double timePerc) {
    final now          = DateTime.now();
    final daysInMonth  = DateTime(now.year, now.month + 1, 0).day;
    final currentDay   = now.day;
    final daysLeft     = daysInMonth - currentDay;
    final limit        = budget.limitAmount;
    final remaining    = limit - spent;
    final dailyAvg     = currentDay > 0 && spent > 0 ? spent / currentDay : 0.0;
    final idealDaily   = daysLeft > 0 && remaining > 0 ? remaining / daysLeft : 0.0;

    String fmt(double v) => CurrencyFormatter.formatCompact(v);

    // 1. Over budget
    if (percentage >= 1.0) {
      return _InsightRow(
        emoji: '😬',
        text: 'Budget terlampaui ${fmt(spent - limit)} bulan ini. Yuk lebih hati-hati!',
        color: AppColors.danger,
      );
    }

    // 2. Belum ada pengeluaran
    if (spent == 0) {
      final dailyBudget = daysInMonth > 0 ? limit / daysInMonth : 0.0;
      return _InsightRow(
        emoji: '💡',
        text: 'Belum ada pengeluaran — kamu bisa pakai ~${fmt(dailyBudget)}/hari bulan ini',
        color: AppColors.textSecondary,
      );
    }

    // 3. Sisa ≤ 3 hari akhir bulan
    if (daysLeft <= 3 && daysLeft > 0) {
      if (remaining <= 0) {
        return _InsightRow(
          emoji: '😬',
          text: 'Budget habis! $daysLeft hari lagi hingga akhir bulan',
          color: AppColors.danger,
        );
      }
      return _InsightRow(
        emoji: '⏰',
        text: 'Tinggal $daysLeft hari lagi! Sisa budget ${fmt(remaining)}',
        color: AppColors.warning,
      );
    }

    // 4. Budget akan habis sebelum akhir bulan
    if (dailyAvg > 0 && percentage >= 0.7) {
      final daysUntilEmpty = remaining / dailyAvg;
      if (daysUntilEmpty < daysLeft) {
        final runOutDay = (currentDay + daysUntilEmpty).round();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InsightRow(
              emoji: '⚠️',
              text: 'Dengan pola ini, budget habis sekitar tanggal $runOutDay',
              color: AppColors.danger,
            ),
            if (idealDaily > 0) ...[
              const SizedBox(height: 6),
              _InsightRow(
                emoji: '💡',
                text: 'Kurangi jadi ~${fmt(idealDaily)}/hari agar pas sampai akhir bulan',
                color: AppColors.textSecondary,
              ),
            ],
          ],
        );
      }
    }

    // 5. Spending lebih cepat dari waktu berjalan
    if (percentage > timePerc + 0.15 && daysLeft > 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _InsightRow(
            emoji: '⚠️',
            text: 'Pengeluaran lebih cepat dari seharusnya',
            color: AppColors.warning,
          ),
          if (idealDaily > 0) ...[
            const SizedBox(height: 6),
            _InsightRow(
              emoji: '💡',
              text: 'Coba max ${fmt(idealDaily)}/hari agar budget aman sampai akhir bulan',
              color: AppColors.textSecondary,
            ),
          ],
        ],
      );
    }

    // 6. Hemat — jauh di bawah ekspektasi waktu
    if (percentage < timePerc - 0.2 && timePerc > 0.25 && daysLeft > 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _InsightRow(
            emoji: '🎉',
            text: 'Pengeluaranmu terkendali, pertahankan!',
            color: AppColors.safe,
          ),
          if (idealDaily > 0) ...[
            const SizedBox(height: 6),
            _InsightRow(
              emoji: '💡',
              text: 'Sisa ${fmt(remaining)} untuk $daysLeft hari — bisa pakai ${fmt(idealDaily)}/hari',
              color: AppColors.textSecondary,
            ),
          ],
        ],
      );
    }

    // 7. Default — on track, tunjukkan sisa per hari
    if (daysLeft > 0 && idealDaily > 0) {
      return _InsightRow(
        emoji: '📊',
        text: 'Sisa ${fmt(remaining)} untuk $daysLeft hari — idealnya ${fmt(idealDaily)}/hari',
        color: AppColors.textSecondary,
      );
    }

    return null;
  }
}

class _InsightRow extends StatelessWidget {
  final String emoji;
  final String text;
  final Color color;

  const _InsightRow({
    required this.emoji,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              height: 1.4,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
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
