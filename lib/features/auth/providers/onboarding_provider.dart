import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/hive/hive_service.dart';

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, bool>((ref) {
  return OnboardingNotifier();
});

class OnboardingNotifier extends StateNotifier<bool> {
  OnboardingNotifier()
      : super(
          HiveService.user.get(AppConstants.keyIsOnboardingDone) ?? false,
        );

  Future<void> completeOnboarding() async {
    await HiveService.user.put(AppConstants.keyIsOnboardingDone, true);
    state = true;
  }
}
