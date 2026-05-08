import '../../../core/hive/hive_service.dart';
import '../../../core/hive/models/transaction_model.dart';
import '../../../core/hive/models/budget_model.dart';
import '../models/analytics_data.dart';

class AnalyticsService {
  static AnalyticsData compute(String period) {
    final all = HiveService.transactions.values.toList();
    final range = _dateRange(period);
    final from = range.$1;
    final to = range.$2;

    final filtered = all.where((tx) {
      return !tx.date.isBefore(from) && !tx.date.isAfter(to);
    }).toList();

    final summary = _buildSummary(filtered);
    final categoryExpenses = _buildCategoryExpenses(filtered);
    final cashflow = _buildCashflow(filtered, period, from, to);
    final weekly = _buildWeeklySpending(all);
    final healthScore = _buildHealthScore(summary, all);

    return AnalyticsData(
      summary: summary,
      categoryExpenses: categoryExpenses,
      cashflowPoints: cashflow,
      weeklySpending: weekly,
      healthScore: healthScore,
      insights: [], // filled by InsightGenerator
    );
  }

  static (DateTime, DateTime) _dateRange(String period) {
    final now = DateTime.now();
    switch (period) {
      case AnalyticsPeriod.week:
        final weekday = now.weekday;
        final start =
            DateTime(now.year, now.month, now.day - (weekday - 1));
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return (start, end);
      case AnalyticsPeriod.year:
        return (
          DateTime(now.year, 1, 1),
          DateTime(now.year, 12, 31, 23, 59, 59),
        );
      default: // month
        return (
          DateTime(now.year, now.month, 1),
          DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        );
    }
  }

  static AnalyticsSummary _buildSummary(List<TransactionModel> txs) {
    final income =
        txs.where((t) => t.type == 'income').fold(0.0, (s, t) => s + t.amount);
    final expense = txs
        .where((t) => t.type == 'expense')
        .fold(0.0, (s, t) => s + t.amount);
    final saving = income - expense;
    final savingRate = income <= 0 ? 0.0 : (saving / income).clamp(0.0, 1.0);
    return AnalyticsSummary(
      totalIncome: income,
      totalExpense: expense,
      totalSaving: saving,
      savingRate: savingRate,
    );
  }

  static List<CategoryExpense> _buildCategoryExpenses(
      List<TransactionModel> txs) {
    final expenses = txs.where((t) => t.type == 'expense');
    final Map<String, _CatAccumulator> acc = {};

    for (final tx in expenses) {
      final id = tx.categoryId;
      acc.putIfAbsent(
        id,
        () => _CatAccumulator(
          id: id,
          name: tx.categoryName,
          icon: tx.categoryIcon,
          color: _categoryColor(id),
        ),
      ).amount += tx.amount;
    }

    if (acc.isEmpty) return [];

    final sorted = acc.values.toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    final total = sorted.fold(0.0, (s, c) => s + c.amount);

    const maxCategories = 5;
    final topCats = sorted.take(maxCategories).toList();
    final rest = sorted.skip(maxCategories).toList();

    final result = topCats
        .map((c) => CategoryExpense(
              categoryId: c.id,
              categoryName: c.name,
              categoryIcon: c.icon,
              categoryColor: c.color,
              amount: c.amount,
              percentage: total > 0 ? c.amount / total : 0,
            ))
        .toList();

    if (rest.isNotEmpty) {
      final restAmount = rest.fold(0.0, (s, c) => s + c.amount);
      result.add(CategoryExpense(
        categoryId: 'others',
        categoryName: 'Lainnya',
        categoryIcon: '📦',
        categoryColor: '#94A3B8',
        amount: restAmount,
        percentage: total > 0 ? restAmount / total : 0,
      ));
    }

    return result;
  }

  static List<CashflowPoint> _buildCashflow(
    List<TransactionModel> txs,
    String period,
    DateTime from,
    DateTime to,
  ) {
    if (period == AnalyticsPeriod.week) {
      return _cashflowByDay(txs, from, to, 'EEE');
    } else if (period == AnalyticsPeriod.year) {
      return _cashflowByMonth(txs, from, to);
    } else {
      return _cashflowByDay(txs, from, to, 'd');
    }
  }

