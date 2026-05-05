import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/hive/models/budget_model.dart';
import '../../../core/hive/models/category_model.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_input.dart';
import '../../transaction/providers/category_provider.dart';
import '../providers/budget_provider.dart';

class BudgetFormSheet extends ConsumerStatefulWidget {
  final BudgetModel? budget;

  const BudgetFormSheet({super.key, this.budget});

  @override
  ConsumerState<BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends ConsumerState<BudgetFormSheet> {
  final _limitController = TextEditingController();

  CategoryModel? _selectedCategory;
  String _selectedPeriod = 'monthly';
  bool _isLoading = false;

  bool get isEdit => widget.budget != null;

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      _limitController.text = widget.budget!.limitAmount.toStringAsFixed(0);
      _selectedPeriod = widget.budget!.period;
      _selectedCategory = ref
          .read(categoryProvider.notifier)
          .findById(widget.budget!.categoryId);
    }
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!isEdit && _selectedCategory == null) {
      _showError('Kategori wajib dipilih');
      return;
    }
    final limit = double.tryParse(
          _limitController.text.replaceAll('.', '').replaceAll(',', ''),
        ) ??
        0;
    if (limit <= 0) {
      _showError('Batas budget harus lebih dari 0');
      return;
    }

    setState(() => _isLoading = true);

    if (isEdit) {
      await ref.read(budgetProvider.notifier).update(
            id: widget.budget!.id,
            limitAmount: limit,
            period: _selectedPeriod,
          );
    } else {
      await ref.read(budgetProvider.notifier).add(
            categoryId: _selectedCategory!.id,
            categoryName: _selectedCategory!.name,
            categoryIcon: _selectedCategory!.icon,
            categoryColor: _selectedCategory!.color,
            limitAmount: limit,
            period: _selectedPeriod,
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
              isEdit ? 'Edit Budget' : 'Tambah Budget',
              style: AppTextStyles.h3,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Kategori (hanya saat tambah baru)
            if (!isEdit) ...[
              _buildCategoryPicker(),
              const SizedBox(height: AppSpacing.md),
            ] else ...[
              // Tampilkan kategori yang sudah dipilih (read only)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Text(
                      _selectedCategory?.icon ?? '',
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _selectedCategory?.name ?? widget.budget!.categoryName,
                      style: AppTextStyles.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Batas budget
            AppAmountInput(
              label: 'Batas Budget',
              controller: _limitController,
            ),
            const SizedBox(height: AppSpacing.md),

            // Periode
            const Text(
              'Periode',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            _buildPeriodSelector(),
            const SizedBox(height: AppSpacing.lg),

            AppButton.primary(
              label: isEdit ? 'Simpan Perubahan' : 'Tambah Budget',
              onPressed: _save,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kategori',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _showCategorySheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                if (_selectedCategory != null) ...[
                  Text(
                    _selectedCategory!.icon,
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _selectedCategory!.name,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ] else
                  const Expanded(
                    child: Text(
                      'Pilih kategori',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textHint,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showCategorySheet() {
    final categories =
        ref.read(categoryProvider.notifier).mainCategories(type: 'expense');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategorySheet(
        categories: categories,
        onSelect: (cat) => setState(() => _selectedCategory = cat),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Row(
      children: [
        _PeriodOption(
          label: 'Setiap Bulan',
          icon: Icons.calendar_month_rounded,
          value: 'monthly',
          selected: _selectedPeriod,
          onTap: () => setState(() => _selectedPeriod = 'monthly'),
        ),
        const SizedBox(width: AppSpacing.sm),
        _PeriodOption(
          label: 'Setiap Minggu',
          icon: Icons.calendar_view_week_rounded,
          value: 'weekly',
          selected: _selectedPeriod,
          onTap: () => setState(() => _selectedPeriod = 'weekly'),
        ),
      ],
    );
  }
}

// ── Period Option ─────────────────────────────────────────────────────────────

class _PeriodOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final String selected;
  final VoidCallback onTap;

  const _PeriodOption({
    required this.label,
    required this.icon,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
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
              Icon(
                icon,
                size: 22,
                color: isSelected ? AppColors.primary : AppColors.textHint,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color:
                      isSelected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Category Sheet ────────────────────────────────────────────────────────────

class _CategorySheet extends ConsumerStatefulWidget {
  final List<CategoryModel> categories;
  final ValueChanged<CategoryModel> onSelect;

  const _CategorySheet({
    required this.categories,
    required this.onSelect,
  });

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  CategoryModel? _selectedParent;

  @override
  Widget build(BuildContext context) {
    final items = _selectedParent == null
        ? widget.categories
        : ref
            .read(categoryProvider.notifier)
            .subCategories(_selectedParent!.id);

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                if (_selectedParent != null)
                  IconButton(
                    onPressed: () => setState(() => _selectedParent = null),
                    icon: const Icon(Icons.arrow_back_rounded),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                const SizedBox(width: 4),
                Text(
                  _selectedParent?.name ?? 'Pilih Kategori',
                  style: AppTextStyles.h4,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: ListView(
              children: [
                // Kalau sudah masuk subkategori,
                // tampilkan opsi "Semua [nama kategori]" di paling atas
                if (_selectedParent != null)
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(
                          int.parse(
                            _selectedParent!.color.replaceFirst('#', '0xFF'),
                          ),
                        ).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Center(
                        child: Text(
                          _selectedParent!.icon,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                    title: Text(
                      'Semua ${_selectedParent!.name}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    subtitle: const Text(
                      'Pilih tanpa subkategori',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    onTap: () {
                      widget.onSelect(_selectedParent!);
                      Navigator.pop(context);
                    },
                  ),

                // List item kategori / subkategori
                ...items.map((cat) {
                  final hasSubs = _selectedParent == null &&
                      ref
                          .read(categoryProvider.notifier)
                          .subCategories(cat.id)
                          .isNotEmpty;

                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(
                          int.parse(cat.color.replaceFirst('#', '0xFF')),
                        ).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Center(
                        child: Text(
                          cat.icon,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                    title: Text(
                      cat.name,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    // Kalau ada subs, tampilkan hint
                    subtitle: hasSubs
                        ? const Text(
                            'Ketuk untuk lihat subkategori',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: AppColors.textHint,
                            ),
                          )
                        : null,
                    trailing: hasSubs
                        ? const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textHint,
                          )
                        : null,
                    onTap: () {
                      if (hasSubs) {
                        // Masuk ke subkategori
                        setState(() => _selectedParent = cat);
                      } else {
                        // Langsung pilih
                        widget.onSelect(cat);
                        Navigator.pop(context);
                      }
                    },
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
