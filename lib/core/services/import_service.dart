import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../hive/hive_service.dart';
import '../hive/models/wallet_model.dart';
import '../hive/models/transaction_model.dart';
import '../hive/models/budget_model.dart';
import '../hive/models/financial_plan_model.dart';
import '../hive/models/debt_model.dart';
import '../hive/models/investment_model.dart';
import '../hive/models/subscription_model.dart';
import '../hive/models/category_model.dart';

enum ImportMode { replace, merge }

class ImportResult {
  final bool success;
  final String message;
  final Map<String, int> counts;

  const ImportResult({
    required this.success,
    required this.message,
    this.counts = const {},
  });
}

/// Hasil dari memilih file backup sebelum proses import dimulai.
/// Digunakan agar UI bisa menampilkan loading dialog di antara
/// pemilihan file dan proses import sesungguhnya.
class PickedBackup {
  final Map<String, dynamic>? data;
  final String? errorMessage;

  const PickedBackup._({this.data, this.errorMessage});

  factory PickedBackup.success(Map<String, dynamic> d) =>
      PickedBackup._(data: d);
  factory PickedBackup.error(String msg) => PickedBackup._(errorMessage: msg);

  bool get isSuccess => data != null;
  bool get hasError => errorMessage != null;
}

class ImportService {
  static final ImportService _instance = ImportService._internal();
  factory ImportService() => _instance;
  ImportService._internal();

  // ── Restore langsung dari Map (dipakai oleh BackupService) ───
  Future<ImportResult> restoreFromMap(Map<String, dynamic> data) async {
    if (!_isValidBackup(data)) {
      return const ImportResult(
        success: false,
        message: 'Format backup tidak dikenali. File mungkin bukan dari Moma.',
      );
    }
    return _importData(data, ImportMode.replace);
  }

