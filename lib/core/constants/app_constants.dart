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

  // API
  static const String apiBaseUrl =
      'http://192.168.1.10:8000/api/v1'; // Android emulator
  // static const String apiBaseUrl = 'http://127.0.0.1:8000/api/v1'; // iOS simulator

  // Google Sign In
  // Isi dengan Web Client ID dari Google Cloud Console
  static const String googleWebClientId =
      '828429949035-tj4hfrkfcm180d5p07n0smvbqcatie52.apps.googleusercontent.com';
}
