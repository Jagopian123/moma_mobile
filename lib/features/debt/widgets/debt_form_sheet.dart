import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/hive/models/wallet_model.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_input.dart';
import '../../asset/providers/wallet_provider.dart';
import '../providers/debt_provider.dart';

class DebtFormSheet extends ConsumerStatefulWidget {
  final String type; // 'debt' atau 'receivable'

  const DebtFormSheet({super.key, required this.type});

  @override
  ConsumerState<DebtFormSheet> createState() => _DebtFormSheetState();
}

class _DebtFormSheetState extends ConsumerState<DebtFormSheet> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  WalletModel? _selectedWallet;
  DateTime? _deadline;
  bool _isLoading = false;
  bool _useWallet = true; // hanya untuk piutang

  bool get isReceivable => widget.type == 'receivable';

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      _showError('Nama orang wajib diisi');
      return;
    }
    final amount = double.tryParse(
          _amountController.text.replaceAll('.', '').replaceAll(',', ''),
        ) ??
        0;
    if (amount <= 0) {
      _showError('Jumlah harus lebih dari 0');
      return;
    }
    if (isReceivable && _useWallet && _selectedWallet == null) {
      _showError('Pilih sumber dompet');
      return;
    }

    setState(() => _isLoading = true);

    if (isReceivable) {
      await ref.read(debtProvider.notifier).addReceivable(
            personName: _nameController.text.trim(),
            amount: amount,
            walletId: _useWallet ? _selectedWallet?.id : null,
            walletName: _useWallet ? _selectedWallet?.name : null,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
            deadline: _deadline,
          );
    } else {
      await ref.read(debtProvider.notifier).addDebt(
            personName: _nameController.text.trim(),
            amount: amount,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
            deadline: _deadline,
          );
    }

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
    final title = isReceivable ? 'Tambah Piutang' : 'Tambah Hutang';
    final nameHint = isReceivable
        ? 'Siapa yang berhutang ke kamu?'
        : 'Kamu berhutang ke siapa?';

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

            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    isReceivable
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text(title, style: AppTextStyles.h3),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Nama orang
            AppInput(
              label: 'Nama',
              hint: nameHint,
              controller: _nameController,
            ),
            const SizedBox(height: AppSpacing.md),

            // Jumlah
            AppAmountInput(
              label: 'Jumlah',
              controller: _amountController,
            ),
            const SizedBox(height: AppSpacing.md),

            // Sumber dompet (khusus piutang)
            if (isReceivable) ...[
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Kurangi dari dompet?',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Switch(
                    value: _useWallet,
                    onChanged: (val) => setState(() => _useWallet = val),
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
              if (_useWallet) ...[
                const SizedBox(height: 8),
                _buildWalletPicker(wallets),
              ],
              const SizedBox(height: AppSpacing.md),
            ],

            // Catatan
            AppInput(
              label: 'Catatan (opsional)',
              hint: 'Tambahkan keterangan...',
              controller: _noteController,
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.md),

            // Deadline
            _buildDeadlinePicker(),
            const SizedBox(height: AppSpacing.lg),

            AppButton.primary(
              label: isReceivable ? 'Catat Piutang' : 'Catat Hutang',
              onPressed: _save,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletPicker(List<WalletModel> wallets) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sumber Dompet',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        if (wallets.isEmpty)
          const Text(
            'Belum ada dompet',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: AppColors.textHint,
            ),
          )
        else
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

  Widget _buildDeadlinePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Jatuh Tempo (opsional)',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _pickDeadline,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _deadline != null
                        ? DateFormat('dd MMMM yyyy', 'id').format(_deadline!)
                        : 'Pilih tanggal jatuh tempo',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: _deadline != null
                          ? AppColors.textPrimary
                          : AppColors.textHint,
                    ),
                  ),
                ),
                if (_deadline != null)
                  GestureDetector(
                    onTap: () => setState(() => _deadline = null),
                    child: const Icon(Icons.close_rounded,
                        size: 18, color: AppColors.textHint),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
