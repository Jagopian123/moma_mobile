import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/hive/models/debt_model.dart';
import '../../../core/hive/models/wallet_model.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_input.dart';
import '../../asset/providers/wallet_provider.dart';
import '../providers/debt_provider.dart';

class PaymentSheet extends ConsumerStatefulWidget {
  final DebtModel debt;

  const PaymentSheet({super.key, required this.debt});

  @override
  ConsumerState<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<PaymentSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  WalletModel? _selectedWallet;
  bool _isLoading = false;

  bool get isReceivable => widget.debt.type == 'receivable';

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(
          _amountController.text.replaceAll('.', '').replaceAll(',', ''),
        ) ??
        0;

    if (amount <= 0) {
      _showError('Jumlah harus lebih dari 0');
      return;
    }
    if (amount > widget.debt.remainingAmount) {
      _showError(
        'Jumlah melebihi sisa ${CurrencyFormatter.format(widget.debt.remainingAmount)}',
      );
      return;
    }
    if (_selectedWallet == null) {
      _showError('Pilih dompet');
      return;
    }

    setState(() => _isLoading = true);

    await ref.read(debtProvider.notifier).addPayment(
          debtId: widget.debt.id,
          amount: amount,
          walletId: _selectedWallet?.id,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );

    setState(() => _isLoading = false);
    if (mounted) Navigator.pop(context);
  }

  // Sesudah
  void _showError(String msg) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        bottom: bottomPadding + 16,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.danger,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.error_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    msg,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () => entry.remove());
  }

  @override
  Widget build(BuildContext context) {
    final wallets = ref.watch(walletProvider);
    final color = isReceivable ? AppColors.income : AppColors.expense;
    final title = isReceivable ? 'Terima Pembayaran' : 'Bayar Hutang';

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),

            Text(title, style: AppTextStyles.h3),
            const SizedBox(height: 4),

            // Info debt
            Text(
              isReceivable
                  ? '${widget.debt.personName} membayar hutangnya'
                  : 'Bayar hutang ke ${widget.debt.personName}',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 4),
            Text(
              'Sisa: ${CurrencyFormatter.format(widget.debt.remainingAmount)}',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Jumlah pembayaran
            AppAmountInput(
              label: 'Jumlah Pembayaran',
              controller: _amountController,
            ),
            const SizedBox(height: AppSpacing.sm),

            // Shortcut lunas sekaligus
            GestureDetector(
              onTap: () {
                final remaining = widget.debt.remainingAmount
                    .toStringAsFixed(0)
                    .replaceAllMapped(
                      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                      (m) => '${m[1]}.',
                    );
                _amountController.text = remaining;
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  'Lunas sekaligus (${CurrencyFormatter.formatCompact(widget.debt.remainingAmount)})',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Pilih dompet
            _buildWalletPicker(wallets, color),
            const SizedBox(height: AppSpacing.md),

            // Catatan
            AppInput(
              label: 'Catatan (opsional)',
              hint: 'Tambahkan keterangan...',
              controller: _noteController,
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.lg),

            AppButton.primary(
              label: title,
              onPressed: _save,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletPicker(List<WalletModel> wallets, Color activeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isReceivable ? 'Masuk ke Dompet' : 'Bayar dari Dompet',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: wallets.map((wallet) {
              final isSelected = _selectedWallet?.id == wallet.id;
              final color = Color(
                int.parse(wallet.color.replaceFirst('#', '0xFF')),
              );
              return GestureDetector(
                onTap: () => setState(() => _selectedWallet = wallet),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withOpacity(0.12)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: isSelected ? color : AppColors.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(wallet.icon, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        wallet.name,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? color : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
