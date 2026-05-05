import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/hive/models/financial_plan_model.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_circular_progress.dart';
import '../providers/financial_plan_provider.dart';
import '../widgets/financial_plan_form_sheet.dart';
import '../widgets/contribution_sheet.dart';

class FinancialPlanPage extends ConsumerWidget {
  const FinancialPlanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(financialPlanProvider);
    final notifier = ref.read(financialPlanProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Rencana Finansial', style: AppTextStyles.h3),
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
          'Tambah Rencana',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: plans.isEmpty
          ? AppEmptyState(
              emoji: '🎯',
              title: 'Belum ada rencana',
              description: 'Tambahkan rencana finansialmu dan mulai menabung',
              actionLabel: 'Tambah Rencana',
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
                // ── Dashboard Keseluruhan ──────────────────────
                _OverallDashboard(notifier: notifier),
                const SizedBox(height: AppSpacing.lg),

                // ── Card per Target ────────────────────────────
                ...plans.map((plan) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _PlanCard(
                        plan: plan,
                        notifier: notifier,
                        onEdit: () => _showForm(context, plan),
                        onDelete: () => _confirmDelete(context, ref, plan),
                        onAddContribution: () =>
                            _showContribution(context, plan),
                      ),
                    )),
              ],
            ),
    );
  }

  void _showForm(BuildContext context, [FinancialPlanModel? plan]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FinancialPlanFormSheet(plan: plan),
    );
  }

  void _showContribution(BuildContext context, FinancialPlanModel plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ContributionSheet(plan: plan),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, FinancialPlanModel plan) async {
    final confirm = await showConfirmSheet(
      context: context,
      title: 'Hapus Rencana',
      description: 'Hapus rencana "${plan.name}"?',
      confirmLabel: 'Ya, Hapus',
    );
    if (confirm == true) {
      ref.read(financialPlanProvider.notifier).delete(plan.id);
    }
  }
}

// ── Overall Dashboard ─────────────────────────────────────────────────────────

class _OverallDashboard extends StatelessWidget {
  final FinancialPlanNotifier notifier;

  const _OverallDashboard({required this.notifier});

  @override
  Widget build(BuildContext context) {
    final pct = notifier.overallPercentage;
    final completed = notifier.completedCount;
    final total = notifier.state.length;

    return AppGradientCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progress Keseluruhan',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(pct * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          Text(
            '${CurrencyFormatter.formatCompact(notifier.totalSaved)} '
            'dari ${CurrencyFormatter.formatCompact(notifier.totalTarget)}',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Completed count
          Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                '$completed/$total target selesai',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Plan Card ─────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final FinancialPlanModel plan;
  final FinancialPlanNotifier notifier;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddContribution;

  const _PlanCard({
    required this.plan,
    required this.notifier,
    required this.onEdit,
    required this.onDelete,
    required this.onAddContribution,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse(plan.color.replaceFirst('#', '0xFF')));
    final percentage = notifier.getPercentage(plan);
    final remaining =
        (plan.targetAmount - plan.savedAmount).clamp(0.0, double.infinity);
    final daysLeft = notifier.getDaysLeft(plan);
    final isDone = plan.savedAmount >= plan.targetAmount;

    // Kontribusi terbaru (3 terakhir)
    final recentContribs = plan.contributions.reversed.take(3).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────
          Row(
            children: [
              // Circular progress
              AppCircularProgress(
                value: percentage,
                size: 68,
                strokeWidth: 7,
                color: isDone ? AppColors.safe : color,
                center: isDone
                    ? const Icon(Icons.check_rounded,
                        color: AppColors.safe, size: 28)
                    : Text(plan.icon, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: AppSpacing.md),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.name, style: AppTextStyles.h4),
                    const SizedBox(height: 4),

                    // Deadline
                    if (daysLeft != null)
                      Row(
                        children: [
                          Icon(
                            daysLeft == 0
                                ? Icons.warning_rounded
                                : Icons.schedule_rounded,
                            size: 14,
                            color: daysLeft <= 7
                                ? AppColors.danger
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            daysLeft == 0
                                ? 'Deadline hari ini!'
                                : '$daysLeft hari lagi',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: daysLeft <= 7
                                  ? AppColors.danger
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),

                    if (isDone)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.safe.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: const Text(
                          '🎉 Target Tercapai!',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.safe,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Actions
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded,
                    color: AppColors.textHint, size: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('Edit', style: TextStyle(fontFamily: 'Poppins')),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_rounded,
                          size: 16, color: AppColors.danger),
                      SizedBox(width: 8),
                      Text('Hapus',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: AppColors.danger,
                          )),
                    ]),
                  ),
                ],
                onSelected: (val) {
                  if (val == 'edit') onEdit();
                  if (val == 'delete') onDelete();
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Data row ────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _DataItem(
                label: 'Saved',
                value: CurrencyFormatter.formatCompact(plan.savedAmount),
                color: color,
              ),
              _DataItem(
                label: 'Target',
                value: CurrencyFormatter.formatCompact(plan.targetAmount),
                color: AppColors.textSecondary,
              ),
              _DataItem(
                label: 'To Go',
                value: CurrencyFormatter.formatCompact(remaining),
                color: AppColors.expense,
              ),
            ],
          ),

          // ── Kontribusi terbaru ───────────────────────────────
          if (recentContribs.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Setoran Terbaru',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            ...recentContribs.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('dd MMM yyyy', 'id').format(c.date),
                        style: AppTextStyles.small,
                      ),
                      Text(
                        '+${CurrencyFormatter.format(c.amount)}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                )),
          ],

          const SizedBox(height: AppSpacing.md),

          // ── Tombol tambah setoran ────────────────────────────
          if (!isDone)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAddContribution,
                icon: Icon(Icons.add_rounded, size: 18, color: color),
                label: Text(
                  'Tambah Setoran',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  side: BorderSide(color: color.withOpacity(0.4)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
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
