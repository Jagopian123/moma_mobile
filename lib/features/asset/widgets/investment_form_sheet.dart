import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/hive/models/investment_model.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_input.dart';
import '../providers/investment_provider.dart';

class InvestmentFormSheet extends ConsumerStatefulWidget {
  final InvestmentModel? investment;

  const InvestmentFormSheet({super.key, this.investment});

  @override
  ConsumerState<InvestmentFormSheet> createState() =>
      _InvestmentFormSheetState();
}

class _InvestmentFormSheetState extends ConsumerState<InvestmentFormSheet> {
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();

  String _selectedType = 'gold';
  bool _isLoading = false;

  bool get isEdit => widget.investment != null;

  final List<Map<String, String>> _types = [
    {'type': 'gold', 'icon': '🥇', 'label': 'Emas'},
    {'type': 'stock', 'icon': '📈', 'label': 'Saham'},
    {'type': 'mutual_fund', 'icon': '📊', 'label': 'Reksa Dana'},
    {'type': 'sbn', 'icon': '🏛️', 'label': 'SBN/Obligasi'},
    {'type': 'deposit', 'icon': '🏦', 'label': 'Deposito'},
    {'type': 'crypto', 'icon': '₿', 'label': 'Kripto'},
  ];

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _nameController.text = widget.investment!.name;
      _valueController.text =
          widget.investment!.currentValue.toStringAsFixed(0);
      _selectedType = widget.investment!.type;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama investasi wajib diisi')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final value = double.tryParse(
          _valueController.text.replaceAll('.', '').replaceAll(',', ''),
        ) ??
        0;

    if (isEdit) {
      await ref.read(investmentProvider.notifier).update(
            id: widget.investment!.id,
            name: _nameController.text.trim(),
            type: _selectedType,
            currentValue: value,
          );
    } else {
      await ref.read(investmentProvider.notifier).add(
            name: _nameController.text.trim(),
            type: _selectedType,
            currentValue: value,
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

            Text(
              isEdit ? 'Edit Investasi' : 'Tambah Investasi',
              style: AppTextStyles.h3,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Tipe investasi
            const Text(
              'Jenis Investasi',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            _buildTypeGrid(),
            const SizedBox(height: AppSpacing.md),

            // Nama
            AppInput(
              label: 'Nama',
              hint: 'Contoh: Emas Antam 10gr',
              controller: _nameController,
            ),
            const SizedBox(height: AppSpacing.md),

            // Nilai saat ini
            AppAmountInput(
              label: 'Nilai Saat Ini',
              controller: _valueController,
            ),
            const SizedBox(height: AppSpacing.lg),

            AppButton.primary(
              label: isEdit ? 'Simpan Perubahan' : 'Tambah Investasi',
              onPressed: _save,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeGrid() {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.6,
      children: _types.map((t) {
        final isSelected = _selectedType == t['type'];
        return GestureDetector(
          onTap: () => setState(() => _selectedType = t['type']!),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(t['icon']!, style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 4),
                Text(
                  t['label']!,
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
        );
      }).toList(),
    );
  }
}
