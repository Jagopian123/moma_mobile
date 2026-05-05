import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/hive/models/transaction_model.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../providers/transaction_provider.dart';
import 'edit_transaction_sheet.dart';

class TransactionCard extends ConsumerWidget {
  final TransactionModel transaction;
  final bool showDate;

  const TransactionCard({
    super.key,
    required this.transaction,
    this.showDate = false,
  });

  Color get _amountColor {
    switch (transaction.type) {
      case 'income':
        return AppColors.income;
      case 'expense':
        return AppColors.expense;
      default:
        return AppColors.transfer;
    }
  }

  String get _amountPrefix {
    switch (transaction.type) {
      case 'income':
        return '+';
      case 'expense':
        return '-';
      default:
        return '→';
    }
  }

  String get _subtitle {
    if (transaction.type == 'transfer') {
      return '${transaction.walletName} → ${transaction.toWalletName ?? ''}';
    }
    return transaction.walletName;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: Key(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Icon(Icons.delete_rounded, color: AppColors.danger),
      ),
      confirmDismiss: (_) => showConfirmSheet(
        context: context,
        title: 'Hapus Transaksi',
        description:
            'Hapus "${transaction.title}"? Saldo dompet akan dikembalikan.',
        confirmLabel: 'Ya, Hapus',
      ),
      onDismissed: (_) {
        ref.read(transactionProvider.notifier).delete(transaction.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${transaction.title}" dihapus'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _showEdit(context),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              // Icon kategori
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _amountColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Center(
                  child: Text(
                    transaction.categoryIcon,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title,
                      style: AppTextStyles.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          transaction.categoryName,
                          style: AppTextStyles.small,
                        ),
                        const Text(
                          ' · ',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textHint,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            _subtitle,
                            style: AppTextStyles.small,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (showDate)
                      Text(
                        DateFormat('dd MMM yyyy, HH:mm', 'id')
                            .format(transaction.date),
                        style: AppTextStyles.small,
                      ),
                  ],
                ),
              ),

              // Jumlah
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$_amountPrefix${CurrencyFormatter.format(transaction.amount)}',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _amountColor,
                    ),
                  ),
                  if (transaction.adminFee != null && transaction.adminFee! > 0)
                    Text(
                      'Admin: ${CurrencyFormatter.formatCompact(transaction.adminFee!)}',
                      style: AppTextStyles.small,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEdit(BuildContext context) {
    if (transaction.type == 'transfer') return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditTransactionSheet(transaction: transaction),
    );
  }
}

// ── Date Group Header ─────────────────────────────────────────────────────────

class TransactionDateHeader extends StatelessWidget {
  final DateTime date;
  final double totalIncome;
  final double totalExpense;

  const TransactionDateHeader({
    super.key,
    required this.date,
    required this.totalIncome,
    required this.totalExpense,
  });

  @override
  Widget build(BuildContext context) {
    final net = totalIncome - totalExpense;
    final isToday = _isToday(date);
    final isYesterday = _isYesterday(date);

    String dateLabel;
    if (isToday) {
      dateLabel = 'Hari ini';
    } else if (isYesterday) {
      dateLabel = 'Kemarin';
    } else {
      dateLabel = DateFormat('EEEE, dd MMMM yyyy', 'id').format(date);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, AppSpacing.md, 4, AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              dateLabel,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            net >= 0
                ? '+${CurrencyFormatter.formatCompact(net)}'
                : CurrencyFormatter.formatCompact(net),
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: net >= 0 ? AppColors.income : AppColors.expense,
            ),
          ),
        ],
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }
}
