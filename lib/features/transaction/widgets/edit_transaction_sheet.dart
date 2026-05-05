import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/hive/models/transaction_model.dart';
import '../../../core/hive/models/category_model.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_input.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';

class EditTransactionSheet extends ConsumerStatefulWidget {
  final TransactionModel transaction;

  const EditTransactionSheet({super.key, required this.transaction});

  @override
  ConsumerState<EditTransactionSheet> createState() =>
      _EditTransactionSheetState();
}

class _EditTransactionSheetState extends ConsumerState<EditTransactionSheet> {
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _descController;

  CategoryModel? _selectedCategory;
  late DateTime _selectedDate;
  bool _isLoading = false;

  bool get isExpense => widget.transaction.type == 'expense';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.transaction.title);
    _amountController = TextEditingController(
      text: widget.transaction.amount.toStringAsFixed(0),
    );
    _descController = TextEditingController(
      text: widget.transaction.description ?? '',
    );
    _selectedDate = widget.transaction.date;

    // Set kategori yang sudah dipilih
    _selectedCategory = ref
        .read(categoryProvider.notifier)
        .findById(widget.transaction.categoryId);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
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
    if (_titleController.text.trim().isEmpty) {
      _showError('Judul wajib diisi');
      return;
    }
    if (_selectedCategory == null) {
      _showError('Kategori wajib dipilih');
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

    setState(() => _isLoading = true);

    await ref.read(transactionProvider.notifier).edit(
          id: widget.transaction.id,
          title: _titleController.text.trim(),
          newAmount: amount,
          categoryId: _selectedCategory!.id,
          categoryName: _selectedCategory!.name,
          categoryIcon: _selectedCategory!.icon,
          date: _selectedDate,
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
        );

    setState(() => _isLoading = false);
    if (mounted) Navigator.pop(context);
  }

  // Sesudah
  void _showError(String msg) {
    ScaffoldMessenger.of(Navigator.of(context, rootNavigator: true).context)
        .showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showCategorySheet() {
    final categories = ref
        .read(categoryProvider.notifier)
        .mainCategories(type: isExpense ? 'expense' : 'income');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategoryPickerSheet(
        categories: categories,
        onSelect: (cat) => setState(() => _selectedCategory = cat),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = isExpense ? AppColors.expense : AppColors.income;
    final label = isExpense ? 'Edit Pengeluaran' : 'Edit Pemasukan';

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
                Text(label, style: AppTextStyles.h3),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    isExpense ? 'Pengeluaran' : 'Pemasukan',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Judul
            AppInput(
              label: 'Judul',
              controller: _titleController,
            ),
            const SizedBox(height: AppSpacing.md),

            // Jumlah
            AppInput(
              label: 'Jumlah',
              controller: _amountController,
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
            const SizedBox(height: AppSpacing.md),

            // Kategori
            GestureDetector(
              onTap: _showCategorySheet,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
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
                    ],
                    Expanded(
                      child: Text(
                        _selectedCategory?.name ?? 'Pilih kategori',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: _selectedCategory != null
                              ? AppColors.textPrimary
                              : AppColors.textHint,
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
            const SizedBox(height: AppSpacing.md),

            // Tanggal & Jam
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('dd MMM yyyy', 'id')
                                .format(_selectedDate),
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('HH:mm').format(_selectedDate),
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Deskripsi
            AppInput(
              label: 'Deskripsi (opsional)',
              hint: 'Tambahkan catatan...',
              controller: _descController,
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.lg),

            AppButton.primary(
              label: 'Simpan Perubahan',
              onPressed: _save,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category Picker Sheet ─────────────────────────────────────────────────────

class _CategoryPickerSheet extends ConsumerStatefulWidget {
  final List<CategoryModel> categories;
  final ValueChanged<CategoryModel> onSelect;

  const _CategoryPickerSheet({
    required this.categories,
    required this.onSelect,
  });

  @override
  ConsumerState<_CategoryPickerSheet> createState() =>
      _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends ConsumerState<_CategoryPickerSheet> {
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
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final cat = items[i];
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
                  trailing: hasSubs
                      ? const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textHint)
                      : null,
                  onTap: () {
                    if (hasSubs) {
                      setState(() => _selectedParent = cat);
                    } else {
                      widget.onSelect(cat);
                      Navigator.pop(context);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
