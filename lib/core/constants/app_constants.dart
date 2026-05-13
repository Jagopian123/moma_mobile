import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  // Hive user box keys
  static const String keyIsOnboardingDone = 'is_onboarding_done';
  static const String keyAuthToken = 'auth_token';
  static const String keyUserId = 'user_id';
  static const String keyUserName = 'user_name';
  static const String keyUserEmail = 'user_email';
  static const String keyUserAvatar = 'user_avatar';
  static const String keyIsPremium = 'is_premium';
  static const String keyIsBalanceVisible = 'is_balance_visible';
  static const String keyLastBackup = 'last_backup_at';

  // Security
  static const String keySecurityEnabled = 'security_enabled';
  static const String keyBiometricEnabled = 'biometric_enabled';
  static const String keyPinHash = 'pin_hash';

  // Web & API — dibaca dari env/.env.{ENV} saat startup
  static String get webBaseUrl =>
      dotenv.env['WEB_URL'] ?? 'https://moma.empatech.id';
  static String get apiBaseUrl =>
      dotenv.env['API_URL'] ?? 'https://moma.empatech.id/api/v1';

  // Google Sign In
  static const String googleWebClientId =
      '640634426800-9j67rvpp1845hc2eutofbnmehtr22e6c.apps.googleusercontent.com';
}
