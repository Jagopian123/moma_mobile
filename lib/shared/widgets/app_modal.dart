import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

// ── Helper show modal ─────────────────────────────────────────────────────────

Future<T?> showAppModal<T>({
  required BuildContext context,
  required Widget child,
  String? title,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (_) => AppModal(title: title, child: child),
  );
}

// ── Modal Widget ──────────────────────────────────────────────────────────────

class AppModal extends StatelessWidget {
  final Widget child;
  final String? title;

  const AppModal({
    super.key,
    required this.child,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      backgroundColor: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(child: Text(title!, style: AppTextStyles.h4)),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(color: AppColors.border),
              const SizedBox(height: AppSpacing.md),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

// ── Alert Modal ───────────────────────────────────────────────────────────────

Future<void> showAlertModal({
  required BuildContext context,
  required String title,
  required String message,
  String buttonLabel = 'Oke',
  bool isError = false,
}) {
  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      backgroundColor: AppColors.white,
      title: Row(
        children: [
          if (isError) ...[
            const Icon(Icons.error_outline_rounded,
                color: AppColors.danger, size: 22),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: AppTextStyles.h4,
          ),
        ],
      ),
      content: Text(
        message,
        style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: isError ? AppColors.danger : AppColors.primary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          child: Text(
            buttonLabel,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ],
    ),
  );
}

// ── Loading Modal ─────────────────────────────────────────────────────────────

void showLoadingModal(BuildContext context, {String message = 'Memproses...'}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => WillPopScope(
      onWillPop: () async => false,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        backgroundColor: AppColors.white,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                message,
                style: AppTextStyles.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void hideLoadingModal(BuildContext context) {
  if (Navigator.canPop(context)) Navigator.pop(context);
}
