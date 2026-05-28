import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/hive/hive_service.dart';
import '../../../core/hive/models/financial_plan_model.dart';

final financialPlanProvider =
    StateNotifierProvider<FinancialPlanNotifier, List<FinancialPlanModel>>(
        (ref) => FinancialPlanNotifier());

class FinancialPlanNotifier extends StateNotifier<List<FinancialPlanModel>> {
  FinancialPlanNotifier() : super([]) {
    _load();
  }

  void _load() {
    state = HiveService.financialPlans.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> add({
    required String name,
    required String icon,
    required String color,
    required double targetAmount,
    double savedAmount = 0,
    DateTime? deadline,
  }) async {
    final plan = FinancialPlanModel(
      id: const Uuid().v4(),
      name: name,
      icon: icon,
      color: color,
      targetAmount: targetAmount,
      savedAmount: savedAmount,
      deadline: deadline,
      contributions: [],
      createdAt: DateTime.now(),
    );
    await HiveService.financialPlans.put(plan.id, plan);
    _load();
  }

  Future<void> update({
    required String id,
    required String name,
    required String icon,
    required String color,
    required double targetAmount,
    DateTime? deadline,
  }) async {
    final existing = HiveService.financialPlans.get(id);
    if (existing == null) return;

    final updated = FinancialPlanModel(
      id: id,
      name: name,
      icon: icon,
      color: color,
      targetAmount: targetAmount,
      savedAmount: existing.savedAmount,
      deadline: deadline,
      contributions: existing.contributions,
      createdAt: existing.createdAt,
    );
    await HiveService.financialPlans.put(id, updated);
    _load();
  }

  Future<void> addContribution({
    required String planId,
    required double amount,
  }) async {
    final existing = HiveService.financialPlans.get(planId);
    if (existing == null) return;

    final contribution = ContributionModel(
      id: const Uuid().v4(),
      amount: amount,
      date: DateTime.now(),
    );

    final updated = FinancialPlanModel(
      id: existing.id,
      name: existing.name,
      icon: existing.icon,
      color: existing.color,
      targetAmount: existing.targetAmount,
      savedAmount: existing.savedAmount + amount,
      deadline: existing.deadline,
      contributions: [...existing.contributions, contribution],
      createdAt: existing.createdAt,
    );
    await HiveService.financialPlans.put(planId, updated);
    _load();
  }

  Future<void> delete(String id) async {
    await HiveService.financialPlans.delete(id);
    _load();
  }

  // ── Computed ──────────────────────────────────────────────────

  double get totalTarget => state.fold(0.0, (s, p) => s + p.targetAmount);

  double get totalSaved => state.fold(0.0, (s, p) => s + p.savedAmount);

  double get overallPercentage {
    if (totalTarget <= 0) return 0;
    return (totalSaved / totalTarget).clamp(0.0, 1.0);
  }

  int get completedCount =>
      state.where((p) => p.savedAmount >= p.targetAmount).length;

  double getPercentage(FinancialPlanModel plan) {
    if (plan.targetAmount <= 0) return 0;
    return (plan.savedAmount / plan.targetAmount).clamp(0.0, 1.0);
  }

  int? getDaysLeft(FinancialPlanModel plan) {
    if (plan.deadline == null) return null;
    final diff = plan.deadline!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  String? getRelativeTime(FinancialPlanModel plan) {
    if (plan.deadline == null) return null;
    final now = DateTime.now();
    final deadline = plan.deadline!;
    if (deadline.isBefore(now)) return 'Deadline terlewat';
    final days = deadline.difference(now).inDays;
    if (days == 0) return 'Deadline hari ini!';
    if (days <= 6) return '$days hari lagi';
    if (days < 30) return '${(days / 7).round()} minggu lagi';
    if (days < 365) return '${(days / 30).round()} bulan lagi';
    return '${(days / 365).round()} tahun lagi';
  }

  double? getMonthlyRecommendation(FinancialPlanModel plan) {
    if (plan.deadline == null) return null;
    final remaining = plan.targetAmount - plan.savedAmount;
    if (remaining <= 0) return null;
    final now = DateTime.now();
    if (plan.deadline!.isBefore(now)) return null;
    final monthsLeft = plan.deadline!.difference(now).inDays / 30.0;
    if (monthsLeft < 0.5) return null;
    return remaining / monthsLeft;
  }

  String? getEstimatedCompletion(FinancialPlanModel plan) {
    if (plan.contributions.isEmpty) return null;
    final remaining = plan.targetAmount - plan.savedAmount;
    if (remaining <= 0) return null;
    final total = plan.contributions.fold(0.0, (s, c) => s + c.amount);
    if (total <= 0) return null;
    final sorted = [...plan.contributions]
      ..sort((a, b) => a.date.compareTo(b.date));
    final spanDays =
        sorted.last.date.difference(sorted.first.date).inDays;
    final monthlyRate =
        spanDays < 15 ? total : total / (spanDays / 30.0);
    if (monthlyRate <= 0) return null;
    final monthsNeeded = (remaining / monthlyRate).ceil();
    if (monthsNeeded <= 0) return null;
    if (monthsNeeded < 12) return '~$monthsNeeded bulan lagi';
    return '~${(monthsNeeded / 12).round()} tahun lagi';
  }
}
