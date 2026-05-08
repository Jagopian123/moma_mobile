class AnalyticsPeriod {
  static const String week = 'week';
  static const String month = 'month';
  static const String year = 'year';
}

class AnalyticsSummary {
  final double totalIncome;
  final double totalExpense;
  final double totalSaving;
  final double savingRate;

  const AnalyticsSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.totalSaving,
    required this.savingRate,
  });
}

class CategoryExpense {
  final String categoryId;
  final String categoryName;
  final String categoryIcon;
  final String categoryColor;
  final double amount;
  final double percentage;

  const CategoryExpense({
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
    required this.amount,
    required this.percentage,
  });
}

class CashflowPoint {
  final DateTime date;
  final double income;
  final double expense;

  const CashflowPoint({
    required this.date,
    required this.income,
    required this.expense,
  });
}

class WeeklySpending {
  final String dayLabel; // Sen, Sel, Rab, ...
  final double amount;

  const WeeklySpending({required this.dayLabel, required this.amount});
}

class FinancialHealthScore {
  final int score; // 0-100
  final String label; // Aman, Waspada, Boros
  final String description;

  const FinancialHealthScore({
    required this.score,
    required this.label,
    required this.description,
  });
}

class InsightItem {
  final String emoji;
  final String title;
  final String body;
  final InsightType type;

  const InsightItem({
    required this.emoji,
    required this.title,
    required this.body,
    required this.type,
  });
}

enum InsightType { positive, warning, neutral, danger }

class AnalyticsData {
  final AnalyticsSummary summary;
  final List<CategoryExpense> categoryExpenses;
  final List<CashflowPoint> cashflowPoints;
  final List<WeeklySpending> weeklySpending;
  final FinancialHealthScore healthScore;
  final List<InsightItem> insights;

  const AnalyticsData({
    required this.summary,
    required this.categoryExpenses,
    required this.cashflowPoints,
    required this.weeklySpending,
    required this.healthScore,
    required this.insights,
  });
}
