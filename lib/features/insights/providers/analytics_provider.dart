import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/analytics_data.dart';
import '../services/analytics_service.dart';
import '../services/insight_generator.dart';
import '../../transaction/providers/transaction_provider.dart';
import '../../budget/providers/budget_provider.dart';

final analyticsPeriodProvider =
    StateProvider<String>((ref) => AnalyticsPeriod.month);

final analyticsDataProvider = Provider<AnalyticsData>((ref) {
  final period = ref.watch(analyticsPeriodProvider);
  ref.watch(transactionProvider);
  ref.watch(budgetProvider);
  final data = AnalyticsService.compute(period);
  final insights = InsightGenerator.generate();
  return AnalyticsData(
    summary: data.summary,
    previousSummary: data.previousSummary,
    categoryExpenses: data.categoryExpenses,
    cashflowPoints: data.cashflowPoints,
    weeklySpending: data.weeklySpending,
    healthScore: data.healthScore,
    insights: insights,
    biggestTransaction: data.biggestTransaction,
    dailyAverage: data.dailyAverage,
  );
});

final homeInsightsProvider = Provider<List<InsightItem>>((ref) {
  ref.watch(transactionProvider);
  return InsightGenerator.generate();
});
