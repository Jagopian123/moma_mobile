import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'app_card.dart';

// ── Circular Progress ─────────────────────────────────────────────────────────

class AppCircularProgress extends StatefulWidget {
  final double value; // 0.0 - 1.0
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? backgroundColor;
  final Widget? center; // widget di tengah lingkaran
  final bool animate;

  const AppCircularProgress({
    super.key,
    required this.value,
    this.size = 80,
    this.strokeWidth = 8,
    this.color,
    this.backgroundColor,
    this.center,
    this.animate = true,
  });

  @override
  State<AppCircularProgress> createState() => _AppCircularProgressState();
}

class _AppCircularProgressState extends State<AppCircularProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = Tween<double>(
      begin: 0,
      end: widget.value.clamp(0.0, 1.0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.animate) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(AppCircularProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.value.clamp(0.0, 1.0),
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
      _controller.forward(from: 0);
    }
  }

  Color _resolveColor() {
    if (widget.color != null) return widget.color!;
    if (widget.value >= 0.9) return AppColors.danger;
    if (widget.value >= 0.7) return AppColors.warning;
    return AppColors.safe;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedColor = _resolveColor();

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _CircularProgressPainter(
              value: _animation.value,
              color: resolvedColor,
              backgroundColor: widget.backgroundColor ?? AppColors.border,
              strokeWidth: widget.strokeWidth,
            ),
            child: widget.center != null ? Center(child: widget.center) : null,
          ),
        );
      },
    );
  }
}

// ── Custom Painter ────────────────────────────────────────────────────────────

class _CircularProgressPainter extends CustomPainter {
  final double value;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  _CircularProgressPainter({
    required this.value,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    if (value > 0) {
      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2, // start dari atas
        2 * pi * value, // sweep angle
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CircularProgressPainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.color != color;
  }
}

// ── Budget Circular Card ──────────────────────────────────────────────────────
// Dipakai di halaman Budget per kategori

class AppBudgetCircularCard extends StatelessWidget {
  final String categoryName;
  final String categoryIcon;
  final double spent;
  final double limit;
  final Color color;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const AppBudgetCircularCard({
    super.key,
    required this.categoryName,
    required this.categoryIcon,
    required this.spent,
    required this.limit,
    required this.color,
    this.onEdit,
    this.onDelete,
  });

  String get _status {
    final pct = limit > 0 ? spent / limit : 0;
    if (pct >= 0.9) return 'Spending Fast';
    if (pct >= 0.7) return 'Slightly Fast';
    return 'Safe';
  }

  Color get _statusColor {
    final pct = limit > 0 ? spent / limit : 0;
    if (pct >= 0.9) return AppColors.danger;
    if (pct >= 0.7) return AppColors.warning;
    return AppColors.safe;
  }

  String _formatAmount(double amount) {
    if (amount >= 1000000) {
      return 'Rp${(amount / 1000000).toStringAsFixed(1)}jt';
    } else if (amount >= 1000) {
      return 'Rp${(amount / 1000).toStringAsFixed(0)}rb';
    }
    return 'Rp${amount.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final percentage = limit > 0 ? spent / limit : 0.0;

    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              // Circular progress
              AppCircularProgress(
                value: percentage.toDouble(),
                size: 64,
                strokeWidth: 6,
                color: _statusColor,
                center: Text(
                  categoryIcon,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(categoryName, style: AppTextStyles.bodyMedium),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        _status,
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
              ),

              // Actions
              if (onEdit != null || onDelete != null)
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.textHint,
                    size: 20,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  itemBuilder: (_) => [
                    if (onEdit != null)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 16),
                            SizedBox(width: 8),
                            Text('Edit',
                                style: TextStyle(fontFamily: 'Poppins')),
                          ],
                        ),
                      ),
                    if (onDelete != null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_rounded,
                                size: 16, color: AppColors.danger),
                            SizedBox(width: 8),
                            Text(
                              'Hapus',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                color: AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  onSelected: (val) {
                    if (val == 'edit') onEdit?.call();
                    if (val == 'delete') onDelete?.call();
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Data row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _DataItem(
                label: 'Spent',
                value: _formatAmount(spent),
                color: AppColors.expense,
              ),
              _DataItem(
                label: 'Limit',
                value: _formatAmount(limit),
                color: AppColors.textSecondary,
              ),
              _DataItem(
                label: 'Remaining',
                value: _formatAmount((limit - spent).clamp(0, double.infinity)),
                color: AppColors.safe,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DataItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DataItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10,
            color: AppColors.textHint,
          ),
        ),
      ],
    );
  }
}
