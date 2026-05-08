import '../../../core/hive/hive_service.dart';
import '../../../core/hive/models/transaction_model.dart';
import '../../../core/hive/models/budget_model.dart';
import '../../../core/utils/currency_formatter.dart';
import '../models/analytics_data.dart';

class InsightGenerator {
  static List<InsightItem> generate() {
    final all = HiveService.transactions.values.toList();
    final budgets = HiveService.budgets.values.toList();
    final now = DateTime.now();

    final insights = <_ScoredInsight>[];

    insights.addAll(_checkBudgetAlerts(budgets, all, now));
    insights.addAll(_checkSpendingTrend(all, now));
    insights.addAll(_checkTopCategory(all, now));
    insights.addAll(_checkSavingHealth(all, now));
    insights.addAll(_checkCashflow(all, now));

    insights.sort((a, b) => b.priority.compareTo(a.priority));

    return insights.take(2).map((s) => s.item).toList();
  }

  // ── Budget Alerts ────────────────────────────────────────────────────────────

  static List<_ScoredInsight> _checkBudgetAlerts(
    List<BudgetModel> budgets,
    List<TransactionModel> all,
    DateTime now,
  ) {
    final results = <_ScoredInsight>[];

    for (final budget in budgets) {
      final spent = _budgetSpent(budget, all, now);
      final pct = budget.limitAmount > 0 ? spent / budget.limitAmount : 0.0;

      if (pct >= 1.0) {
        results.add(_ScoredInsight(
          priority: 100,
          item: InsightItem(
            emoji: '🚨',
            title: 'Budget ${budget.categoryName} habis!',
            body: 'Kamu sudah melewati batas budget '
                '${CurrencyFormatter.formatCompact(budget.limitAmount)}.',
            type: InsightType.danger,
          ),
        ));
      } else if (pct >= 0.85) {
        results.add(_ScoredInsight(
          priority: 80,
          item: InsightItem(
            emoji: '⚠️',
            title: 'Budget ${budget.categoryName} hampir habis',
            body: 'Sudah terpakai ${(pct * 100).toStringAsFixed(0)}% dari '
                '${CurrencyFormatter.formatCompact(budget.limitAmount)}.',
            type: InsightType.warning,
          ),
        ));
      }
    }

    return results;
  }

  // ── Spending Trend ───────────────────────────────────────────────────────────

  static List<_ScoredInsight> _checkSpendingTrend(
    List<TransactionModel> all,
    DateTime now,
  ) {
    // Compare this week vs last week
    final weekStart =
        DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final lastWeekStart = weekStart.subtract(const Duration(days: 7));
    final lastWeekEnd = weekStart.subtract(const Duration(seconds: 1));

    final thisWeekExp = _sumExpense(all, weekStart, now);
    final lastWeekExp = _sumExpense(all, lastWeekStart, lastWeekEnd);

    if (lastWeekExp <= 0) return [];

    final diff = thisWeekExp - lastWeekExp;
    final pct = (diff / lastWeekExp * 100).abs();

    if (diff > 0 && pct >= 20) {
      return [
        _ScoredInsight(
          priority: 70,
          item: InsightItem(
            emoji: '📈',
            title: 'Pengeluaran naik ${pct.toStringAsFixed(0)}%',
            body: 'Minggu ini kamu lebih boros dibanding minggu lalu. '
                'Coba evaluasi pengeluaranmu.',
            type: InsightType.warning,
          ),
        ),
      ];
    }

    if (diff < 0 && pct >= 15) {
      return [
        _ScoredInsight(
          priority: 40,
          item: InsightItem(
            emoji: '🎉',
            title: 'Lebih hemat minggu ini!',
            body: 'Pengeluaranmu turun ${pct.toStringAsFixed(0)}% '
                'dibanding minggu lalu. Pertahankan!',
            type: InsightType.positive,
          ),
        ),
      ];
    }

    return [];
  }

  // ── Top Category ─────────────────────────────────────────────────────────────

  static List<_ScoredInsight> _checkTopCategory(
    List<TransactionModel> all,
    DateTime now,
  ) {
    final monthStart = DateTime(now.year, now.month, 1);
    final monthExp = all.where((tx) =>
        tx.type == 'expense' && !tx.date.isBefore(monthStart));

    if (monthExp.isEmpty) return [];

    final Map<String, _CatData> acc = {};
    for (final tx in monthExp) {
      acc.putIfAbsent(
        tx.categoryId,
        () => _CatData(tx.categoryName, tx.categoryIcon),
      ).amount += tx.amount;
    }

    final top = acc.values.reduce((a, b) => a.amount >= b.amount ? a : b);

    return [
      _ScoredInsight(
        priority: 50,
        item: InsightItem(
          emoji: top.icon,
          title: 'Terbesar: ${top.name}',
          body: 'Pengeluaran terbesar bulan ini adalah ${top.name} sebesar '
              '${CurrencyFormatter.formatCompact(top.amount)}.',
          type: InsightType.neutral,
        ),
      ),
    ];
  }

