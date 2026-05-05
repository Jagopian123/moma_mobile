import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/hive/models/financial_plan_model.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_input.dart';
import '../providers/financial_plan_provider.dart';

class FinancialPlanFormSheet extends ConsumerStatefulWidget {
  final FinancialPlanModel? plan;

  const FinancialPlanFormSheet({super.key, this.plan});

  @override
  ConsumerState<FinancialPlanFormSheet> createState() =>
      _FinancialPlanFormSheetState();
}

class _FinancialPlanFormSheetState
    extends ConsumerState<FinancialPlanFormSheet> {
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _savedController = TextEditingController();

  String _selectedIcon = '🎯';
  String _selectedColor = '#2563EB';
  DateTime? _deadline;
  bool _isLoading = false;

  bool get isEdit => widget.plan != null;

  final List<String> _icons = [
    '🏠',
    '🚗',
    '✈️',
    '💻',
    '📱',
    '🎓',
    '💍',
    '🏖️',
    '🎯',
    '💰',
    '🏦',
    '🛒',
    '🎮',
    '🏋️',
    '📷',
    '🎸',
  ];

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

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _nameController.text = widget.plan!.name;
      _targetController.text = widget.plan!.targetAmount.toStringAsFixed(0);
      _savedController.text = widget.plan!.savedAmount.toStringAsFixed(0);
      _selectedIcon = widget.plan!.icon;
      _selectedColor = widget.plan!.color;
      _deadline = widget.plan!.deadline;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _savedController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 30)),
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
      _showError('Nama target wajib diisi');
      return;
    }
    final target = double.tryParse(
          _targetController.text.replaceAll('.', '').replaceAll(',', ''),
        ) ??
        0;
    if (target <= 0) {
      _showError('Target jumlah harus lebih dari 0');
      return;
    }

    setState(() => _isLoading = true);

    if (isEdit) {
      await ref.read(financialPlanProvider.notifier).update(
            id: widget.plan!.id,
            name: _nameController.text.trim(),
            icon: _selectedIcon,
            color: _selectedColor,
            targetAmount: target,
            deadline: _deadline,
          );
    } else {
      final saved = double.tryParse(
            _savedController.text.replaceAll('.', '').replaceAll(',', ''),
          ) ??
          0;
      await ref.read(financialPlanProvider.notifier).add(
            name: _nameController.text.trim(),
            icon: _selectedIcon,
            color: _selectedColor,
            targetAmount: target,
            savedAmount: saved,
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
              isEdit ? 'Edit Rencana' : 'Tambah Rencana',
              style: AppTextStyles.h3,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Nama
            AppInput(
              label: 'Nama Target',
              hint: 'Contoh: Beli Rumah',
              controller: _nameController,
            ),
            const SizedBox(height: AppSpacing.md),

            // Target jumlah
            AppAmountInput(
              label: 'Target Jumlah',
              controller: _targetController,
            ),
            const SizedBox(height: AppSpacing.md),

            // Jumlah sekarang (hanya saat tambah baru)
            if (!isEdit) ...[
              AppAmountInput(
                label: 'Jumlah Sekarang (opsional)',
                controller: _savedController,
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Pilih icon
            _buildIconPicker(),
            const SizedBox(height: AppSpacing.md),

            // Pilih warna
            _buildColorPicker(),
            const SizedBox(height: AppSpacing.md),

            // Deadline
            _buildDeadlinePicker(),
            const SizedBox(height: AppSpacing.lg),

            AppButton.primary(
              label: isEdit ? 'Simpan Perubahan' : 'Tambah Rencana',
              onPressed: _save,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pilih Icon',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _icons.map((icon) {
            final isSelected = _selectedIcon == icon;
            return GestureDetector(
              onTap: () => setState(() => _selectedIcon = icon),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
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

  Widget _buildColorPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pilih Warna',
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
            final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
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

  Widget _buildDeadlinePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Deadline (opsional)',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
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
                        : 'Pilih tanggal target',
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
