import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../models/analytics_data.dart';

class SummaryCards extends StatelessWidget {
  final AnalyticsSummary summary;

  const SummaryCards({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: AppSpacing.sm,
      mainAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.55,
      children: [
        _SummaryCard(
          label: 'Pemasukan',
          amount: CurrencyFormatter.formatCompact(summary.totalIncome),
          icon: Icons.arrow_downward_rounded,
          color: AppColors.income,
          bgColor: const Color(0xFFD1FAE5),
        ),
        _SummaryCard(
          label: 'Pengeluaran',
          amount: CurrencyFormatter.formatCompact(summary.totalExpense),
          icon: Icons.arrow_upward_rounded,
          color: AppColors.expense,
          bgColor: const Color(0xFFFEE2E2),
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
        ),
        _SummaryCard(
          label: 'Saving Rate',
          amount: '${(summary.savingRate * 100).toStringAsFixed(1)}%',
          icon: Icons.percent_rounded,
          color: const Color(0xFF8B5CF6),
          bgColor: const Color(0xFFEDE9FE),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String amount;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
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
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, size: 16, color: color),
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
