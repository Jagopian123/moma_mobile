import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

/// Shows a bottom sheet when user hits a free plan limit.
/// [featureName] e.g. "Budget", "Rencana Finansial"
/// [freeLimit]   e.g. 3
void showPlanLimitSheet(
  BuildContext context, {
  required String featureName,
  required int freeLimit,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _PlanLimitSheet(
      featureName: featureName,
      freeLimit: freeLimit,
    ),
  );
}

class _PlanLimitSheet extends StatelessWidget {
  final String featureName;
  final int freeLimit;

  const _PlanLimitSheet({
    required this.featureName,
    required this.freeLimit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: const Center(
              child: Icon(Icons.workspace_premium_rounded,
                  size: 32, color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            'Batas Free Plan Tercapai',
            style: AppTextStyles.h3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Free plan hanya mendukung $freeLimit $featureName. '
            'Upgrade ke Pro untuk menambahkan lebih banyak tanpa batas.',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Pro benefits
          _BenefitRow(
            icon: Icons.all_inclusive_rounded,
            text: '$featureName tanpa batas',
          ),
          const SizedBox(height: 10),
          _BenefitRow(
            icon: Icons.cloud_upload_rounded,
            text: 'Backup otomatis ke cloud',
          ),
          const SizedBox(height: 10),
          _BenefitRow(
            icon: Icons.download_rounded,
            text: 'Export data lengkap (PDF & Excel)',
          ),
          const SizedBox(height: 10),
          _BenefitRow(
            icon: Icons.auto_awesome_rounded,
            text: 'Semua AI Insight tanpa pembatasan',
          ),
          const SizedBox(height: 28),

          // Upgrade button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.push('/premium');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Lihat Paket Pro',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Cancel button
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'Nanti saja',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BenefitRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Center(
            child: Icon(icon, size: 16, color: const Color(0xFF6366F1)),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
