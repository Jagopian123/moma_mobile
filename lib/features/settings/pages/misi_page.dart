import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/hive/hive_service.dart';
import '../../../core/services/admob_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../transaction/providers/ai_chat_provider.dart';

class MisiPage extends ConsumerStatefulWidget {
  const MisiPage({super.key});

  @override
  ConsumerState<MisiPage> createState() => _MisiPageState();
}

class _MisiPageState extends ConsumerState<MisiPage> {
  bool _isWatchingAd = false;

  // ── Local daily counter (sinkron dengan backend rate limit) ──────────────────

  String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  String _keyDate(String userId) => 'ad_watch_date_$userId';
  String _keyCount(String userId) => 'ad_watch_count_$userId';

  int _todayCount(String userId) {
    final savedDate = HiveService.user.get(_keyDate(userId)) as String?;
    if (savedDate != _today) return 0;
    return HiveService.user.get(_keyCount(userId)) as int? ?? 0;
  }

  void _incrementCount(String userId) {
    HiveService.user.put(_keyDate(userId), _today);
    HiveService.user.put(_keyCount(userId), _todayCount(userId) + 1);
  }

  // ── Watch ad flow ────────────────────────────────────────────────────────────

  Future<void> _watchAd(String userId) async {
    if (_isWatchingAd) return;

    setState(() => _isWatchingAd = true);

    final shown = await AdmobService.showRewardedAd(
      onRewarded: () async {
        final result = await ref.read(aiChatProvider.notifier).grantAdBonus();

        if (!mounted) return;

        switch (result) {
          case AdBonusResult.success:
            _incrementCount(userId);
            setState(() => _isWatchingAd = false);
            _showSnack(
              '+${AppConstants.adBonusCredits} kredit AI berhasil ditambahkan! 🎉',
              isError: false,
            );
          case AdBonusResult.limitReached:
            setState(() => _isWatchingAd = false);
            HiveService.user.put(_keyDate(userId), _today);
            HiveService.user.put(_keyCount(userId), AppConstants.adMaxPerDay);
            _showSnack(
              'Sudah ${AppConstants.adMaxPerDay}x nonton hari ini. Kembali besok!',
              isError: true,
            );
          case AdBonusResult.error:
            setState(() => _isWatchingAd = false);
            _showSnack('Gagal menambahkan kredit. Coba lagi.', isError: true);
        }
      },
    );

    if (!shown && mounted) {
      setState(() => _isWatchingAd = false);
      _showSnack('Gagal memuat iklan. Periksa koneksi dan coba lagi.', isError: true);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
        ),
        backgroundColor: isError ? AppColors.danger : AppColors.income,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aiChatProvider);
    final user = ref.watch(authProvider).user;
    final isPremium = user?.isPremium ?? false;
    final userId = user?.id.toString() ?? '';
    final count = _todayCount(userId);
    final isDone = count >= AppConstants.adMaxPerDay;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Misi', style: AppTextStyles.h3),
        centerTitle: false,
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // ── Credits card ─────────────────────────────────────────────────────
          _CreditsCard(chatState: chatState, isPremium: isPremium),
          const SizedBox(height: AppSpacing.lg),

          // ── Section label ─────────────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.only(left: AppSpacing.sm, bottom: AppSpacing.sm),
            child: Text(
              'MISI HARIAN',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // ── Mission card ──────────────────────────────────────────────────────
          _MissionCard(
            count: count,
            maxCount: AppConstants.adMaxPerDay,
            bonusCredits: AppConstants.adBonusCredits,
            isWatchingAd: _isWatchingAd,
            isDone: isDone,
            isPremium: isPremium,
            onWatch: () => _watchAd(userId),
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Reset info ────────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 13, color: AppColors.textHint),
              const SizedBox(width: 4),
              Text(
                'Misi reset setiap hari pukul 00:00',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Credits Card ──────────────────────────────────────────────────────────────

class _CreditsCard extends StatelessWidget {
  final AiChatState chatState;
  final bool isPremium;
  const _CreditsCard({required this.chatState, required this.isPremium});

  @override
  Widget build(BuildContext context) {
    final remaining = chatState.creditsRemaining;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kredit AI tersisa',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPremium
                      ? '∞ Unlimited'
                      : '$remaining / ${AppConstants.aiFreeMonthlyLimit}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          if (!isPremium) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${((remaining / AppConstants.aiFreeMonthlyLimit) * 100).clamp(0, 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 60,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    child: LinearProgressIndicator(
                      value:
                          (remaining / AppConstants.aiFreeMonthlyLimit).clamp(0.0, 1.0),
                      backgroundColor: Colors.white24,
                      color: Colors.white,
                      minHeight: 6,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Mission Card ──────────────────────────────────────────────────────────────

class _MissionCard extends StatelessWidget {
  final int count;
  final int maxCount;
  final int bonusCredits;
  final bool isWatchingAd;
  final bool isDone;
  final bool isPremium;
  final VoidCallback onWatch;

  const _MissionCard({
    required this.count,
    required this.maxCount,
    required this.bonusCredits,
    required this.isWatchingAd,
    required this.isDone,
    required this.isPremium,
    required this.onWatch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9C4),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Center(
                    child: Text('🎬', style: TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tonton Iklan',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Dapatkan +$bonusCredits kredit AI per tayangan',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Reward badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9C4),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bolt_rounded,
                          size: 13, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 2),
                      Text(
                        '+$bonusCredits',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // Progress dots
            Row(
              children: List.generate(maxCount, (i) {
                final done = i < count;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: done ? 32 : 28,
                    height: 8,
                    decoration: BoxDecoration(
                      color: done
                          ? AppColors.income
                          : AppColors.border,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 6),
            Text(
              isDone
                  ? 'Selesai untuk hari ini ✓'
                  : '$count / $maxCount selesai hari ini',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: isDone ? AppColors.income : AppColors.textSecondary,
                fontWeight:
                    isDone ? FontWeight.w600 : FontWeight.w400,
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Button
            SizedBox(
              width: double.infinity,
              child: isDone
                  ? OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check_circle_rounded,
                          size: 16, color: AppColors.income),
                      label: const Text(
                        'Misi hari ini selesai',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: AppColors.income,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColors.income),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: isWatchingAd ? null : onWatch,
                      icon: isWatchingAd
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.play_circle_filled_rounded,
                              size: 18),
                      label: Text(
                        isWatchingAd
                            ? 'Memuat iklan...'
                            : 'Tonton Iklan (+$bonusCredits kredit)',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
