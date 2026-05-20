import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/analytics_data.dart';
import '../providers/analytics_provider.dart';
import '../widgets/summary_cards.dart';
import '../widgets/cashflow_chart.dart';
import '../widgets/donut_chart.dart';
import '../widgets/weekly_bar_chart.dart';
import '../widgets/health_score_card.dart';

class InsightsPage extends ConsumerStatefulWidget {
  const InsightsPage({super.key});

  @override
  ConsumerState<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends ConsumerState<InsightsPage> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      final insights = ref.read(analyticsDataProvider).insights;
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
    final period = ref.watch(analyticsPeriodProvider);
    final data = ref.watch(analyticsDataProvider);
    final isPro = ref.watch(authProvider).user?.isPremium == true;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ───────────────────────────────────────────────
          SliverAppBar(
            floating: true,
            backgroundColor: AppColors.background,
            elevation: 0,
            toolbarHeight: 60,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              color: AppColors.textPrimary,
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text('Analisis Keuangan', style: AppTextStyles.h3),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: _PeriodDropdown(
                  value: period,
                  onChanged: (v) =>
                      ref.read(analyticsPeriodProvider.notifier).state = v!,
                ),
              ),
            ],
          ),

          // ── Body ─────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.xxl,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // AI Insight rotating card
                if (data.insights.isNotEmpty) ...[
                  _InsightRotatingCard(
                    insights: data.insights,
                    pageController: _pageController,
                    currentPage: _currentPage,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    onTap: () => context.push('/ai-insight'),
                    isPro: isPro,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Summary Cards
                SummaryCards(
                  summary: data.summary,
                  previousSummary: data.previousSummary,
                  dailyAverage: data.dailyAverage,
                ),
                const SizedBox(height: AppSpacing.md),

                // Biggest Transaction
                if (data.biggestTransaction != null) ...[
                  _BiggestTransactionCard(tx: data.biggestTransaction!),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Cashflow Chart
                CashflowChart(
                  points: data.cashflowPoints,
                  period: period,
                ),
                const SizedBox(height: AppSpacing.md),

                // Donut Chart
                DonutChart(categories: data.categoryExpenses),
                const SizedBox(height: AppSpacing.md),

                // Bar Chart (period-aware)
                WeeklyBarChart(data: data.weeklySpending, period: period),
                const SizedBox(height: AppSpacing.md),

                // Health Score
                HealthScoreCard(score: data.healthScore),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Period Dropdown ───────────────────────────────────────────────────────────

class _PeriodDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;

  const _PeriodDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: AppColors.textSecondary),
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
          onChanged: onChanged,
          items: const [
            DropdownMenuItem(
              value: AnalyticsPeriod.week,
              child: Text('Minggu ini'),
            ),
            DropdownMenuItem(
              value: AnalyticsPeriod.month,
              child: Text('Bulan ini'),
            ),
            DropdownMenuItem(
              value: AnalyticsPeriod.year,
              child: Text('Tahun ini'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── AI Insight Rotating Card ──────────────────────────────────────────────────

class _InsightRotatingCard extends StatelessWidget {
  final List<InsightItem> insights;
  final PageController pageController;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final VoidCallback? onTap;
  final bool isPro;

  const _InsightRotatingCard({
    required this.insights,
    required this.pageController,
    required this.currentPage,
    required this.onPageChanged,
    this.onTap,
    this.isPro = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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

                  // PageView — fixed height so card doesn't resize
                  SizedBox(
                    height: 54,
                    child: PageView.builder(
                      controller: pageController,
                      itemCount: insights.length,
                      onPageChanged: onPageChanged,
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

                  // Dot indicators + Lihat Semua
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (insights.length > 1)
                        ...List.generate(
                          insights.length.clamp(0, 8),
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: i == currentPage ? 14 : 5,
                            height: 5,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(
                                  alpha: i == currentPage ? 1.0 : 0.25),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                            ),
                          ),
                        ),
                      const Spacer(),
                      Text(
                        'Lihat Semua',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color:
                              const Color(0xFF6366F1).withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color:
                            const Color(0xFF6366F1).withValues(alpha: 0.8),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Mascot — static
            Positioned(
              right: 0,
              bottom: 0,
              child: Image.asset(
                isPro
                    ? 'assets/images/mascot-pro.png'
                    : 'assets/images/mascot.png',
                width: 90,
                height: 90,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox(
                  width: 90,
                  height: 90,
                  child: Center(
                      child: Text('🤖', style: TextStyle(fontSize: 40))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Biggest Transaction Card ──────────────────────────────────────────────────

class _BiggestTransactionCard extends StatelessWidget {
  final BiggestTx tx;

  const _BiggestTransactionCard({required this.tx});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('d MMM yyyy', 'id').format(tx.date);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.expense.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Center(
              child: Text(tx.emoji, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Transaksi Terbesar',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  tx.title.isNotEmpty ? tx.title : tx.categoryName,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${tx.categoryName} · $dateStr',
                  style: AppTextStyles.small,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Amount
          Text(
            CurrencyFormatter.formatCompact(tx.amount),
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.expense,
            ),
          ),
        ],
      ),
    );
  }
}
