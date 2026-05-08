import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

import '../hive/hive_service.dart';

class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  // ── Export JSON ───────────────────────────────────────────────

  Future<void> exportJson() async {
    final data = _buildExportData();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

    final file = await _writeFile(
      name: 'moma_backup_${_dateStamp()}.json',
      content: jsonStr,
    );

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Moma - Backup Data',
      text: 'Backup data Moma ${_dateStamp()}',
    );
  }

  // ── Export CSV Transaksi ──────────────────────────────────────

  Future<void> exportTransactionsCsv() async {
    final transactions = HiveService.transactions.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final rows = <List<dynamic>>[
      // Header
      [
        'Tanggal',
        'Judul',
        'Tipe',
        'Jumlah',
        'Kategori',
        'Dompet',
        'Dompet Tujuan',
        'Biaya Admin',
        'Deskripsi',
      ],
      // Data
      ...transactions.map((tx) => [
            DateFormat('dd/MM/yyyy HH:mm').format(tx.date),
            tx.title,
            _typeLabel(tx.type),
            tx.amount,
            tx.categoryName,
            tx.walletName,
            tx.toWalletName ?? '',
            tx.adminFee ?? '',
            tx.description ?? '',
          ]),
    ];

    final csvStr = const ListToCsvConverter().convert(rows);
    final file = await _writeFile(
      name: 'moma_transaksi_${_dateStamp()}.csv',
      content: csvStr,
    );

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Moma - Export Transaksi',
      text: 'Data transaksi Moma ${_dateStamp()}',
    );
  }

  // ── Export CSV Aset ───────────────────────────────────────────

  Future<void> exportAssetsCsv() async {
    final wallets = HiveService.wallets.values.toList();
    final investments = HiveService.investments.values.toList();

    final rows = <List<dynamic>>[
      ['=== DOMPET & REKENING ==='],
      ['Nama', 'Tipe', 'Saldo'],
      ...wallets.map((w) => [w.name, _walletTypeLabel(w.type), w.balance]),
      [''],
      ['=== INVESTASI ==='],
      ['Nama', 'Jenis', 'Nilai Saat Ini'],
      ...investments
          .map((i) => [i.name, _investmentTypeLabel(i.type), i.currentValue]),
    ];

    final csvStr = const ListToCsvConverter().convert(rows);
    final file = await _writeFile(
      name: 'moma_aset_${_dateStamp()}.csv',
      content: csvStr,
    );

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Moma - Export Aset',
      text: 'Data aset Moma ${_dateStamp()}',
    );
  }

  // ── Helpers ───────────────────────────────────────────────────

  // Public static sehingga BackupService bisa memakai tanpa instance
  static Map<String, dynamic> buildBackupMap() {
    return ExportService()._buildExportData();
  }

  Map<String, dynamic> _buildExportData() {
    final transactions = HiveService.transactions.values.toList();
    final wallets = HiveService.wallets.values.toList();
    final budgets = HiveService.budgets.values.toList();
    final plans = HiveService.financialPlans.values.toList();
    final debts = HiveService.debts.values.toList();
    final investments = HiveService.investments.values.toList();

    return {
      'exported_at': DateTime.now().toIso8601String(),
      'app_version': '1.0.0',
      'transactions': transactions
          .map((tx) => {
                'id': tx.id,
                'title': tx.title,
                'type': tx.type,
                'amount': tx.amount,
                'category_id': tx.categoryId,
                'category_name': tx.categoryName,
                'wallet_id': tx.walletId,
                'wallet_name': tx.walletName,
                'to_wallet_id': tx.toWalletId,
                'to_wallet_name': tx.toWalletName,
                'admin_fee': tx.adminFee,
                'description': tx.description,
                'date': tx.date.toIso8601String(),
                'created_at': tx.createdAt.toIso8601String(),
              })
          .toList(),
      'wallets': wallets
          .map((w) => {
                'id': w.id,
                'name': w.name,
                'type': w.type,
                'balance': w.balance,
                'icon': w.icon,
                'color': w.color,
                'bank_name': w.bankName,
                'account_number': w.accountNumber,
              })
          .toList(),
      'budgets': budgets
          .map((b) => {
                'id': b.id,
                'category_id': b.categoryId,
                'category_name': b.categoryName,
                'limit_amount': b.limitAmount,
                'period': b.period,
                'start_date': b.startDate.toIso8601String(),
              })
          .toList(),
      'financial_plans': plans
          .map((p) => {
                'id': p.id,
                'name': p.name,
                'icon': p.icon,
                'target_amount': p.targetAmount,
                'saved_amount': p.savedAmount,
                'deadline': p.deadline?.toIso8601String(),
                'contributions': p.contributions
                    .map((c) => {
                          'id': c.id,
                          'amount': c.amount,
                          'date': c.date.toIso8601String(),
                        })
                    .toList(),
              })
          .toList(),
      'debts': debts
          .map((d) => {
                'id': d.id,
                'type': d.type,
                'person_name': d.personName,
                'total_amount': d.totalAmount,
                'remaining_amount': d.remainingAmount,
                'status': d.status,
                'note': d.note,
                'deadline': d.deadline?.toIso8601String(),
                'payments': d.payments
                    .map((p) => {
                          'id': p.id,
                          'amount': p.amount,
                          'date': p.date.toIso8601String(),
                          'note': p.note,
                        })
                    .toList(),
              })
          .toList(),
      'investments': investments
          .map((i) => {
                'id': i.id,
                'name': i.name,
                'type': i.type,
                'current_value': i.currentValue,
              })
          .toList(),
    };
  }

  Future<File> _writeFile({
    required String name,
    required String content,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsString(content, encoding: utf8);
    return file;
  }

  String _dateStamp() => DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

  String _typeLabel(String type) {
    switch (type) {
      case 'income':
        return 'Pemasukan';
      case 'expense':
        return 'Pengeluaran';
      case 'transfer':
        return 'Transfer';
      default:
        return type;
    }
  }

  String _walletTypeLabel(String type) {
    switch (type) {
      case 'bank':
        return 'Bank';
      case 'ewallet':
        return 'E-Wallet';
      default:
        return 'Tunai';
    }
  }

  String _investmentTypeLabel(String type) {
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
        return 'Deposito';
      case 'crypto':
        return 'Kripto';
      default:
        return type;
    }
  }
}
