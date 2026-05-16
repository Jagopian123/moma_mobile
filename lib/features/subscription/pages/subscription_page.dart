import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/hive/models/subscription_model.dart';
import '../../../core/hive/models/wallet_model.dart';
import '../../../core/hive/hive_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../../../shared/widgets/app_card.dart';
import '../providers/subscription_provider.dart';
import '../widgets/subscription_form_sheet.dart';
import '../../transaction/providers/transaction_provider.dart';

class SubscriptionPage extends ConsumerStatefulWidget {
  const SubscriptionPage({super.key});

  @override
  ConsumerState<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends ConsumerState<SubscriptionPage>
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

  void _showForm({SubscriptionModel? existing}) {
    showAppBottomSheet(
      context: context,
      title: existing == null ? 'Tambah Langganan' : 'Edit Langganan',
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      child: SubscriptionFormSheet(existing: existing),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subs = ref.watch(subscriptionProvider);
    final notifier = ref.read(subscriptionProvider.notifier);
    final active = notifier.active;
    final all = subs;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kelola Langganan', style: AppTextStyles.h3),
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
          // Tab Aktif
          _SubscriptionTab(
            subs: active,
            notifier: notifier,
            emptyEmoji: '📋',
            emptyImagePath: 'assets/images/mascot-langganan.png',
            emptyTitle: 'Belum ada langganan aktif',
            emptyDesc: 'Tambahkan layanan berlangganan yang kamu pakai',
            onAdd: _showForm,
            onEdit: (s) => _showForm(existing: s),
            showSummary: true,
          ),
          // Tab Semua
          _SubscriptionTab(
            subs: all,
            notifier: notifier,
            emptyEmoji: '📦',
            emptyImagePath: 'assets/images/mascot-langganan.png',
            emptyTitle: 'Belum ada langganan',
            emptyDesc: 'Mulai tambahkan layanan berlanggananmu',
            onAdd: _showForm,
            onEdit: (s) => _showForm(existing: s),
            showSummary: false,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showForm,
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
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
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
            Tab(text: 'Aktif'),
            Tab(text: 'Semua'),
          ],
        ),
      ),
    );
  }
}

// ── Tab Content ───────────────────────────────────────────────────────────────

class _SubscriptionTab extends ConsumerWidget {
  final List<SubscriptionModel> subs;
  final SubscriptionNotifier notifier;
  final String emptyEmoji;
  final String emptyTitle;
  final String emptyDesc;
  final String? emptyImagePath;
  final VoidCallback onAdd;
  final ValueChanged<SubscriptionModel> onEdit;
  final bool showSummary;

