import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/providers/app_info_provider.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── App Bar gradient ─────────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),

                      // Avatar
                      _buildAvatar(user.avatar, user.name),
                      const SizedBox(height: 12),

                      // Nama
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),

                      // Email
                      Text(
                        user.email,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Premium badge (kalau premium)
                  if (user.isPremium) ...[
                    _PremiumBadge(),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Informasi akun
                  _SectionCard(
                    title: 'Informasi Akun',
                    children: [
                      _InfoRow(
                        icon: Icons.person_rounded,
                        label: 'Nama',
                        value: user.name,
                      ),
                      _InfoRow(
                        icon: Icons.email_rounded,
                        label: 'Email',
                        value: user.email,
                      ),
                      _InfoRow(
                        icon: Icons.monetization_on_rounded,
                        label: 'Mata Uang',
                        value: user.currency,
                      ),
                      _InfoRow(
                        icon: Icons.language_rounded,
                        label: 'Bahasa',
                        value: user.locale == 'id' ? 'Indonesia' : 'English',
                        isLast: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Status Google
                  _SectionCard(
                    title: 'Akun Google',
                    children: [
                      _InfoRow(
                        icon: Icons.account_circle_rounded,
                        label: 'Status',
                        value: 'Terhubung',
                        valueColor: AppColors.income,
                        isLast: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Versi app
                  _SectionCard(
                    title: 'Aplikasi',
                    children: [
                      _InfoRow(
                        icon: Icons.info_outline_rounded,
                        label: 'Versi',
                        value: ref.watch(appVersionProvider).valueOrNull ?? '...',
                        isLast: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Tombol logout
                  _LogoutButton(),

                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? avatarUrl, String name) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 42,
        backgroundImage: CachedNetworkImageProvider(avatarUrl),
        backgroundColor: AppColors.primaryLight,
      );
    }
    return CircleAvatar(
      radius: 42,
      backgroundColor: Colors.white.withOpacity(0.25),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ── Premium Badge ────────────────────────────────────────────────────────────

class _PremiumBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFB800), Color(0xFFFF8C00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFB800).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: const [
          Text('👑', style: TextStyle(fontSize: 28)),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Moma Premium',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                'Nikmati semua fitur tanpa batas',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Section Card ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.sm,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

// ── Info Row ─────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isLast;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
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
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(
            height: 1,
            indent: 64,
            endIndent: 16,
            color: AppColors.border,
          ),
      ],
    );
  }
}

// ── Logout Button ─────────────────────────────────────────────────────────────

class _LogoutButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              title: const Text(
                'Keluar dari Akun',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              content: const Text(
                'Apakah kamu yakin ingin keluar dari akun ini?',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    'Batal',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
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
        },
        icon: const Icon(
          Icons.logout_rounded,
          color: AppColors.danger,
          size: 20,
        ),
        label: const Text(
          'Keluar dari Akun',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.danger,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: AppColors.danger),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
    );
  }
}
