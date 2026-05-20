import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/analytics_data.dart';
import '../services/analytics_service.dart';
import '../services/insight_generator.dart';
import '../../transaction/providers/transaction_provider.dart';
import '../../budget/providers/budget_provider.dart';
import '../../../shared/providers/plan_limits_provider.dart';

final analyticsPeriodProvider =
    StateProvider<String>((ref) => AnalyticsPeriod.month);

final analyticsDataProvider = Provider<AnalyticsData>((ref) {
  final period = ref.watch(analyticsPeriodProvider);
  ref.watch(transactionProvider);
  ref.watch(budgetProvider);
  final limits = ref.watch(planLimitsProvider);
  final data = AnalyticsService.compute(period);
  final allInsights = InsightGenerator.generate();
  final insights = allInsights.take(limits.maxInsights).toList();
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
  final limits = ref.watch(planLimitsProvider);
  final all = InsightGenerator.generate();
  return all.take(limits.maxInsights).toList();
});
