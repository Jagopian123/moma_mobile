import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/hive/hive_service.dart';
import '../../../core/hive/models/category_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/hive/models/transaction_model.dart';
import '../../../shared/widgets/app_card.dart';
import '../providers/transaction_provider.dart';
import '../widgets/transaction_card.dart';

class CustomTab extends ConsumerStatefulWidget {
  const CustomTab({super.key});

  @override
  ConsumerState<CustomTab> createState() => _CustomTabState();
}

class _CustomTabState extends ConsumerState<CustomTab> {
  DateTime _from = DateTime.now().subtract(const Duration(days: 6));
  DateTime _to = DateTime.now();
  String? _selectedCategoryId;

  // ── Quick range helpers ──────────────────────────────────────────────────────

  bool get _isThisWeek {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(_from.year, _from.month, _from.day) == weekStart &&
        DateTime(_to.year, _to.month, _to.day) == today;
  }

  bool get _isThisMonth {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(_from.year, _from.month, _from.day) == monthStart &&
        DateTime(_to.year, _to.month, _to.day) == today;
  }

  void _setThisWeek() {
    final now = DateTime.now();
    setState(() {
      _from = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));
      _to = now;
    });
  }

  void _setThisMonth() {
    final now = DateTime.now();
    setState(() {
      _from = DateTime(now.year, now.month, 1);
      _to = now;
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _from = picked.start;
        _to = picked.end;
      });
    }
  }

  // ── Category filter ──────────────────────────────────────────────────────────

  Future<void> _showCategoryPicker() async {
    final all = HiveService.categories.values.toList();
    final parents = all.where((c) => c.parentId == null).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CategoryPickerSheet(
        allCategories: all,
        parents: parents,
        selectedId: _selectedCategoryId,
        onSelect: (id) => setState(() => _selectedCategoryId = id),
      ),
    );
  }

  String get _categoryLabel {
    if (_selectedCategoryId == null) return 'Semua Kategori';
    final cat = HiveService.categories.get(_selectedCategoryId);
    if (cat == null) return 'Semua Kategori';
    return '${cat.icon} ${cat.name}';
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final allTx = ref.watch(transactionProvider);
    final from = DateTime(_from.year, _from.month, _from.day);
    final to = DateTime(_to.year, _to.month, _to.day, 23, 59, 59);

    var transactions = allTx
        .where((tx) =>
            tx.date.isAfter(from.subtract(const Duration(seconds: 1))) &&
            tx.date.isBefore(to.add(const Duration(seconds: 1))))
        .toList();

    if (_selectedCategoryId != null) {
      transactions = transactions
          .where((tx) => tx.categoryId == _selectedCategoryId)
          .toList();
    }

    transactions.sort((a, b) => b.date.compareTo(a.date));

    final income = transactions
        .where((t) => t.type == 'income')
        .fold(0.0, (s, t) => s + t.amount);
    final expense = transactions
        .where((t) => t.type == 'expense')
        .fold(0.0, (s, t) => s + t.amount);

    final grouped = <DateTime, List<TransactionModel>>{};
    for (final tx in transactions) {
      final date = DateTime(tx.date.year, tx.date.month, tx.date.day);
      grouped.putIfAbsent(date, () => []).add(tx);
    }
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // ── Quick chips + date picker (1 row) ────────────────
        Row(
          children: [
            _QuickChip(
              label: 'Minggu Ini',
              selected: _isThisWeek,
              onTap: _setThisWeek,
            ),
            const SizedBox(width: AppSpacing.sm),
            _QuickChip(
              label: 'Bulan Ini',
              selected: _isThisMonth,
              onTap: _setThisMonth,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: GestureDetector(
                onTap: _pickDateRange,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.date_range_rounded,
                          size: 15, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '${DateFormat('dd MMM', 'id').format(_from)}'
                          ' – '
                          '${DateFormat('dd MMM', 'id').format(_to)}',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 15, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // ── Category filter ──────────────────────────────────
        GestureDetector(
          onTap: _showCategoryPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: _selectedCategoryId != null
                  ? AppColors.primary.withValues(alpha: 0.07)
                  : AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: _selectedCategoryId != null
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.category_rounded,
                  size: 18,
                  color: _selectedCategoryId != null
                      ? AppColors.primary
                      : AppColors.textHint,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _categoryLabel,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _selectedCategoryId != null
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                if (_selectedCategoryId != null)
                  GestureDetector(
                    onTap: () => setState(() => _selectedCategoryId = null),
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: AppColors.primary),
                  )
                else
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 18, color: AppColors.textHint),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Summary ──────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: AppSummaryCard(
                label: 'Pemasukan',
                amount: CurrencyFormatter.formatCompact(income),
                icon: Icons.arrow_downward_rounded,
                color: AppColors.income,
                bgColor: AppColors.income.withValues(alpha: 0.08),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppSummaryCard(
                label: 'Pengeluaran',
                amount: CurrencyFormatter.formatCompact(expense),
                icon: Icons.arrow_upward_rounded,
                color: AppColors.expense,
                bgColor: AppColors.expense.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // ── Transaction list ─────────────────────────────────
        if (transactions.isEmpty)
          AppEmptyState(
            emoji: '🔍',
            imagePath: 'assets/images/mascot-transaksi.png',
            title: 'Tidak ada transaksi',
            description: _selectedCategoryId != null
                ? 'Tidak ada transaksi untuk kategori ini pada rentang tanggal ini'
                : 'Tidak ada transaksi pada rentang tanggal ini',
          )
        else
          ...sortedDates.map((date) {
            final txList = grouped[date]!;
            final dayIncome = txList
                .where((t) => t.type == 'income')
                .fold(0.0, (s, t) => s + t.amount);
            final dayExpense = txList
                .where((t) => t.type == 'expense')
                .fold(0.0, (s, t) => s + t.amount);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TransactionDateHeader(
                  date: date,
                  totalIncome: dayIncome,
                  totalExpense: dayExpense,
                ),
                ...txList.map((tx) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: TransactionCard(transaction: tx),
                    )),
              ],
            );
          }),
      ],
    );
  }
}

