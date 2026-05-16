import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/app_card.dart';
import '../providers/transaction_provider.dart';
import '../widgets/transaction_card.dart';

class TodayTab extends ConsumerWidget {
  const TodayTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTx = ref.watch(transactionProvider);
    final now = DateTime.now();
    final transactions = allTx
        .where((tx) =>
            tx.date.year == now.year &&
            tx.date.month == now.month &&
            tx.date.day == now.day)
        .toList();
    final income = transactions
        .where((t) => t.type == 'income')
        .fold(0.0, (s, t) => s + t.amount);
    final expense = transactions
        .where((t) => t.type == 'expense')
        .fold(0.0, (s, t) => s + t.amount);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // ── Summary Card ─────────────────────────────────────
        _TodaySummaryCard(income: income, expense: expense),
        const SizedBox(height: AppSpacing.md),

        // ── List transaksi ───────────────────────────────────
        if (transactions.isEmpty)
          AppEmptyState(
            emoji: '📭',
            imagePath: 'assets/images/mascot-transaksi.png',
            title: 'Belum ada transaksi',
            description: 'Tap tombol + untuk mencatat transaksi hari ini',
          )
        else
          ...transactions.map((tx) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: TransactionCard(transaction: tx),
              )),
      ],
    );
  }
}

class _TodaySummaryCard extends StatelessWidget {
  final double income;
  final double expense;

  const _TodaySummaryCard({required this.income, required this.expense});

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}
