import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/hive/models/debt_model.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../../../shared/widgets/app_card.dart';
import '../providers/debt_provider.dart';
import '../widgets/debt_form_sheet.dart';
import '../widgets/payment_sheet.dart';

class DebtPage extends ConsumerStatefulWidget {
  const DebtPage({super.key});

  @override
  ConsumerState<DebtPage> createState() => _DebtPageState();
}

class _DebtPageState extends ConsumerState<DebtPage>
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
    final notifier = ref.watch(debtProvider.notifier);
    ref.watch(debtProvider); // trigger rebuild

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Hutang & Piutang', style: AppTextStyles.h3),
        centerTitle: false,
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _buildTabBar(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab Piutang
          _DebtListTab(
            type: 'receivable',
            emptyEmoji: '💸',
            emptyTitle: 'Belum ada piutang',
            emptyDesc: 'Catat uang yang dipinjamkan ke orang lain',
            onAdd: () => _showForm(context, 'receivable'),
          ),
          // Tab Hutang
          _DebtListTab(
            type: 'debt',
            emptyEmoji: '🤝',
            emptyTitle: 'Belum ada hutang',
            emptyDesc: 'Catat hutangmu agar tidak lupa',
            onAdd: () => _showForm(context, 'debt'),
          ),
        ],
      ),
      // FAB berubah sesuai tab aktif
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (_, __) => FloatingActionButton.extended(
          onPressed: () => _showForm(
            context,
            _tabController.index == 0 ? 'receivable' : 'debt',
          ),
          backgroundColor:
              _tabController.index == 0 ? AppColors.income : AppColors.expense,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text(
            _tabController.index == 0 ? 'Tambah Piutang' : 'Tambah Hutang',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.border.withOpacity(0.4),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelPadding: EdgeInsets.zero,
          tabs: [
            _TabItem(
              label: 'Piutang',
              color: AppColors.income,
              isActive: _tabController.index == 0,
            ),
            _TabItem(
              label: 'Hutang',
              color: AppColors.expense,
              isActive: _tabController.index == 1,
            ),
          ],
        ),
      ),
    );
  }

  void _showForm(BuildContext context, String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DebtFormSheet(type: type),
    );
  }
}

// ── Tab Widget ────────────────────────────────────────────────────────────────

class _TabItem extends StatelessWidget {
  final String label;
  final Color color;
  final bool isActive;

