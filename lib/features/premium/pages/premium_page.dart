import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/premium_provider.dart';

class PremiumPage extends ConsumerStatefulWidget {
  const PremiumPage({super.key});

  @override
  ConsumerState<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends ConsumerState<PremiumPage> {
  String _selected = AppConstants.iapYearly;

  @override
  void initState() {
    super.initState();
    // Reset any lingering error/success from a previous session
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(premiumProvider.notifier).resetStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final premium = ref.watch(premiumProvider);
    final authState = ref.watch(authProvider);
    final isPremium = authState.user?.isPremium ?? false;

    ref.listen<PremiumState>(premiumProvider, (prev, next) {
      if (next.status == PurchaseFlowStatus.success) {
        _showSuccess();
      } else if (next.status == PurchaseFlowStatus.error && next.errorMessage != null) {
        _showError(next.errorMessage!);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(isPremium),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildHeader(isPremium),
                _buildFeatureList(),
                if (!isPremium) ...[
                  _buildPlanCards(premium),
                  _buildBuyButton(premium),
                  _buildFooterNote(),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── App Bar ───────────────────────────────────────────────────────────────

  SliverAppBar _buildAppBar(bool isPremium) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: false,
      floating: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      expandedHeight: 0,
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isPremium) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.workspace_premium_rounded,
                color: Colors.amber, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            isPremium ? 'Kamu sudah Premium!' : 'Upgrade ke Premium',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isPremium
                ? 'Nikmati semua fitur tanpa batas'
                : 'Catat transaksi dengan AI tanpa batas bulanan',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }

  // ── Feature List ──────────────────────────────────────────────────────────

  Widget _buildFeatureList() {
    final features = [
      (Icons.auto_awesome_rounded, 'AI Catat Unlimited',
          'Tanpa batas bulanan — free hanya 30x/bulan'),
      (Icons.mic_rounded, 'Catat Suara & Scan Struk',
          'Gunakan sesukamu setiap hari'),
      (Icons.flash_on_rounded, 'Prioritas Kecepatan AI',
          'Antrian prioritas di server AI'),
      (Icons.support_agent_rounded, 'Support Prioritas',
          'Respons lebih cepat via email'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Yang kamu dapatkan',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...features.map((f) => _FeatureRow(
                icon: f.$1,
                title: f.$2,
                subtitle: f.$3,
              )),
        ],
      ),
    );
  }

  // ── Plan Cards ────────────────────────────────────────────────────────────

  Widget _buildPlanCards(PremiumState premium) {
    if (!premium.isAvailable) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Google Play tidak tersedia di perangkat ini.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    if (premium.products.isEmpty &&
        premium.status != PurchaseFlowStatus.loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pilih Paket',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _PlanCard(
            productId: AppConstants.iapYearly,
            title: 'Tahunan',
            subtitle: 'Hemat 28% dibanding bulanan',
            price: _priceLabel(premium.yearly),
            badge: 'TERPOPULER',
            isSelected: _selected == AppConstants.iapYearly,
            onTap: () => setState(() => _selected = AppConstants.iapYearly),
          ),
          const SizedBox(height: 10),
          _PlanCard(
            productId: AppConstants.iapMonthly,
            title: 'Bulanan',
            subtitle: 'Bayar bulan per bulan',
            price: _priceLabel(premium.monthly),
            badge: null,
            isSelected: _selected == AppConstants.iapMonthly,
            onTap: () => setState(() => _selected = AppConstants.iapMonthly),
          ),
        ],
      ),
    );
  }

  String _priceLabel(ProductDetails? product) {
    if (product == null) return '...';
    return product.price;
  }

  // ── Buy Button ────────────────────────────────────────────────────────────

  Widget _buildBuyButton(PremiumState premium) {
    final isLoading = premium.status == PurchaseFlowStatus.loading;

    ProductDetails? selected;
    if (_selected == AppConstants.iapYearly) {
      selected = premium.yearly;
    } else {
      selected = premium.monthly;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: (isLoading || selected == null || !premium.isAvailable)
              ? null
              : () => ref.read(premiumProvider.notifier).buy(selected!),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.border,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Berlangganan Sekarang',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildFooterNote() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Text(
        'Langganan dikelola oleh Google Play. Batalkan kapan saja di Google Play Store → Subscriptions.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          color: AppColors.textHint,
          height: 1.5,
        ),
      ),
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded,
                color: AppColors.income, size: 64),
            SizedBox(height: 12),
            Text(
              'Selamat!',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Premium berhasil diaktifkan.\nSelamat menikmati AI tanpa batas!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // close dialog
                Navigator.of(context).pop(); // back to previous page
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: const Text(
                'Mulai Gunakan',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    ref.read(premiumProvider.notifier).resetStatus();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
        ),
        backgroundColor: AppColors.expense,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
    ref.read(premiumProvider.notifier).resetStatus();
  }
}

// ── Feature Row ───────────────────────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: const Color(0xFF4F46E5), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_rounded, color: AppColors.income, size: 18),
        ],
      ),
    );
  }
}

// ── Plan Card ─────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final String productId;
  final String title;
  final String subtitle;
  final String price;
  final String? badge;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.productId,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.badge,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const selectedColor = Color(0xFF4F46E5);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? selectedColor.withValues(alpha: 0.06)
              : AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? selectedColor : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? selectedColor : AppColors.border,
                  width: 2,
                ),
                color: isSelected ? selectedColor : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? selectedColor
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius:
                                BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              price,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isSelected ? selectedColor : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