  const _SubscriptionTab({
    required this.subs,
    required this.notifier,
    required this.emptyEmoji,
    required this.emptyTitle,
    required this.emptyDesc,
    this.emptyImagePath,
    required this.onAdd,
    required this.onEdit,
    required this.showSummary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (subs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emptyImagePath != null)
                Image.asset(
                  emptyImagePath!,
                  width: 120,
                  height: 120,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      Text(emptyEmoji, style: const TextStyle(fontSize: 56)),
                )
              else
                Text(emptyEmoji, style: const TextStyle(fontSize: 56)),
              const SizedBox(height: AppSpacing.md),
              Text(emptyTitle,
                  style: AppTextStyles.h4, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text(emptyDesc,
                  style: AppTextStyles.caption, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Tambah Langganan'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  foregroundColor: AppColors.primary,
                  textStyle: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final overdue = notifier.overdue;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, 100),
      children: [
        if (showSummary && overdue.isNotEmpty) ...[
          _OverdueBanner(
            count: overdue.length,
            onTap: () => showAppBottomSheet(
              context: context,
              title: 'Konfirmasi Pembayaran',
              child: _OverduePaymentSheet(
                subs: overdue,
                subNotifier: notifier,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (showSummary) ...[
          _SummaryBanner(notifier: notifier),
          const SizedBox(height: AppSpacing.md),
        ],
        ...subs.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _SubscriptionCard(
              sub: s,
              notifier: notifier,
              onEdit: onEdit,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Summary Banner ────────────────────────────────────────────────────────────

class _SummaryBanner extends ConsumerWidget {
  final SubscriptionNotifier notifier;

  const _SummaryBanner({required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(subscriptionProvider); // rebuild on change
    final monthly = notifier.totalMonthly;
    final yearly = notifier.totalYearly;
    final count = notifier.active.length;

    return AppGradientCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total per bulan',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  CurrencyFormatter.format(monthly),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '~${CurrencyFormatter.format(yearly)}/tahun',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              '$count aktif',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Subscription Card ─────────────────────────────────────────────────────────

class _SubscriptionCard extends ConsumerWidget {
  final SubscriptionModel sub;
  final SubscriptionNotifier notifier;
  final ValueChanged<SubscriptionModel> onEdit;

  const _SubscriptionCard({
    required this.sub,
    required this.notifier,
    required this.onEdit,
  });

  Color get _statusColor {
    switch (sub.status) {
      case 'paused':
        return AppColors.warning;
      case 'cancelled':
        return AppColors.danger;
      default:
        return AppColors.income;
    }
  }

  String get _statusLabel {
    switch (sub.status) {
      case 'paused':
        return 'Dijeda';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return 'Aktif';
    }
  }

  String get _cycleLabel {
    switch (sub.cycle) {
      case 'yearly':
        return '/tahun';
      case 'weekly':
        return '/minggu';
      default:
        return '/bulan';
    }
  }

  bool get _isOverdue =>
      sub.status == 'active' && sub.nextBillingDate.isBefore(DateTime.now());

  bool get _isDueSoon {
    if (sub.status != 'active' || _isOverdue) return false;
    final diff = sub.nextBillingDate.difference(DateTime.now()).inDays;
    return diff >= 0 && diff <= 3;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Color(sub.color).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Center(
                  child: Text(sub.icon, style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            sub.name,
                            style: AppTextStyles.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            _statusLabel,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          _categoryLabel(sub.category),
                          style: AppTextStyles.small,
                        ),
                        if (sub.walletName != null) ...[
                          const Text(' · ',
                              style: TextStyle(
                                  color: AppColors.textHint, fontSize: 11)),
                          Text(sub.walletName!, style: AppTextStyles.small),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded,
                    size: 18, color: AppColors.textHint),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                onSelected: (v) => _handleMenu(context, ref, v),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'record',
                    child: Row(children: [
                      Icon(
                        _isOverdue
                            ? Icons.check_circle_outline_rounded
                            : Icons.payment_rounded,
                        size: 16,
                        color: AppColors.income,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isOverdue
                            ? 'Konfirmasi Pembayaran'
                            : 'Bayar Lebih Awal',
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 13),
                      ),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(children: [
                      Icon(
                        sub.status == 'active'
                            ? Icons.pause_circle_outline_rounded
                            : Icons.play_circle_outline_rounded,
                        size: 16,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        sub.status == 'active' ? 'Jeda' : 'Aktifkan',
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 13),
                      ),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      const Icon(Icons.edit_outlined,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text('Edit',
                          style:
                              TextStyle(fontFamily: 'Poppins', fontSize: 13)),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      const Icon(Icons.delete_outline_rounded,
                          size: 16, color: AppColors.danger),
                      const SizedBox(width: 8),
                      const Text('Hapus',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: AppColors.danger)),
                    ]),
                  ),
                ],
              ),
            ],
          ),

          // Divider + billing info
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.sm),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Next billing
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 13,
                        color: _isOverdue
                            ? AppColors.danger
                            : _isDueSoon
                                ? AppColors.warning
                                : AppColors.textHint,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        sub.status == 'active'
                            ? 'Tagihan ${DateFormat('d MMM yyyy', 'id').format(sub.nextBillingDate)}'
                            : 'Mulai ${DateFormat('d MMM yyyy', 'id').format(sub.startDate)}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: _isOverdue
                              ? AppColors.danger
                              : _isDueSoon
                                  ? AppColors.warning
                                  : AppColors.textSecondary,
                          fontWeight: (_isOverdue || _isDueSoon)
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  if (_isOverdue) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: const Text(
                        'Menunggu Konfirmasi',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ] else if (_isDueSoon) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: const Text(
                        'Segera',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              // Amount
              Text(
                '${CurrencyFormatter.format(sub.amount)}$_cycleLabel',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleMenu(
      BuildContext context, WidgetRef ref, String action) async {
    switch (action) {
      case 'record':
        final isOverdue = _isOverdue;
        final label = isOverdue ? 'Konfirmasi Pembayaran' : 'Bayar Lebih Awal';

        // Tentukan dompet — wajib ada
        WalletModel? walletToUse =
            sub.walletId != null ? HiveService.wallets.get(sub.walletId) : null;

        if (walletToUse == null) {
          final allWallets = HiveService.wallets.values.toList();
          if (allWallets.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text(
                  'Tambahkan dompet terlebih dahulu di halaman Aset'),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ));
            return;
          }
          walletToUse = await showAppBottomSheet<WalletModel>(
            context: context,
            title: 'Pilih Dompet Pembayaran',
            child: _WalletPickerSheet(wallets: allWallets),
          );
          if (walletToUse == null) return;
          if (!context.mounted) return;
        }

        final wallet = walletToUse;
        final desc = isOverdue
            ? 'Tandai ${sub.name} sudah dibayar dari ${wallet.name}?\nTagihan berikutnya akan diperbarui otomatis.'
            : 'Catat pembayaran ${sub.name} lebih awal dari ${wallet.name}?\nTagihan berikutnya akan diperbarui otomatis.';

        final confirm = await showConfirmSheet(
          context: context,
          title: label,
          description: desc,
          confirmLabel: 'Ya, Catat',
          isDanger: false,
        );
        if (confirm == true) {
          await ref.read(transactionProvider.notifier).addExpense(
                title: 'Langganan ${sub.name}',
                amount: sub.amount,
                categoryId: 'cat_subscription',
                categoryName: 'Langganan',
                categoryIcon: '🔄',
                walletId: wallet.id,
                walletName: wallet.name,
                date: DateTime.now(),
              );
          if (sub.walletId == null) {
            await notifier.updateWallet(sub.id, wallet.id, wallet.name);
          }
          await notifier.recordPayment(sub.id);
        }

      case 'toggle':
        final newStatus = sub.status == 'active' ? 'paused' : 'active';
        await notifier.updateStatus(sub.id, newStatus);

      case 'edit':
        onEdit(sub);

      case 'delete':
        final confirm = await showConfirmSheet(
          context: context,
          title: 'Hapus Langganan',
          description: 'Hapus ${sub.name} dari daftar langganan?',
          confirmLabel: 'Ya, Hapus',
        );
        if (confirm == true) {
          await notifier.delete(sub.id);
        }
    }
  }

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'streaming':
        return 'Streaming';
      case 'musik':
        return 'Musik';
      case 'produktivitas':
        return 'Produktivitas';
      case 'game':
        return 'Game';
      case 'cloud':
        return 'Cloud';
      case 'edukasi':
        return 'Edukasi';
      default:
        return 'Lainnya';
    }
  }
}

// ── Overdue Banner ────────────────────────────────────────────────────────────

class _OverdueBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _OverdueBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.notifications_active_rounded,
                color: AppColors.warning, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$count langganan menunggu konfirmasi pembayaran',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.warning,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 12, color: AppColors.warning),
          ],
        ),
      ),
    );
  }
}

// ── Overdue Payment Sheet ─────────────────────────────────────────────────────

class _OverduePaymentSheet extends ConsumerStatefulWidget {
  final List<SubscriptionModel> subs;
  final SubscriptionNotifier subNotifier;

