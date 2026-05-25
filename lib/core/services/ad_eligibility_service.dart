import '../constants/app_constants.dart';
import '../hive/hive_service.dart';

class AdEligibilityService {
  // true saat build dengan --dart-define=ENV=development
  static const bool _isDev =
      String.fromEnvironment('ENV', defaultValue: 'production') == 'development';

  static void recordInstallIfNeeded() {
    if (HiveService.user.get(AppConstants.keyInstallDate) == null) {
      HiveService.user.put(
        AppConstants.keyInstallDate,
        DateTime.now().toIso8601String(),
      );
    }
  }

  static bool get isEligible {
    // Premium user tidak pernah lihat iklan
    final isPremium =
        HiveService.user.get(AppConstants.keyIsPremium) as bool? ?? false;
    if (isPremium) return false;

    // Di development build selalu eligible supaya bisa testing
    if (_isDev) return true;

    final installStr =
        HiveService.user.get(AppConstants.keyInstallDate) as String?;
    if (installStr == null) return false;

    final installDate = DateTime.parse(installStr);
    final daysSince = DateTime.now().difference(installDate).inDays;
    if (daysSince < AppConstants.adEligibilityDays) return false;

    final txCount = HiveService.transactions.length;
    return txCount >= AppConstants.adEligibilityMinTx;
  }
}
