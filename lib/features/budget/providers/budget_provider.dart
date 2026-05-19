import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/hive/hive_service.dart';
import '../../../core/hive/models/budget_model.dart';
import '../../transaction/providers/transaction_provider.dart';

final budgetProvider =
    StateNotifierProvider<BudgetNotifier, List<BudgetModel>>((ref) {
  return BudgetNotifier(ref);
});

class BudgetNotifier extends StateNotifier<List<BudgetModel>> {
  BudgetNotifier(this._ref) : super([]) {
    _load();
  }

  final Ref _ref;

  void _load() {
    state = HiveService.budgets.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _spentCache.clear(); // ← reset cache setiap state berubah
  }

  Future<void> add({
    required String categoryId,
    required String categoryName,
    required String categoryIcon,
    required String categoryColor,
    required double limitAmount,
    required String period,
  }) async {
    final budget = BudgetModel(
      id: const Uuid().v4(),
      categoryId: categoryId,
      categoryName: categoryName,
      categoryIcon: categoryIcon,
      categoryColor: categoryColor,
      limitAmount: limitAmount,
      period: period,
      startDate: DateTime.now(),
      createdAt: DateTime.now(),
    );
    await HiveService.budgets.put(budget.id, budget);
    _load();
  }

  Future<void> update({
    required String id,
    required double limitAmount,
    required String period,
  }) async {
    final existing = HiveService.budgets.get(id);
    if (existing == null) return;

    final updated = BudgetModel(
      id: id,
      categoryId: existing.categoryId,
      categoryName: existing.categoryName,
      categoryIcon: existing.categoryIcon,
      categoryColor: existing.categoryColor,
      limitAmount: limitAmount,
      period: period,
      startDate: existing.startDate,
      createdAt: existing.createdAt,
    );
    await HiveService.budgets.put(id, updated);
    _load();
  }

  Future<void> delete(String id) async {
    await HiveService.budgets.delete(id);
    _load();
  }

  void refresh() {
    _spentCache.clear();
    state = [...state];
  }

  // ── Computed data ─────────────────────────────────────────────
  // Cache spent per budget ID, di-reset saat transaksi berubah
  final Map<String, double> _spentCache = {};

  void invalidateCache() => _spentCache.clear();

  // Pengeluaran per kategori bulan/minggu ini
  double getSpent(BudgetModel budget) {
    if (_spentCache.containsKey(budget.id)) {
      return _spentCache[budget.id]!;
    }
    final allTx = _ref.read(transactionProvider);

    // Ambil semua subkategori dari kategori ini
    // supaya transaksi yang pakai subkategori ikut terhitung
    final categoryBox = HiveService.categories;
    final relatedIds = <String>{budget.categoryId};

    for (final cat in categoryBox.values) {
      // Kalau parentId sama dengan categoryId budget → ini subkategori nya
      if (cat.parentId == budget.categoryId) {
        relatedIds.add(cat.id);
      }
      // Kalau categoryId budget sendiri adalah subkategori,
      // hanya hitung exact match
    }

    if (budget.period == 'weekly') {
      final now = DateTime.now();
      final start = now.subtract(Duration(days: now.weekday - 1));
      final weekStart = DateTime(start.year, start.month, start.day);

      final result = allTx
          .where((tx) =>
              tx.type == 'expense' &&
              relatedIds.contains(tx.categoryId) &&
              tx.date.isAfter(
                weekStart.subtract(const Duration(seconds: 1)),
              ))
          .fold(0.0, (s, tx) => s + tx.amount);

      _spentCache[budget.id] = result; // ← simpan ke cache
      return result;
    }

    // Monthly
    final now = DateTime.now();
    final result = allTx
        .where((tx) =>
            tx.type == 'expense' &&
            relatedIds.contains(tx.categoryId) &&
            tx.date.year == now.year &&
            tx.date.month == now.month)
        .fold(0.0, (s, tx) => s + tx.amount);

    _spentCache[budget.id] = result; // ← simpan ke cache
    return result;
  }

  // Persentase penggunaan budget (0.0 - 1.0+)
  double getPercentage(BudgetModel budget) {
    final spent = getSpent(budget);
    if (budget.limitAmount <= 0) return 0;
    return spent / budget.limitAmount;
  }

  // Status budget
  BudgetStatus getStatus(BudgetModel budget) {
    final pct = getPercentage(budget);
    if (pct >= 1.0) return BudgetStatus.overBudget;
    if (pct >= 0.9) return BudgetStatus.spendingFast;
    if (pct >= 0.7) return BudgetStatus.slightlyFast;
    return BudgetStatus.safe;
  }

  // Total limit semua budget
  double get totalLimit => state.fold(0, (s, b) => s + b.limitAmount);

  // Total spent semua budget
  double get totalSpent => state.fold(0.0, (s, b) => s + getSpent(b));

  // Overall percentage
  double get overallPercentage {
    if (totalLimit <= 0) return 0;
    return totalSpent / totalLimit;
  }

  // Persentase waktu bulan berjalan (0.0 - 1.0)
  double get timePercentage {
    try {
      final now = DateTime.now();
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      if (daysInMonth <= 0) return 0;
      return (now.day / daysInMonth).clamp(0.0, 1.0);
    } catch (_) {
      return 0;
    }
  }

  // Status kesehatan anggaran keseluruhan
  BudgetHealth get overallHealth {
    final pct = overallPercentage;
    final time = timePercentage;
    if (pct > time + 0.1) return BudgetHealth.boros;
    if (pct > time - 0.05) return BudgetHealth.waspada;
    return BudgetHealth.aman;
  }
}

enum BudgetStatus { overBudget, spendingFast, slightlyFast, safe }

enum BudgetHealth { aman, waspada, boros }
