import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/export_service.dart';
import '../../../core/services/import_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../asset/providers/wallet_provider.dart';
import '../../asset/providers/investment_provider.dart';
import '../../transaction/providers/transaction_provider.dart';
import '../../budget/providers/budget_provider.dart';
import '../../financial_plan/providers/financial_plan_provider.dart';
import '../../debt/providers/debt_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pengaturan', style: AppTextStyles.h3),
        centerTitle: false,
        backgroundColor: AppColors.background,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // ── Profile Card ─────────────────────────────────────
          GestureDetector(
            onTap: () => context.push('/profile'),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Text(
                      user?.name.isNotEmpty == true
                          ? user!.name[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Pengguna',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          user?.email ?? '',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Fitur ────────────────────────────────────────────
          _SectionLabel(label: 'Fitur'),
          const SizedBox(height: AppSpacing.sm),
          _SettingsGroup(
            items: [
              _SettingsItem(
                icon: Icons.help_outline_rounded,
                iconColor: AppColors.primary,
                label: 'FAQ',
                onTap: () => _showComingSoon(context),
              ),
              _SettingsItem(
                icon: Icons.emoji_events_rounded,
                iconColor: const Color(0xFFF59E0B),
                label: 'Misi',
                onTap: () => _showComingSoon(context),
              ),
              _SettingsItem(
                icon: Icons.workspace_premium_rounded,
                iconColor: const Color(0xFF8B5CF6),
                label: 'Premium',
                badge: 'Segera',
                onTap: () => _showComingSoon(context),
              ),
              _SettingsItem(
                icon: Icons.cloud_upload_rounded,
                iconColor: const Color(0xFF06B6D4),
                label: 'Backup Data',
                badge: 'Segera',
                onTap: () => _showComingSoon(context),
              ),
              _SettingsItem(
                icon: Icons.download_rounded,
                iconColor: const Color(0xFF10B981),
                label: 'Ekspor & Import Data',
                onTap: () => _showDataSheet(context, ref),
              ),
              _SettingsItem(
                icon: Icons.security_rounded,
                iconColor: const Color(0xFFEF4444),
                label: 'Keamanan',
                isLast: true,
                onTap: () => _showComingSoon(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Tentang Aplikasi ─────────────────────────────────
          _SectionLabel(label: 'Tentang Aplikasi'),
          const SizedBox(height: AppSpacing.sm),
          _SettingsGroup(
            items: [
              _SettingsItem(
                icon: Icons.info_outline_rounded,
                iconColor: AppColors.primary,
                label: 'Versi',
                value: '1.0.0',
                onTap: null,
              ),
              _SettingsItem(
                icon: Icons.bug_report_rounded,
                iconColor: const Color(0xFFF97316),
                label: 'Laporan Bug & Saran',
                onTap: () => _showComingSoon(context),
              ),
              _SettingsItem(
                icon: Icons.privacy_tip_rounded,
                iconColor: const Color(0xFF6366F1),
                label: 'Kebijakan Privasi',
                isLast: true,
                onTap: () => _showComingSoon(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Logout ───────────────────────────────────────────
          _SettingsGroup(
            items: [
              _SettingsItem(
                icon: Icons.logout_rounded,
                iconColor: AppColors.danger,
                label: 'Keluar dari Akun',
                labelColor: AppColors.danger,
                showArrow: false,
                isLast: true,
                onTap: () => _confirmLogout(context, ref),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Footer
          Center(
            child: Column(
              children: [
                Text(
                  'Moma',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary.withOpacity(0.6),
                  ),
                ),
                Text(
                  'Catat keuangan lebih cerdas',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Fitur ini segera hadir!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }

  // ── Data Sheet ────────────────────────────────────────────────

  void _showDataSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const Text('Data', style: AppTextStyles.h3),
                const SizedBox(height: 4),
                const Text(
                  'Import atau ekspor data kamu',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Import
                _ExportOption(
                  icon: Icons.upload_file_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  label: 'Import Data (JSON)',
                  description: 'Pulihkan data dari file backup Moma',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showImportDialog(context, ref);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                const Divider(color: AppColors.border),
                const SizedBox(height: AppSpacing.sm),

                // Export JSON
                _ExportOption(
                  icon: Icons.data_object_rounded,
                  iconColor: const Color(0xFF2563EB),
                  label: 'Backup Semua Data (JSON)',
                  description:
                      'Semua data termasuk transaksi, aset, budget, dll',
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    try {
                      await ExportService().exportJson();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Gagal ekspor: $e')),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.sm),

                // Export CSV Transaksi
                _ExportOption(
                  icon: Icons.table_chart_rounded,
                  iconColor: const Color(0xFF10B981),
                  label: 'Ekspor Transaksi (CSV)',
                  description: 'Data transaksi dalam format spreadsheet',
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    try {
                      await ExportService().exportTransactionsCsv();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Gagal ekspor: $e')),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.sm),

                // Export CSV Aset
                _ExportOption(
                  icon: Icons.account_balance_wallet_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  label: 'Ekspor Aset (CSV)',
                  description: 'Data dompet dan investasi',
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    try {
                      await ExportService().exportAssetsCsv();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Gagal ekspor: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Import Dialog ─────────────────────────────────────────────

  void _showImportDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text(
          'Import Data',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'Pilih mode import:\n\n'
          '• Gabung — data baru ditambahkan, data lama tetap ada\n'
          '• Ganti — semua data lama dihapus dan diganti dengan data baru',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Batal',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: AppColors.textSecondary,
              ),
            ),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _doImport(context, ref, ImportMode.merge);
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: const Text(
              'Gabung',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: AppColors.primary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _doImport(context, ref, ImportMode.replace);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: const Text(
              'Ganti',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Do Import ─────────────────────────────────────────────────

  Future<void> _doImport(
      BuildContext context, WidgetRef ref, ImportMode mode) async {
    try {
      final result = await ImportService().pickAndImport(mode: mode);

      if (result == null) return;

      if (!context.mounted) return;

      // Refresh semua provider supaya UI update tanpa restart
      if (result.success) {
        ref.invalidate(walletProvider);
        ref.invalidate(transactionProvider);
        ref.invalidate(budgetProvider);
        ref.invalidate(financialPlanProvider);
        ref.invalidate(debtProvider);
        ref.invalidate(investmentProvider);
      }

      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          title: Row(
            children: [
              Icon(
                result.success
                    ? Icons.check_circle_rounded
                    : Icons.error_rounded,
                color: result.success ? AppColors.safe : AppColors.danger,
              ),
              const SizedBox(width: 8),
              Text(
                result.success ? 'Berhasil' : 'Gagal',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: result.success
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Data berhasil diimport:',
                      style: TextStyle(fontFamily: 'Poppins'),
                    ),
                    const SizedBox(height: 8),
                    ...result.counts.entries
                        .where((e) => e.value > 0)
                        .map((e) => Text(
                              '• ${_countLabel(e.key)}: ${e.value}',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                              ),
                            )),
                  ],
                )
              : Text(
                  result.message,
                  style: const TextStyle(fontFamily: 'Poppins'),
                ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: const Text(
                'OK',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e, stack) {
      debugPrint('Import error: $e');
      debugPrint('Stack: $stack');
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            title: const Row(
              children: [
                Icon(Icons.error_rounded, color: AppColors.danger),
                SizedBox(width: 8),
                Text(
                  'Error',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            content: Text(
              e.toString(),
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  String _countLabel(String key) {
    switch (key) {
      case 'wallets':
        return 'Dompet';
      case 'transactions':
        return 'Transaksi';
      case 'budgets':
        return 'Budget';
      case 'plans':
        return 'Rencana Finansial';
      case 'debts':
        return 'Hutang & Piutang';
      case 'investments':
        return 'Investasi';
      default:
        return key;
    }
  }

  // ── Logout ────────────────────────────────────────────────────

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text(
          'Keluar',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'Apakah kamu yakin ingin keluar dari akun ini?',
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Batal',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: const Text(
              'Keluar',
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

    if (confirm == true && context.mounted) {
      await ref.read(authProvider.notifier).signOut();
      if (context.mounted) context.go('/login');
    }
  }
}

// ── Section Label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.sm),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Settings Group ────────────────────────────────────────────────────────────

class _SettingsGroup extends StatelessWidget {
  final List<_SettingsItem> items;
  const _SettingsGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: items),
    );
  }
}

// ── Settings Item ─────────────────────────────────────────────────────────────

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color? labelColor;
  final String? value;
  final String? badge;
  final bool showArrow;
  final bool isLast;
  final VoidCallback? onTap;

  const _SettingsItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.labelColor,
    this.value,
    this.badge,
    this.showArrow = true,
    this.isLast = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.vertical(
              bottom:
                  isLast ? const Radius.circular(AppRadius.lg) : Radius.zero,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 14,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(icon, size: 18, color: iconColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: labelColor ?? AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (value != null)
                    Text(
                      value!,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    )
                  else if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  else if (showArrow)
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textHint,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 64, color: AppColors.border),
      ],
    );
  }
}

// ── Export Option ─────────────────────────────────────────────────────────────

class _ExportOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String description;
  final VoidCallback onTap;

  const _ExportOption({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.bodyMedium),
                  Text(description, style: AppTextStyles.small),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textHint, size: 20),
          ],
        ),
      ),
    );
  }
}
