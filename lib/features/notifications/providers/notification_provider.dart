import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/hive/hive_service.dart';
import '../../../core/hive/models/in_app_notification_model.dart';

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, List<InAppNotificationModel>>(
  (ref) => NotificationNotifier(),
);

class NotificationNotifier
    extends StateNotifier<List<InAppNotificationModel>> {
  NotificationNotifier() : super([]) {
    _load();
  }

  void _load() {
    state = HiveService.notifications.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  int get unreadCount => state.where((n) => !n.isRead).length;

  // ── Generate semua notif dari data lokal ──────────────────────

  Future<void> generateAll() async {
    await Future.wait([
      _generateBudgetNotifs(),
      _generateSubscriptionNotifs(),
      _generateDebtNotifs(),
    ]);
    _load();
  }

  Future<void> generateBudgetNotifs() async {
    await _generateBudgetNotifs();
    _load();
  }

  // Dipanggil dari transaction_provider dengan persentase yang sudah dihitung benar
  Future<void> updateBudgetNotif({
    required String budgetId,
    required String categoryName,
    required double percentage,
  }) async {
    if (percentage >= 1.0) {
      await HiveService.notifications.put(
        'budget_${budgetId}_100',
        InAppNotificationModel(
          id: 'budget_${budgetId}_100',
          type: 'budget',
          title: '🚨 Budget $categoryName Habis!',
          body: 'Pengeluaran sudah melebihi limit $categoryName',
          createdAt: DateTime.now(),
        ),
      );
      // Hapus notif 80% kalau sudah upgrade ke 100%
      await HiveService.notifications.delete('budget_${budgetId}_80');
    } else if (percentage >= 0.8) {
      await HiveService.notifications.put(
        'budget_${budgetId}_80',
        InAppNotificationModel(
          id: 'budget_${budgetId}_80',
          type: 'budget',
          title: '⚠️ Budget $categoryName Hampir Habis',
          body: 'Sudah ${(percentage * 100).toStringAsFixed(0)}% dari limit budget',
          createdAt: DateTime.now(),
        ),
      );
    }
    _load();
  }

  // ── Budget ────────────────────────────────────────────────────

  Future<void> _generateBudgetNotifs() async {
    final budgets = HiveService.budgets.values.toList();
    final allTx = HiveService.transactions.values.toList();
    final now = DateTime.now();

    for (final budget in budgets) {
      // Hitung spent
      final spent = allTx.where((tx) {
        if (tx.type != 'expense') return false;
        if (tx.categoryId != budget.categoryId) return false;
        if (budget.period == 'monthly') {
          return tx.date.year == now.year && tx.date.month == now.month;
        } else {
          final start = now.subtract(Duration(days: now.weekday - 1));
          final weekStart = DateTime(start.year, start.month, start.day);
          return tx.date.isAfter(weekStart.subtract(const Duration(seconds: 1)));
        }
      }).fold(0.0, (s, tx) => s + tx.amount);

      if (budget.limitAmount <= 0) continue;
      final pct = spent / budget.limitAmount;

      if (pct >= 1.0) {
        await _put(InAppNotificationModel(
          id: 'budget_${budget.id}_100',
          type: 'budget',
          title: '🚨 Budget ${budget.categoryName} Habis!',
          body: 'Pengeluaran sudah melebihi limit ${budget.categoryName}',
          createdAt: DateTime.now(),
        ));
      } else if (pct >= 0.8) {
        await _put(InAppNotificationModel(
          id: 'budget_${budget.id}_80',
          type: 'budget',
          title: '⚠️ Budget ${budget.categoryName} Hampir Habis',
          body: 'Sudah ${(pct * 100).toStringAsFixed(0)}% dari limit budget',
          createdAt: DateTime.now(),
        ));
      }
    }
  }

  // ── Subscription ──────────────────────────────────────────────

  Future<void> _generateSubscriptionNotifs() async {
    final subs = HiveService.subscriptions.values
        .where((s) => s.status == 'active')
        .toList();
    final now = DateTime.now();

    for (final sub in subs) {
      final daysLeft =
          sub.nextBillingDate.difference(now).inDays;

      if (daysLeft <= 1 && daysLeft >= 0) {
        await _put(InAppNotificationModel(
          id: 'sub_${sub.id}_h1',
          type: 'subscription',
          title: '⏰ ${sub.icon} ${sub.name} Besok!',
          body: 'Tagihan ${_fmt(sub.amount)} jatuh tempo besok',
          createdAt: DateTime.now(),
        ));
      } else if (daysLeft <= 3) {
        await _put(InAppNotificationModel(
          id: 'sub_${sub.id}_h3',
          type: 'subscription',
          title: '📅 ${sub.icon} ${sub.name} — $daysLeft Hari Lagi',
          body: 'Siapkan ${_fmt(sub.amount)} untuk tagihan ini',
          createdAt: DateTime.now(),
        ));
      }
    }
  }

  // ── Debt ──────────────────────────────────────────────────────

  Future<void> _generateDebtNotifs() async {
    final debts = HiveService.debts.values
        .where((d) => d.status == 'active' && d.deadline != null)
        .toList();
    final now = DateTime.now();

    for (final debt in debts) {
      final daysLeft = debt.deadline!.difference(now).inDays;
      final label = debt.type == 'debt'
          ? 'Hutang ke ${debt.personName}'
          : 'Piutang dari ${debt.personName}';

      if (daysLeft < 0) continue;

      if (daysLeft <= 1) {
        await _put(InAppNotificationModel(
          id: 'debt_${debt.id}_h1',
          type: 'debt',
          title: '⚠️ $label — Besok!',
          body: '${_fmt(debt.remainingAmount)} jatuh tempo besok',
          createdAt: DateTime.now(),
        ));
      } else if (daysLeft <= 7) {
        await _put(InAppNotificationModel(
          id: 'debt_${debt.id}_h7',
          type: 'debt',
          title: '💰 $label — $daysLeft Hari Lagi',
          body: '${_fmt(debt.remainingAmount)} jatuh tempo dalam $daysLeft hari',
          createdAt: DateTime.now(),
        ));
      }
    }
  }

  // ── Read / Delete ─────────────────────────────────────────────

  Future<void> markAsRead(String id) async {
    final notif = HiveService.notifications.get(id);
    if (notif == null) return;
    notif.isRead = true;
    await notif.save();
    _load();
  }

  Future<void> markAllAsRead() async {
    for (final notif in HiveService.notifications.values) {
      if (!notif.isRead) {
        notif.isRead = true;
        await notif.save();
      }
    }
    _load();
  }

  Future<void> delete(String id) async {
    await HiveService.notifications.delete(id);
    _load();
  }

  Future<void> clearAll() async {
    await HiveService.notifications.clear();
    _load();
  }

  // ── Helper ────────────────────────────────────────────────────

  // put hanya jika belum ada — pakai id sebagai key untuk deduplication
  Future<void> _put(InAppNotificationModel notif) async {
    if (!HiveService.notifications.containsKey(notif.id)) {
      await HiveService.notifications.put(notif.id, notif);
    }
  }

  static String _fmt(double amount) {
    if (amount >= 1000000) {
      return 'Rp${(amount / 1000000).toStringAsFixed(1)}jt';
    }
    if (amount >= 1000) return 'Rp${(amount / 1000).toStringAsFixed(0)}rb';
    return 'Rp${amount.toStringAsFixed(0)}';
  }
}
