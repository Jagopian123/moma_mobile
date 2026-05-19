import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../models/analytics_data.dart';

class SummaryCards extends StatelessWidget {
  final AnalyticsSummary summary;
  final AnalyticsSummary? previousSummary;
  final double dailyAverage;

  const SummaryCards({
    super.key,
    required this.summary,
    this.previousSummary,
    this.dailyAverage = 0,
  });

  @override
  Widget build(BuildContext context) {
    final prev = previousSummary;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.45,
      children: [
        _SummaryCard(
          label: 'Pemasukan',
          amount: CurrencyFormatter.formatCompact(summary.totalIncome),
          icon: Icons.arrow_downward_rounded,
          color: AppColors.income,
          bgColor: const Color(0xFFD1FAE5),
          delta: prev != null
              ? _delta(summary.totalIncome, prev.totalIncome, true)
              : null,
          deltaGood: prev != null
              ? summary.totalIncome >= prev.totalIncome
              : null,
        ),
        _SummaryCard(
          label: 'Pengeluaran',
          amount: CurrencyFormatter.formatCompact(summary.totalExpense),
          icon: Icons.arrow_upward_rounded,
          color: AppColors.expense,
          bgColor: const Color(0xFFFEE2E2),
          delta: prev != null
              ? _delta(summary.totalExpense, prev.totalExpense, false)
              : null,
          deltaGood: prev != null
              ? summary.totalExpense <= prev.totalExpense
              : null,
        ),
        _SummaryCard(
          label: 'Tabungan',
          amount: summary.totalSaving > 0
              ? '+${CurrencyFormatter.formatCompact(summary.totalSaving)}'
              : CurrencyFormatter.formatCompact(summary.totalSaving),
          icon: Icons.savings_rounded,
          color: summary.totalSaving >= 0 ? AppColors.primary : AppColors.expense,
          bgColor: summary.totalSaving >= 0
              ? const Color(0xFFDBEAFE)
              : const Color(0xFFFEE2E2),
          delta: prev != null
              ? _delta(summary.totalSaving, prev.totalSaving, true)
              : null,
          deltaGood: prev != null
              ? summary.totalSaving >= prev.totalSaving
              : null,
        ),
        _SummaryCard(
          label: 'Rata-rata/Hari',
          amount: CurrencyFormatter.formatCompact(dailyAverage),
          icon: Icons.today_rounded,
          color: const Color(0xFF8B5CF6),
          bgColor: const Color(0xFFEDE9FE),
          delta: prev != null
              ? _delta(summary.savingRate, prev.savingRate, true)
              : null,
          deltaGood: prev != null
              ? summary.savingRate >= prev.savingRate
              : null,
        ),
      ],
    );
  }

  // Returns delta string like "↑12%" or "↓5%" or "" if change is negligible
  static String _delta(double current, double previous, bool higherIsBetter) {
    if (previous == 0) return '';
    final pct = (current - previous) / previous.abs() * 100;
    if (pct.abs() < 1) return '';
    final isUp = pct > 0;
    final sign = isUp ? '↑' : '↓';
    return '$sign${pct.abs().toStringAsFixed(0)}%';
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String amount;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String? delta;
  final bool? deltaGood;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.delta,
    this.deltaGood,
  });

  @override
  Widget build(BuildContext context) {
    final hasDelta = delta != null && delta!.isNotEmpty;
    final deltaColor = deltaGood == true ? AppColors.income : AppColors.expense;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              if (hasDelta)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: deltaColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    delta!,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: deltaColor,
                    ),
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                amount,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(label, style: AppTextStyles.small),
            ],
          ),
        ],
      ),
    );
  }
}
