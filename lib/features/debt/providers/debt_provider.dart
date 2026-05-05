import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/hive/hive_service.dart';
import '../../../core/hive/models/debt_model.dart';
import '../../asset/providers/wallet_provider.dart';

final debtProvider =
    StateNotifierProvider<DebtNotifier, List<DebtModel>>((ref) {
  return DebtNotifier(ref);
});

class DebtNotifier extends StateNotifier<List<DebtModel>> {
  DebtNotifier(this._ref) : super([]) {
    _load();
  }

  final Ref _ref;

  void _load() {
    state = HiveService.debts.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // ── Tambah Piutang (orang berhutang ke saya) ──────────────────
  Future<void> addReceivable({
    required String personName,
    required double amount,
    String? walletId,
    String? walletName,
    String? categoryId,
    String? categoryName,
    String? note,
    DateTime? deadline,
  }) async {
    // Kurangi saldo dompet jika ada sumber dana
    if (walletId != null) {
      final wallet = HiveService.wallets.get(walletId);
      if (wallet != null) {
        await _ref.read(walletProvider.notifier).updateBalance(
              walletId,
              wallet.balance - amount,
            );
      }
    }

    final debt = DebtModel(
      id: const Uuid().v4(),
      type: 'receivable',
      personName: personName,
      totalAmount: amount,
      remainingAmount: amount,
      walletId: walletId,
      walletName: walletName,
      categoryId: categoryId,
      categoryName: categoryName,
      note: note,
      deadline: deadline,
      status: 'active',
      payments: [],
      createdAt: DateTime.now(),
    );
    await HiveService.debts.put(debt.id, debt);
    _load();
  }

  // ── Tambah Hutang (saya berhutang ke orang) ───────────────────
  Future<void> addDebt({
    required String personName,
    required double amount,
    String? categoryId,
    String? categoryName,
    String? note,
    DateTime? deadline,
  }) async {
    // Tidak mengurangi saldo
    final debt = DebtModel(
      id: const Uuid().v4(),
      type: 'debt',
      personName: personName,
      totalAmount: amount,
      remainingAmount: amount,
      walletId: null,
      walletName: null,
      categoryId: categoryId,
      categoryName: categoryName,
      note: note,
      deadline: deadline,
      status: 'active',
      payments: [],
      createdAt: DateTime.now(),
    );
    await HiveService.debts.put(debt.id, debt);
    _load();
  }

  // ── Bayar hutang / Terima pembayaran piutang ──────────────────
  Future<void> addPayment({
    required String debtId,
    required double amount,
    String? walletId,
    String? note,
  }) async {
    final debt = HiveService.debts.get(debtId);
    if (debt == null) return;

    // Update saldo dompet
    if (walletId != null) {
      final wallet = HiveService.wallets.get(walletId);
      if (wallet != null) {
        double newBalance;
        if (debt.type == 'receivable') {
          // Terima pembayaran → tambah saldo
          newBalance = wallet.balance + amount;
        } else {
          // Bayar hutang → kurangi saldo
          newBalance = wallet.balance - amount;
        }
        await _ref.read(walletProvider.notifier).updateBalance(
              walletId,
              newBalance,
            );
      }
    }

    final payment = DebtPaymentModel(
      id: const Uuid().v4(),
      amount: amount,
      date: DateTime.now(),
      note: note,
    );

    final newRemaining =
        (debt.remainingAmount - amount).clamp(0.0, double.infinity);
    final newStatus = newRemaining <= 0 ? 'paid' : 'active';

    final updated = DebtModel(
      id: debt.id,
      type: debt.type,
      personName: debt.personName,
      totalAmount: debt.totalAmount,
      remainingAmount: newRemaining,
      walletId: debt.walletId,
      walletName: debt.walletName,
      categoryId: debt.categoryId,
      categoryName: debt.categoryName,
      note: debt.note,
      deadline: debt.deadline,
      status: newStatus,
      payments: [...debt.payments, payment],
      createdAt: debt.createdAt,
    );
    await HiveService.debts.put(debtId, updated);
    _load();
  }

  Future<void> delete(String id) async {
    await HiveService.debts.delete(id);
    _load();
  }

  // ── Getters ───────────────────────────────────────────────────

  List<DebtModel> get activeDebts =>
      state.where((d) => d.type == 'debt' && d.status == 'active').toList();

  List<DebtModel> get activeReceivables => state
      .where((d) => d.type == 'receivable' && d.status == 'active')
      .toList();

  List<DebtModel> get paidDebts =>
      state.where((d) => d.status == 'paid').toList();

  double get totalDebt =>
      activeDebts.fold(0.0, (s, d) => s + d.remainingAmount);

  double get totalReceivable =>
      activeReceivables.fold(0.0, (s, d) => s + d.remainingAmount);

  int? getDaysLeft(DebtModel debt) {
    if (debt.deadline == null) return null;
    final diff = debt.deadline!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }
}
