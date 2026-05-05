import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

// ── Linear Progress Bar ───────────────────────────────────────────────────────

class AppProgressBar extends StatelessWidget {
  final double value; // 0.0 - 1.0
  final double height;
  final Color? color;
  final Color? backgroundColor;
  final bool showPercentage;
  final bool animate;

  const AppProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.color,
    this.backgroundColor,
    this.showPercentage = false,
    this.animate = true,
  });

  Color _resolveColor() {
    if (color != null) return color!;
    if (value >= 0.9) return AppColors.danger;
    if (value >= 0.7) return AppColors.warning;
    return AppColors.safe;
  }

  @override
  Widget build(BuildContext context) {
    final resolvedColor = _resolveColor();
    final clampedValue = value.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: Stack(
            children: [
              // Background
              Container(
                height: height,
                width: double.infinity,
                color: backgroundColor ?? AppColors.border,
              ),
              // Progress
              LayoutBuilder(
                builder: (context, constraints) {
                  return AnimatedContainer(
                    duration: animate
                        ? const Duration(milliseconds: 600)
                        : Duration.zero,
                    curve: Curves.easeInOut,
                    height: height,
                    width: constraints.maxWidth * clampedValue,
                    decoration: BoxDecoration(
                      color: resolvedColor,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        if (showPercentage) ...[
          const SizedBox(height: 4),
          Text(
            '${(clampedValue * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: resolvedColor,
            ),
          ),
        ],
      ],
    );
  }
}

// ── Budget Progress Bar (dengan label kiri kanan) ─────────────────────────────

class AppBudgetProgressBar extends StatelessWidget {
  final double spent;
  final double limit;
  final bool showLabels;

  const AppBudgetProgressBar({
    super.key,
    required this.spent,
    required this.limit,
    this.showLabels = false,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;

    Color barColor;
    if (percentage >= 0.9) {
      barColor = AppColors.danger;
    } else if (percentage >= 0.7) {
      barColor = AppColors.warning;
    } else {
      barColor = AppColors.safe;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppProgressBar(value: percentage, color: barColor),
        if (showLabels) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(percentage * 100).toStringAsFixed(0)}% terpakai',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: barColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Sisa ${(100 - percentage * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Timeline Progress Bar (untuk budget bulanan) ──────────────────────────────

class AppTimelineProgressBar extends StatelessWidget {
  final double budgetPercentage; // seberapa banyak budget terpakai
  final double timePercentage; // seberapa jauh waktu bulan berjalan
  final String todayLabel;

  const AppTimelineProgressBar({
    super.key,
    required this.budgetPercentage,
    required this.timePercentage,
    this.todayLabel = 'Hari ini',
  });

  @override
  Widget build(BuildContext context) {
    // Tambahkan null/NaN check
    final budget = (budgetPercentage.isNaN || budgetPercentage.isInfinite)
        ? 0.0
        : budgetPercentage.clamp(0.0, 1.0);
    final time = (timePercentage.isNaN || timePercentage.isInfinite)
        ? 0.0
        : timePercentage.clamp(0.0, 1.0);

    Color barColor;
    if (budget > time + 0.1) {
      barColor = AppColors.danger; // boros
    } else if (budget > time - 0.05) {
      barColor = AppColors.warning; // normal
    } else {
      barColor = AppColors.safe; // hemat
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            // Background bar
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: Container(
                height: 10,
                width: double.infinity,
                color: AppColors.border,
              ),
            ),
            // Budget bar
            LayoutBuilder(
              builder: (context, constraints) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeInOut,
                    height: 10,
                    width: constraints.maxWidth * budget,
                    color: barColor,
                  ),
                );
              },
            ),
            // Today marker — ganti Positioned dengan LayoutBuilder + Transform
            LayoutBuilder(
              builder: (context, constraints) {
                return Transform.translate(
                  offset: Offset((constraints.maxWidth * time) - 1, 0),
                  child: Container(
                    width: 2,
                    height: 10,
                    color: AppColors.textPrimary,
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '1',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: AppColors.textHint,
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                return Text(
                  '$todayLabel ${(time * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                );
              },
            ),
            Text(
              '31',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
