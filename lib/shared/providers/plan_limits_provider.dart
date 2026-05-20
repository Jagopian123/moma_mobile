import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/plan_limits.dart';
import '../../features/auth/providers/auth_provider.dart';

final planLimitsProvider = Provider<PlanLimits>((ref) {
  final isPro = ref.watch(authProvider).user?.isPremium ?? false;
  return PlanLimits(isPro: isPro);
});