  // ── Saving Health ────────────────────────────────────────────────────────────

  static List<_ScoredInsight> _checkSavingHealth(
    List<TransactionModel> all,
    DateTime now,
  ) {
    final monthStart = DateTime(now.year, now.month, 1);
    final income = _sumIncome(all, monthStart, now);
    final expense = _sumExpense(all, monthStart, now);

    if (income <= 0) return [];

    final savingRate = (income - expense) / income;

    if (savingRate >= 0.2) {
      return [
        _ScoredInsight(
          priority: 35,
          item: InsightItem(
            emoji: '💰',
            title: 'Saving rate bagus!',
            body: 'Kamu berhasil menabung ${(savingRate * 100).toStringAsFixed(0)}%'
                ' dari pemasukan bulan ini.',
            type: InsightType.positive,
          ),
        ),
      ];
    }

    if (savingRate < 0) {
      return [
        _ScoredInsight(
          priority: 90,
          item: InsightItem(
            emoji: '😟',
            title: 'Pengeluaran melebihi pemasukan',
            body: 'Bulan ini kamu lebih banyak keluar daripada masuk. '
                'Cek kembali anggaranmu.',
            type: InsightType.danger,
          ),
        ),
      ];
    }

    return [];
  }

  // ── Cashflow ─────────────────────────────────────────────────────────────────

  static List<_ScoredInsight> _checkCashflow(
    List<TransactionModel> all,
    DateTime now,
  ) {
    // Compare this month vs last month
    final thisStart = DateTime(now.year, now.month, 1);
    final lastStart = DateTime(now.year, now.month - 1, 1);
    final lastEnd = thisStart.subtract(const Duration(seconds: 1));

    final thisExp = _sumExpense(all, thisStart, now);
    final lastExp = _sumExpense(all, lastStart, lastEnd);

    if (lastExp <= 0) return [];

    final diff = thisExp - lastExp;
    final pct = (diff / lastExp * 100).abs();

    if (diff < 0 && pct >= 10) {
      return [
        _ScoredInsight(
          priority: 45,
          item: InsightItem(
            emoji: '✅',
            title: 'Lebih hemat dari bulan lalu',
            body: 'Pengeluaranmu bulan ini turun ${pct.toStringAsFixed(0)}% '
                'dibanding bulan lalu.',
            type: InsightType.positive,
          ),
        ),
      ];
    }

    return [];
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static double _sumExpense(
      List<TransactionModel> all, DateTime from, DateTime to) {
    return all
        .where((tx) =>
            tx.type == 'expense' &&
            !tx.date.isBefore(from) &&
            !tx.date.isAfter(to))
        .fold(0.0, (s, t) => s + t.amount);
  }

  static double _sumIncome(
      List<TransactionModel> all, DateTime from, DateTime to) {
    return all
        .where((tx) =>
            tx.type == 'income' &&
            !tx.date.isBefore(from) &&
            !tx.date.isAfter(to))
        .fold(0.0, (s, t) => s + t.amount);
  }

  static double _budgetSpent(
    BudgetModel budget,
    List<TransactionModel> all,
    DateTime now,
  ) {
    if (budget.period == 'weekly') {
      final weekStart = DateTime(
        now.year,
        now.month,
        now.day - (now.weekday - 1),
      );
      return all
          .where((tx) =>
              tx.type == 'expense' &&
              tx.categoryId == budget.categoryId &&
              !tx.date.isBefore(weekStart))
          .fold(0.0, (s, t) => s + t.amount);
    }
    return all
        .where((tx) =>
            tx.type == 'expense' &&
            tx.categoryId == budget.categoryId &&
            tx.date.year == now.year &&
            tx.date.month == now.month)
        .fold(0.0, (s, t) => s + t.amount);
  }
}

class _ScoredInsight {
  final int priority;
  final InsightItem item;
  const _ScoredInsight({required this.priority, required this.item});
}

class _CatData {
  final String name;
  final String icon;
  double amount = 0;
  _CatData(this.name, this.icon);
}
