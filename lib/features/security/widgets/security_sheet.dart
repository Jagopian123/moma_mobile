import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/security_service.dart';
import '../providers/security_provider.dart';
import 'pin_setup_sheet.dart';

class SecuritySheet extends ConsumerStatefulWidget {
  const SecuritySheet({super.key});

  @override
  ConsumerState<SecuritySheet> createState() => _SecuritySheetState();
}

class _SecuritySheetState extends ConsumerState<SecuritySheet> {
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    SecurityService().isBiometricAvailable().then((v) {
      if (mounted) setState(() => _biometricAvailable = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final security = ref.watch(securityProvider);
    final notifier = ref.read(securityProvider.notifier);

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.expense.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: AppColors.expense,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Keamanan', style: AppTextStyles.h4),
                    Text('Lindungi data keuanganmu', style: AppTextStyles.caption),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Aktifkan App Lock ──────────────────────────────
            _SheetTile(
              icon: Icons.lock_rounded,
              iconColor: AppColors.primary,
              title: 'Kunci di Latar Belakang',
              subtitle: 'Kunci app otomatis saat pindah ke app lain',
              trailing: Switch.adaptive(
                value: security.isEnabled,
                activeTrackColor: AppColors.primary,
                onChanged: (v) async {
                  if (v && !security.hasPin && !_biometricAvailable) {
                    _showNeedPinOrBioAlert(context);
                    return;
                  }
                  await notifier.setEnabled(v);
                },
              ),
            ),
            const Divider(color: AppColors.border, height: 1),

            // ── Biometrik ──────────────────────────────────────
            _SheetTile(
              icon: Icons.fingerprint_rounded,
              iconColor: const Color(0xFF10B981),
              title: 'Sidik Jari / Face ID',
              subtitle: _biometricAvailable
                  ? 'Gunakan biometrik untuk membuka app'
                  : 'Tidak tersedia di perangkat ini',
              trailing: Switch.adaptive(
                value: security.isBiometricEnabled && _biometricAvailable,
                activeTrackColor: AppColors.primary,
                onChanged: _biometricAvailable
                    ? (v) => notifier.setBiometric(v)
                    : null,
              ),
            ),
            const Divider(color: AppColors.border, height: 1),

            // ── PIN ────────────────────────────────────────────
            _SheetTile(
              icon: Icons.pin_rounded,
              iconColor: const Color(0xFF8B5CF6),
              title: security.hasPin ? 'Ganti PIN' : 'Buat PIN',
              subtitle: security.hasPin
                  ? 'PIN 4 digit sudah diatur'
                  : 'Belum ada PIN, tap untuk membuat',
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textHint,
              ),
              onTap: () => _showPinSetup(context),
            ),

            if (security.hasPin) ...[
              const Divider(color: AppColors.border, height: 1),
              _SheetTile(
                icon: Icons.no_encryption_rounded,
                iconColor: AppColors.expense,
                title: 'Hapus PIN',
                subtitle: 'Nonaktifkan pengamanan PIN',
                trailing: const SizedBox.shrink(),
                onTap: () => _confirmRemovePin(context),
              ),
            ],

            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  void _showPinSetup(BuildContext context) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PinSetupSheet(),
    );
  }

  void _confirmRemovePin(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text(
          'Hapus PIN?',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'PIN akan dihapus. Pastikan kamu masih mengaktifkan biometrik agar app tetap aman.',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Batal',
              style: TextStyle(fontFamily: 'Poppins', color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(securityProvider.notifier).removePin();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expense,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: const Text(
              'Hapus',
              style: TextStyle(
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

  void _showNeedPinOrBioAlert(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Buat PIN atau aktifkan biometrik terlebih dahulu',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.warning,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}

// ── Sheet Tile ────────────────────────────────────────────────────────────────

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SheetTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.bodyMedium),
                  Text(subtitle, style: AppTextStyles.small),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
