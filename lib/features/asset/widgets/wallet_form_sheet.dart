import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/hive/models/wallet_model.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_input.dart';
import '../providers/wallet_provider.dart';

// Tipe dompet
enum WalletType { bank, ewallet, cash }

class WalletFormSheet extends ConsumerStatefulWidget {
  final WalletModel? wallet; // null = tambah baru

  const WalletFormSheet({super.key, this.wallet});

  @override
  ConsumerState<WalletFormSheet> createState() => _WalletFormSheetState();
}

class _WalletFormSheetState extends ConsumerState<WalletFormSheet> {
  final _nameController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountController = TextEditingController();
  final _balanceController = TextEditingController();

  WalletType _selectedType = WalletType.cash;
  String _selectedColor = '#2563EB';
  String _selectedIcon = '💵';
  bool _isLoading = false;

  bool get isEdit => widget.wallet != null;

  // Pilihan warna
  final List<String> _colors = [
    '#2563EB',
    '#7C3AED',
    '#059669',
    '#DC2626',
    '#D97706',
    '#0891B2',
    '#BE185D',
    '#65A30D',
  ];

  // Pilihan icon per tipe
  final Map<WalletType, List<String>> _icons = {
    WalletType.bank: ['🏦', '💳', '🏧', '💰'],
    WalletType.ewallet: ['📱', '💸', '🛒', '⚡'],
    WalletType.cash: ['💵', '💴', '💶', '👛'],
  };

  // Nama bank populer
  final List<String> _popularBanks = [
    'BRI',
    'BCA',
    'Mandiri',
    'BNI',
    'CIMB Niaga',
    'Seabank',
    'Jago',
    'Blu',
    'Neo Bank',
    'Allo Bank',
  ];

  // E-wallet populer
  final List<String> _popularEwallets = [
    'GoPay',
    'OVO',
    'Dana',
    'ShopeePay',
    'LinkAja',
    'Jenius',
  ];

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      final w = widget.wallet!;
      _nameController.text = w.name;
      _bankNameController.text = w.bankName ?? '';
      _accountController.text = w.accountNumber ?? '';
      _balanceController.text = w.balance.toStringAsFixed(0);
      _selectedColor = w.color;
      _selectedIcon = w.icon;
      _selectedType = switch (w.type) {
        'bank' => WalletType.bank,
        'ewallet' => WalletType.ewallet,
        _ => WalletType.cash,
      };
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bankNameController.dispose();
    _accountController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  String get _typeString => switch (_selectedType) {
        WalletType.bank => 'bank',
        WalletType.ewallet => 'ewallet',
        WalletType.cash => 'cash',
      };

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama dompet wajib diisi')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final balance = double.tryParse(
          _balanceController.text.replaceAll('.', '').replaceAll(',', ''),
        ) ??
        0;

    if (isEdit) {
      await ref.read(walletProvider.notifier).update(
            id: widget.wallet!.id,
            name: _nameController.text.trim(),
            type: _typeString,
            balance: balance,
            icon: _selectedIcon,
            color: _selectedColor,
            bankName: _bankNameController.text.trim().isEmpty
                ? null
                : _bankNameController.text.trim(),
            accountNumber: _accountController.text.trim().isEmpty
                ? null
                : _accountController.text.trim(),
          );
    } else {
      await ref.read(walletProvider.notifier).add(
            name: _nameController.text.trim(),
            type: _typeString,
            balance: balance,
            icon: _selectedIcon,
            color: _selectedColor,
            bankName: _bankNameController.text.trim().isEmpty
                ? null
                : _bankNameController.text.trim(),
            accountNumber: _accountController.text.trim().isEmpty
                ? null
                : _accountController.text.trim(),
          );
    }

    setState(() => _isLoading = false);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
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

            // Title
            Text(
              isEdit ? 'Edit Dompet' : 'Tambah Dompet',
              style: AppTextStyles.h3,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Tipe dompet
            _buildTypeSelector(),
            const SizedBox(height: AppSpacing.md),

            // Nama
            AppInput(
              label: 'Nama Dompet',
              hint: 'Contoh: BCA Utama',
              controller: _nameController,
            ),
            const SizedBox(height: AppSpacing.md),

            // Quick select nama bank/ewallet
            if (_selectedType == WalletType.bank)
              _buildQuickSelect(_popularBanks, (val) {
                _bankNameController.text = val;
                _nameController.text = val;
              }),
            if (_selectedType == WalletType.ewallet)
              _buildQuickSelect(_popularEwallets, (val) {
                _nameController.text = val;
              }),

            // Bank name (khusus bank)
            if (_selectedType == WalletType.bank) ...[
              AppInput(
                label: 'Nama Bank',
                hint: 'Contoh: BCA',
                controller: _bankNameController,
              ),
              const SizedBox(height: AppSpacing.md),
              AppInput(
                label: 'Nomor Rekening (opsional)',
                hint: 'Contoh: 1234567890',
                controller: _accountController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Saldo awal
            AppAmountInput(
              label: 'Saldo Awal',
              controller: _balanceController,
            ),
            const SizedBox(height: AppSpacing.md),

            // Pilih warna
            _buildColorPicker(),
            const SizedBox(height: AppSpacing.md),

            // Pilih icon
            _buildIconPicker(),
            const SizedBox(height: AppSpacing.lg),

            // Tombol simpan
            AppButton.primary(
              label: isEdit ? 'Simpan Perubahan' : 'Tambah Dompet',
              onPressed: _save,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    final types = [
      (WalletType.bank, '🏦', 'Bank & Digital'),
      (WalletType.ewallet, '📱', 'E-Wallet'),
      (WalletType.cash, '💵', 'Cash'),
    ];

    return Row(
      children: types.map((t) {
        final isSelected = _selectedType == t.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() {
              _selectedType = t.$1;
              _selectedIcon = _icons[t.$1]!.first;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.1)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Text(t.$2, style: const TextStyle(fontSize: 20)),
                  const SizedBox(height: 4),
                  Text(
                    t.$3,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuickSelect(List<String> items, Function(String) onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pilih cepat',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: items
              .map((item) => GestureDetector(
                    onTap: () => onSelect(item),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  Widget _buildColorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Warna',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: _colors.map((hex) {
            final color = Color(
              int.parse(hex.replaceFirst('#', '0xFF')),
            );
            final isSelected = _selectedColor == hex;
            return GestureDetector(
              onTap: () => setState(() => _selectedColor = hex),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        isSelected ? AppColors.textPrimary : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildIconPicker() {
    final icons = _icons[_selectedType] ?? _icons[WalletType.cash]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Icon',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: icons.map((icon) {
            final isSelected = _selectedIcon == icon;
            return GestureDetector(
              onTap: () => setState(() => _selectedIcon = icon),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.1)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Center(
                  child: Text(icon, style: const TextStyle(fontSize: 22)),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
