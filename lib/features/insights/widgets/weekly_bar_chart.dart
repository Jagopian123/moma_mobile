import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../models/analytics_data.dart';

class WeeklyBarChart extends StatelessWidget {
  final List<WeeklySpending> data;
  final String period;

  const WeeklyBarChart({
    super.key,
    required this.data,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    final maxY = data.fold(0.0, (m, d) => d.amount > m ? d.amount : m) * 1.3;
    final hasData = data.any((d) => d.amount > 0);

    // Index of the bar with the highest value
    int maxIdx = -1;
    if (hasData) {
      double maxVal = 0;
      for (var i = 0; i < data.length; i++) {
        if (data[i].amount > maxVal) {
          maxVal = data[i].amount;
          maxIdx = i;
        }
      }
    }

    String title;
    switch (period) {
      case AnalyticsPeriod.year:
        title = 'Pengeluaran per Bulan';
        break;
      case AnalyticsPeriod.week:
        title = 'Pengeluaran Minggu Ini';
        break;
      default:
        title = 'Pengeluaran per Minggu';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h4),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 160,
            child: hasData
                ? BarChart(
                    BarChartData(
                      maxY: maxY <= 0 ? 1 : maxY,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) =>
                              AppColors.primary.withValues(alpha: 0.1),
                          tooltipRoundedRadius: 6,
                          tooltipPadding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          tooltipMargin: 6,
                          getTooltipItem: (group, _, rod, __) {
                            if (rod.toY <= 0) return null;
                            return BarTooltipItem(
                              _formatAmount(rod.toY),
                              const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            getTitlesWidget: (value, _) {
                              final i = value.toInt();
                              if (i < 0 || i >= data.length) {
                                return const SizedBox();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  data[i].dayLabel,
                                  style: period == AnalyticsPeriod.year
                                      ? const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 8,
                                          color: AppColors.textSecondary,
                                        )
                                      : AppTextStyles.small,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: AppColors.border,
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: data.asMap().entries.map((e) {
                        final isCurrent = _isCurrentBar(e.key);
                        final isMax = e.key == maxIdx;
                        return BarChartGroupData(
                          x: e.key,
                          // Show persistent value label on peak bar only
                          showingTooltipIndicators: isMax ? [0] : [],
                          barRods: [
                            BarChartRodData(
                              toY: e.value.amount,
                              color: isCurrent
                                  ? AppColors.primary
                                  : AppColors.primary.withValues(alpha: 0.35),
                              width: _barWidth,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bar_chart_rounded,
                            size: 36, color: AppColors.textHint),
                        const SizedBox(height: 8),
                        Text(
                          _emptyLabel,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  bool _isCurrentBar(int index) {
    final now = DateTime.now();
    switch (period) {
      case AnalyticsPeriod.week:
        return index == now.weekday - 1;
      case AnalyticsPeriod.year:
        return index == now.month - 1;
      default:
        return index == ((now.day - 1) ~/ 7).clamp(0, 4);
    }
  }

  double get _barWidth {
    switch (period) {
      case AnalyticsPeriod.year:
        return 14;
      case AnalyticsPeriod.week:
        return 22;
      default:
        return 32;
    }
  }

  String get _emptyLabel {
    switch (period) {
      case AnalyticsPeriod.year:
        return 'Belum ada pengeluaran tahun ini';
      case AnalyticsPeriod.week:
        return 'Belum ada pengeluaran minggu ini';
      default:
        return 'Belum ada pengeluaran bulan ini';
    }
  }

  String _formatAmount(double v) {
    if (v >= 1000000) return '${_strip(v / 1000000)}jt';
    if (v >= 1000) return '${_strip(v / 1000)}rb';
    return v.toStringAsFixed(0);
  }

  String _strip(double n) =>
      n.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
}
