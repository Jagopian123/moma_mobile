import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/premium_provider.dart';

// ── Color constants ───────────────────────────────────────────────────────────
const _kIndigo = Color(0xFF4F46E5);
const _kIndigoDark = Color(0xFF1E1B4B);
const _kIndigoMid = Color(0xFF312E81);

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(premiumProvider.notifier).resetStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final premium = ref.watch(premiumProvider);
    final isPremium = ref.watch(authProvider).user?.isPremium ?? false;

    ref.listen<PremiumState>(premiumProvider, (prev, next) {
      if (next.status == PurchaseFlowStatus.success) {
        _showSuccess();
      } else if (next.status == PurchaseFlowStatus.error &&
          next.errorMessage != null) {
        _showError(next.errorMessage!);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────────────
          SliverAppBar(
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
                  colors: [_kIndigoDark, _kIndigoMid],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            expandedHeight: 0,
          ),

          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildHeader(isPremium),
                if (isPremium)
                  _buildAlreadyPremium()
                else ...[
                  _buildComparisonTable(),
                  _buildPlanSelector(premium),
                  _buildBuyButton(premium),
                  _buildTrustRow(),
                  _buildFooterNote(),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isPremium) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kIndigoDark, _kIndigoMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 36),
      child: Column(
        children: [
          // Crown icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.workspace_premium_rounded,
                color: Colors.amber, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            isPremium ? 'Kamu sudah Pro! 🎉' : 'MOMA Pro',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isPremium
                ? 'Nikmati semua fitur tanpa batas'
                : 'Kelola keuangan tanpa batas.\nAnalisis lebih dalam, keputusan lebih cerdas.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          if (!isPremium) ...[
            const SizedBox(height: 20),
            // Social proof row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Star icons
                  ...List.generate(
                    5,
                    (_) => const Icon(Icons.star_rounded,
                        color: Colors.amber, size: 14),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Dipercaya ribuan pengguna MOMA',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Already Premium ───────────────────────────────────────────────────────

  Widget _buildAlreadyPremium() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // ── Banner sama persis dengan profile page ──────────────
          Container(
            width: double.infinity,
            height: 96,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF3730A3)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E3A8A).withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Lingkaran dekoratif
                Positioned(
                  left: -24,
                  bottom: -24,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                // Teks
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, 110, 0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFFFD700).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFFFFD700)
                                .withValues(alpha: 0.5),
                            width: 0.8,
                          ),
                        ),
                        child: const Text(
                          'AKTIF',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFFD700),
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Moma Premium',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Semua fitur tanpa batas untukmu',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                // Mascot
                Positioned(
                  right: -4,
                  bottom: 0,
                  child: Image.asset(
                    'assets/images/mascot-banner-pro.png',
                    width: 104,
                    height: 104,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox(width: 104),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          ..._proFeatures.map((f) => _ProFeatureRow(
                icon: f.icon,
                title: f.title,
                subtitle: f.subtitle,
              )),
        ],
      ),
    );
  }

  // ── Comparison Table ──────────────────────────────────────────────────────

  Widget _buildComparisonTable() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Row(
            children: [
              const Text(
                'Perbandingan Paket',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              // Column headers — right-aligned
              SizedBox(
                width: 130,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Free',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: _kIndigo,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Text(
                          'Pro ⭐',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Table card
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: _tableRows.asMap().entries.map((entry) {
                final i = entry.key;
                final row = entry.value;
                return _ComparisonRow(
                  label: row.label,
                  freeValue: row.freeValue,
                  proValue: row.proValue,
                  isLimited: row.isLimited,
                  isAlternate: i.isEven,
                  isLast: i == _tableRows.length - 1,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Plan Selector ─────────────────────────────────────────────────────────

  Widget _buildPlanSelector(PremiumState premium) {
    if (!premium.isAvailable) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
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

          // Yearly card — recommended
          _PlanCard(
            productId: AppConstants.iapYearly,
            title: 'Tahunan',
            subtitle: 'Hemat 20% dibanding bulanan',
            price: _priceLabel(premium.yearly),
            badge: 'TERPOPULER',
            isSelected: _selected == AppConstants.iapYearly,
            onTap: () => setState(() => _selected = AppConstants.iapYearly),
          ),
          const SizedBox(height: 10),

          // Monthly card
          _PlanCard(
            productId: AppConstants.iapMonthly,
            title: 'Bulanan',
            subtitle: 'Bayar bulan per bulan, batalkan kapan saja',
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
    final selected =
        _selected == AppConstants.iapYearly ? premium.yearly : premium.monthly;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: (isLoading || selected == null || !premium.isAvailable)
              ? null
              : () => ref.read(premiumProvider.notifier).buy(selected),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kIndigo,
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
                      strokeWidth: 2, color: Colors.white),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Mulai Berlangganan',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _selected == AppConstants.iapYearly
                          ? 'Hemat 20% vs bulanan'
                          : 'Batalkan kapan saja',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ── Trust Row ─────────────────────────────────────────────────────────────

  Widget _buildTrustRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          _TrustBadge(
            icon: Icons.lock_outline_rounded,
            label: 'Pembayaran\nAman',
          ),
          const SizedBox(width: 10),
          _TrustBadge(
            icon: Icons.cancel_outlined,
            label: 'Batalkan\nKapan Saja',
          ),
          const SizedBox(width: 10),
          _TrustBadge(
            icon: Icons.sync_rounded,
            label: 'Update\nOtomatis',
          ),
        ],
      ),
    );
  }

  Widget _buildFooterNote() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Text(
        'Langganan dikelola Google Play. Perpanjang otomatis kecuali dibatalkan minimal 24 jam sebelum periode berakhir.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10,
          color: AppColors.textHint,
          height: 1.5,
        ),
      ),
    );
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  static const _tableRows = [
    _TableRow(
      label: 'Catat Transaksi',
      freeValue: 'Unlimited',
      proValue: 'Unlimited',
      isLimited: false,
    ),
    _TableRow(
      label: 'AI Catat Transaksi',
      freeValue: '30x/bulan',
      proValue: 'Unlimited',
      isLimited: true,
    ),
    _TableRow(
      label: 'Budget',
      freeValue: 'Maks 3',
      proValue: 'Unlimited',
      isLimited: true,
    ),
    _TableRow(
      label: 'Rencana Finansial',
      freeValue: 'Maks 2',
      proValue: 'Unlimited',
      isLimited: true,
    ),
    _TableRow(
      label: 'Hutang & Piutang',
      freeValue: 'Maks 5',
      proValue: 'Unlimited',
      isLimited: true,
    ),
    _TableRow(
      label: 'Dompet / Aset',
      freeValue: 'Maks 5',
      proValue: 'Unlimited',
      isLimited: true,
    ),
    _TableRow(
      label: 'Langganan',
      freeValue: 'Maks 5',
      proValue: 'Unlimited',
      isLimited: true,
    ),
    _TableRow(
      label: 'Investasi',
      freeValue: 'Maks 3',
      proValue: 'Unlimited',
      isLimited: true,
    ),
    _TableRow(
      label: 'AI Insight',
      freeValue: '3 teratas',
      proValue: 'Semua insight',
      isLimited: true,
    ),
    _TableRow(
      label: 'Analisis Keuangan',
      freeValue: 'Lengkap',
      proValue: 'Lengkap',
      isLimited: false,
    ),
    _TableRow(
      label: 'Export Data',
      freeValue: 'CSV, 3 bln',
      proValue: 'PDF+Excel, semua',
      isLimited: true,
    ),
    _TableRow(
      label: 'Backup Otomatis',
      freeValue: 'Mingguan',
      proValue: 'Harian + Manual',
      isLimited: true,
    ),
    _TableRow(
      label: 'Iklan',
      freeValue: 'Ada iklan',
      proValue: 'Bebas iklan',
      isLimited: true,
    ),
    _TableRow(
      label: 'Support',
      freeValue: 'Normal',
      proValue: 'Prioritas',
      isLimited: true,
    ),
  ];

  static const _proFeatures = [
    _FeatureDef(
      icon: Icons.all_inclusive_rounded,
      title: 'Semua Fitur Tanpa Batas',
      subtitle: 'Budget, rencana, hutang, investasi — unlimited',
    ),
    _FeatureDef(
      icon: Icons.block_rounded,
      title: 'Bebas Iklan',
      subtitle: 'Nikmati aplikasi tanpa gangguan iklan sama sekali',
    ),
    _FeatureDef(
      icon: Icons.auto_awesome_rounded,
      title: 'Semua AI Insight',
      subtitle: 'Analisis kondisi keuanganmu secara menyeluruh',
    ),
    _FeatureDef(
      icon: Icons.cloud_upload_rounded,
      title: 'Backup Harian + Manual',
      subtitle: 'Backup otomatis tiap hari & bisa backup kapan saja',
    ),
    _FeatureDef(
      icon: Icons.download_rounded,
      title: 'Export Lengkap',
      subtitle: 'Unduh semua riwayat dalam format PDF & Excel',
    ),
  ];

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mascot or icon
            Image.asset(
              'assets/images/mascot.png',
              width: 90,
              height: 90,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.check_circle_rounded,
                color: AppColors.income,
                size: 64,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Selamat, kamu Pro! 🎉',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Semua fitur Pro sudah aktif.\nNikmati pengalaman keuangan tanpa batas!',
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
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _kIndigo,
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
        content: Text(message,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13)),
        backgroundColor: AppColors.expense,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
    ref.read(premiumProvider.notifier).resetStatus();
  }
}

