import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/hive/hive_service.dart';
import '../../../core/hive/models/wallet_model.dart';

final walletProvider =
    StateNotifierProvider<WalletNotifier, List<WalletModel>>((ref) {
  return WalletNotifier();
});

class WalletNotifier extends StateNotifier<List<WalletModel>> {
  WalletNotifier() : super([]) {
    _load();
  }

  void _load() {
    state = HiveService.wallets.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> add({
    required String name,
    required String type,
    required double balance,
    required String icon,
    required String color,
    String? bankName,
    String? accountNumber,
  }) async {
    final wallet = WalletModel(
      id: const Uuid().v4(),
      name: name,
      type: type,
      balance: balance,
      icon: icon,
      color: color,
      bankName: bankName,
      accountNumber: accountNumber,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await HiveService.wallets.put(wallet.id, wallet);
    _load();
  }

  Future<void> update({
    required String id,
    required String name,
    required String type,
    required double balance,
    required String icon,
    required String color,
    String? bankName,
    String? accountNumber,
  }) async {
    final existing = HiveService.wallets.get(id);
    if (existing == null) return;

    final updated = WalletModel(
      id: id,
      name: name,
      type: type,
      balance: balance,
      icon: icon,
      color: color,
      bankName: bankName,
      accountNumber: accountNumber,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
    );
    await HiveService.wallets.put(id, updated);
    _load();
  }

  Future<void> delete(String id) async {
    await HiveService.wallets.delete(id);
    _load();
  }

  // Dipakai oleh transaksi untuk update saldo
  Future<void> updateBalance(String id, double newBalance) async {
    final wallet = HiveService.wallets.get(id);
    if (wallet == null) return;
    final updated = WalletModel(
      id: wallet.id,
      name: wallet.name,
      type: wallet.type,
      balance: newBalance,
      icon: wallet.icon,
      color: wallet.color,
      bankName: wallet.bankName,
      accountNumber: wallet.accountNumber,
      createdAt: wallet.createdAt,
      updatedAt: DateTime.now(),
    );
    await HiveService.wallets.put(id, updated);
    _load();
  }

  double get totalBalance => state.fold(0, (sum, w) => sum + w.balance);

  List<WalletModel> get cashWallets =>
      state.where((w) => w.type == 'cash').toList();

  List<WalletModel> get bankWallets =>
      state.where((w) => w.type == 'bank').toList();

  List<WalletModel> get ewalletWallets =>
      state.where((w) => w.type == 'ewallet').toList();
}
