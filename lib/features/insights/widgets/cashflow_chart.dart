import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../models/analytics_data.dart';

class CashflowChart extends StatelessWidget {
  final List<CashflowPoint> points;
  final String period;

  const CashflowChart({
    super.key,
    required this.points,
    required this.period,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = points.any((p) => p.income > 0 || p.expense > 0);

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
          Row(
            children: [
              Text('Arus Kas', style: AppTextStyles.h4),
              const Spacer(),
              _Legend(color: AppColors.income, label: 'Masuk'),
              const SizedBox(width: AppSpacing.sm),
              _Legend(color: AppColors.expense, label: 'Keluar'),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 180,
            child: hasData ? _buildChart() : _emptyChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    final maxY = points.fold(0.0, (m, p) {
          final top = p.income > p.expense ? p.income : p.expense;
          return top > m ? top : m;
        }) *
        1.2;

    final incomeSpots = <FlSpot>[];
    final expenseSpots = <FlSpot>[];

    for (var i = 0; i < points.length; i++) {
      incomeSpots.add(FlSpot(i.toDouble(), points[i].income));
      expenseSpots.add(FlSpot(i.toDouble(), points[i].expense));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 0 ? maxY / 4 : 1,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppColors.border,
            strokeWidth: 1,
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
              reservedSize: 28,
              interval: _bottomInterval(),
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= points.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _label(points[idx].date),
                    style: AppTextStyles.small,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        minY: 0,
        maxY: maxY <= 0 ? 1 : maxY,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.textPrimary.withOpacity(0.85),
            tooltipRoundedRadius: AppRadius.sm,
            getTooltipItems: (spots) {
              return spots.map((s) {
                final isIncome = s.barIndex == 0;
                return LineTooltipItem(
                  _formatAmount(s.y),
                  TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isIncome ? AppColors.income : AppColors.expense,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          _line(incomeSpots, AppColors.income),
          _line(expenseSpots, AppColors.expense),
        ],
      ),
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.3,
      color: color,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: color.withOpacity(0.08),
      ),
    );
  }

  double _bottomInterval() {
    if (points.length <= 7) return 1;
    if (points.length <= 14) return 2;
    if (points.length <= 31) return 5;
    return 2;
  }

  String _label(DateTime date) {
    if (period == AnalyticsPeriod.year) {
      return DateFormat('MMM', 'id_ID').format(date);
    }
    if (period == AnalyticsPeriod.week) {
      return DateFormat('EEE', 'id_ID').format(date);
    }
    return date.day.toString();
  }

  String _formatAmount(double v) {
    if (v >= 1000000) return '${_strip(v / 1000000)}jt';
    if (v >= 1000) return '${_strip(v / 1000)}rb';
    return v.toStringAsFixed(0);
  }

  String _strip(double n) =>
      n.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');

  Widget _emptyChart() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.show_chart_rounded, size: 40, color: AppColors.textHint),
          SizedBox(height: 8),
          Text(
            'Belum ada data',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.small),
      ],
    );
  }
}
