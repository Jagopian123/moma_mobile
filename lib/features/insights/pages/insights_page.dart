import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../models/analytics_data.dart';
import '../providers/analytics_provider.dart';
import '../widgets/summary_cards.dart';
import '../widgets/cashflow_chart.dart';
import '../widgets/donut_chart.dart';
import '../widgets/weekly_bar_chart.dart';
import '../widgets/health_score_card.dart';

class InsightsPage extends ConsumerWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(analyticsPeriodProvider);
    final data = ref.watch(analyticsDataProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ───────────────────────────────────────────────
          SliverAppBar(
            floating: true,
            backgroundColor: AppColors.background,
            elevation: 0,
            toolbarHeight: 60,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              color: AppColors.textPrimary,
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text('Insights', style: AppTextStyles.h3),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: _PeriodDropdown(
                  value: period,
                  onChanged: (v) =>
                      ref.read(analyticsPeriodProvider.notifier).state = v!,
                ),
              ),
            ],
          ),

          // ── Body ─────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.xxl,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Insight Cards
                if (data.insights.isNotEmpty) ...[
                  ...data.insights.map((insight) => Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _InsightBanner(insight: insight),
                      )),
                  const SizedBox(height: AppSpacing.sm),
                ],

                // Summary Cards
                SummaryCards(summary: data.summary),
                const SizedBox(height: AppSpacing.md),

                // Cashflow Chart
                CashflowChart(
                  points: data.cashflowPoints,
                  period: period,
                ),
                const SizedBox(height: AppSpacing.md),

                // Donut Chart
                DonutChart(categories: data.categoryExpenses),
                const SizedBox(height: AppSpacing.md),

                // Weekly Bar Chart
                WeeklyBarChart(data: data.weeklySpending),
                const SizedBox(height: AppSpacing.md),

                // Health Score
                HealthScoreCard(score: data.healthScore),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Period Dropdown ───────────────────────────────────────────────────────────

class _PeriodDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;

  const _PeriodDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: AppColors.textSecondary),
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
          onChanged: onChanged,
          items: const [
            DropdownMenuItem(
              value: AnalyticsPeriod.week,
              child: Text('Minggu ini'),
            ),
            DropdownMenuItem(
              value: AnalyticsPeriod.month,
              child: Text('Bulan ini'),
            ),
            DropdownMenuItem(
              value: AnalyticsPeriod.year,
              child: Text('Tahun ini'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Insight Banner ────────────────────────────────────────────────────────────

class _InsightBanner extends StatelessWidget {
  final InsightItem insight;

  const _InsightBanner({required this.insight});

  @override
  Widget build(BuildContext context) {
    final colors = _resolveColors(insight.type);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: colors.$2),
      ),
      child: Row(
        children: [
          Text(insight.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.$3,
                  ),
                ),
                Text(
                  insight.body,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: colors.$3.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color, Color) _resolveColors(InsightType type) {
    switch (type) {
      case InsightType.positive:
        return (
          const Color(0xFFF0FDF4),
          const Color(0xFFBBF7D0),
          AppColors.income,
        );
      case InsightType.warning:
        return (
          const Color(0xFFFFFBEB),
          const Color(0xFFFDE68A),
          AppColors.transfer,
        );
      case InsightType.danger:
        return (
          const Color(0xFFFFF1F2),
          const Color(0xFFFECACA),
          AppColors.expense,
        );
      default:
        return (
          const Color(0xFFF8FAFF),
          AppColors.border,
          AppColors.textPrimary,
        );
    }
  }
}
