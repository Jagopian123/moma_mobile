import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/hive/hive_service.dart';
import '../../../core/hive/models/transaction_model.dart';
import '../../../core/hive/models/wallet_model.dart';
import '../../../core/services/notification_service.dart';
import '../../asset/providers/wallet_provider.dart';
import '../../budget/providers/budget_provider.dart';
import '../../notifications/providers/notification_provider.dart';

final transactionProvider =
    StateNotifierProvider<TransactionNotifier, List<TransactionModel>>((ref) {
  return TransactionNotifier(ref);
});

class TransactionNotifier extends StateNotifier<List<TransactionModel>> {
  TransactionNotifier(this._ref) : super([]) {
    _load();
  }

  final Ref _ref;

  void _load() {
    state = HiveService.transactions.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  // ── Tambah Pengeluaran ────────────────────────────────────────
  Future<void> addExpense({
    required String title,
    required double amount,
    required String categoryId,
    required String categoryName,
    required String categoryIcon,
    required String walletId,
    required String walletName,
    required DateTime date,
    String? description,
  }) async {
    // Kurangi saldo dompet
    final wallet = HiveService.wallets.get(walletId);
    if (wallet != null) {
      await _ref.read(walletProvider.notifier).updateBalance(
            walletId,
            wallet.balance - amount,
          );
    }

    final tx = TransactionModel(
      id: const Uuid().v4(),
      title: title,
      type: 'expense',
      amount: amount,
      categoryId: categoryId,
      categoryName: categoryName,
      categoryIcon: categoryIcon,
      walletId: walletId,
      walletName: walletName,
      description: description,
      date: date,
      createdAt: DateTime.now(),
    );

    // Tangkap spent SEBELUM transaksi baru masuk (untuk threshold check)
    final budgetNotifier = _ref.read(budgetProvider.notifier);
    final budgets = _ref.read(budgetProvider);
    final spentBefore = budgets.map((b) => budgetNotifier.getSpent(b)).toList();

    await HiveService.transactions.put(tx.id, tx);
    _load();
    budgetNotifier.refresh();

    // Cek budget alert & update in-app notif setelah state terupdate
    final notifNotifier = _ref.read(notificationProvider.notifier);
    for (int i = 0; i < budgets.length; i++) {
      final spentAfter = budgetNotifier.getSpent(budgets[i]);
      final pctAfter = budgets[i].limitAmount > 0
          ? spentAfter / budgets[i].limitAmount
          : 0.0;

      await NotificationService.checkBudgetAlert(
        budget: budgets[i],
        spentBefore: spentBefore[i],
        spentAfter: spentAfter,
        index: i,
      );

      if (pctAfter >= 0.8) {
        await notifNotifier.updateBudgetNotif(
          budgetId: budgets[i].id,
          categoryName: budgets[i].categoryName,
          percentage: pctAfter,
        );
      }
    }
  }

  // ── Tambah Pemasukan ──────────────────────────────────────────
  Future<void> addIncome({
    required String title,
    required double amount,
    required String categoryId,
    required String categoryName,
    required String categoryIcon,
    required String walletId,
    required String walletName,
    required DateTime date,
    String? description,
  }) async {
    // Tambah saldo dompet
    final wallet = HiveService.wallets.get(walletId);
    if (wallet != null) {
      await _ref.read(walletProvider.notifier).updateBalance(
            walletId,
            wallet.balance + amount,
          );
    }

    final tx = TransactionModel(
      id: const Uuid().v4(),
      title: title,
      type: 'income',
      amount: amount,
      categoryId: categoryId,
      categoryName: categoryName,
      categoryIcon: categoryIcon,
      walletId: walletId,
      walletName: walletName,
      description: description,
      date: date,
      createdAt: DateTime.now(),
    );

    await HiveService.transactions.put(tx.id, tx);
    _load();
    _ref.read(budgetProvider.notifier).refresh(); // ← tambah ini
  }

  // ── Tambah Transfer ───────────────────────────────────────────
  Future<void> addTransfer({
    required String title,
    required double amount,
    required String fromWalletId,
    required String fromWalletName,
    required String toWalletId,
    required String toWalletName,
    required double adminFee,
    required DateTime date,
    String? description,
  }) async {
    final fromWallet = HiveService.wallets.get(fromWalletId);
    final toWallet = HiveService.wallets.get(toWalletId);

    // Kurangi saldo dompet asal (amount + admin fee)
    if (fromWallet != null) {
      await _ref.read(walletProvider.notifier).updateBalance(
            fromWalletId,
            fromWallet.balance - amount - adminFee,
          );
    }

    // Tambah saldo dompet tujuan
    if (toWallet != null) {
      await _ref.read(walletProvider.notifier).updateBalance(
            toWalletId,
            toWallet.balance + amount,
          );
    }

    // Simpan transaksi transfer
    final tx = TransactionModel(
      id: const Uuid().v4(),
      title: title,
      type: 'transfer',
      amount: amount,
      categoryId: 'transfer',
      categoryName: 'Transfer',
      categoryIcon: '🔄',
      walletId: fromWalletId,
      walletName: fromWalletName,
      toWalletId: toWalletId,
      toWalletName: toWalletName,
      adminFee: adminFee > 0 ? adminFee : null,
      description: description,
      date: date,
      createdAt: DateTime.now(),
    );
    await HiveService.transactions.put(tx.id, tx);

    // Kalau ada biaya admin → simpan juga sebagai pengeluaran terpisah
    if (adminFee > 0) {
      final adminTx = TransactionModel(
        id: const Uuid().v4(),
        title: 'Biaya Admin Transfer',
        type: 'expense',
        amount: adminFee,
        categoryId: 'sub_transfer_fee',
        categoryName: 'Biaya Transfer',
        categoryIcon: '💸',
        walletId: fromWalletId,
        walletName: fromWalletName,
        description: 'Biaya admin transfer ke $toWalletName',
        date: date,
        createdAt: DateTime.now(),
      );
      await HiveService.transactions.put(adminTx.id, adminTx);
    }

    _load();
    _ref.read(budgetProvider.notifier).refresh(); // ← tambah ini
  }

  // ── Edit Transaksi ────────────────────────────────────────────
  Future<void> edit({
    required String id,
    required String title,
    required double newAmount,
    required String categoryId,
    required String categoryName,
    required String categoryIcon,
    required DateTime date,
    String? description,
  }) async {
    final existing = HiveService.transactions.get(id);
    if (existing == null) return;

    // Revert saldo lama
    final wallet = HiveService.wallets.get(existing.walletId);
    if (wallet != null) {
      double revertedBalance = wallet.balance;
      if (existing.type == 'expense') {
        revertedBalance = wallet.balance + existing.amount; // kembalikan
      } else if (existing.type == 'income') {
        revertedBalance = wallet.balance - existing.amount; // kurangi
      }

      // Apply saldo baru
      double newBalance = revertedBalance;
      if (existing.type == 'expense') {
        newBalance = revertedBalance - newAmount;
      } else if (existing.type == 'income') {
        newBalance = revertedBalance + newAmount;
      }

      await _ref.read(walletProvider.notifier).updateBalance(
            existing.walletId,
            newBalance,
          );
    }

    final updated = TransactionModel(
      id: id,
      title: title,
      type: existing.type,
      amount: newAmount,
      categoryId: categoryId,
      categoryName: categoryName,
      categoryIcon: categoryIcon,
      walletId: existing.walletId,
      walletName: existing.walletName,
      toWalletId: existing.toWalletId,
      toWalletName: existing.toWalletName,
      adminFee: existing.adminFee,
      description: description,
      date: date,
      createdAt: existing.createdAt,
    );

    await HiveService.transactions.put(id, updated);
    _load();
    _ref.read(budgetProvider.notifier).refresh();
  }

  // ── Hapus Transaksi ───────────────────────────────────────────
  Future<void> delete(String id) async {
    final tx = HiveService.transactions.get(id);
    if (tx == null) return;

    // Revert saldo
    final wallet = HiveService.wallets.get(tx.walletId);
    if (wallet != null) {
      double newBalance = wallet.balance;
      if (tx.type == 'expense') {
        newBalance = wallet.balance + tx.amount;
      } else if (tx.type == 'income') {
        newBalance = wallet.balance - tx.amount;
      } else if (tx.type == 'transfer') {
        // Kembalikan ke dompet asal
        newBalance = wallet.balance + tx.amount + (tx.adminFee ?? 0);
        // Kurangi dari dompet tujuan
        if (tx.toWalletId != null) {
          final toWallet = HiveService.wallets.get(tx.toWalletId!);
          if (toWallet != null) {
            await _ref.read(walletProvider.notifier).updateBalance(
                  tx.toWalletId!,
                  toWallet.balance - tx.amount,
                );
          }
        }
      }
      await _ref.read(walletProvider.notifier).updateBalance(
            tx.walletId,
            newBalance,
          );
    }

    await HiveService.transactions.delete(id);
    _load();
    _ref.read(budgetProvider.notifier).refresh();
  }

  // ── Helpers ───────────────────────────────────────────────────

  // Transaksi hari ini
  List<TransactionModel> get todayTransactions {
    final now = DateTime.now();
    return state.where((tx) {
      return tx.date.year == now.year &&
          tx.date.month == now.month &&
          tx.date.day == now.day;
    }).toList();
  }

  // Transaksi dalam rentang tanggal
  List<TransactionModel> getByDateRange(DateTime from, DateTime to) {
    return state.where((tx) {
      return tx.date.isAfter(from.subtract(const Duration(days: 1))) &&
          tx.date.isBefore(to.add(const Duration(days: 1)));
    }).toList();
  }

  // Total pemasukan hari ini
  double get todayIncome => todayTransactions
      .where((tx) => tx.type == 'income')
      .fold(0, (s, tx) => s + tx.amount);

  // Total pengeluaran hari ini
  double get todayExpense => todayTransactions
      .where((tx) => tx.type == 'expense')
      .fold(0, (s, tx) => s + tx.amount);

  // Pengeluaran bulan ini per kategori (untuk budget)
  Map<String, double> get thisMonthExpenseByCategory {
    final now = DateTime.now();
    final monthly = state.where((tx) =>
        tx.type == 'expense' &&
        tx.date.year == now.year &&
        tx.date.month == now.month);
    final Map<String, double> result = {};
    for (final tx in monthly) {
      result[tx.categoryId] = (result[tx.categoryId] ?? 0) + tx.amount;
    }
    return result;
  }

  // Group transaksi by tanggal
  Map<DateTime, List<TransactionModel>> groupByDate(
      List<TransactionModel> transactions) {
    final Map<DateTime, List<TransactionModel>> grouped = {};
    for (final tx in transactions) {
      final date = DateTime(tx.date.year, tx.date.month, tx.date.day);
      grouped.putIfAbsent(date, () => []).add(tx);
    }
    return grouped;
  }
}
