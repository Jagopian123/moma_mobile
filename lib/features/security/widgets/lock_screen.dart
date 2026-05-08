import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/security_service.dart';
import '../providers/security_provider.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final List<String> _pin = [];
  String? _errorMessage;
  bool _isAuthenticating = false;
  static const _pinLength = 4;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  Future<void> _tryBiometric() async {
    final security = ref.read(securityProvider);
    if (!security.isBiometricEnabled) return;
    if (_isAuthenticating) return;

    setState(() => _isAuthenticating = true);
    final ok = await SecurityService().authenticateWithBiometric();
    if (!mounted) return;
    setState(() => _isAuthenticating = false);

    if (ok) ref.read(securityProvider.notifier).unlock();
  }

  void _onKey(String key) {
    if (_pin.length >= _pinLength) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pin.add(key);
      _errorMessage = null;
    });
    if (_pin.length == _pinLength) _verifyPin();
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pin.removeLast();
      _errorMessage = null;
    });
  }

  void _verifyPin() {
    final ok = ref.read(securityProvider.notifier).verifyPin(_pin.join());
    if (ok) {
      ref.read(securityProvider.notifier).unlock();
    } else {
      HapticFeedback.vibrate();
      setState(() {
        _pin.clear();
        _errorMessage = 'PIN salah, coba lagi';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final security = ref.watch(securityProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: security.hasPin
            ? _buildPinLayout(security.isBiometricEnabled)
            : _buildBiometricLayout(),
      ),
    );
  }

  // ── Layout PIN (dengan optional tombol biometrik di numpad) ───────────────

  Widget _buildPinLayout(bool showBiometric) {
    return Column(
      children: [
        const Spacer(flex: 2),

        const _Logo(subtitle: 'Masukkan PIN untuk melanjutkan'),

        const Spacer(),

        // PIN dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_pinLength, (i) {
            final filled = i < _pin.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: filled ? 18 : 16,
              height: filled ? 18 : 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: filled ? AppColors.primary : AppColors.textHint,
                  width: 2,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: AppSpacing.sm),

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _errorMessage != null
              ? Text(
                  _errorMessage!,
                  key: ValueKey(_errorMessage),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: AppColors.expense,
                    fontWeight: FontWeight.w500,
                  ),
                )
              : const SizedBox(height: 18),
        ),

        const Spacer(),

        _Numpad(
          onKey: _onKey,
          onDelete: _onDelete,
          showBiometric: showBiometric,
          isAuthenticating: _isAuthenticating,
          onBiometric: _tryBiometric,
        ),

        const Spacer(flex: 2),
      ],
    );
  }

  // ── Layout biometrik saja (tanpa PIN) — Center ────────────────────────────

  Widget _buildBiometricLayout() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Logo(subtitle: 'Gunakan sidik jari / Face ID\nuntuk melanjutkan'),

          const SizedBox(height: 56),

          GestureDetector(
            onTap: _isAuthenticating ? null : _tryBiometric,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: _isAuthenticating
                    ? AppColors.textHint.withValues(alpha: 0.1)
                    : AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.fingerprint_rounded,
                size: 48,
                color:
                    _isAuthenticating ? AppColors.textHint : AppColors.primary,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          Text(
            _isAuthenticating ? 'Memverifikasi...' : 'Ketuk untuk mencoba lagi',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

// ── Logo + title ──────────────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  final String subtitle;
  const _Logo({required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: const Icon(Icons.lock_rounded, color: Colors.white, size: 32),
        ),
        const SizedBox(height: AppSpacing.md),
        const Text('Moma', style: AppTextStyles.h2),
        const SizedBox(height: AppSpacing.sm),
        Text(
          subtitle,
          style: AppTextStyles.caption,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Numpad ────────────────────────────────────────────────────────────────────

class _Numpad extends StatelessWidget {
  final ValueChanged<String> onKey;
  final VoidCallback onDelete;
  final VoidCallback onBiometric;
  final bool showBiometric;
  final bool isAuthenticating;

  const _Numpad({
    required this.onKey,
    required this.onDelete,
    required this.onBiometric,
    required this.showBiometric,
    required this.isAuthenticating,
  });

  @override
  Widget build(BuildContext context) {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: [
          ...keys.map((row) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: row
                      .map((k) => _NumKey(label: k, onTap: () => onKey(k)))
                      .toList(),
                ),
              )),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              showBiometric
                  ? _IconKey(
                      icon: Icons.fingerprint_rounded,
                      color: isAuthenticating
                          ? AppColors.textHint
                          : AppColors.primary,
                      onTap: isAuthenticating ? null : onBiometric,
                    )
                  : const SizedBox(width: 72),
              _NumKey(label: '0', onTap: () => onKey('0')),
              _IconKey(
                icon: Icons.backspace_outlined,
                color: AppColors.textSecondary,
                onTap: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _NumKey({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconKey extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _IconKey({required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        height: 72,
        child: Center(child: Icon(icon, size: 26, color: color)),
      ),
    );
  }
}
