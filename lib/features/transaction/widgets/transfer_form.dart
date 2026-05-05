import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/hive/models/wallet_model.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_input.dart';
import '../providers/transaction_provider.dart';
import '../../asset/providers/wallet_provider.dart';
import '../../../main.dart';

class TransferForm extends ConsumerStatefulWidget {
  final double initialAmount;

  const TransferForm({super.key, required this.initialAmount});

  @override
  ConsumerState<TransferForm> createState() => _TransferFormState();
}

class _TransferFormState extends ConsumerState<TransferForm> {
  final _titleController = TextEditingController(text: 'Transfer');
  final _adminFeeController = TextEditingController(text: '0');
  final _descController = TextEditingController();

  WalletModel? _fromWallet;
  WalletModel? _toWallet;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _adminFeeController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        bottom: bottomPadding + 16, // ← di atas navigation bar HP
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          time?.hour ?? _selectedDate.hour,
          time?.minute ?? _selectedDate.minute,
        );
      });
    }
  }

  Future<void> _save() async {
    if (_fromWallet == null) {
      _showError('Pilih dompet asal');
      return;
    }
    if (_toWallet == null) {
      _showError('Pilih dompet tujuan');
      return;
    }
    if (_fromWallet!.id == _toWallet!.id) {
      _showError('Dompet asal dan tujuan tidak boleh sama');
      return;
    }
    if (widget.initialAmount <= 0) {
      _showError('Jumlah harus lebih dari 0');
      return;
    }

    final adminFee = double.tryParse(
          _adminFeeController.text.replaceAll('.', '').replaceAll(',', ''),
        ) ??
        0;

    final totalDeduct = widget.initialAmount + adminFee;
    if (_fromWallet!.balance < totalDeduct) {
      _showError(
        'Saldo tidak cukup. Saldo: Rp${_fromWallet!.balance.toStringAsFixed(0)}, '
        'Dibutuhkan: Rp${totalDeduct.toStringAsFixed(0)}',
      );
      return;
    }

    setState(() => _isLoading = true);

    await ref.read(transactionProvider.notifier).addTransfer(
          title: _titleController.text.trim(),
          amount: widget.initialAmount,
          fromWalletId: _fromWallet!.id,
          fromWalletName: _fromWallet!.name,
          toWalletId: _toWallet!.id,
          toWalletName: _toWallet!.name,
          adminFee: adminFee,
          date: _selectedDate,
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
        );

    setState(() => _isLoading = false);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final wallets = ref.watch(walletProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppInput(
            label: 'Judul',
            hint: 'Transfer',
            controller: _titleController,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildWalletTransferRow(wallets),
          const SizedBox(height: AppSpacing.md),
          AppInput(
            label: 'Biaya Admin',
            hint: '0',
            controller: _adminFeeController,
            keyboardType: TextInputType.number,
            prefixIcon: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Rp',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Biaya admin otomatis dicatat sebagai pengeluaran dari dompet asal',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: AppColors.textHint,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: GestureDetector(
                  onTap: _pickDate,
                  child: _PickerBox(
                    icon: Icons.calendar_today_rounded,
                    label:
                        DateFormat('dd MMM yyyy', 'id').format(_selectedDate),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: _pickDate,
                  child: _PickerBox(
                    icon: Icons.access_time_rounded,
                    label: DateFormat('HH:mm').format(_selectedDate),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppInput(
            label: 'Deskripsi (opsional)',
            hint: 'Tambahkan catatan...',
            controller: _descController,
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton.primary(
            label: 'Simpan Transfer',
            onPressed: _save,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildWalletTransferRow(List<WalletModel> wallets) {
    return Row(
      children: [
        Expanded(
          child: _WalletDropdown(
            label: 'Dari Dompet',
            selected: _fromWallet,
            wallets: wallets.where((w) => w.id != _toWallet?.id).toList(),
            onSelect: (w) => setState(() => _fromWallet = w),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: AppColors.primary,
            ),
          ),
        ),
        Expanded(
          child: _WalletDropdown(
            label: 'Ke Dompet',
            selected: _toWallet,
            wallets: wallets.where((w) => w.id != _fromWallet?.id).toList(),
            onSelect: (w) => setState(() => _toWallet = w),
          ),
        ),
      ],
    );
  }
}

// ── Wallet Dropdown ───────────────────────────────────────────────────────────

class _WalletDropdown extends StatelessWidget {
  final String label;
  final WalletModel? selected;
  final List<WalletModel> wallets;
  final ValueChanged<WalletModel> onSelect;

  const _WalletDropdown({
    required this.label,
    required this.selected,
    required this.wallets,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _showPicker(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                if (selected != null)
                  Text(selected!.icon, style: const TextStyle(fontSize: 16))
                else
                  const Icon(Icons.account_balance_wallet_rounded,
                      size: 16, color: AppColors.textHint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    selected?.name ?? 'Pilih',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: selected != null
                          ? AppColors.textPrimary
                          : AppColors.textHint,
                    ),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 16, color: AppColors.textHint),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(label, style: AppTextStyles.h4),
            ),
            const Divider(height: 1, color: AppColors.border),
            ...wallets.map((w) => ListTile(
                  leading: Text(w.icon, style: const TextStyle(fontSize: 22)),
                  title: Text(
                    w.name,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    'Saldo: Rp${w.balance.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  onTap: () {
                    onSelect(w);
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

// ── Picker Box ────────────────────────────────────────────────────────────────

class _PickerBox extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PickerBox({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
