import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/hive/models/transaction_model.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_progress_bar.dart';
import '../../../shared/widgets/native_ad_widget.dart';
import '../providers/transaction_provider.dart';

class SummaryTab extends ConsumerStatefulWidget {
  const SummaryTab({super.key});

  @override
  ConsumerState<SummaryTab> createState() => _SummaryTabState();
}

class _SummaryTabState extends ConsumerState<SummaryTab> {
  final int _year = DateTime.now().year;
  // Set bulan yang sedang di-expand breakdown-nya
  int? _expandedMonth;

  @override
  Widget build(BuildContext context) {
    final allTx = ref.watch(transactionProvider);

    // Hitung per bulan
    final monthlyData = _buildMonthlyData(allTx);

    // Hitung tahun ini
    final yearIncome = monthlyData.fold(0.0, (s, m) => s + m.income);
    final yearExpense = monthlyData.fold(0.0, (s, m) => s + m.expense);
    final netBalance = yearIncome - yearExpense;
    final ratio = yearIncome > 0 ? yearExpense / yearIncome : 0.0;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // ── Ringkasan Tahun ──────────────────────────────────
        _YearlySummaryCard(
          year: _year,
          income: yearIncome,
          expense: yearExpense,
          netBalance: netBalance,
          ratio: ratio,
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── Ringkasan Per Bulan ──────────────────────────────
        const Text('Ringkasan Per Bulan', style: AppTextStyles.h4),
        const SizedBox(height: AppSpacing.sm),

        ...monthlyData.map((month) => _MonthlyCard(
              data: month,
              isExpanded: _expandedMonth == month.month,
              onToggle: () => setState(() {
                _expandedMonth =
                    _expandedMonth == month.month ? null : month.month;
              }),
              allTransactions: allTx,
              year: _year,
            )),

        if (allTx.isNotEmpty) const NativeAdWidget(),
      ],
    );
  }

  List<_MonthData> _buildMonthlyData(List<TransactionModel> allTx) {
    return List.generate(12, (i) {
      final month = i + 1;
      final txs =
          allTx.where((tx) => tx.date.year == _year && tx.date.month == month);
      final income = txs
          .where((t) => t.type == 'income')
          .fold(0.0, (s, t) => s + t.amount);
      final expense = txs
          .where((t) => t.type == 'expense')
          .fold(0.0, (s, t) => s + t.amount);
      return _MonthData(month: month, income: income, expense: expense);
    });
  }
}

// ── Yearly Summary Card ───────────────────────────────────────────────────────

class _YearlySummaryCard extends StatelessWidget {
  final int year;
  final double income;
  final double expense;
  final double netBalance;
  final double ratio;

  const _YearlySummaryCard({
    required this.year,
    required this.income,
    required this.expense,
    required this.netBalance,
    required this.ratio,
  });

  @override
  Widget build(BuildContext context) {
    return AppGradientCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tahun $year',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Saldo Bersih',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
          Text(
            netBalance >= 0
                ? '+${CurrencyFormatter.format(netBalance)}'
                : CurrencyFormatter.format(netBalance),
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Rasio pengeluaran
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rasio Pengeluaran',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              Text(
                '${(ratio * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                ratio > 0.9
                    ? Colors.redAccent
                    : ratio > 0.7
                        ? Colors.orangeAccent
                        : Colors.greenAccent,
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Pemasukan & Pengeluaran
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: 'Pemasukan',
                  value: CurrencyFormatter.formatCompact(income),
                  color: const Color(0xFF86EFAC),
                ),
              ),
              Expanded(
                child: _StatItem(
                  label: 'Pengeluaran',
                  value: CurrencyFormatter.formatCompact(expense),
                  color: const Color(0xFFFCA5A5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ── Monthly Card ──────────────────────────────────────────────────────────────

class _MonthlyCard extends StatelessWidget {
  final _MonthData data;
  final bool isExpanded;
  final VoidCallback onToggle;
  final List<TransactionModel> allTransactions;
  final int year;

  const _MonthlyCard({
    required this.data,
    required this.isExpanded,
    required this.onToggle,
    required this.allTransactions,
    required this.year,
  });

  String get _monthName =>
      DateFormat('MMMM', 'id').format(DateTime(year, data.month));

  bool get _hasData => data.income > 0 || data.expense > 0;

  // Breakdown mingguan: 1-7, 8-14, 15-21, 22-akhir
  List<_WeekData> _getWeeklyBreakdown() {
    final weeks = [
      _WeekRange(1, 7),
      _WeekRange(8, 14),
      _WeekRange(15, 21),
      _WeekRange(22, 31),
    ];

    return weeks.map((w) {
      final txs = allTransactions.where((tx) =>
          tx.date.year == year &&
          tx.date.month == data.month &&
          tx.date.day >= w.start &&
          tx.date.day <= w.end);
      final income = txs
          .where((t) => t.type == 'income')
          .fold(0.0, (s, t) => s + t.amount);
      final expense = txs
          .where((t) => t.type == 'expense')
          .fold(0.0, (s, t) => s + t.amount);
      return _WeekData(range: w, income: income, expense: expense);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Header bulan
          InkWell(
            onTap: _hasData ? onToggle : null,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  // Nama bulan
                  SizedBox(
                    width: 80,
                    child: Text(
                      _monthName,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _hasData
                            ? AppColors.textPrimary
                            : AppColors.textHint,
                      ),
                    ),
                  ),

                  // Income & Expense
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (data.income > 0)
                          Text(
                            '+${CurrencyFormatter.formatCompact(data.income)}',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: AppColors.income,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (data.income > 0 && data.expense > 0)
                          const Text(
                            '  ·  ',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textHint,
                            ),
                          ),
                        if (data.expense > 0)
                          Text(
                            '-${CurrencyFormatter.formatCompact(data.expense)}',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: AppColors.expense,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (!_hasData)
                          const Text(
                            '-',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: AppColors.textHint,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Arrow
                  if (_hasData) ...[
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Breakdown mingguan
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: isExpanded
                ? Column(
                    children: [
                      const Divider(height: 1, color: AppColors.border),
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          children: _getWeeklyBreakdown()
                              .map((w) => _WeekRow(data: w))
                              .toList(),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ── Week Row ──────────────────────────────────────────────────────────────────

class _WeekRow extends StatelessWidget {
  final _WeekData data;

  const _WeekRow({required this.data});

  bool get _hasData => data.income > 0 || data.expense > 0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '${data.range.start} - ${data.range.end}',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: _hasData ? AppColors.textSecondary : AppColors.textHint,
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (data.income > 0)
                  Text(
                    '+${CurrencyFormatter.formatCompact(data.income)}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.income,
                    ),
                  ),
                if (data.income > 0 && data.expense > 0)
                  const Text(
                    '  ·  ',
                    style: TextStyle(fontSize: 12, color: AppColors.textHint),
                  ),
                if (data.expense > 0)
                  Text(
                    '-${CurrencyFormatter.formatCompact(data.expense)}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.expense,
                    ),
                  ),
                if (!_hasData)
                  const Text(
                    '-',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.textHint,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data Classes ──────────────────────────────────────────────────────────────

class _MonthData {
  final int month;
  final double income;
  final double expense;

  const _MonthData({
    required this.month,
    required this.income,
    required this.expense,
  });
}

class _WeekData {
  final _WeekRange range;
  final double income;
  final double expense;

  const _WeekData({
    required this.range,
    required this.income,
    required this.expense,
  });
}

class _WeekRange {
  final int start;
  final int end;

  const _WeekRange(this.start, this.end);
}
