import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/hive/models/transaction_model.dart';
import '../../../shared/widgets/app_card.dart';
import '../providers/transaction_provider.dart';
import '../widgets/transaction_card.dart';

class CustomTab extends ConsumerStatefulWidget {
  const CustomTab({super.key});

  @override
  ConsumerState<CustomTab> createState() => _CustomTabState();
}

class _CustomTabState extends ConsumerState<CustomTab> {
  DateTime _from = DateTime.now().subtract(const Duration(days: 6));
  DateTime _to = DateTime.now();

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _from = picked.start;
        _to = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allTx = ref.watch(transactionProvider);
    final from = DateTime(_from.year, _from.month, _from.day);
    final to = DateTime(_to.year, _to.month, _to.day, 23, 59, 59);
    final transactions = allTx
        .where((tx) =>
            tx.date.isAfter(from.subtract(const Duration(seconds: 1))) &&
            tx.date.isBefore(to.add(const Duration(seconds: 1))))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final income = transactions
        .where((t) => t.type == 'income')
        .fold(0.0, (s, t) => s + t.amount);
    final expense = transactions
        .where((t) => t.type == 'expense')
        .fold(0.0, (s, t) => s + t.amount);

    // Group by date
    final grouped = <DateTime, List<TransactionModel>>{};
    for (final tx in transactions) {
      final date = DateTime(tx.date.year, tx.date.month, tx.date.day);
      grouped.putIfAbsent(date, () => []).add(tx);
    }
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // ── Date Range Picker ────────────────────────────────
        GestureDetector(
          onTap: _pickDateRange,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.primary.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.date_range_rounded,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  '${DateFormat('dd MMM yyyy', 'id').format(_from)}'
                  '  –  '
                  '${DateFormat('dd MMM yyyy', 'id').format(_to)}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 18, color: AppColors.primary),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Summary ──────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: AppSummaryCard(
                label: 'Pemasukan',
                amount: CurrencyFormatter.formatCompact(income),
                icon: Icons.arrow_downward_rounded,
                color: AppColors.income,
                bgColor: AppColors.income.withOpacity(0.08),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppSummaryCard(
                label: 'Pengeluaran',
                amount: CurrencyFormatter.formatCompact(expense),
                icon: Icons.arrow_upward_rounded,
                color: AppColors.expense,
                bgColor: AppColors.expense.withOpacity(0.08),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // ── List grouped by date ─────────────────────────────
        if (transactions.isEmpty)
          AppEmptyState(
            emoji: '🔍',
            imagePath: 'assets/images/mascot-transaksi.png',
            title: 'Tidak ada transaksi',
            description: 'Tidak ada transaksi pada rentang tanggal ini',
          )
        else
          ...sortedDates.map((date) {
            final txList = grouped[date]!;
            final dayIncome = txList
                .where((t) => t.type == 'income')
                .fold(0.0, (s, t) => s + t.amount);
            final dayExpense = txList
                .where((t) => t.type == 'expense')
                .fold(0.0, (s, t) => s + t.amount);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TransactionDateHeader(
                  date: date,
                  totalIncome: dayIncome,
                  totalExpense: dayExpense,
                ),
                ...txList.map((tx) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: TransactionCard(transaction: tx),
                    )),
              ],
            );
          }),
      ],
    );
  }
}
