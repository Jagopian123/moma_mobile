import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:flutter/services.dart';

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  final _auth = LocalAuthentication();

  // ── Biometrik ─────────────────────────────────────────────────

  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  // Return true jika auth berhasil, false jika user membatalkan
  // Throws PlatformException jika ada error lain
  Future<bool> authenticateWithBiometric() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Verifikasi identitas kamu untuk membuka Moma',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // allow PIN/pattern fallback dari OS
        ),
      );
    } on PlatformException catch (e) {
      if (e.code == auth_error.notAvailable ||
          e.code == auth_error.notEnrolled ||
          e.code == auth_error.lockedOut ||
          e.code == auth_error.permanentlyLockedOut) {
        return false;
      }
      rethrow;
    }
  }

  // ── PIN ───────────────────────────────────────────────────────

  // Hash PIN dengan SHA-256 + salt tetap
  String hashPin(String pin) {
    const salt = 'moma_security_2026';
    final bytes = utf8.encode(pin + salt);
    return sha256.convert(bytes).toString();
  }

  bool verifyPin(String input, String storedHash) {
    return hashPin(input) == storedHash;
  }
}