// ── Data models ───────────────────────────────────────────────────────────────

class _TableRow {
  final String label;
  final String freeValue;
  final String proValue;
  final bool isLimited; // true = free value shown as restricted

  const _TableRow({
    required this.label,
    required this.freeValue,
    required this.proValue,
    required this.isLimited,
  });
}

class _FeatureDef {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureDef({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

// ── Comparison Row ────────────────────────────────────────────────────────────

class _ComparisonRow extends StatelessWidget {
  final String label;
  final String freeValue;
  final String proValue;
  final bool isLimited;
  final bool isAlternate;
  final bool isLast;

  const _ComparisonRow({
    required this.label,
    required this.freeValue,
    required this.proValue,
    required this.isLimited,
    required this.isAlternate,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final freeColor = isLimited
        ? const Color(0xFFB45309) // amber-700
        : AppColors.textSecondary;
    final freeBg = isLimited
        ? const Color(0xFFFEF3C7) // amber-100
        : Colors.transparent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: isAlternate ? const Color(0xFFF8FAFF) : AppColors.white,
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          // Feature label
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),

          // Free value
          Expanded(
            flex: 3,
            child: Center(
              child: Container(
                padding: isLimited
                    ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
                    : EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: freeBg,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  freeValue,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: isLimited ? FontWeight.w600 : FontWeight.w400,
                    color: freeColor,
                  ),
                ),
              ),
            ),
          ),

          // Pro value
          Expanded(
            flex: 3,
            child: Center(
              child: Text(
                proValue,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _kIndigo,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pro Feature Row (for already-premium view) ────────────────────────────────

class _ProFeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ProFeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _kIndigo.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: _kIndigo, size: 20),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.4,
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

// ── Trust Badge ───────────────────────────────────────────────────────────────

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TrustBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: _kIndigo),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ],
        ),
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isSelected ? _kIndigo.withValues(alpha: 0.06) : AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? _kIndigo : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Radio circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? _kIndigo : AppColors.border,
                  width: 2,
                ),
                color: isSelected ? _kIndigo : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 12),

            // Label + subtitle
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
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? _kIndigo : AppColors.textPrimary,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
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
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Price
            Text(
              price,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected ? _kIndigo : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
