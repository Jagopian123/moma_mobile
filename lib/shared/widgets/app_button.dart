import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

enum AppButtonVariant { primary, secondary, outline, ghost, danger }

enum AppButtonSize { small, medium, large }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final bool isLoading;
  final bool fullWidth;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.prefixIcon,
    this.suffixIcon,
    this.isLoading = false,
    this.fullWidth = true,
  });

  // ── Factory constructors ──────────────────────────────────────
  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.medium,
    this.prefixIcon,
    this.suffixIcon,
    this.isLoading = false,
    this.fullWidth = true,
  }) : variant = AppButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.medium,
    this.prefixIcon,
    this.suffixIcon,
    this.isLoading = false,
    this.fullWidth = true,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.outline({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.medium,
    this.prefixIcon,
    this.suffixIcon,
    this.isLoading = false,
    this.fullWidth = true,
  }) : variant = AppButtonVariant.outline;

  const AppButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = AppButtonSize.medium,
    this.prefixIcon,
    this.suffixIcon,
    this.isLoading = false,
    this.fullWidth = true,
  }) : variant = AppButtonVariant.danger;

  // ── Style helpers ─────────────────────────────────────────────
  double get _height {
    switch (size) {
      case AppButtonSize.small:
        return 36;
      case AppButtonSize.medium:
        return 48;
      case AppButtonSize.large:
        return 56;
    }
  }

  double get _fontSize {
    switch (size) {
      case AppButtonSize.small:
        return 12;
      case AppButtonSize.medium:
        return 14;
      case AppButtonSize.large:
        return 16;
    }
  }

  double get _iconSize {
    switch (size) {
      case AppButtonSize.small:
        return 16;
      case AppButtonSize.medium:
        return 18;
      case AppButtonSize.large:
        return 20;
    }
  }

  Color get _bgColor {
    switch (variant) {
      case AppButtonVariant.primary:
        return AppColors.primary;
      case AppButtonVariant.secondary:
        return AppColors.primary.withOpacity(0.1);
      case AppButtonVariant.outline:
        return Colors.transparent;
      case AppButtonVariant.ghost:
        return Colors.transparent;
      case AppButtonVariant.danger:
        return AppColors.danger;
    }
  }

  Color get _fgColor {
    switch (variant) {
      case AppButtonVariant.primary:
        return Colors.white;
      case AppButtonVariant.secondary:
        return AppColors.primary;
      case AppButtonVariant.outline:
        return AppColors.primary;
      case AppButtonVariant.ghost:
        return AppColors.textSecondary;
      case AppButtonVariant.danger:
        return Colors.white;
    }
  }

  BorderSide get _border {
    switch (variant) {
      case AppButtonVariant.outline:
        return const BorderSide(color: AppColors.primary, width: 1.5);
      case AppButtonVariant.danger:
        return BorderSide.none;
      default:
        return BorderSide.none;
    }
  }

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: fullWidth ? double.infinity : null,
      height: _height,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: _bgColor,
          foregroundColor: _fgColor,
          side: _border,
          elevation: 0,
          padding: EdgeInsets.symmetric(
            horizontal: size == AppButtonSize.small ? 12 : 20,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textHint,
        ),
        child: isLoading
            ? SizedBox(
                width: _iconSize,
                height: _iconSize,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _fgColor,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (prefixIcon != null) ...[
                    Icon(prefixIcon, size: _iconSize),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: _fontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (suffixIcon != null) ...[
                    const SizedBox(width: 6),
                    Icon(suffixIcon, size: _iconSize),
                  ],
                ],
              ),
      ),
    );

    // Primary pakai gradient
    if (variant == AppButtonVariant.primary &&
        onPressed != null &&
        !isLoading) {
      return SizedBox(
        width: fullWidth ? double.infinity : null,
        height: _height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              side: BorderSide.none,
              elevation: 0,
              padding: EdgeInsets.symmetric(
                horizontal: size == AppButtonSize.small ? 12 : 20,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (prefixIcon != null) ...[
                  Icon(prefixIcon, size: _iconSize),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: _fontSize,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (suffixIcon != null) ...[
                  const SizedBox(width: 6),
                  Icon(suffixIcon, size: _iconSize),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return button;
  }
}
