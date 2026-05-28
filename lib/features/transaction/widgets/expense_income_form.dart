import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/hive/models/category_model.dart';
import '../../../core/hive/models/wallet_model.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_input.dart';
import '../providers/category_provider.dart';
import '../providers/transaction_provider.dart';
import '../../asset/providers/wallet_provider.dart';
import '../../../main.dart';

class ExpenseIncomeForm extends ConsumerStatefulWidget {
  final String type;
  final double initialAmount;

  const ExpenseIncomeForm({
    super.key,
    required this.type,
    required this.initialAmount,
  });

  @override
  ConsumerState<ExpenseIncomeForm> createState() => _ExpenseIncomeFormState();
}

class _ExpenseIncomeFormState extends ConsumerState<ExpenseIncomeForm> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  CategoryModel? _selectedCategory;
  WalletModel? _selectedWallet;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  bool get isExpense => widget.type == 'expense';

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
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
                  color: Colors.black.withValues(alpha: 0.2),
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
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
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
    if (_selectedWallet == null) {
      _showError('Dompet wajib dipilih');
      return;
    }
    if (widget.initialAmount <= 0) {
      _showError('Jumlah harus lebih dari 0');
      return;
    }

    setState(() => _isLoading = true);

    final notifier = ref.read(transactionProvider.notifier);

    if (isExpense) {
      await notifier.addExpense(
        title: _titleController.text.trim(),
        amount: widget.initialAmount,
        categoryId: _selectedCategory!.id,
        categoryName: _selectedCategory!.name,
        categoryIcon: _selectedCategory!.icon,
        walletId: _selectedWallet!.id,
        walletName: _selectedWallet!.name,
        date: _selectedDate,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );
    } else {
      await notifier.addIncome(
        title: _titleController.text.trim(),
        amount: widget.initialAmount,
        categoryId: _selectedCategory!.id,
        categoryName: _selectedCategory!.name,
        categoryIcon: _selectedCategory!.icon,
        walletId: _selectedWallet!.id,
        walletName: _selectedWallet!.name,
        date: _selectedDate,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );
    }

    setState(() => _isLoading = false);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final wallets = ref.watch(walletProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.lg + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppInput(
            label: 'Judul',
            hint: isExpense ? 'Contoh: Makan siang' : 'Contoh: Gaji bulanan',
            controller: _titleController,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildCategoryPicker(),
          const SizedBox(height: AppSpacing.md),
          _buildWalletPicker(wallets),
          const SizedBox(height: AppSpacing.md),
          _buildDateTimePicker(),
          const SizedBox(height: AppSpacing.md),
          AppInput(
            label: 'Deskripsi (opsional)',
            hint: 'Tambahkan catatan...',
            controller: _descriptionController,
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton.primary(
            label: 'Simpan',
            onPressed: _save,
            isLoading: _isLoading,
          ),
        ],
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
          onTap: () => _showCategorySheet(),
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
                  Text(_selectedCategory!.icon,
                      style: const TextStyle(fontSize: 18)),
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
                const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textHint),
              ],
            ),
          ),
        ),
      ],
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
      builder: (_) => _CategorySheet(
        categories: categories,
        onSelect: (cat) => setState(() => _selectedCategory = cat),
      ),
    );
  }

  Widget _buildWalletPicker(List<WalletModel> wallets) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isExpense ? 'Dari Dompet' : 'Ke Dompet',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        if (wallets.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              'Belum ada dompet. Tambahkan di halaman Aset.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
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
                          ? color.withValues(alpha: 0.12)
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

  Widget _buildDateTimePicker() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: GestureDetector(
            onTap: _pickDate,
            child: _PickerBox(
              icon: Icons.calendar_today_rounded,
              label: DateFormat('dd MMM yyyy', 'id').format(_selectedDate),
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
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CategoryModel> get _searchResults {
    final q = _query.toLowerCase();
    final notifier = ref.read(categoryProvider.notifier);
    final results = <CategoryModel>[];
    for (final main in widget.categories) {
      if (main.name.toLowerCase().contains(q)) results.add(main);
      results.addAll(
        notifier.subCategories(main.id).where(
              (s) => s.name.toLowerCase().contains(q),
            ),
      );
    }
    return results;
  }

  Widget _buildTile(CategoryModel cat, {required bool allowNavigation}) {
    final hasSubs = allowNavigation &&
        ref.read(categoryProvider.notifier).subCategories(cat.id).isNotEmpty;
    final color = Color(int.parse(cat.color.replaceFirst('#', '0xFF')));
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Center(
          child: Text(cat.icon, style: const TextStyle(fontSize: 18)),
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
          ? const Icon(Icons.chevron_right_rounded, color: AppColors.textHint)
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
  }

  @override
  Widget build(BuildContext context) {
    final isSearching = _query.isNotEmpty;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        children: [
          // ── Drag handle ──────────────────────────────────────
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

          // ── Header ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                if (_selectedParent != null && !isSearching)
                  IconButton(
                    onPressed: () => setState(() => _selectedParent = null),
                    icon: const Icon(Icons.arrow_back_rounded),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                if (_selectedParent != null && !isSearching)
                  const SizedBox(width: 4),
                Text(
                  isSearching
                      ? 'Cari Kategori'
                      : _selectedParent?.name ?? 'Pilih Kategori',
                  style: AppTextStyles.h4,
                ),
              ],
            ),
          ),

          // ── Search field ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() {
                _query = v;
                if (v.isNotEmpty) _selectedParent = null;
              }),
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Cari kategori...',
                hintStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: AppColors.textHint,
                ),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 18, color: AppColors.textHint),
                suffixIcon: isSearching
                    ? GestureDetector(
                        onTap: () => setState(() {
                          _query = '';
                          _searchController.clear();
                        }),
                        child: const Icon(Icons.close_rounded,
                            size: 18, color: AppColors.textHint),
                      )
                    : null,
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // ── List ─────────────────────────────────────────────
          Expanded(
            child: isSearching
                ? _searchResults.isEmpty
                    ? const Center(
                        child: Text(
                          'Kategori tidak ditemukan',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : ListView(
                        children: _searchResults
                            .map((cat) =>
                                _buildTile(cat, allowNavigation: false))
                            .toList(),
                      )
                : ListView(
                    children: [
                      if (_selectedParent != null)
                        ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Color(int.parse(
                                _selectedParent!.color
                                    .replaceFirst('#', '0xFF'),
                              )).withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Center(
                              child: Text(_selectedParent!.icon,
                                  style: const TextStyle(fontSize: 18)),
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
                              size: 20),
                          onTap: () {
                            widget.onSelect(_selectedParent!);
                            Navigator.pop(context);
                          },
                        ),
                      ...(_selectedParent == null
                              ? widget.categories
                              : ref
                                  .read(categoryProvider.notifier)
                                  .subCategories(_selectedParent!.id))
                          .map((cat) =>
                              _buildTile(cat, allowNavigation: _selectedParent == null)),
                    ],
                  ),
          ),
        ],
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
