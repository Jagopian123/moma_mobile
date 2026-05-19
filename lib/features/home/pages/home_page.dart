import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/hive/models/transaction_model.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_circular_progress.dart';
import '../../../shared/widgets/app_progress_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../asset/providers/wallet_provider.dart';
import '../../transaction/providers/transaction_provider.dart';
import '../../budget/providers/budget_provider.dart';
import '../../financial_plan/providers/financial_plan_provider.dart';
import '../../debt/providers/debt_provider.dart';
import '../../transaction/widgets/transaction_card.dart';
import '../providers/home_provider.dart';
import '../../insights/providers/analytics_provider.dart';
import '../../notifications/providers/notification_provider.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final wallets = ref.watch(walletProvider);
    final transactions = ref.watch(transactionProvider);
    final budgets = ref.watch(budgetProvider);
    final plans = ref.watch(financialPlanProvider);
    final debts = ref.watch(debtProvider);
    final isVisible = ref.watch(balanceVisibleProvider);
    final walletNotifier = ref.read(walletProvider.notifier);
    final txNotifier = ref.read(transactionProvider.notifier);
    final budgetNotifier = ref.watch(budgetProvider.notifier);
    final planNotifier = ref.watch(financialPlanProvider.notifier);
    final debtNotifier = ref.watch(debtProvider.notifier);

    final totalBalance = walletNotifier.totalBalance;
    final todayIncome = txNotifier.todayIncome;
    final todayExpense = txNotifier.todayExpense;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {},
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            // ── App Bar ────────────────────────────────────────
            SliverAppBar(
              floating: true,
              backgroundColor: AppColors.background,
              elevation: 0,
              expandedHeight: 0,
              toolbarHeight: 60,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        getGreetingEmoji(),
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        getGreeting(),
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    user?.name.split(' ').first ?? 'Pengguna',
                    style: AppTextStyles.h3,
                  ),
                ],
              ),
              actions: [
                // Bell icon
                const _NotifBell(),
                const SizedBox(width: 4),
                // Avatar
                GestureDetector(
                  onTap: () => context.push('/profile'),
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Text(
                        user?.name.isNotEmpty == true
                            ? user!.name[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.xxl,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Balance Card ───────────────────────────────
                  _BalanceCard(
                    totalBalance: totalBalance,
                    todayIncome: todayIncome,
                    todayExpense: todayExpense,
                    isVisible: isVisible,
                    onToggleVisibility: () =>
                        ref.read(balanceVisibleProvider.notifier).toggle(),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // ── Insight Card ───────────────────────────────
                  _HomeInsightSection(
                    onTap: () => context.push('/insights'),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ── Budget Preview ─────────────────────────────
                  AppSectionHeader(
                    title: 'Budget',
                    subtitle: 'Lacak batas pengeluaran kamu',
                    onSeeAll: () => context.push('/budget'),
                    seeAllLabel: 'Lihat Detail',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  budgets.isEmpty
                      ? _EmptyPreviewCard(
                          emoji: '💰',
                          title: 'Belum ada budget',
                          description: 'Set spending limits to stay on track',
                          actionLabel: '+ Buat Budget',
                          onAction: () => context.push('/budget'),
                        )
                      : _BudgetPreview(
                          budgets: budgets.take(2).toList(),
                          notifier: budgetNotifier,
                        ),
                  const SizedBox(height: AppSpacing.lg),

                  // ── Rencana Finansial Preview ──────────────────
                  AppSectionHeader(
                    title: 'Rencana Finansial',
                    subtitle: 'Lacak tujuan keuangan kamu',
                    onSeeAll: () => context.push('/financial-plan'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  plans.isEmpty
                      ? _EmptyPreviewCard(
                          emoji: '🎯',
                          title: 'Belum ada rencana',
                          description: 'Mulai rencanakan tujuan keuanganmu',
                          actionLabel: '+ Buat Rencana',
                          onAction: () => context.push('/financial-plan'),
                        )
                      : _PlanPreview(
                          plans: plans.take(2).toList(),
                          notifier: planNotifier,
                        ),
                  const SizedBox(height: AppSpacing.lg),

                  // ── Hutang & Piutang Preview ───────────────────
                  AppSectionHeader(
                    title: 'Hutang & Piutang',
                    subtitle: 'Pantau pinjaman dan tagihan kamu',
                    onSeeAll: () => context.push('/debt'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  debtNotifier.activeDebts.isEmpty &&
                          debtNotifier.activeReceivables.isEmpty
                      ? _EmptyPreviewCard(
                          emoji: '🤝',
                          title: 'Belum ada catatan',
                          description: 'Catat hutang dan piutangmu di sini',
                          actionLabel: '+ Catat Hutang/Piutang',
                          onAction: () => context.push('/debt'),
                        )
                      : _DebtPreview(notifier: debtNotifier),
                  const SizedBox(height: AppSpacing.lg),

                  // ── Transaksi Terbaru ──────────────────────────
                  AppSectionHeader(
                    title: 'Transaksi Terbaru',
                    onSeeAll: () => context.go('/transaction'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _RecentTransactions(transactions: transactions),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Home Insight Section ──────────────────────────────────────────────────────

class _HomeInsightSection extends ConsumerStatefulWidget {
  final VoidCallback onTap;
  const _HomeInsightSection({required this.onTap});

  @override
  ConsumerState<_HomeInsightSection> createState() =>
      _HomeInsightSectionState();
}

class _HomeInsightSectionState extends ConsumerState<_HomeInsightSection> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      final insights = ref.read(homeInsightsProvider);
      if (insights.length > 1 && _pageController.hasClients) {
        final next = (_currentPage + 1) % insights.length;
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insights = ref.watch(homeInsightsProvider);
    if (insights.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
              color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, 100, AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label — static
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded,
                          size: 12, color: Color(0xFF6366F1)),
                      SizedBox(width: 4),
                      Text(
                        'AI Insight',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // PageView — swipeable, fixed height biar card tidak naik-turun
                  SizedBox(
                    height: 54,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: insights.length,
                      onPageChanged: (i) =>
                          setState(() => _currentPage = i),
                      itemBuilder: (_, i) {
                        final insight = insights[i];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${insight.emoji}  ${insight.title}',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              insight.body,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  // Dot indicators
                  if (insights.length > 1) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(
                        insights.length.clamp(0, 8),
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: i == _currentPage ? 14 : 5,
                          height: 5,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(
                                alpha: i == _currentPage ? 1.0 : 0.25),
                            borderRadius:
                                BorderRadius.circular(AppRadius.full),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Mascot — static
            Positioned(
              right: 0,
              bottom: 0,
              child: Image.asset(
                'assets/images/mascot.png',
                width: 90,
                height: 90,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox(
                  width: 90,
                  height: 90,
                  child: Center(
                      child: Text('🤖',
                          style: TextStyle(fontSize: 40))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPreviewCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;

  const _EmptyPreviewCard({
    required this.emoji,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.safe.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(title, style: AppTextStyles.h4),
          const SizedBox(height: 4),
          Text(
            description,
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

// ── Balance Card ──────────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  final double totalBalance;
  final double todayIncome;
  final double todayExpense;
  final bool isVisible;
  final VoidCallback onToggleVisibility;

  const _BalanceCard({
    required this.totalBalance,
    required this.todayIncome,
    required this.todayExpense,
    required this.isVisible,
    required this.onToggleVisibility,
  });

  String _mask(double amount) =>
      isVisible ? CurrencyFormatter.format(amount) : 'Rp •••••••';

  @override
  Widget build(BuildContext context) {
    return AppGradientCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label + toggle
          Row(
            children: [
              Text(
                'Total Saldo',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onToggleVisibility,
                child: Icon(
                  isVisible
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: Colors.white.withValues(alpha: 0.8),
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Total saldo
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _mask(totalBalance),
              key: ValueKey(isVisible),
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Pemasukan & pengeluaran hari ini
          Row(
            children: [
              Expanded(
                child: _BalanceStat(
                  label: 'Pemasukan',
                  value: _mask(todayIncome),
                  icon: Icons.arrow_downward_rounded,
                  color: const Color(0xFF86EFAC),
                ),
              ),
              Expanded(
                child: _BalanceStat(
                  label: 'Pengeluaran',
                  value: _mask(todayExpense),
                  icon: Icons.arrow_upward_rounded,
                  color: const Color(0xFFFCA5A5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _BalanceStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Budget Preview ────────────────────────────────────────────────────────────

class _BudgetPreview extends StatelessWidget {
  final List budgets;
  final BudgetNotifier notifier;

  const _BudgetPreview({required this.budgets, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: budgets.asMap().entries.map((entry) {
          final i = entry.key;
          final budget = entry.value;
          final spent = notifier.getSpent(budget);
          final pct = notifier.getPercentage(budget);

          Color color;
          switch (notifier.getStatus(budget)) {
            case BudgetStatus.overBudget:
            case BudgetStatus.spendingFast:
              color = AppColors.danger;
              break;
            case BudgetStatus.slightlyFast:
              color = AppColors.warning;
              break;
            default:
              color = AppColors.safe;
          }

          return Column(
            children: [
              if (i > 0) const Divider(height: 20, color: AppColors.border),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(int.parse(
                        budget.categoryColor.replaceFirst('#', '0xFF'),
                      )).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Center(
                      child: Text(budget.categoryIcon,
                          style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(budget.categoryName,
                                style: AppTextStyles.bodyMedium),
                            Text(
                              '${(pct * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        AppProgressBar(value: pct.clamp(0.0, 1.0), height: 6),
                        const SizedBox(height: 2),
                        Text(
                          '${CurrencyFormatter.formatCompact(spent)} '
                          'dari ${CurrencyFormatter.formatCompact(budget.limitAmount)}',
                          style: AppTextStyles.small,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Plan Preview ──────────────────────────────────────────────────────────────

class _PlanPreview extends StatelessWidget {
  final List plans;
  final FinancialPlanNotifier notifier;

  const _PlanPreview({required this.plans, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: plans.asMap().entries.map((entry) {
          final i = entry.key;
          final plan = entry.value;
          final pct = notifier.getPercentage(plan);
          final color = Color(
            int.parse(plan.color.replaceFirst('#', '0xFF')),
          );

          return Column(
            children: [
              if (i > 0) const Divider(height: 20, color: AppColors.border),
              Row(
                children: [
                  AppCircularProgress(
                    value: pct,
                    size: 48,
                    strokeWidth: 5,
                    color: color,
                    center:
                        Text(plan.icon, style: const TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(plan.name, style: AppTextStyles.bodyMedium),
                        Text(
                          '${CurrencyFormatter.formatCompact(plan.savedAmount)} '
                          'dari ${CurrencyFormatter.formatCompact(plan.targetAmount)}',
                          style: AppTextStyles.small,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${(pct * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Debt Preview ──────────────────────────────────────────────────────────────

class _DebtPreview extends StatelessWidget {
  final DebtNotifier notifier;

  const _DebtPreview({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (notifier.totalReceivable > 0)
          Expanded(
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.arrow_downward_rounded,
                          size: 16, color: AppColors.income),
                      SizedBox(width: 4),
                      Text(
                        'Piutang',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.income,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.formatCompact(notifier.totalReceivable),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.income,
                    ),
                  ),
                  Text(
                    '${notifier.activeReceivables.length} orang',
                    style: AppTextStyles.small,
                  ),
                ],
              ),
            ),
          ),
        if (notifier.totalReceivable > 0 && notifier.totalDebt > 0)
          const SizedBox(width: AppSpacing.sm),
        if (notifier.totalDebt > 0)
          Expanded(
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.arrow_upward_rounded,
                          size: 16, color: AppColors.expense),
                      SizedBox(width: 4),
                      Text(
                        'Hutang',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.expense,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.formatCompact(notifier.totalDebt),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.expense,
                    ),
                  ),
                  Text(
                    '${notifier.activeDebts.length} orang',
                    style: AppTextStyles.small,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Recent Transactions ───────────────────────────────────────────────────────

class _RecentTransactions extends StatelessWidget {
  final List<TransactionModel> transactions;

  const _RecentTransactions({required this.transactions});

  @override
  Widget build(BuildContext context) {
    // Ambil 10 transaksi terbaru
    final recent = transactions.take(10).toList();

    if (recent.isEmpty) {
      return const AppEmptyState(
        emoji: '📭',
        title: 'Belum ada transaksi',
        description: 'Tap tombol + untuk mulai mencatat',
      );
    }

    // Group by date
    final grouped = <DateTime, List<TransactionModel>>{};
    for (final tx in recent) {
      final date = DateTime(tx.date.year, tx.date.month, tx.date.day);
      grouped.putIfAbsent(date, () => []).add(tx);
    }
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      children: [
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

        // Lihat semua
        if (transactions.length > 10) ...[
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => context.go('/transaction'),
              child: const Text(
                'Lihat semua transaksi',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Notification Bell ─────────────────────────────────────────────────────────

class _NotifBell extends ConsumerWidget {
  const _NotifBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifs = ref.watch(notificationProvider);
    final unread = notifs.where((n) => !n.isRead).length;

    return GestureDetector(
      onTap: () => context.push('/notifications'),
      child: Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(
              Icons.notifications_outlined,
              color: AppColors.textPrimary,
              size: 26,
            ),
            if (unread > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: AppColors.expense,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