  static List<CashflowPoint> _cashflowByDay(
    List<TransactionModel> txs,
    DateTime from,
    DateTime to,
    String fmt,
  ) {
    final Map<DateTime, _FlowAccumulator> acc = {};
    var cursor = from;
    while (!cursor.isAfter(to)) {
      final day = DateTime(cursor.year, cursor.month, cursor.day);
      acc[day] = _FlowAccumulator();
      cursor = cursor.add(const Duration(days: 1));
    }

    for (final tx in txs) {
      final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
      if (acc.containsKey(day)) {
        if (tx.type == 'income') acc[day]!.income += tx.amount;
        if (tx.type == 'expense') acc[day]!.expense += tx.amount;
      }
    }

    return acc.entries
        .map((e) => CashflowPoint(
              date: e.key,
              income: e.value.income,
              expense: e.value.expense,
            ))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  static List<CashflowPoint> _cashflowByMonth(
    List<TransactionModel> txs,
    DateTime from,
    DateTime to,
  ) {
    final Map<int, _FlowAccumulator> acc = {};
    for (var m = 1; m <= 12; m++) {
      acc[m] = _FlowAccumulator();
    }

    for (final tx in txs) {
      if (tx.type == 'income') acc[tx.date.month]!.income += tx.amount;
      if (tx.type == 'expense') acc[tx.date.month]!.expense += tx.amount;
    }

    return acc.entries
        .map((e) => CashflowPoint(
              date: DateTime(from.year, e.key, 1),
              income: e.value.income,
              expense: e.value.expense,
            ))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  static List<WeeklySpending> _buildWeeklySpending(
      List<TransactionModel> all) {
    final now = DateTime.now();
    final weekStart =
        DateTime(now.year, now.month, now.day - (now.weekday - 1));

    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    final amounts = List.filled(7, 0.0);

    for (final tx in all) {
      if (tx.type != 'expense') continue;
      final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
      final diff = day.difference(weekStart).inDays;
      if (diff >= 0 && diff < 7) {
        amounts[diff] += tx.amount;
      }
    }

    return List.generate(
      7,
      (i) => WeeklySpending(dayLabel: days[i], amount: amounts[i]),
    );
  }

  static FinancialHealthScore _buildHealthScore(
    AnalyticsSummary summary,
    List<TransactionModel> all,
  ) {
    int score = 50;

    // Saving ratio: 0-40 pts
    final savingRatio = summary.savingRate;
    score += (savingRatio * 40).toInt();

    // Budget adherence: 0-30 pts
    final budgets = HiveService.budgets.values.toList();
    if (budgets.isNotEmpty) {
      double totalLimit = 0, totalSpent = 0;
      final now = DateTime.now();
      for (final b in budgets) {
        totalLimit += b.limitAmount;
        totalSpent += _getBudgetSpent(b, all, now);
      }
      if (totalLimit > 0) {
        final ratio = (totalSpent / totalLimit).clamp(0.0, 2.0);
        score += (30 * (1 - (ratio / 2))).toInt();
      }
    }

    // Expense ratio penalty: -20 pts if expense > income
    if (summary.totalIncome > 0 &&
        summary.totalExpense > summary.totalIncome) {
      score -= 20;
    }

    score = score.clamp(0, 100);

    String label;
    String description;
    if (score >= 70) {
      label = 'Aman';
      description = 'Keuanganmu dalam kondisi sehat';
    } else if (score >= 40) {
      label = 'Waspada';
      description = 'Perlu perhatian lebih pada pengeluaran';
    } else {
      label = 'Boros';
      description = 'Pengeluaran melebihi batas sehat';
    }

    return FinancialHealthScore(
      score: score,
      label: label,
      description: description,
    );
  }

  static double _getBudgetSpent(
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

  static final _chartColors = [
    '#3B82F6', // blue
    '#10B981', // green
    '#F59E0B', // amber
    '#EF4444', // red
    '#8B5CF6', // purple
    '#EC4899', // pink
    '#06B6D4', // cyan
  ];

  static String _categoryColor(String categoryId) {
    final idx = categoryId.hashCode.abs() % _chartColors.length;
    return _chartColors[idx];
  }
}

class _CatAccumulator {
  final String id;
  final String name;
  final String icon;
  final String color;
  double amount = 0;

  _CatAccumulator({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}

class _FlowAccumulator {
  double income = 0;
  double expense = 0;
}
