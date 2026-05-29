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

    // Batasi 3 bulan terakhir untuk performa
    final threeMonthsAgo = DateTime(now.year, now.month - 3, 1);
    final recent = all.where((tx) => !tx.date.isBefore(threeMonthsAgo)).toList();

    final insights = <_ScoredInsight>[];

    insights.addAll(_checkBudgetAlerts(budgets, recent, now));
    insights.addAll(_checkSavingHealth(recent, now));
    insights.addAll(_checkUnusualSpike(recent, now));
    insights.addAll(_checkSpendingTrend(recent, now));
    insights.addAll(_checkStreak(recent, now));
    insights.addAll(_checkProjection(recent, now));
    insights.addAll(_checkCategoryTrend(recent, now));
    insights.addAll(_checkCashflow(recent, now));
    insights.addAll(_checkTopCategory(recent, now));
    insights.addAll(_checkWeekendEffect(recent, now));
    insights.addAll(_checkBusiestDay(recent, now));
    insights.addAll(_checkMonthRecap(all, now));

    insights.sort((a, b) => b.priority.compareTo(a.priority));

    return insights.map((s) => s.item).toList();
  }

  // ── Budget Alerts (prioritas tertinggi) ──────────────────────────────────────

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
            body: 'Pengeluaran udah melewati batas ${_fmt(budget.limitAmount)}. '
                'Saatnya rem pengeluaran bulan ini!',
            type: InsightType.danger,
            mascotAsset: 'assets/images/mascot-insight-sad.png',
          ),
        ));
      } else if (pct >= 0.85) {
        final sisa = _fmt(budget.limitAmount - spent);
        results.add(_ScoredInsight(
          priority: 80,
          item: InsightItem(
            emoji: '⚠️',
            title: 'Budget ${budget.categoryName} hampir habis',
            body: 'Udah terpakai ${(pct * 100).toStringAsFixed(0)}% dari '
                '${_fmt(budget.limitAmount)}, sisa $sisa lagi. Hati-hati ya!',
            type: InsightType.warning,
            mascotAsset: 'assets/images/mascot-insight-worried.png',
          ),
        ));
      }
    }

    return results;
  }

  // ── Pengeluaran melebihi pemasukan ───────────────────────────────────────────

  static List<_ScoredInsight> _checkSavingHealth(
    List<TransactionModel> all,
    DateTime now,
  ) {
    final monthStart = DateTime(now.year, now.month, 1);
    final income = _sumIncome(all, monthStart, now);
    final expense = _sumExpense(all, monthStart, now);

    if (income <= 0) return [];

    final savingRate = (income - expense) / income;

    if (savingRate < 0) {
      return [
        const _ScoredInsight(
          priority: 90,
          item: InsightItem(
            emoji: '😟',
            title: 'Pengeluaran melebihi pemasukan',
            body: 'Bulan ini lebih banyak keluar daripada masuk. '
                'Yuk cek mana yang bisa dikurangi!',
            type: InsightType.danger,
            mascotAsset: 'assets/images/mascot-insight-sad.png',
          ),
        ),
      ];
    }

    if (savingRate >= 0.2) {
      return [
        _ScoredInsight(
          priority: 35,
          item: InsightItem(
            emoji: '💰',
            title: 'Saving rate bulan ini bagus!',
            body: 'Kamu berhasil sisihkan ${(savingRate * 100).toStringAsFixed(0)}%'
                ' dari pemasukan. Terus pertahankan ya!',
            type: InsightType.positive,
            mascotAsset: 'assets/images/mascot-insight-happy.png',
          ),
        ),
      ];
    }

    return [];
  }

  // ── Lonjakan pengeluaran hari ini ────────────────────────────────────────────

  static List<_ScoredInsight> _checkUnusualSpike(
    List<TransactionModel> all,
    DateTime now,
  ) {
    final todayStart = DateTime(now.year, now.month, now.day);
    final thirtyDaysAgo = todayStart.subtract(const Duration(days: 30));

    final todayExp = _sumExpense(all, todayStart, now);
    if (todayExp <= 0) return [];

    // Rata-rata harian 30 hari terakhir (tidak termasuk hari ini)
    final pastExp = _sumExpense(all, thirtyDaysAgo,
        todayStart.subtract(const Duration(seconds: 1)));
    if (pastExp <= 0) return [];

    final dailyAvg = pastExp / 30;
    if (dailyAvg <= 0) return [];

    final ratio = todayExp / dailyAvg;

    if (ratio >= 2.5 && todayExp >= 50000) {
      return [
        _ScoredInsight(
          priority: 75,
          item: InsightItem(
            emoji: '👀',
            title: 'Pengeluaran hari ini melonjak',
            body: 'Hari ini keluar ${_fmt(todayExp)}, sekitar '
                '${ratio.toStringAsFixed(1)}x dari rata-rata harianmu. '
                'Ada pengeluaran tak terduga?',
            type: InsightType.warning,
            mascotAsset: 'assets/images/mascot-insight-shocked.png',
          ),
        ),
      ];
    }

    return [];
  }

  // ── Tren pengeluaran minggu ini vs minggu lalu ───────────────────────────────

  static List<_ScoredInsight> _checkSpendingTrend(
    List<TransactionModel> all,
    DateTime now,
  ) {
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
            title: 'Lebih boros ${pct.toStringAsFixed(0)}% minggu ini',
            body: 'Pengeluaran minggu ini lebih tinggi dari minggu lalu. '
                'Ada yang bisa dikurangi?',
            type: InsightType.warning,
            mascotAsset: 'assets/images/mascot-insight-worried.png',
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
            title: 'Lebih hemat ${pct.toStringAsFixed(0)}% minggu ini!',
            body: 'Pengeluaran turun dibanding minggu lalu. Pertahankan terus!',
            type: InsightType.positive,
            mascotAsset: 'assets/images/mascot-insight-happy.png',
          ),
        ),
      ];
    }

    return [];
  }

  // ── Streak hemat (2+ minggu berturut-turut) ──────────────────────────────────

  static List<_ScoredInsight> _checkStreak(
    List<TransactionModel> all,
    DateTime now,
  ) {
    final weekStart =
        DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final w1Start = weekStart.subtract(const Duration(days: 7));
    final w1End = weekStart.subtract(const Duration(seconds: 1));
    final w2Start = weekStart.subtract(const Duration(days: 14));
    final w2End = w1Start.subtract(const Duration(seconds: 1));

    final thisWeek = _sumExpense(all, weekStart, now);
    final lastWeek = _sumExpense(all, w1Start, w1End);
    final weekBefore = _sumExpense(all, w2Start, w2End);

    if (lastWeek <= 0 || weekBefore <= 0) return [];

    // Normalisasi: this week by days elapsed
    final daysThisWeek = now.weekday;
    final thisWeekNorm = daysThisWeek > 0 ? thisWeek / daysThisWeek : 0.0;
    final lastWeekNorm = lastWeek / 7;
    final weekBeforeNorm = weekBefore / 7;

    if (thisWeekNorm < lastWeekNorm && lastWeekNorm < weekBeforeNorm) {
      return [
        const _ScoredInsight(
          priority: 55,
          item: InsightItem(
            emoji: '🔥',
            title: '2 minggu berturut-turut makin hemat!',
            body: 'Pengeluaran terus turun 2 minggu ini. '
                'Kamu lagi on track banget, keep it up!',
            type: InsightType.positive,
            mascotAsset: 'assets/images/mascot-insight-celebrate.png',
          ),
        ),
      ];
    }

    return [];
  }

  // ── Proyeksi akhir bulan ─────────────────────────────────────────────────────

  static List<_ScoredInsight> _checkProjection(
    List<TransactionModel> all,
    DateTime now,
  ) {
    if (now.day < 5) return []; // Terlalu awal, data belum representatif

    final monthStart = DateTime(now.year, now.month, 1);
    final income = _sumIncome(all, monthStart, now);
    final expense = _sumExpense(all, monthStart, now);

    if (expense <= 0) return [];

    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final dailyAvg = expense / now.day;
    final projectedExpense = dailyAvg * daysInMonth;

    if (income > 0) {
      final projectedSaving = income - projectedExpense;

      if (projectedSaving > 0) {
        return [
          _ScoredInsight(
            priority: 30,
            item: InsightItem(
              emoji: '🎯',
              title: 'Proyeksi bulan ini: bisa hemat!',
              body: 'Kalau pola ini lanjut, kamu akan menyisihkan sekitar '
                  '${_fmt(projectedSaving)} sampai akhir bulan. Bagus!',
              type: InsightType.positive,
              mascotAsset: 'assets/images/mascot-insight-excited.png',
            ),
          ),
        ];
      } else {
        final overAmount = projectedExpense - income;
        return [
          _ScoredInsight(
            priority: 65,
            item: InsightItem(
              emoji: '📊',
              title: 'Proyeksi bulan ini: mungkin over',
              body: 'Dengan pola saat ini, bisa kehabisan ${_fmt(overAmount)} '
                  'sebelum akhir bulan. Perlu dikontrol!',
              type: InsightType.warning,
              mascotAsset: 'assets/images/mascot-insight-worried.png',
            ),
          ),
        ];
      }
    }

    return [];
  }

  // ── Kategori yang terus naik 2-3 bulan ──────────────────────────────────────

  static List<_ScoredInsight> _checkCategoryTrend(
    List<TransactionModel> all,
    DateTime now,
  ) {
    final m0Start = DateTime(now.year, now.month, 1);
    final m1Start = DateTime(now.year, now.month - 1, 1);
    final m1End = m0Start.subtract(const Duration(seconds: 1));
    final m2Start = DateTime(now.year, now.month - 2, 1);
    final m2End = m1Start.subtract(const Duration(seconds: 1));

    final Map<String, _CatData> m0 = {};
    final Map<String, _CatData> m1 = {};
    final Map<String, _CatData> m2 = {};

    void accumulate(
        TransactionModel tx, DateTime from, DateTime to, Map<String, _CatData> map) {
      if (tx.type != 'expense') return;
      if (tx.date.isBefore(from) || tx.date.isAfter(to)) return;
      map
          .putIfAbsent(tx.categoryId, () => _CatData(tx.categoryName, tx.categoryIcon))
          .amount += tx.amount;
    }

    for (final tx in all) {
      accumulate(tx, m0Start, now, m0);
      accumulate(tx, m1Start, m1End, m1);
      accumulate(tx, m2Start, m2End, m2);
    }

    for (final id in m0.keys) {
      final a0 = m0[id]?.amount ?? 0;
      final a1 = m1[id]?.amount ?? 0;
      final a2 = m2[id]?.amount ?? 0;

      if (a2 > 0 && a1 > a2 && a0 > a1) {
        final totalGrowth = ((a0 - a2) / a2 * 100).toStringAsFixed(0);
        final name = m0[id]!.name;
        return [
          _ScoredInsight(
            priority: 60,
            item: InsightItem(
              emoji: '🤔',
              title: '$name terus naik 3 bulan',
              body: 'Pengeluaran $name naik $totalGrowth% dari 2 bulan lalu. '
                  'Mungkin sudah waktunya dievaluasi?',
              type: InsightType.warning,
              mascotAsset: 'assets/images/mascot-insight-info.png',
            ),
          ),
        ];
      }
    }

    return [];
  }

  // ── Lebih hemat dari bulan lalu ──────────────────────────────────────────────

  static List<_ScoredInsight> _checkCashflow(
    List<TransactionModel> all,
    DateTime now,
  ) {
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
            title: 'Lebih hemat dari bulan lalu!',
            body: 'Pengeluaran bulan ini turun ${pct.toStringAsFixed(0)}% '
                'dibanding bulan lalu. Progres yang bagus!',
            type: InsightType.positive,
            mascotAsset: 'assets/images/mascot-insight-happy.png',
          ),
        ),
      ];
    }

    return [];
  }

  // ── Kategori pengeluaran terbesar bulan ini ──────────────────────────────────

  static List<_ScoredInsight> _checkTopCategory(
    List<TransactionModel> all,
    DateTime now,
  ) {
    final monthStart = DateTime(now.year, now.month, 1);
    final monthExp =
        all.where((tx) => tx.type == 'expense' && !tx.date.isBefore(monthStart));

    if (monthExp.isEmpty) return [];

    final Map<String, _CatData> acc = {};
    for (final tx in monthExp) {
      acc
          .putIfAbsent(tx.categoryId, () => _CatData(tx.categoryName, tx.categoryIcon))
          .amount += tx.amount;
    }

    final totalExp = acc.values.fold(0.0, (s, c) => s + c.amount);
    final top = acc.values.reduce((a, b) => a.amount >= b.amount ? a : b);
    final pct = totalExp > 0 ? (top.amount / totalExp * 100).toStringAsFixed(0) : '0';

    return [
      _ScoredInsight(
        priority: 25,
        item: InsightItem(
          emoji: top.icon,
          title: '${top.name} jadi yang terbesar',
          body: 'Kategori ini menyedot $pct% dari total pengeluaran bulan ini '
              '(${_fmt(top.amount)}). Normal aja atau bisa dikurangi?',
          type: InsightType.neutral,
          mascotAsset: 'assets/images/mascot-insight-thinking.png',
        ),
      ),
    ];
  }

  // ── Weekend effect ───────────────────────────────────────────────────────────

  static List<_ScoredInsight> _checkWeekendEffect(
    List<TransactionModel> all,
    DateTime now,
  ) {
    // Perlu minimal 3 minggu data
    final threeWeeksAgo = now.subtract(const Duration(days: 21));
    final expenses = all.where((tx) =>
        tx.type == 'expense' && !tx.date.isBefore(threeWeeksAgo));

    double weekdayTotal = 0;
    int weekdayDays = 0;
    double weekendTotal = 0;
    int weekendDays = 0;

    // Hitung per hari unik
    final dayMap = <DateTime, double>{};
    for (final tx in expenses) {
      final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
      dayMap[day] = (dayMap[day] ?? 0) + tx.amount;
    }

    for (final entry in dayMap.entries) {
      final dow = entry.key.weekday; // 1=Mon, 7=Sun
      if (dow >= 6) {
        weekendTotal += entry.value;
        weekendDays++;
      } else {
        weekdayTotal += entry.value;
        weekdayDays++;
      }
    }

    if (weekdayDays < 5 || weekendDays < 2) return [];

    final weekdayAvg = weekdayTotal / weekdayDays;
    final weekendAvg = weekendTotal / weekendDays;

    if (weekendAvg > weekdayAvg * 1.6) {
      final ratio = (weekendAvg / weekdayAvg).toStringAsFixed(1);
      return [
        _ScoredInsight(
          priority: 38,
          item: InsightItem(
            emoji: '😅',
            title: 'Weekend kamu selalu lebih boros',
            body: 'Rata-rata Sabtu-Minggu ${ratio}x lebih banyak dari hari kerja. '
                'Weekend effect nih, perlu diwaspadai!',
            type: InsightType.neutral,
            mascotAsset: 'assets/images/mascot-insight-thinking.png',
          ),
        ),
      ];
    }

    return [];
  }

  // ── Hari paling boros ────────────────────────────────────────────────────────

  static List<_ScoredInsight> _checkBusiestDay(
    List<TransactionModel> all,
    DateTime now,
  ) {
    // Perlu minimal 4 minggu data
    final fourWeeksAgo = now.subtract(const Duration(days: 28));
    final expenses = all.where((tx) =>
        tx.type == 'expense' && !tx.date.isBefore(fourWeeksAgo));

    final Map<int, double> totalByDow = {};
    final Map<int, int> countByDow = {};

    final dayMap = <DateTime, double>{};
    for (final tx in expenses) {
      final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
      dayMap[day] = (dayMap[day] ?? 0) + tx.amount;
    }

    for (final entry in dayMap.entries) {
      final dow = entry.key.weekday;
      totalByDow[dow] = (totalByDow[dow] ?? 0) + entry.value;
      countByDow[dow] = (countByDow[dow] ?? 0) + 1;
    }

    if (totalByDow.length < 5) return []; // Belum cukup data

    final avgByDow = {
      for (final dow in totalByDow.keys)
        if ((countByDow[dow] ?? 0) >= 2)
          dow: totalByDow[dow]! / countByDow[dow]!,
    };

    if (avgByDow.isEmpty) return [];

    final busiestDow =
        avgByDow.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    const dayNames = {
      1: 'Senin', 2: 'Selasa', 3: 'Rabu', 4: 'Kamis',
      5: 'Jumat', 6: 'Sabtu', 7: 'Minggu',
    };

    return [
      _ScoredInsight(
        priority: 20,
        item: InsightItem(
          emoji: '💡',
          title: 'Tiap hari ${dayNames[busiestDow]} paling boros',
          body: 'Rata-rata pengeluaran tertinggi ada di hari ${dayNames[busiestDow]}. '
              'Mau lebih hati-hati di hari itu?',
          type: InsightType.neutral,
          mascotAsset: 'assets/images/mascot-insight-info.png',
        ),
      ),
    ];
  }

  // ── Rekap bulan lalu (tampil di awal bulan) ──────────────────────────────────

  static List<_ScoredInsight> _checkMonthRecap(
    List<TransactionModel> all,
    DateTime now,
  ) {
    if (now.day > 7) return []; // Hanya tampil di awal bulan

    final lastStart = DateTime(now.year, now.month - 1, 1);
    final lastEnd = DateTime(now.year, now.month, 1).subtract(const Duration(seconds: 1));

    final income = _sumIncome(all, lastStart, lastEnd);
    final expense = _sumExpense(all, lastStart, lastEnd);

    if (income <= 0) return [];

    final saving = income - expense;

    if (saving > 0) {
      return [
        _ScoredInsight(
          priority: 42,
          item: InsightItem(
            emoji: '💪',
            title: 'Bulan lalu hemat ${_fmt(saving)}!',
            body: 'Bulan kemarin berhasil sisihkan ${_fmt(saving)} dari pemasukan. '
                'Bisa dipertahankan bulan ini?',
            type: InsightType.positive,
            mascotAsset: 'assets/images/mascot-insight-celebrate.png',
          ),
        ),
      ];
    }

    return [];
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static String _fmt(double v) => CurrencyFormatter.formatCompact(v);

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
