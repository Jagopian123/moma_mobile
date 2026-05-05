import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/hive/hive_service.dart';
import '../../../core/constants/app_constants.dart';

// Toggle visibility saldo
final balanceVisibleProvider =
    StateNotifierProvider<BalanceVisibleNotifier, bool>((ref) {
  return BalanceVisibleNotifier();
});

class BalanceVisibleNotifier extends StateNotifier<bool> {
  BalanceVisibleNotifier()
      : super(
          HiveService.user.get(AppConstants.keyIsBalanceVisible) ?? true,
        );

  void toggle() {
    state = !state;
    HiveService.user.put(AppConstants.keyIsBalanceVisible, state);
  }
}

// Greeting berdasarkan jam
String getGreeting() {
  final hour = DateTime.now().hour;
  if (hour >= 5 && hour < 11) return 'Selamat Pagi';
  if (hour >= 11 && hour < 15) return 'Selamat Siang';
  if (hour >= 15 && hour < 19) return 'Selamat Sore';
  return 'Selamat Malam';
}

String getGreetingEmoji() {
  final hour = DateTime.now().hour;
  if (hour >= 5 && hour < 11) return '☀️';
  if (hour >= 11 && hour < 15) return '🌤️';
  if (hour >= 15 && hour < 19) return '🌅';
  return '🌙';
}
