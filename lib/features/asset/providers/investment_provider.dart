import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/hive/hive_service.dart';
import '../../../core/hive/models/investment_model.dart';

final investmentProvider =
    StateNotifierProvider<InvestmentNotifier, List<InvestmentModel>>((ref) {
  return InvestmentNotifier();
});

class InvestmentNotifier extends StateNotifier<List<InvestmentModel>> {
  InvestmentNotifier() : super([]) {
    _load();
  }

  void _load() {
    state = HiveService.investments.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> add({
    required String name,
    required String type,
    required double currentValue,
  }) async {
    final investment = InvestmentModel(
      id: const Uuid().v4(),
      name: name,
      type: type,
      currentValue: currentValue,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await HiveService.investments.put(investment.id, investment);
    _load();
  }

  Future<void> update({
    required String id,
    required String name,
    required String type,
    required double currentValue,
  }) async {
    final existing = HiveService.investments.get(id);
    if (existing == null) return;

    final updated = InvestmentModel(
      id: id,
      name: name,
      type: type,
      currentValue: currentValue,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
    );
    await HiveService.investments.put(id, updated);
    _load();
  }

  Future<void> delete(String id) async {
    await HiveService.investments.delete(id);
    _load();
  }

  double get totalValue => state.fold(0, (sum, i) => sum + i.currentValue);

  // Label tampilan per tipe
  static String typeLabel(String type) {
    switch (type) {
      case 'gold':
        return 'Emas';
      case 'stock':
        return 'Saham';
      case 'mutual_fund':
        return 'Reksa Dana';
      case 'sbn':
        return 'SBN/Obligasi';
      case 'deposit':
        return 'Deposito Berjangka';
      case 'crypto':
        return 'Kripto';
      default:
        return type;
    }
  }

  static String typeIcon(String type) {
    switch (type) {
      case 'gold':
        return '🥇';
      case 'stock':
        return '📈';
      case 'mutual_fund':
        return '📊';
      case 'sbn':
        return '🏛️';
      case 'deposit':
        return '🏦';
      case 'crypto':
        return '₿';
      default:
        return '💰';
    }
  }
}
