import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/hive/hive_service.dart';
import '../../../core/hive/models/subscription_model.dart';
import '../../../core/services/notification_service.dart';

// ── Preset layanan populer ─────────────────────────────────────────────────────

class SubscriptionPreset {
  final String name;
  final String icon;
  final String category;
  final double amount;
  final String cycle;
  final int color; // warna brand

  const SubscriptionPreset({
    required this.name,
    required this.icon,
    required this.category,
    required this.amount,
    required this.cycle,
    required this.color,
  });
}

const kSubscriptionPresets = [
  SubscriptionPreset(name: 'Netflix',         icon: '🎬', category: 'streaming',     amount: 54000,  cycle: 'monthly', color: 0xFFE50914),
  SubscriptionPreset(name: 'Spotify',         icon: '🎵', category: 'musik',         amount: 54990,  cycle: 'monthly', color: 0xFF1ED760),
  SubscriptionPreset(name: 'YouTube Premium', icon: '▶️', category: 'streaming',     amount: 59000,  cycle: 'monthly', color: 0xFFFF0000),
  SubscriptionPreset(name: 'Disney+',         icon: '🏰', category: 'streaming',     amount: 49000,  cycle: 'monthly', color: 0xFF113CCF),
  SubscriptionPreset(name: 'Apple Music',     icon: '🎶', category: 'musik',         amount: 59000,  cycle: 'monthly', color: 0xFFFC3C44),
  SubscriptionPreset(name: 'ChatGPT Plus',    icon: '🤖', category: 'produktivitas', amount: 280000, cycle: 'monthly', color: 0xFF412991),
  SubscriptionPreset(name: 'iCloud+',         icon: '☁️', category: 'cloud',         amount: 15000,  cycle: 'monthly', color: 0xFF3693F3),
  SubscriptionPreset(name: 'Microsoft 365',   icon: '📊', category: 'produktivitas', amount: 99000,  cycle: 'monthly', color: 0xFFD83B01),
  SubscriptionPreset(name: 'Canva Pro',       icon: '🎨', category: 'produktivitas', amount: 120000, cycle: 'monthly', color: 0xFF00C4CC),
  SubscriptionPreset(name: 'Prime Video',     icon: '🎥', category: 'streaming',     amount: 39000,  cycle: 'monthly', color: 0xFF00A8E0),
  SubscriptionPreset(name: 'GamePass',        icon: '🎮', category: 'game',          amount: 60000,  cycle: 'monthly', color: 0xFF107C10),
  SubscriptionPreset(name: 'Vidio',           icon: '📺', category: 'streaming',     amount: 30000,  cycle: 'monthly', color: 0xFF1E73BE),
  SubscriptionPreset(name: 'Duolingo',        icon: '📗', category: 'edukasi',       amount: 75000,  cycle: 'monthly', color: 0xFF58CC02),
  SubscriptionPreset(name: 'Max',             icon: '🎞️', category: 'streaming',     amount: 75000,  cycle: 'monthly', color: 0xFF002BE7),
];

// ── Helper ─────────────────────────────────────────────────────────────────────

DateTime nextBillingFrom(DateTime start, String cycle) {
  final now = DateTime.now();
  var next = start;
  while (!next.isAfter(now)) {
    next = _advance(next, cycle);
  }
  return next;
}

DateTime _advance(DateTime date, String cycle) {
  switch (cycle) {
    case 'yearly':
      return DateTime(date.year + 1, date.month, date.day);
    case 'weekly':
      return date.add(const Duration(days: 7));
    default:
      final month = date.month + 1;
      final year = date.year + (month > 12 ? 1 : 0);
      return DateTime(year, month > 12 ? month - 12 : month, date.day);
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class SubscriptionNotifier extends StateNotifier<List<SubscriptionModel>> {
  SubscriptionNotifier() : super([]) {
    _load();
  }

  void _load() {
    state = HiveService.subscriptions.values.toList()
      ..sort((a, b) => a.nextBillingDate.compareTo(b.nextBillingDate));
  }

  Future<void> add({
    required String name,
    required String icon,
    required String category,
    required double amount,
    required String cycle,
    required DateTime startDate,
    required int color,
    String? walletId,
    String? walletName,
  }) async {
    final model = SubscriptionModel(
      id: const Uuid().v4(),
      name: name,
      icon: icon,
      category: category,
      amount: amount,
      cycle: cycle,
      startDate: startDate,
      nextBillingDate: nextBillingFrom(startDate, cycle),
      walletId: walletId,
      walletName: walletName,
      status: 'active',
      createdAt: DateTime.now(),
      color: color,
    );
    await HiveService.subscriptions.put(model.id, model);
    _load();
    NotificationService.scheduleSubscriptionReminders();
  }

  Future<void> update({
    required String id,
    required String name,
    required String icon,
    required String category,
    required double amount,
    required String cycle,
    required DateTime startDate,
    required int color,
    String? walletId,
    String? walletName,
  }) async {
    final existing = HiveService.subscriptions.get(id);
    if (existing == null) return;

    final updated = SubscriptionModel(
      id: id,
      name: name,
      icon: icon,
      category: category,
      amount: amount,
      cycle: cycle,
      startDate: startDate,
      nextBillingDate: nextBillingFrom(startDate, cycle),
      walletId: walletId,
      walletName: walletName,
      status: existing.status,
      createdAt: existing.createdAt,
      color: color,
    );
    await HiveService.subscriptions.put(id, updated);
    _load();
    NotificationService.scheduleSubscriptionReminders();
  }

  Future<void> updateStatus(String id, String status) async {
    final existing = HiveService.subscriptions.get(id);
    if (existing == null) return;
    existing.status = status;
    await existing.save();
    _load();
    NotificationService.scheduleSubscriptionReminders();
  }

  Future<void> updateWallet(String id, String? walletId, String? walletName) async {
    final existing = HiveService.subscriptions.get(id);
    if (existing == null) return;
    existing.walletId = walletId;
    existing.walletName = walletName;
    await existing.save();
    _load();
  }

  Future<void> recordPayment(String id) async {
    final existing = HiveService.subscriptions.get(id);
    if (existing == null) return;
    existing.nextBillingDate = _advance(existing.nextBillingDate, existing.cycle);
    await existing.save();
    _load();
    NotificationService.scheduleSubscriptionReminders();
  }

  Future<void> delete(String id) async {
    await HiveService.subscriptions.delete(id);
    _load();
    NotificationService.scheduleSubscriptionReminders();
  }

  // ── Computed ──────────────────────────────────────────────────────────────────

  List<SubscriptionModel> get active =>
      state.where((s) => s.status == 'active').toList();

  List<SubscriptionModel> get paused =>
      state.where((s) => s.status == 'paused').toList();

  List<SubscriptionModel> get overdue =>
      active.where((s) => s.nextBillingDate.isBefore(DateTime.now())).toList();

  double get totalMonthly => active.fold(0, (sum, s) => sum + _toMonthly(s));

  double get totalYearly => totalMonthly * 12;

  double _toMonthly(SubscriptionModel s) {
    switch (s.cycle) {
      case 'yearly':
        return s.amount / 12;
      case 'weekly':
        return s.amount * 4.33;
      default:
        return s.amount;
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, List<SubscriptionModel>>(
  (ref) => SubscriptionNotifier(),
);
