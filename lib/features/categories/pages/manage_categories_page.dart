import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/hive/models/category_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_input.dart';
import '../../transaction/providers/category_provider.dart';

// ── Color palette for new categories ─────────────────────────────────────────

const _kColors = [
  '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7', '#DDA0DD',
  '#F8B500', '#A29BFE', '#55EFC4', '#636E72', '#FDCB6E', '#00B894',
  '#8B5CF6', '#F97316', '#6366F1', '#EC4899',
];

Color _hexToColor(String hex) {
  final h = hex.replaceAll('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

String _typeLabel(String type) {
  switch (type) {
    case 'income':
      return 'Pemasukan';
    case 'both':
      return 'Keduanya';
    default:
      return 'Pengeluaran';
  }
}

Color _typeColor(String type) {
  switch (type) {
    case 'income':
      return AppColors.income;
    case 'both':
      return AppColors.transfer;
    default:
      return AppColors.expense;
  }
}

// ── Page ──────────────────────────────────────────────────────────────────────

class ManageCategoriesPage extends ConsumerStatefulWidget {
  const ManageCategoriesPage({super.key});

  @override
  ConsumerState<ManageCategoriesPage> createState() =>
      _ManageCategoriesPageState();
}

class _ManageCategoriesPageState extends ConsumerState<ManageCategoriesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kelola Kategori', style: AppTextStyles.h3),
        backgroundColor: AppColors.background,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: _buildTabBar(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(null),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Tambah',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _CategoryTabView(
            typeFilter: 'expense',
            onEdit: _showForm,
            onDelete: _confirmDelete,
          ),
          _CategoryTabView(
            typeFilter: 'income',
            onEdit: _showForm,
            onDelete: _confirmDelete,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.border.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Pengeluaran'),
            Tab(text: 'Pemasukan'),
          ],
        ),
      ),
    );
  }

  Future<void> _showForm(CategoryModel? existing) async {
    final all = ref.read(categoryProvider);
    final parents = all.where((c) => c.parentId == null).toList();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategoryFormSheet(
        existing: existing,
        allParents: parents,
        onSave: ({
          required String name,
          required String icon,
          required String color,
          required String type,
          String? parentId,
        }) async {
          if (existing == null) {
            await ref.read(categoryProvider.notifier).addCategory(
                  name: name,
                  icon: icon,
                  color: color,
                  type: type,
                  parentId: parentId,
                );
          } else {
            await ref.read(categoryProvider.notifier).updateCategory(
                  id: existing.id,
                  name: name,
                  icon: icon,
                  color: color,
                  type: type,
                );
          }
        },
      ),
    );
  }

  Future<void> _confirmDelete(CategoryModel cat) async {
    final all = ref.read(categoryProvider);
    final notifier = ref.read(categoryProvider.notifier);
    final txCount = notifier.transactionCountFor(cat.id);
    final userSubs =
        all.where((c) => c.parentId == cat.id && !c.isDefault).toList();

    final lines = <String>[];
    if (cat.parentId == null && userSubs.isNotEmpty) {
      lines.add('${userSubs.length} sub-kategori milikmu akan ikut dihapus.');
    }
    if (txCount > 0) {
      lines.add(
        'Kategori ini digunakan di $txCount transaksi. '
        'Transaksinya tidak akan dihapus, tapi referensi kategorinya akan hilang.',
      );
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text(
          'Hapus Kategori?',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kategori "${cat.name}" akan dihapus permanen.',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
            ),
            if (lines.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...lines.map(
                (l) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('⚠️ ', style: TextStyle(fontSize: 13)),
                      Expanded(
                        child: Text(
                          l,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Batal',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: const Text(
              'Hapus',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await notifier.deleteCategory(cat.id);
    }
  }
}

// ── Tab View ──────────────────────────────────────────────────────────────────

class _CategoryTabView extends ConsumerWidget {
  final String typeFilter;
  final void Function(CategoryModel?) onEdit;
  final void Function(CategoryModel) onDelete;

  const _CategoryTabView({
    required this.typeFilter,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(categoryProvider);
    final parents = all.where((c) {
      if (c.parentId != null) return false;
      if (typeFilter == 'expense') return c.type == 'expense' || c.type == 'both';
      return c.type == 'income' || c.type == 'both';
    }).toList();

    if (parents.isEmpty) {
      return Center(
        child: Text(
          'Tidak ada kategori ${typeFilter == 'expense' ? 'pengeluaran' : 'pemasukan'}',
          style: const TextStyle(
            fontFamily: 'Poppins',
            color: AppColors.textHint,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md, AppSpacing.sm, AppSpacing.md, 100,
      ),
      itemCount: parents.length,
      itemBuilder: (context, i) {
        final parent = parents[i];
        final subs = all.where((c) => c.parentId == parent.id).toList();
        return _ParentTile(
          parent: parent,
          subs: subs,
          onEdit: onEdit,
          onDelete: onDelete,
        );
      },
    );
  }
}

// ── Parent Tile ───────────────────────────────────────────────────────────────

class _ParentTile extends StatelessWidget {
  final CategoryModel parent;
  final List<CategoryModel> subs;
  final void Function(CategoryModel) onEdit;
  final void Function(CategoryModel) onDelete;

  const _ParentTile({
    required this.parent,
    required this.subs,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final catColor = _hexToColor(parent.color);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 4,
          ),
          childrenPadding: EdgeInsets.zero,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: catColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Center(
              child: Text(parent.icon, style: const TextStyle(fontSize: 20)),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  parent.name,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _TypeBadge(type: parent.type),
              if (parent.isDefault) ...[
                const SizedBox(width: 6),
                _SystemBadge(),
              ],
            ],
          ),
          subtitle: subs.isNotEmpty
              ? Text(
                  '${subs.length} sub-kategori',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                )
              : null,
          trailing: parent.isDefault
              ? const Icon(Icons.expand_more_rounded, color: AppColors.textHint)
              : PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.textHint,
                    size: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded,
                              size: 18, color: AppColors.textSecondary),
                          SizedBox(width: 10),
                          Text('Edit',
                              style: TextStyle(fontFamily: 'Poppins')),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_rounded,
                              size: 18, color: AppColors.danger),
                          SizedBox(width: 10),
                          Text('Hapus',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: AppColors.danger)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (v) =>
                      v == 'edit' ? onEdit(parent) : onDelete(parent),
                ),
          children: [
            if (subs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  'Belum ada sub-kategori',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                ),
              )
            else
              ...subs.map((sub) => _SubTile(
                    sub: sub,
                    parentColor: catColor,
                    onEdit: () => onEdit(sub),
                    onDelete: () => onDelete(sub),
                  )),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

// ── Sub Tile ──────────────────────────────────────────────────────────────────

class _SubTile extends StatelessWidget {
  final CategoryModel sub;
  final Color parentColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SubTile({
    required this.sub,
    required this.parentColor,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(height: 1, indent: 16, color: AppColors.border),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 10,
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: parentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Center(
                  child: Text(sub.icon, style: const TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  sub.name,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (sub.isDefault)
                _SystemBadge()
              else
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.textHint,
                    size: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded,
                              size: 18, color: AppColors.textSecondary),
                          SizedBox(width: 10),
                          Text('Edit',
                              style: TextStyle(fontFamily: 'Poppins')),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_rounded,
                              size: 18, color: AppColors.danger),
                          SizedBox(width: 10),
                          Text('Hapus',
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: AppColors.danger)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Badges ────────────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        _typeLabel(type),
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _SystemBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.textHint.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: const Text(
        'Sistem',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.textHint,
        ),
      ),
    );
  }
}

// ── Form Sheet ────────────────────────────────────────────────────────────────

typedef _OnSave = Future<void> Function({
  required String name,
  required String icon,
  required String color,
  required String type,
  String? parentId,
});

class _CategoryFormSheet extends StatefulWidget {
  final CategoryModel? existing;
  final List<CategoryModel> allParents;
  final _OnSave onSave;

  const _CategoryFormSheet({
    required this.existing,
    required this.allParents,
    required this.onSave,
  });

  @override
  State<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<_CategoryFormSheet> {
  final _nameCtrl = TextEditingController();
  final _iconCtrl = TextEditingController();
  bool _isSubCategory = false;
  String _selectedColor = _kColors[0];
  String _type = 'expense';
  CategoryModel? _selectedParent;
  bool _loading = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _iconCtrl.text = e.icon;
      _selectedColor = e.color;
      _type = e.type;
      _isSubCategory = e.parentId != null;
      if (e.parentId != null) {
        _selectedParent = widget.allParents
            .where((p) => p.id == e.parentId)
            .firstOrNull;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _iconCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickParent() async {
    final picked = await showModalBottomSheet<CategoryModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ParentPickerSheet(parents: widget.allParents),
    );
    if (picked != null) {
      setState(() => _selectedParent = picked);
    }
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final icon = _iconCtrl.text.trim();
    if (name.isEmpty) {
      _showError('Nama kategori tidak boleh kosong');
      return;
    }
    if (icon.isEmpty) {
      _showError('Ikon tidak boleh kosong');
      return;
    }
    if (_isSubCategory && _selectedParent == null) {
      _showError('Pilih kategori induk terlebih dahulu');
      return;
    }

    setState(() => _loading = true);
    try {
      final parentId = _isSubCategory ? _selectedParent!.id : null;
      final color = _isSubCategory ? _selectedParent!.color : _selectedColor;
      final type = _isSubCategory ? _selectedParent!.type : _type;

      await widget.onSave(
        name: name,
        icon: icon,
        color: color,
        type: type,
        parentId: parentId,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Poppins')),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg + bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              _isEdit ? 'Edit Kategori' : 'Tambah Kategori',
              style: AppTextStyles.h3,
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Tipe toggle (hanya saat tambah baru) ─────────────
            if (!_isEdit) ...[
              const Text(
                'Tipe',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _ToggleChip(
                    label: 'Kategori Utama',
                    selected: !_isSubCategory,
                    onTap: () => setState(() => _isSubCategory = false),
                  ),
                  const SizedBox(width: 8),
                  _ToggleChip(
                    label: 'Sub-Kategori',
                    selected: _isSubCategory,
                    onTap: () => setState(() => _isSubCategory = true),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // ── Parent picker (hanya untuk sub-kategori) ──────────
            if (_isSubCategory) ...[
              const Text(
                'Kategori Induk',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _pickParent,
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
                      if (_selectedParent != null) ...[
                        Text(
                          _selectedParent!.icon,
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedParent!.name,
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
                            'Pilih kategori induk',
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
              const SizedBox(height: AppSpacing.md),
            ],

            // ── Nama ──────────────────────────────────────────────
            AppInput(
              label: 'Nama Kategori',
              hint: 'contoh: Hobi, Olahraga',
              controller: _nameCtrl,
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Ikon ──────────────────────────────────────────────
            AppInput(
              label: 'Ikon (emoji)',
              hint: 'Ketik emoji, contoh: 🏋️',
              controller: _iconCtrl,
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Warna (hanya untuk kategori utama) ───────────────
            if (!_isSubCategory) ...[
              const Text(
                'Warna',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _kColors.map((hex) {
                  final isSelected = _selectedColor == hex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = hex),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _hexToColor(hex),
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: AppColors.textPrimary, width: 2.5)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: _hexToColor(hex).withValues(alpha: 0.5),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Tipe transaksi ────────────────────────────────
              const Text(
                'Tipe Transaksi',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final entry in [
                    ('expense', 'Pengeluaran'),
                    ('income', 'Pemasukan'),
                    ('both', 'Keduanya'),
                  ])
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _type = entry.$1),
                        child: Container(
                          margin: entry.$1 != 'both'
                              ? const EdgeInsets.only(right: 6)
                              : null,
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _type == entry.$1
                                ? _hexToColor(_selectedColor)
                                : AppColors.background,
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: _type == entry.$1
                                  ? _hexToColor(_selectedColor)
                                  : AppColors.border,
                            ),
                          ),
                          child: Text(
                            entry.$2,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _type == entry.$1
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ] else ...[
              const SizedBox(height: AppSpacing.lg),
            ],

            // ── Save button ───────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        _isEdit ? 'Simpan Perubahan' : 'Tambah Kategori',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Parent Picker Sheet ───────────────────────────────────────────────────────

class _ParentPickerSheet extends StatelessWidget {
  final List<CategoryModel> parents;

  const _ParentPickerSheet({required this.parents});

  @override
  Widget build(BuildContext context) {
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
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Pilih Kategori Induk', style: AppTextStyles.h4),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: parents.length,
              itemBuilder: (context, i) {
                final cat = parents[i];
                final catColor = _hexToColor(cat.color);
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 4,
                  ),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.12),
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
                  subtitle: Text(
                    _typeLabel(cat.type),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: _typeColor(cat.type),
                    ),
                  ),
                  onTap: () => Navigator.pop(context, cat),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Toggle Chip ───────────────────────────────────────────────────────────────

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.background,
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
