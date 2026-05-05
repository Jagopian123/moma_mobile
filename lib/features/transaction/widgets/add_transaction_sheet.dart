import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../widgets/expense_income_form.dart';
import '../widgets/transfer_form.dart';

final _activeTabProvider = StateProvider<int>((ref) => 0);

class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({super.key});

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  double _amount = 0;
  final _amountController = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      ref.read(_activeTabProvider.notifier).state = _tabController.index;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Color get _activeColor {
    switch (_tabController.index) {
      case 0:
        return AppColors.expense;
      case 1:
        return AppColors.income;
      default:
        return AppColors.transfer;
    }
  }

  String _formatAmount(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '0';
    final number = int.parse(digits);
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.92,
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
          ),
          child: Column(
            children: [
              // ── Handle ───────────────────────────────────────
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

              // ── Amount Input ──────────────────────────────────
              _buildAmountSection(),

              // ── Tab Bar ───────────────────────────────────────
              _buildTabBar(),

              // ── Tab Content ───────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    SingleChildScrollView(
                      padding: EdgeInsets.zero,
                      physics: const ClampingScrollPhysics(),
                      child: ExpenseIncomeForm(
                        type: 'expense',
                        initialAmount: _amount,
                      ),
                    ),
                    SingleChildScrollView(
                      padding: EdgeInsets.zero,
                      physics: const ClampingScrollPhysics(),
                      child: ExpenseIncomeForm(
                        type: 'income',
                        initialAmount: _amount,
                      ),
                    ),
                    SingleChildScrollView(
                      padding: EdgeInsets.zero,
                      physics: const ClampingScrollPhysics(),
                      child: TransferForm(initialAmount: _amount),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAmountSection() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        children: [
          Text(
            'Jumlah',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Rp',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: _activeColor,
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: IntrinsicWidth(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: _activeColor,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (val) {
                      final formatted = _formatAmount(val);
                      if (formatted != val) {
                        _amountController.value = TextEditingValue(
                          text: formatted,
                          selection: TextSelection.collapsed(
                            offset: formatted.length,
                          ),
                        );
                      }
                      final digits = formatted.replaceAll('.', '');
                      setState(() {
                        _amount = double.tryParse(digits) ?? 0;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            height: 2,
            width: 120,
            decoration: BoxDecoration(
              color: _activeColor.withOpacity(0.4),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.background,
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
              label: 'Pengeluaran',
              color: AppColors.expense,
              isActive: _tabController.index == 0,
            ),
            _TabItem(
              label: 'Pemasukan',
              color: AppColors.income,
              isActive: _tabController.index == 1,
            ),
            _TabItem(
              label: 'Transfer',
              color: AppColors.transfer,
              isActive: _tabController.index == 2,
            ),
          ],
        ),
      ),
    );
  }
}

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
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
