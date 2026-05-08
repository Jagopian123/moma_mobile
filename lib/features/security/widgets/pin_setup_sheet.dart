import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/security_provider.dart';

enum _PinStep { create, confirm }

class PinSetupSheet extends ConsumerStatefulWidget {
  const PinSetupSheet({super.key});

  @override
  ConsumerState<PinSetupSheet> createState() => _PinSetupSheetState();
}

class _PinSetupSheetState extends ConsumerState<PinSetupSheet> {
  _PinStep _step = _PinStep.create;
  final List<String> _pin = [];
  String _firstPin = '';
  String? _errorMessage;
  static const _pinLength = 4;

  void _onKey(String key) {
    if (_pin.length >= _pinLength) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pin.add(key);
      _errorMessage = null;
    });
    if (_pin.length == _pinLength) _handleComplete();
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pin.removeLast();
      _errorMessage = null;
    });
  }

  Future<void> _handleComplete() async {
    final entered = _pin.join();

    if (_step == _PinStep.create) {
      await Future.delayed(const Duration(milliseconds: 150));
      setState(() {
        _firstPin = entered;
        _pin.clear();
        _step = _PinStep.confirm;
      });
    } else {
      if (entered == _firstPin) {
        await ref.read(securityProvider.notifier).setPin(entered);
        // Aktifkan security otomatis jika belum aktif
        if (!ref.read(securityProvider).isEnabled) {
          await ref.read(securityProvider.notifier).setEnabled(true);
        }
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('PIN berhasil dibuat ✓'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.income,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          );
        }
      } else {
        HapticFeedback.vibrate();
        setState(() {
          _pin.clear();
          _step = _PinStep.create;
          _firstPin = '';
          _errorMessage = 'PIN tidak cocok, mulai ulang';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),

            // Title
            Text(
              _step == _PinStep.create ? 'Buat PIN Baru' : 'Konfirmasi PIN',
              style: AppTextStyles.h3,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _step == _PinStep.create
                  ? 'Masukkan 4 digit PIN kamu'
                  : 'Masukkan PIN yang sama sekali lagi',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),

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

            // Error
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

            const SizedBox(height: AppSpacing.lg),

            // Numpad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: _buildNumpad(),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];
    return Column(
      children: [
        ...rows.map((row) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: row
                    .map((k) => _NumKey(label: k, onTap: () => _onKey(k)))
                    .toList(),
              ),
            )),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 72),
            _NumKey(label: '0', onTap: () => _onKey('0')),
            _IconKey(
              icon: Icons.backspace_outlined,
              onTap: _onDelete,
            ),
          ],
        ),
      ],
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
          color: AppColors.background,
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
  final VoidCallback onTap;
  const _IconKey({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        height: 72,
        child: Center(
          child: Icon(icon, size: 24, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
