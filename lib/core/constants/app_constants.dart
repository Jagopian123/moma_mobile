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
  static const String keySecurityEnabled  = 'security_enabled';
  static const String keyBiometricEnabled = 'biometric_enabled';
  static const String keyPinHash          = 'pin_hash';

  // API
  //static const String apiBaseUrl = 'https://moma.empatech.id/api/v1';
  static const String apiBaseUrl = 'http://192.168.1.10:8000/api/v1';
  // static const String apiBaseUrl = 'http://127.0.0.1:8000/api/v1'; // iOS simulator

  // Google Sign In
  static const String googleWebClientId =
      '828429949035-tj4hfrkfcm180d5p07n0smvbqcatie52.apps.googleusercontent.com';
}