// ── Quick Chip ────────────────────────────────────────────────────────────────

class _QuickChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _QuickChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Category Picker Sheet ─────────────────────────────────────────────────────

class _CategoryPickerSheet extends StatefulWidget {
  final List<CategoryModel> allCategories;
  final List<CategoryModel> parents;
  final String? selectedId;
  final void Function(String?) onSelect;

  const _CategoryPickerSheet({
    required this.allCategories,
    required this.parents,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
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
    return widget.allCategories
        .where((c) => c.name.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<CategoryModel> _subsOf(String parentId) => widget.allCategories
      .where((c) => c.parentId == parentId)
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  Color _catColor(CategoryModel cat) =>
      Color(int.parse(cat.color.replaceFirst('#', '0xFF')));

  @override
  Widget build(BuildContext context) {
    final isSearching = _query.isNotEmpty;
    final showingParent = _selectedParent != null && !isSearching;

    // Header title
    String title;
    if (isSearching) {
      title = 'Hasil Pencarian';
    } else if (showingParent) {
      title = _selectedParent!.name;
    } else {
      title = 'Filter Kategori';
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        children: [
          // Handle
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

          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                if (showingParent)
                  GestureDetector(
                    onTap: () => setState(() => _selectedParent = null),
                    child: const Padding(
                      padding: EdgeInsets.only(right: AppSpacing.sm),
                      child: Icon(Icons.arrow_back_rounded, size: 20),
                    ),
                  ),
                Expanded(
                    child: Text(title, style: AppTextStyles.h4)),
              ],
            ),
          ),

          // Search field
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
                suffixIcon: _query.isNotEmpty
                    ? GestureDetector(
                        onTap: () => setState(() {
                          _query = '';
                          _searchController.clear();
                        }),
                        child: const Icon(Icons.close_rounded,
                            size: 16, color: AppColors.textHint),
                      )
                    : null,
                filled: true,
                fillColor: AppColors.background,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // List
          Expanded(
            child: ListView(
              children: [
                if (isSearching) ...[
                  // Flat search results
                  if (_searchResults.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Center(
                        child: Text(
                          'Kategori tidak ditemukan',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
                    )
                  else
                    ..._searchResults.map((cat) => _buildTile(cat, false)),
                ] else if (showingParent) ...[
                  // Subcategory view: "Semua [Parent]" + subs
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _catColor(_selectedParent!)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
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
                    trailing: const Icon(Icons.check_circle_outline_rounded,
                        color: AppColors.primary, size: 20),
                    onTap: () {
                      widget.onSelect(_selectedParent!.id);
                      Navigator.pop(context);
                    },
                  ),
                  ..._subsOf(_selectedParent!.id)
                      .map((sub) => _buildTile(sub, false)),
                ] else ...[
                  // Root view: "Semua Kategori" + parents
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Center(
                        child:
                            Text('📋', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    title: const Text(
                      'Semua Kategori',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: widget.selectedId == null
                        ? const Icon(Icons.check_rounded,
                            color: AppColors.primary, size: 18)
                        : null,
                    onTap: () {
                      widget.onSelect(null);
                      Navigator.pop(context);
                    },
                  ),
                  ...widget.parents.map((parent) {
                    final hasSubs = _subsOf(parent.id).isNotEmpty;
                    return _buildTile(parent, hasSubs);
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(CategoryModel cat, bool hasSubs) {
    final isSelected = widget.selectedId == cat.id;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _catColor(cat).withValues(alpha: 0.12),
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
          ? const Icon(Icons.chevron_right_rounded,
              color: AppColors.textHint)
          : isSelected
              ? const Icon(Icons.check_rounded,
                  color: AppColors.primary, size: 18)
              : null,
      onTap: () {
        if (hasSubs) {
          setState(() => _selectedParent = cat);
        } else {
          widget.onSelect(cat.id);
          Navigator.pop(context);
        }
      },
    );
  }
}
