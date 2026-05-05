import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../hive/hive_service.dart';
import '../hive/models/wallet_model.dart';
import '../hive/models/transaction_model.dart';
import '../hive/models/budget_model.dart';
import '../hive/models/financial_plan_model.dart';
import '../hive/models/debt_model.dart';
import '../hive/models/investment_model.dart';

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

class ImportService {
  static final ImportService _instance = ImportService._internal();
  factory ImportService() => _instance;
  ImportService._internal();

  // ── Pick & Import file JSON ───────────────────────────────────

  Future<ImportResult?> pickAndImport({
    ImportMode mode = ImportMode.merge,
  }) async {
    debugPrint('=== pickAndImport called ===');
    debugPrint('=== Platform.isAndroid: ${Platform.isAndroid} ===');
    // Request permission dulu
    if (Platform.isAndroid) {
      // Cek versi Android
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      if (sdkInt < 33) {
        // Android 12 ke bawah — perlu request permission
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          if (status.isPermanentlyDenied) await openAppSettings();
          return const ImportResult(
            success: false,
            message: 'Izin akses penyimpanan diperlukan',
          );
        }
      }
      debugPrint('=== requesting permission ===');

      // Android 13+ pakai READ_MEDIA_IMAGES, Android 12 kebawah pakai storage
      PermissionStatus status;

      if (await Permission.photos.isGranted ||
          await Permission.storage.isGranted ||
          await Permission.manageExternalStorage.isGranted) {
        // Sudah ada permission, lanjut
        status = PermissionStatus.granted;
      } else {
        // Coba request satu per satu
        status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
        if (!status.isGranted) {
          status = await Permission.photos.request();
        }
      }

      debugPrint('=== permission status: $status ===');

      if (status.isPermanentlyDenied) {
        await openAppSettings();
        return const ImportResult(
          success: false,
          message: 'Buka pengaturan HP untuk mengizinkan akses penyimpanan',
        );
      }

      if (!status.isGranted) {
        return const ImportResult(
          success: false,
          message: 'Izin akses penyimpanan diperlukan untuk import file',
        );
      }
    }
    // 1. Pilih file
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = File(result.files.single.path!);

    // 2. Baca file
    final content = await file.readAsString(encoding: utf8);

    // 3. Parse JSON
    Map<String, dynamic> data;
    try {
      data = jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return const ImportResult(
        success: false,
        message: 'File tidak valid. Pastikan file adalah backup dari Moma.',
      );
    }

    // 4. Validasi struktur
    if (!_isValidBackup(data)) {
      return const ImportResult(
        success: false,
        message:
            'Format file tidak dikenali. Pastikan file adalah backup dari Moma.',
      );
    }

    // 5. Import data
    return await _importData(data, mode);
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
      // Kalau replace → hapus semua data dulu
      if (mode == ImportMode.replace) {
        await _clearAllData();
      }

      int walletCount = 0;
      int transactionCount = 0;
      int budgetCount = 0;
      int planCount = 0;
      int debtCount = 0;
      int investmentCount = 0;

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
        // Merge: skip kalau sudah ada
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
        final investment = InvestmentModel(
          id: i['id'],
          name: i['name'],
          type: i['type'],
          currentValue: (i['current_value'] as num).toDouble(),
          createdAt: DateTime.tryParse(i['created_at'] ?? '') ?? DateTime.now(),
          updatedAt: DateTime.now(),
        );
        if (mode == ImportMode.merge &&
            HiveService.investments.containsKey(investment.id)) continue;
        await HiveService.investments.put(investment.id, investment);
        investmentCount++;
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
  }
}