  const _OverduePaymentSheet({
    required this.subs,
    required this.subNotifier,
  });

  @override
  ConsumerState<_OverduePaymentSheet> createState() =>
      _OverduePaymentSheetState();
}

class _OverduePaymentSheetState extends ConsumerState<_OverduePaymentSheet> {
  late List<WalletModel?> _pickedWallets;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _pickedWallets = widget.subs
        .map((s) =>
            s.walletId != null ? HiveService.wallets.get(s.walletId) : null)
        .toList();
  }

  bool get _allWalletsSet => _pickedWallets.every((w) => w != null);

  Future<void> _pickWallet(int i) async {
    final wallets = HiveService.wallets.values.toList();
    if (wallets.isEmpty) return;
    final picked = await showAppBottomSheet<WalletModel>(
      context: context,
      title: 'Pilih Dompet',
      child: _WalletPickerSheet(wallets: wallets),
    );
    if (picked != null) setState(() => _pickedWallets[i] = picked);
  }

  Future<void> _confirm() async {
    setState(() => _loading = true);
    final txNotifier = ref.read(transactionProvider.notifier);

    for (int i = 0; i < widget.subs.length; i++) {
      final sub = widget.subs[i];
      final wallet = _pickedWallets[i]!;
      await txNotifier.addExpense(
        title: 'Langganan ${sub.name}',
        amount: sub.amount,
        categoryId: 'cat_subscription',
        categoryName: 'Langganan',
        categoryIcon: '🔄',
        walletId: wallet.id,
        walletName: wallet.name,
        date: DateTime.now(),
      );
      if (sub.walletId == null) {
        await widget.subNotifier.updateWallet(sub.id, wallet.id, wallet.name);
      }
      await widget.subNotifier.recordPayment(sub.id);
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.subs.length} langganan berhasil dicatat'),
          backgroundColor: AppColors.income,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...List.generate(widget.subs.length, (i) {
          final sub = widget.subs[i];
          final wallet = _pickedWallets[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: wallet == null
                      ? AppColors.danger.withValues(alpha: 0.4)
                      : AppColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(sub.color).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Center(
                          child: Text(sub.icon,
                              style: const TextStyle(fontSize: 20)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sub.name, style: AppTextStyles.bodyMedium),
                            const SizedBox(height: 2),
                            Text(
                              '${CurrencyFormatter.format(sub.amount)} · jatuh tempo ${DateFormat('d MMM', 'id').format(sub.nextBillingDate)}',
                              style: AppTextStyles.small,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _pickWallet(i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: wallet == null
                            ? AppColors.danger.withValues(alpha: 0.08)
                            : AppColors.income.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: wallet == null
                              ? AppColors.danger.withValues(alpha: 0.3)
                              : AppColors.income.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 13,
                            color: wallet == null
                                ? AppColors.danger
                                : AppColors.income,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            wallet == null ? 'Pilih dompet' : wallet.name,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: wallet == null
                                  ? AppColors.danger
                                  : AppColors.income,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 14,
                            color: wallet == null
                                ? AppColors.danger
                                : AppColors.income,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_loading || !_allWalletsSet) ? null : _confirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.border,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    _allWalletsSet
                        ? 'Konfirmasi Pembayaran'
                        : 'Pilih dompet terlebih dahulu',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

// ── Wallet Picker Sheet ───────────────────────────────────────────────────────

class _WalletPickerSheet extends StatelessWidget {
  final List<WalletModel> wallets;
  const _WalletPickerSheet({required this.wallets});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: wallets.map((w) {
        return GestureDetector(
          onTap: () => Navigator.pop(context, w),
          child: Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Center(
                    child: Text(w.icon, style: const TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(w.name, style: AppTextStyles.bodyMedium),
                      Text(CurrencyFormatter.format(w.balance),
                          style: AppTextStyles.small),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: AppColors.textHint),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