  // ── Langkah 1: Pilih file & parse ────────────────────────────
  // Mengembalikan null jika user membatalkan pemilihan file.
  // Mengembalikan PickedBackup.error() jika ada masalah.
  // Mengembalikan PickedBackup.success() jika file siap diimport.
  //
  // Pisahkan dari importFromMap() agar UI bisa menampilkan
  // loading dialog di antara pick file dan proses import.
  Future<PickedBackup?> pickFile() async {
    // Request permission di Android
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      if (sdkInt < 33) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          if (status.isPermanentlyDenied) {
            await openAppSettings();
            return PickedBackup.error(
              'Izin akses file ditolak. Buka Pengaturan HP → Izin Aplikasi → Penyimpanan, lalu aktifkan.',
            );
          }
          return PickedBackup.error(
            'Izin akses file diperlukan untuk memilih file backup.',
          );
        }
      }

      PermissionStatus status;
      if (await Permission.photos.isGranted ||
          await Permission.storage.isGranted ||
          await Permission.manageExternalStorage.isGranted) {
        status = PermissionStatus.granted;
      } else {
        status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) status = await Permission.storage.request();
        if (!status.isGranted) status = await Permission.photos.request();
      }

      if (status.isPermanentlyDenied) {
        await openAppSettings();
        return PickedBackup.error(
          'Izin akses file ditolak. Buka Pengaturan HP → Izin Aplikasi → Penyimpanan, lalu aktifkan.',
        );
      }
      if (!status.isGranted) {
        return PickedBackup.error(
          'Izin akses file diperlukan untuk memilih file backup.',
        );
      }
    }

    // Buka file picker
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
    );

    // User membatalkan → kembalikan null (bukan error)
    if (picked == null || picked.files.isEmpty) return null;

    final file = File(picked.files.single.path!);

    // Baca isi file
    String content;
    try {
      content = await file.readAsString(encoding: utf8);
    } catch (_) {
      return PickedBackup.error(
        'Tidak bisa membaca file. Pastikan file tidak rusak dan coba lagi.',
      );
    }

    // Parse JSON
    Map<String, dynamic> data;
    try {
      data = jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return PickedBackup.error(
        'File tidak bisa dibaca sebagai backup Moma. Pastikan kamu memilih file yang benar.',
      );
    }

    // Validasi format backup
    if (!_isValidBackup(data)) {
      return PickedBackup.error(
        'Format file tidak dikenali. Pastikan file adalah backup yang diekspor dari aplikasi Moma.',
      );
    }

    return PickedBackup.success(data);
  }

  // ── Langkah 2: Proses import dari data yang sudah dipilih ────
  Future<ImportResult> importFromMap(
    Map<String, dynamic> data,
    ImportMode mode,
  ) async {
    return _importData(data, mode);
  }

  // ── Validasi backup ───────────────────────────────────────────

  bool _isValidBackup(Map<String, dynamic> data) {
    return data.containsKey('app_version') &&
        data.containsKey('transactions') &&
        data.containsKey('wallets');
  }

  // ── Import data ke Hive ───────────────────────────────────────

  Future<ImportResult> _importData(
    Map<String, dynamic> data,
    ImportMode mode,
  ) async {
    try {
      if (mode == ImportMode.replace) {
        await _clearAllData();
      }

      int walletCount = 0;
      int transactionCount = 0;
      int budgetCount = 0;
      int planCount = 0;
      int debtCount = 0;
      int investmentCount = 0;
      int subscriptionCount = 0;
      int categoryCount = 0;

      // Import wallets
      final wallets = data['wallets'] as List? ?? [];
      for (final w in wallets) {
        final wallet = WalletModel(
          id: w['id'],
          name: w['name'],
          type: w['type'],
          balance: (w['balance'] as num).toDouble(),
          icon: w['icon'] ?? '💵',
          color: w['color'] ?? '#2563EB',
          bankName: w['bank_name'],
          accountNumber: w['account_number'],
          createdAt: DateTime.tryParse(w['created_at'] ?? '') ?? DateTime.now(),
          updatedAt: DateTime.now(),
        );
        if (mode == ImportMode.merge &&
            HiveService.wallets.containsKey(wallet.id)) continue;
        await HiveService.wallets.put(wallet.id, wallet);
        walletCount++;
      }

      // Import transactions
      final transactions = data['transactions'] as List? ?? [];
      for (final t in transactions) {
        final tx = TransactionModel(
          id: t['id'],
          title: t['title'],
          type: t['type'],
          amount: (t['amount'] as num).toDouble(),
          categoryId: t['category_id'],
          categoryName: t['category_name'],
          categoryIcon: t['category_icon'] ?? '📦',
          walletId: t['wallet_id'],
          walletName: t['wallet_name'],
          toWalletId: t['to_wallet_id'],
          toWalletName: t['to_wallet_name'],
          adminFee: t['admin_fee'] != null
              ? (t['admin_fee'] as num).toDouble()
              : null,
          description: t['description'],
          date: DateTime.tryParse(t['date'] ?? '') ?? DateTime.now(),
          createdAt: DateTime.tryParse(t['created_at'] ?? '') ?? DateTime.now(),
        );
        if (mode == ImportMode.merge &&
            HiveService.transactions.containsKey(tx.id)) continue;
        await HiveService.transactions.put(tx.id, tx);
        transactionCount++;
      }

      // Import budgets
      final budgets = data['budgets'] as List? ?? [];
      for (final b in budgets) {
        final budget = BudgetModel(
          id: b['id'],
          categoryId: b['category_id'],
          categoryName: b['category_name'],
          categoryIcon: b['category_icon'] ?? '📦',
          categoryColor: b['category_color'] ?? '#2563EB',
          limitAmount: (b['limit_amount'] as num).toDouble(),
          period: b['period'],
          startDate: DateTime.tryParse(b['start_date'] ?? '') ?? DateTime.now(),
          createdAt: DateTime.tryParse(b['created_at'] ?? '') ?? DateTime.now(),
        );
        if (mode == ImportMode.merge &&
            HiveService.budgets.containsKey(budget.id)) continue;
        await HiveService.budgets.put(budget.id, budget);
        budgetCount++;
      }

      // Import financial plans
      final plans = data['financial_plans'] as List? ?? [];
      for (final p in plans) {
        final contributions = (p['contributions'] as List? ?? [])
            .map((c) => ContributionModel(
                  id: c['id'],
                  amount: (c['amount'] as num).toDouble(),
                  date: DateTime.tryParse(c['date'] ?? '') ?? DateTime.now(),
                ))
            .toList();

        final plan = FinancialPlanModel(
          id: p['id'],
          name: p['name'],
          icon: p['icon'] ?? '🎯',
          color: p['color'] ?? '#2563EB',
          targetAmount: (p['target_amount'] as num).toDouble(),
          savedAmount: (p['saved_amount'] as num).toDouble(),
          deadline:
              p['deadline'] != null ? DateTime.tryParse(p['deadline']) : null,
          contributions: contributions,
          createdAt: DateTime.tryParse(p['created_at'] ?? '') ?? DateTime.now(),
        );
        if (mode == ImportMode.merge &&
            HiveService.financialPlans.containsKey(plan.id)) continue;
        await HiveService.financialPlans.put(plan.id, plan);
        planCount++;
      }

      // Import debts
      final debts = data['debts'] as List? ?? [];
      for (final d in debts) {
        final payments = (d['payments'] as List? ?? [])
            .map((p) => DebtPaymentModel(
                  id: p['id'],
                  amount: (p['amount'] as num).toDouble(),
                  date: DateTime.tryParse(p['date'] ?? '') ?? DateTime.now(),
                  note: p['note'],
                ))
            .toList();

        final debt = DebtModel(
          id: d['id'],
          type: d['type'],
          personName: d['person_name'],
          totalAmount: (d['total_amount'] as num).toDouble(),
          remainingAmount: (d['remaining_amount'] as num).toDouble(),
          walletId: d['wallet_id'],
          walletName: d['wallet_name'],
          categoryId: d['category_id'],
          categoryName: d['category_name'],
          note: d['note'],
          deadline:
              d['deadline'] != null ? DateTime.tryParse(d['deadline']) : null,
          status: d['status'],
          payments: payments,
          createdAt: DateTime.tryParse(d['created_at'] ?? '') ?? DateTime.now(),
        );
        if (mode == ImportMode.merge && HiveService.debts.containsKey(debt.id))
          continue;
        await HiveService.debts.put(debt.id, debt);
        debtCount++;
      }

      // Import investments
      final investments = data['investments'] as List? ?? [];
      for (final i in investments) {
        final now = DateTime.now();
        final investment = InvestmentModel(
          id: i['id'],
          name: i['name'],
          type: i['type'],
          currentValue: (i['current_value'] as num).toDouble(),
          createdAt: DateTime.tryParse(i['created_at'] ?? '') ?? now,
          updatedAt: DateTime.tryParse(i['updated_at'] ?? '') ?? now,
        );
        if (mode == ImportMode.merge &&
            HiveService.investments.containsKey(investment.id)) continue;
        await HiveService.investments.put(investment.id, investment);
        investmentCount++;
      }

      // Import subscriptions
      final subscriptions = data['subscriptions'] as List? ?? [];
      for (final s in subscriptions) {
        final subscription = SubscriptionModel(
          id: s['id'],
          name: s['name'],
          icon: s['icon'] ?? '📱',
          category: s['category'] ?? '',
          amount: (s['amount'] as num).toDouble(),
          cycle: s['cycle'] ?? 'monthly',
          startDate: DateTime.tryParse(s['start_date'] ?? '') ?? DateTime.now(),
          nextBillingDate:
              DateTime.tryParse(s['next_billing_date'] ?? '') ?? DateTime.now(),
          walletId: s['wallet_id'],
          walletName: s['wallet_name'],
          status: s['status'] ?? 'active',
          note: s['note'],
          color: s['color'] ?? 0xFF2563EB,
          createdAt: DateTime.tryParse(s['created_at'] ?? '') ?? DateTime.now(),
        );
        if (mode == ImportMode.merge &&
            HiveService.subscriptions.containsKey(subscription.id)) continue;
        await HiveService.subscriptions.put(subscription.id, subscription);
        subscriptionCount++;
      }

      // Import custom categories (skip default categories)
      final customCategories = data['custom_categories'] as List? ?? [];
      for (final c in customCategories) {
        final category = CategoryModel(
          id: c['id'],
          name: c['name'],
          icon: c['icon'] ?? '📦',
          color: c['color'] ?? '#2563EB',
          parentId: c['parent_id'],
          type: c['type'] ?? 'expense',
          isDefault: false,
        );
        if (mode == ImportMode.merge &&
            HiveService.categories.containsKey(category.id)) continue;
        await HiveService.categories.put(category.id, category);
        categoryCount++;
      }

      return ImportResult(
        success: true,
        message: 'Import berhasil!',
        counts: {
          'wallets': walletCount,
          'transactions': transactionCount,
          'budgets': budgetCount,
          'plans': planCount,
          'debts': debtCount,
          'investments': investmentCount,
          'subscriptions': subscriptionCount,
          'categories': categoryCount,
        },
      );
    } catch (e) {
      return ImportResult(
        success: false,
        message: 'Gagal import: $e',
      );
    }
  }

  // ── Clear semua data ──────────────────────────────────────────

  Future<void> _clearAllData() async {
    await HiveService.wallets.clear();
    await HiveService.transactions.clear();
    await HiveService.budgets.clear();
    await HiveService.financialPlans.clear();
    await HiveService.debts.clear();
    await HiveService.investments.clear();
    await HiveService.subscriptions.clear();
    // Hapus hanya kategori kustom, biarkan kategori default
    final customKeys = HiveService.categories.values
        .where((c) => !c.isDefault)
        .map((c) => c.id)
        .toList();
    await HiveService.categories.deleteAll(customKeys);
  }
}
