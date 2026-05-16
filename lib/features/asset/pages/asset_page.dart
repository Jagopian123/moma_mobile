import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/hive/models/wallet_model.dart';
import '../../../core/hive/models/investment_model.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../providers/wallet_provider.dart';
import '../providers/investment_provider.dart';
import '../widgets/wallet_form_sheet.dart';
import '../widgets/investment_form_sheet.dart';

class AssetPage extends ConsumerWidget {
  const AssetPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallets = ref.watch(walletProvider);
    final investments = ref.watch(investmentProvider);

    final totalWallet = ref.read(walletProvider.notifier).totalBalance;
    final totalInvestment = ref.read(investmentProvider.notifier).totalValue;
    final totalAsset = totalWallet + totalInvestment;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 0,
            floating: true,
            backgroundColor: AppColors.background,
            title: const Text('Aset', style: AppTextStyles.h3),
            centerTitle: false,
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                children: [
                  // ── Overview Card ───────────────────────────
                  _AssetOverviewCard(
                    totalAsset: totalAsset,
                    totalCash: wallets
                        .where((w) => w.type == 'cash')
                        .fold(0.0, (s, w) => s + w.balance),
                    totalBank: wallets
                        .where((w) => w.type != 'cash')
                        .fold(0.0, (s, w) => s + w.balance),
                    totalInvestment: totalInvestment,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ── Dompet & Rekening ────────────────────────
                  AppSectionHeader(
                    title: 'Dompet & Rekening',
                    onSeeAll: null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _WalletSection(wallets: wallets),
                  const SizedBox(height: AppSpacing.md),

                  // Tombol tambah dompet
                  _AddButton(
                    label: 'Tambah Dompet',
                    icon: Icons.account_balance_wallet_rounded,
                    onTap: () => _showWalletForm(context, ref),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ── Investasi ────────────────────────────────
                  AppSectionHeader(
                    title: 'Investasi',
                    onSeeAll: null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _InvestmentSection(investments: investments),
                  const SizedBox(height: AppSpacing.md),

                  // Tombol tambah investasi
                  _AddButton(
                    label: 'Tambah Investasi',
                    icon: Icons.trending_up_rounded,
                    onTap: () => _showInvestmentForm(context, ref),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showWalletForm(BuildContext context, WidgetRef ref,
      [WalletModel? wallet]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WalletFormSheet(wallet: wallet),
    );
  }

  void _showInvestmentForm(BuildContext context, WidgetRef ref,
      [InvestmentModel? investment]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InvestmentFormSheet(investment: investment),
    );
  }
}

// ── Asset Overview Card ───────────────────────────────────────────────────────

class _AssetOverviewCard extends StatelessWidget {
  final double totalAsset;
  final double totalCash;
  final double totalBank;
  final double totalInvestment;

  const _AssetOverviewCard({
    required this.totalAsset,
    required this.totalCash,
    required this.totalBank,
    required this.totalInvestment,
  });

  @override
  Widget build(BuildContext context) {
    return AppGradientCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Aset',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            CurrencyFormatter.format(totalAsset),
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Distribusi bar
          _DistributionBar(
            totalCash: totalCash,
            totalBank: totalBank,
            totalInvestment: totalInvestment,
            total: totalAsset,
          ),
          const SizedBox(height: AppSpacing.md),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _LegendItem(
                color: Colors.white,
                label: 'Tunai',
                value: CurrencyFormatter.formatCompact(totalCash),
              ),
              _LegendItem(
                color: Colors.white.withOpacity(0.7),
                label: 'Bank/E-Wallet',
                value: CurrencyFormatter.formatCompact(totalBank),
              ),
              _LegendItem(
                color: const Color(0xFF93C5FD),
                label: 'Investasi',
                value: CurrencyFormatter.formatCompact(totalInvestment),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DistributionBar extends StatelessWidget {
  final double totalCash;
  final double totalBank;
  final double totalInvestment;
  final double total;

  const _DistributionBar({
    required this.totalCash,
    required this.totalBank,
    required this.totalInvestment,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    if (total == 0) {
      return Container(
        height: 8,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
      );
    }

    final cashPct = totalCash / total;
    final bankPct = totalBank / total;
    final invPct = totalInvestment / total;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Row(
        children: [
          if (cashPct > 0)
            Flexible(
              flex: (cashPct * 100).round(),
              child: Container(height: 8, color: Colors.white),
            ),
          if (bankPct > 0)
            Flexible(
              flex: (bankPct * 100).round(),
              child: Container(
                height: 8,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          if (invPct > 0)
            Flexible(
              flex: (invPct * 100).round(),
              child: Container(
                height: 8,
                color: const Color(0xFF93C5FD),
              ),
            ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Wallet Section ────────────────────────────────────────────────────────────

class _WalletSection extends ConsumerWidget {
  final List<WalletModel> wallets;

  const _WalletSection({required this.wallets});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (wallets.isEmpty) {
      return AppEmptyState(
        emoji: '👛',
        imagePath: 'assets/images/mascot-wallet.png',
        title: 'Belum ada dompet',
        description: 'Tambahkan dompet atau rekening untuk mulai mencatat',
      );
    }

    return Column(
      children: wallets
          .map((wallet) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _WalletCard(
                  wallet: wallet,
                  onEdit: () => _showEdit(context, ref, wallet),
                  onDelete: () => _confirmDelete(context, ref, wallet),
                ),
              ))
          .toList(),
    );
  }

  void _showEdit(BuildContext context, WidgetRef ref, WalletModel wallet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WalletFormSheet(wallet: wallet),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, WalletModel wallet) async {
    final confirm = await showConfirmSheet(
      context: context,
      title: 'Hapus Dompet',
      description:
          'Hapus "${wallet.name}"? Data transaksi terkait tidak akan ikut terhapus.',
      confirmLabel: 'Ya, Hapus',
    );
    if (confirm == true) {
      ref.read(walletProvider.notifier).delete(wallet.id);
    }
  }
}

class _WalletCard extends StatelessWidget {
  final WalletModel wallet;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _WalletCard({
    required this.wallet,
    required this.onEdit,
    required this.onDelete,
  });

  String get _typeLabel {
    switch (wallet.type) {
      case 'bank':
        return 'Bank';
      case 'ewallet':
        return 'E-Wallet';
      default:
        return 'Tunai';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(
      int.parse(wallet.color.replaceFirst('#', '0xFF')),
    );

    return AppCard(
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Center(
              child: Text(wallet.icon, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(wallet.name, style: AppTextStyles.bodyMedium),
                Text(
                  _typeLabel,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Saldo
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.format(wallet.balance),
                style: AppTextStyles.bodyMedium,
              ),
              if (wallet.accountNumber != null &&
                  wallet.accountNumber!.isNotEmpty)
                Text(
                  '••••${wallet.accountNumber!.substring(
                    wallet.accountNumber!.length > 4
                        ? wallet.accountNumber!.length - 4
                        : 0,
                  )}',
                  style: AppTextStyles.small,
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),

          // Actions
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.textHint, size: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, size: 16),
                    SizedBox(width: 8),
                    Text('Edit', style: TextStyle(fontFamily: 'Poppins')),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_rounded,
                        size: 16, color: AppColors.danger),
                    SizedBox(width: 8),
                    Text('Hapus',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: AppColors.danger,
                        )),
                  ],
                ),
              ),
            ],
            onSelected: (val) {
              if (val == 'edit') onEdit();
              if (val == 'delete') onDelete();
            },
          ),
        ],
      ),
    );
  }
}

// ── Investment Section ────────────────────────────────────────────────────────

class _InvestmentSection extends ConsumerWidget {
  final List<InvestmentModel> investments;

  const _InvestmentSection({required this.investments});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (investments.isEmpty) {
      return AppEmptyState(
        emoji: '📈',
        imagePath: 'assets/images/mascot-investasi.png',
        title: 'Belum ada investasi',
        description: 'Catat aset investasimu di sini',
      );
    }

    return Column(
      children: investments
          .map((inv) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _InvestmentCard(
                  investment: inv,
                  onEdit: () => _showEdit(context, ref, inv),
                  onDelete: () => _confirmDelete(context, ref, inv),
                ),
              ))
          .toList(),
    );
  }

  void _showEdit(BuildContext context, WidgetRef ref, InvestmentModel inv) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InvestmentFormSheet(investment: inv),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, InvestmentModel inv) async {
    final confirm = await showConfirmSheet(
      context: context,
      title: 'Hapus Investasi',
      description: 'Hapus "${inv.name}"?',
      confirmLabel: 'Ya, Hapus',
    );
    if (confirm == true) {
      ref.read(investmentProvider.notifier).delete(inv.id);
    }
  }
}

class _InvestmentCard extends StatelessWidget {
  final InvestmentModel investment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _InvestmentCard({
    required this.investment,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Center(
              child: Text(
                InvestmentNotifier.typeIcon(investment.type),
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(investment.name, style: AppTextStyles.bodyMedium),
                Text(
                  InvestmentNotifier.typeLabel(investment.type),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Nilai
          Text(
            CurrencyFormatter.format(investment.currentValue),
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(width: AppSpacing.sm),

          // Actions
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.textHint, size: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, size: 16),
                    SizedBox(width: 8),
                    Text('Edit', style: TextStyle(fontFamily: 'Poppins')),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_rounded,
                        size: 16, color: AppColors.danger),
                    SizedBox(width: 8),
                    Text('Hapus',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: AppColors.danger,
                        )),
                  ],
                ),
              ),
            ],
            onSelected: (val) {
              if (val == 'edit') onEdit();
              if (val == 'delete') onDelete();
            },
          ),
        ],
      ),
    );
  }
}

// ── Add Button ────────────────────────────────────────────────────────────────

class _AddButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _AddButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
