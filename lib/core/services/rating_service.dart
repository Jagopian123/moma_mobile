import 'package:in_app_review/in_app_review.dart';
import '../hive/hive_service.dart';

class RatingService {
  static const _countKey = 'aiTransactionCount';
  static const _shownKey = 'hasShownRating';

  static Future<void> onTransactionSaved() async {
    final box = HiveService.user;
    if (box.get(_shownKey, defaultValue: false) as bool) return;

    final count = (box.get(_countKey, defaultValue: 0) as int) + 1;
    await box.put(_countKey, count);

    if (count >= 3) {
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
        await box.put(_shownKey, true);
      }
    }
  }
}
