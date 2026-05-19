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
    final previousSummary = _buildPreviousSummary(period);
    final categoryExpenses = _buildCategoryExpenses(filtered);
    final cashflow = _buildCashflow(filtered, period, from, to);
    final weekly = _buildWeeklySpending(all, period, from, to);
    final healthScore = _buildHealthScore(summary, all);
    final biggestTx = _buildBiggestTransaction(filtered);
    final dailyAverage = _buildDailyAverage(filtered, from, to);

    return AnalyticsData(
      summary: summary,
      previousSummary: previousSummary,
      categoryExpenses: categoryExpenses,
      cashflowPoints: cashflow,
      weeklySpending: weekly,
      healthScore: healthScore,
      insights: [],
      biggestTransaction: biggestTx,
      dailyAverage: dailyAverage,
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
    // Do NOT clamp — negative saving rate is valid and shown to user
    final savingRate = income <= 0 ? (saving < 0 ? -1.0 : 0.0) : saving / income;
    return AnalyticsSummary(
      totalIncome: income,
      totalExpense: expense,
      totalSaving: saving,
      savingRate: savingRate,
    );
  }

  static AnalyticsSummary _buildPreviousSummary(String period) {
    final now = DateTime.now();
    DateTime from, to;
    switch (period) {
      case AnalyticsPeriod.week:
        final thisWeekStart = DateTime(
            now.year, now.month, now.day - (now.weekday - 1));
        to = thisWeekStart.subtract(const Duration(seconds: 1));
        from = thisWeekStart.subtract(const Duration(days: 7));
        break;
      case AnalyticsPeriod.year:
        from = DateTime(now.year - 1, 1, 1);
        to = DateTime(now.year - 1, 12, 31, 23, 59, 59);
        break;
      default: // month
        from = DateTime(now.year, now.month - 1, 1);
        to = DateTime(now.year, now.month, 0, 23, 59, 59);
    }
    final all = HiveService.transactions.values.toList();
    final prevTxs = all
        .where((tx) => !tx.date.isBefore(from) && !tx.date.isAfter(to))
        .toList();
    return _buildSummary(prevTxs);
  }

  static List<CategoryExpense> _buildCategoryExpenses(
      List<TransactionModel> txs) {
    final expenses = txs.where((t) => t.type == 'expense');
    final categoryBox = HiveService.categories;
    final Map<String, _CatAccumulator> acc = {};

    for (final tx in expenses) {
      // Roll up subcategory to its parent category
      final cat = categoryBox.get(tx.categoryId);
      final String resolvedId;
      final String resolvedName;
      final String resolvedIcon;
      final String resolvedColor;

      if (cat != null && cat.parentId != null) {
        final parent = categoryBox.get(cat.parentId!);
        if (parent != null) {
          resolvedId = parent.id;
          resolvedName = parent.name;
          resolvedIcon = parent.icon;
          resolvedColor =
              parent.color.isNotEmpty ? parent.color : _realCategoryColor(parent.id);
        } else {
          resolvedId = tx.categoryId;
          resolvedName = tx.categoryName;
          resolvedIcon = tx.categoryIcon;
          resolvedColor = _realCategoryColor(tx.categoryId);
        }
      } else {
        resolvedId = tx.categoryId;
        resolvedName = tx.categoryName;
        resolvedIcon = tx.categoryIcon;
        resolvedColor = cat != null && cat.color.isNotEmpty
            ? cat.color
            : _realCategoryColor(tx.categoryId);
      }

      acc.putIfAbsent(
        resolvedId,
        () => _CatAccumulator(
          id: resolvedId,
          name: resolvedName,
          icon: resolvedIcon,
          color: resolvedColor,
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
    List<TransactionModel> all,
    String period,
    DateTime from,
    DateTime to,
  ) {
    if (period == AnalyticsPeriod.week) {
      final now = DateTime.now();
      final weekStart =
          DateTime(now.year, now.month, now.day - (now.weekday - 1));
      const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
      final amounts = List.filled(7, 0.0);
      for (final tx in all) {
        if (tx.type != 'expense') continue;
        final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
        final diff = day.difference(weekStart).inDays;
        if (diff >= 0 && diff < 7) amounts[diff] += tx.amount;
      }
      return List.generate(
          7, (i) => WeeklySpending(dayLabel: days[i], amount: amounts[i]));
    } else if (period == AnalyticsPeriod.year) {
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      final amounts = List.filled(12, 0.0);
      for (final tx in all) {
        if (tx.type != 'expense') continue;
        if (tx.date.year != from.year) continue;
        amounts[tx.date.month - 1] += tx.amount;
      }
      return List.generate(
          12, (i) => WeeklySpending(dayLabel: months[i], amount: amounts[i]));
    } else {
      // Month: group by 7-day chunks (M1=day1-7, M2=8-14, M3=15-21, M4=22-28, M5=29+)
      final now = DateTime.now();
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final weekCount = (daysInMonth / 7).ceil().clamp(4, 5);
      final labels = ['M1', 'M2', 'M3', 'M4', 'M5'];
      final amounts = List.filled(5, 0.0);
      for (final tx in all) {
        if (tx.type != 'expense') continue;
        if (tx.date.isBefore(from) || tx.date.isAfter(to)) continue;
        final weekIdx = ((tx.date.day - 1) ~/ 7).clamp(0, 4);
        amounts[weekIdx] += tx.amount;
      }
      return List.generate(
          weekCount, (i) => WeeklySpending(dayLabel: labels[i], amount: amounts[i]));
    }
  }

  static FinancialHealthScore _buildHealthScore(
    AnalyticsSummary summary,
    List<TransactionModel> all,
  ) {
    int score = 0;

    // Komponen 1: Saving Rate — 0-50 poin
    // Saving 40%+ = 50 poin, negatif = 0 poin
    final savingRate = summary.savingRate.clamp(-1.0, 1.0);
    if (savingRate > 0) {
      score += (savingRate.clamp(0.0, 0.4) / 0.4 * 50).toInt();
    }

    // Komponen 2: Keseimbangan pengeluaran vs pemasukan — 0-30 poin
    if (summary.totalIncome <= 0 && summary.totalExpense <= 0) {
      score += 15; // netral, belum ada data
    } else if (summary.totalIncome > 0) {
      final ratio = summary.totalExpense / summary.totalIncome;
      if (ratio < 0.5) {
        score += 30;
      } else if (ratio < 0.8) {
        score += 25;
      } else if (ratio < 1.0) {
        score += 15;
      } else if (ratio < 1.5) {
        score += 5;
      }
      // >= 1.5: 0 poin
    }

    // Komponen 3: Disiplin budget — 0-20 poin
    final budgets = HiveService.budgets.values.toList();
    if (budgets.isEmpty) {
      score += 10; // netral, tidak dihukum karena tidak pakai budget
    } else {
      final now = DateTime.now();
      int notExceeded = 0;
      for (final b in budgets) {
        if (_getBudgetSpent(b, all, now) <= b.limitAmount) notExceeded++;
      }
      score += (notExceeded / budgets.length * 20).toInt();
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

    final tips = _buildTips(summary, budgets, all, savingRate, score);

    return FinancialHealthScore(
      score: score,
      label: label,
      description: description,
      tips: tips,
    );
  }

  static List<String> _buildTips(
    AnalyticsSummary summary,
    List<BudgetModel> budgets,
    List<TransactionModel> all,
    double savingRate,
    int score,
  ) {
    final tips = <String>[];
    final savingPct = (savingRate * 100).round().abs();

    // ── Tip 1: Saving rate (prioritas tertinggi) ──────────────────
    if (savingRate < 0) {
      tips.add(
          'Pengeluaran bulan ini melebihi pemasukan — segera identifikasi dan kurangi pengeluaran yang tidak mendesak.');
    } else if (savingRate < 0.1) {
      tips.add(
          'Saving rate kamu baru $savingPct% — coba sisihkan minimal 10% di awal bulan sebelum dipakai belanja.');
    } else if (savingRate < 0.2) {
      tips.add(
          'Saving rate $savingPct% sudah oke, tapi target 20%+ lebih ideal untuk membangun dana darurat.');
    }

    // ── Tip 2: Rasio pengeluaran vs pemasukan ────────────────────
    if (tips.length < 2 && summary.totalIncome > 0) {
      final ratio = summary.totalExpense / summary.totalIncome;
      if (ratio >= 0.85 && savingRate >= 0) {
        final pct = (ratio * 100).round();
        tips.add(
            '$pct% penghasilanmu habis dibelanjakan — cek kategori terbesar dan lihat mana yang bisa dikurangi.');
      }
    }

    // ── Tip 3: Disiplin budget ────────────────────────────────────
    if (tips.length < 2) {
      if (budgets.isNotEmpty) {
        final now = DateTime.now();
        int exceeded = 0;
        for (final b in budgets) {
          if (_getBudgetSpent(b, all, now) > b.limitAmount) exceeded++;
        }
        if (exceeded > 0) {
          tips.add(
              '$exceeded dari ${budgets.length} budget sudah terlewat — review limit atau kurangi pengeluaran di kategori tersebut.');
        }
      } else if (summary.totalExpense > 0) {
        tips.add(
            'Belum pakai fitur budget? Buat budget untuk kategori terbesar agar pengeluaran lebih terkontrol.');
      }
    }

    // ── Fallback: skor bagus, beri apresiasi + tantangan ─────────
    if (tips.isEmpty) {
      if (savingRate >= 0.3) {
        tips.add(
            'Saving rate ${(savingRate * 100).round()}% sangat bagus! Pertimbangkan investasikan sebagian untuk tumbuh lebih cepat.');
      } else {
        tips.add(
            'Keuanganmu sehat! Pertahankan kebiasaan ini dan coba tingkatkan saving rate ke 20%+.');
      }
    }

    return tips;
  }

  static BiggestTx? _buildBiggestTransaction(List<TransactionModel> filtered) {
    final expenses =
        filtered.where((tx) => tx.type == 'expense').toList();
    if (expenses.isEmpty) return null;
    expenses.sort((a, b) => b.amount.compareTo(a.amount));
    final tx = expenses.first;
    return BiggestTx(
      emoji: tx.categoryIcon,
      title: tx.title,
      categoryName: tx.categoryName,
      amount: tx.amount,
      date: tx.date,
    );
  }

  static double _buildDailyAverage(
    List<TransactionModel> filtered,
    DateTime from,
    DateTime to,
  ) {
    final expense = filtered
        .where((t) => t.type == 'expense')
        .fold(0.0, (s, t) => s + t.amount);
    final days = to.difference(from).inDays + 1;
    return days > 0 ? expense / days : 0;
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

  // Look up real category color from Hive, fall back to hash-based color
  static String _realCategoryColor(String categoryId) {
    final cat = HiveService.categories.get(categoryId);
    if (cat != null && cat.color.isNotEmpty) return cat.color;
    final idx = categoryId.hashCode.abs() % _chartColors.length;
    return _chartColors[idx];
  }

  static const _chartColors = [
    '#3B82F6',
    '#10B981',
    '#F59E0B',
    '#EF4444',
    '#8B5CF6',
    '#EC4899',
    '#06B6D4',
  ];
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
