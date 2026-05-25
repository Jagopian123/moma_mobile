import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../hive/hive_service.dart';
import '../hive/models/budget_model.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _pluginInitialized = false;
  static bool _timezonesInitialized = false;

  static const _channelId = 'moma_channel';
  static const _channelName = 'Moma Notifikasi';

  // Notification ID ranges
  // 1000-1999 : Budget alert
  // 2000-2999 : Subscription reminder
  // 3000-3999 : Debt reminder
  // 9000      : Daily reminder

  // Dipanggil sebelum runApp — hanya inisialisasi plugin, tanpa timezone DB
  static Future<void> initPlugin() async {
    if (_pluginInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'Notifikasi pengingat keuangan dari Moma',
          importance: Importance.high,
        ));

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _pluginInitialized = true;
  }

  // Dipanggil post-frame — load timezone DB (~200-500ms) di luar critical path
  static void initTimezones() {
    if (_timezonesInitialized) return;
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    _timezonesInitialized = true;
  }

  static AndroidNotificationDetails get _androidDetails =>
      const AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

  // ── Budget Alert ──────────────────────────────────────────────────────────────
  // Dipanggil setelah addExpense — cek apakah budget crossed 80% atau 100%

  static Future<void> checkBudgetAlert({
    required BudgetModel budget,
    required double spentBefore,
    required double spentAfter,
    required int index,
  }) async {
    if (budget.limitAmount <= 0) return;

    final pctBefore = spentBefore / budget.limitAmount;
    final pctAfter = spentAfter / budget.limitAmount;

    if (pctBefore < 1.0 && pctAfter >= 1.0) {
      await _plugin.show(
        1000 + index,
        '🚨 Budget ${budget.categoryName} Habis!',
        'Pengeluaran sudah melebihi limit ${_fmt(budget.limitAmount)}',
        NotificationDetails(android: _androidDetails),
      );
    } else if (pctBefore < 0.8 && pctAfter >= 0.8) {
      await _plugin.show(
        1000 + index,
        '⚠️ Budget ${budget.categoryName} Hampir Habis',
        'Sudah ${(pctAfter * 100).toStringAsFixed(0)}% dari ${_fmt(budget.limitAmount)}',
        NotificationDetails(android: _androidDetails),
      );
    }
  }

  // ── Subscription Reminders ────────────────────────────────────────────────────
  // Jadwalkan ulang setiap kali data langganan berubah

  static Future<void> scheduleSubscriptionReminders() async {
    for (int i = 0; i < 100; i++) {
      await _plugin.cancel(2000 + i);
    }

    final subs = HiveService.subscriptions.values
        .where((s) => s.status == 'active')
        .toList();

    int notifIndex = 0;
    for (final sub in subs) {
      final billing = sub.nextBillingDate;

      final h3 = _atNoon(billing.subtract(const Duration(days: 3)));
      if (h3.isAfter(DateTime.now())) {
        await _scheduleNotif(
          id: 2000 + notifIndex,
          title: '📅 ${sub.icon} ${sub.name} — 3 Hari Lagi',
          body: 'Tagihan ${_fmt(sub.amount)} jatuh tempo dalam 3 hari',
          scheduledDate: h3,
        );
        notifIndex++;
      }

      final h1 = _atNoon(billing.subtract(const Duration(days: 1)));
      if (h1.isAfter(DateTime.now())) {
        await _scheduleNotif(
          id: 2000 + notifIndex,
          title: '⏰ ${sub.icon} ${sub.name} — Besok!',
          body: 'Tagihan ${_fmt(sub.amount)} jatuh tempo besok',
          scheduledDate: h1,
        );
        notifIndex++;
      }
    }
  }

  // ── Debt Reminders ────────────────────────────────────────────────────────────

  static Future<void> scheduleDebtReminders() async {
    for (int i = 0; i < 200; i++) {
      await _plugin.cancel(3000 + i);
    }

    final debts = HiveService.debts.values
        .where((d) => d.status == 'active' && d.deadline != null)
        .toList();

    int notifIndex = 0;
    for (final debt in debts) {
      final deadline = debt.deadline!;
      final isDebt = debt.type == 'debt';
      final label = isDebt
          ? 'Hutang ke ${debt.personName}'
          : 'Piutang dari ${debt.personName}';

      final h7 = _atNoon(deadline.subtract(const Duration(days: 7)));
      if (h7.isAfter(DateTime.now())) {
        await _scheduleNotif(
          id: 3000 + notifIndex,
          title: '💰 $label — 7 Hari Lagi',
          body: '${_fmt(debt.remainingAmount)} jatuh tempo dalam 7 hari',
          scheduledDate: h7,
        );
        notifIndex++;
      }

      final h1 = _atNoon(deadline.subtract(const Duration(days: 1)));
      if (h1.isAfter(DateTime.now())) {
        await _scheduleNotif(
          id: 3000 + notifIndex,
          title: '⚠️ $label — Besok!',
          body: '${_fmt(debt.remainingAmount)} jatuh tempo besok!',
          scheduledDate: h1,
        );
        notifIndex++;
      }
    }
  }

  // ── Daily Reminder ────────────────────────────────────────────────────────────

  static Future<void> scheduleDailyReminder({int hour = 21, int minute = 0}) async {
    await _plugin.cancel(9000);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      9000,
      '📝 Sudah catat transaksi hari ini?',
      'Jangan lupa catat pengeluaran & pemasukan kamu',
      scheduled,
      NotificationDetails(android: _androidDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancelDailyReminder() async {
    await _plugin.cancel(9000);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  static Future<void> _scheduleNotif({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzDate,
      NotificationDetails(android: _androidDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static DateTime _atNoon(DateTime date) =>
      DateTime(date.year, date.month, date.day, 10, 0);

  static String _fmt(double amount) {
    if (amount >= 1000000) return 'Rp${(amount / 1000000).toStringAsFixed(1)}jt';
    if (amount >= 1000) return 'Rp${(amount / 1000).toStringAsFixed(0)}rb';
    return 'Rp${amount.toStringAsFixed(0)}';
  }
}
