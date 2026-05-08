import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/hive/hive_service.dart';
import '../../../core/services/security_service.dart';

class SecurityState {
  final bool isEnabled;
  final bool isBiometricEnabled;
  final bool hasPin;
  final bool isLocked;

  const SecurityState({
    this.isEnabled = false,
    this.isBiometricEnabled = false,
    this.hasPin = false,
    this.isLocked = false,
  });

  SecurityState copyWith({
    bool? isEnabled,
    bool? isBiometricEnabled,
    bool? hasPin,
    bool? isLocked,
  }) {
    return SecurityState(
      isEnabled: isEnabled ?? this.isEnabled,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      hasPin: hasPin ?? this.hasPin,
      isLocked: isLocked ?? this.isLocked,
    );
  }
}

class SecurityNotifier extends StateNotifier<SecurityState> {
  SecurityNotifier() : super(const SecurityState()) {
    _load();
  }

  final _service = SecurityService();

  void _load() {
    final box = HiveService.user;
    final isEnabled =
        box.get(AppConstants.keySecurityEnabled, defaultValue: false) as bool;
    final isBiometricEnabled =
        box.get(AppConstants.keyBiometricEnabled, defaultValue: false) as bool;
    final hasPin = box.get(AppConstants.keyPinHash) != null;

    state = SecurityState(
      isEnabled: isEnabled,
      isBiometricEnabled: isBiometricEnabled,
      hasPin: hasPin,
      // Cold start: kunci jika ada metode auth (PIN atau biometrik), terlepas dari toggle background
      isLocked: hasPin || isBiometricEnabled,
    );
  }

  // ── Aktifkan / nonaktifkan app lock ───────────────────────────

  Future<void> setEnabled(bool value) async {
    await HiveService.user.put(AppConstants.keySecurityEnabled, value);
    state = state.copyWith(isEnabled: value, isLocked: false);
  }

  // ── Biometrik ─────────────────────────────────────────────────

  Future<void> setBiometric(bool value) async {
    await HiveService.user.put(AppConstants.keyBiometricEnabled, value);
    state = state.copyWith(isBiometricEnabled: value);
  }

  // ── PIN ───────────────────────────────────────────────────────

  Future<void> setPin(String pin) async {
    final hash = _service.hashPin(pin);
    await HiveService.user.put(AppConstants.keyPinHash, hash);
    state = state.copyWith(hasPin: true);
  }

  Future<void> removePin() async {
    await HiveService.user.delete(AppConstants.keyPinHash);
    state = state.copyWith(hasPin: false);
  }

  bool verifyPin(String input) {
    final stored = HiveService.user.get(AppConstants.keyPinHash) as String?;
    if (stored == null) return false;
    return _service.verifyPin(input, stored);
  }

  // ── Lock / Unlock ─────────────────────────────────────────────

  void lock() {
    if (state.isEnabled && (state.hasPin || state.isBiometricEnabled)) {
      state = state.copyWith(isLocked: true);
    }
  }

  void unlock() {
    state = state.copyWith(isLocked: false);
  }
}

final securityProvider =
    StateNotifierProvider<SecurityNotifier, SecurityState>((ref) {
  return SecurityNotifier();
});