  const _TabItem({
    required this.label,
    required this.color,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Debt List Tab ─────────────────────────────────────────────────────────────

class _DebtListTab extends ConsumerWidget {
  final String type;
  final String emptyEmoji;
  final String emptyTitle;
  final String emptyDesc;
  final VoidCallback onAdd;

  const _DebtListTab({
    required this.type,
    required this.emptyEmoji,
    required this.emptyTitle,
    required this.emptyDesc,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(debtProvider.notifier);
    final items = type == 'receivable'
        ? notifier.activeReceivables
        : notifier.activeDebts;
    final total =
        type == 'receivable' ? notifier.totalReceivable : notifier.totalDebt;

    if (items.isEmpty) {
      return Column(
        children: [
          if (total > 0) _SummaryBanner(type: type, total: total),
          Expanded(
            child: AppEmptyState(
              emoji: emptyEmoji,
              title: emptyTitle,
              description: emptyDesc,
              actionLabel:
                  type == 'receivable' ? 'Tambah Piutang' : 'Tambah Hutang',
              onAction: onAdd,
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        100,
      ),
      children: [
        // Summary banner
        _SummaryBanner(type: type, total: total),
        const SizedBox(height: AppSpacing.md),

        // List
        ...items.map((debt) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _DebtCard(
                debt: debt,
                onPayment: () => _showPayment(context, debt),
                onDelete: () => _confirmDelete(context, ref, debt),
              ),
            )),
      ],
    );
  }

  void _showPayment(BuildContext context, DebtModel debt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaymentSheet(debt: debt),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, DebtModel debt) async {
    final confirm = await showConfirmSheet(
      context: context,
      title: type == 'receivable' ? 'Hapus Piutang' : 'Hapus Hutang',
      description: 'Hapus catatan dengan ${debt.personName}?',
      confirmLabel: 'Ya, Hapus',
    );
    if (confirm == true) {
      ref.read(debtProvider.notifier).delete(debt.id);
    }
  }
}

// ── Summary Banner ────────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  final String type;
  final double total;

  const _SummaryBanner({required this.type, required this.total});

  @override
  Widget build(BuildContext context) {
    final isReceivable = type == 'receivable';
    final color = isReceivable ? AppColors.income : AppColors.expense;
    final label = isReceivable ? 'Total Piutang' : 'Total Hutang';
    final icon = isReceivable
        ? Icons.arrow_downward_rounded
        : Icons.arrow_upward_rounded;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.caption),
              Text(
                CurrencyFormatter.format(total),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Debt Card ─────────────────────────────────────────────────────────────────

class _DebtCard extends StatelessWidget {
  final DebtModel debt;
  final VoidCallback onPayment;
  final VoidCallback onDelete;

  const _DebtCard({
    required this.debt,
    required this.onPayment,
    required this.onDelete,
  });

  bool get isReceivable => debt.type == 'receivable';

  Color get _color => isReceivable ? AppColors.income : AppColors.expense;

  double get _progressValue => debt.totalAmount > 0
      ? (1 - debt.remainingAmount / debt.totalAmount).clamp(0.0, 1.0)
      : 0;

  @override
  Widget build(BuildContext context) {
    final daysLeft = debt.deadline != null
        ? debt.deadline!.difference(DateTime.now()).inDays
        : null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Center(
                  child: Text(
                    debt.personName.isNotEmpty
                        ? debt.personName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(debt.personName, style: AppTextStyles.bodyMedium),
                    if (debt.note != null && debt.note!.isNotEmpty)
                      Text(debt.note!, style: AppTextStyles.small),
                    if (daysLeft != null)
                      Text(
                        daysLeft <= 0
                            ? 'Sudah jatuh tempo!'
                            : 'Jatuh tempo $daysLeft hari lagi',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: daysLeft <= 3
                              ? AppColors.danger
                              : AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),

              // Jumlah
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(debt.remainingAmount),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _color,
                    ),
                  ),
                  if (debt.remainingAmount < debt.totalAmount)
                    Text(
                      'dari ${CurrencyFormatter.formatCompact(debt.totalAmount)}',
                      style: AppTextStyles.small,
                    ),
                ],
              ),

              const SizedBox(width: 4),

              // Actions
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded,
                    color: AppColors.textHint, size: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'pay',
                    child: Row(children: [
                      Icon(
                        isReceivable
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        size: 16,
                        color: _color,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isReceivable ? 'Terima Bayaran' : 'Bayar',
                        style: const TextStyle(fontFamily: 'Poppins'),
                      ),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_rounded,
                          size: 16, color: AppColors.danger),
                      SizedBox(width: 8),
                      Text('Hapus',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: AppColors.danger,
                          )),
                    ]),
                  ),
                ],
                onSelected: (val) {
                  if (val == 'pay') onPayment();
                  if (val == 'delete') onDelete();
                },
              ),
            ],
          ),

          // Progress bar pembayaran
          if (debt.payments.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: LinearProgressIndicator(
                value: _progressValue,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation<Color>(_color),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Terbayar ${(_progressValue * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: _color,
                  ),
                ),
                Text(
                  '${debt.payments.length}x pembayaran',
                  style: AppTextStyles.small,
                ),
              ],
            ),
          ],

          // Tombol bayar
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onPayment,
              icon: Icon(
                isReceivable
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                size: 16,
                color: _color,
              ),
              label: Text(
                isReceivable ? 'Terima Pembayaran' : 'Bayar Hutang',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _color,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                side: BorderSide(color: _color.withOpacity(0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
