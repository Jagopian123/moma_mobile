import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../constants/app_constants.dart';

class AdmobService {
  static RewardedAd? _rewardedAd;
  static bool _isLoading = false;

  static Future<void> init() async {
    await MobileAds.instance.initialize();
    _loadRewardedAd();
  }

  static void _loadRewardedAd() {
    if (_isLoading || AppConstants.admobRewardedId.isEmpty) return;
    _isLoading = true;

    RewardedAd.load(
      adUnitId: AppConstants.admobRewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoading = false;
          debugPrint('[AdmobService] Rewarded ad loaded');
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isLoading = false;
          debugPrint('[AdmobService] Failed to load rewarded ad: $error');
        },
      ),
    );
  }

  static bool get isReady => _rewardedAd != null;

  static Future<bool> showRewardedAd({
    required VoidCallback onRewarded,
    Duration loadTimeout = const Duration(seconds: 10),
  }) async {
    if (_rewardedAd == null) {
      _loadRewardedAd();
      final stopwatch = Stopwatch()..start();
      while (_rewardedAd == null && stopwatch.elapsed < loadTimeout) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!_isLoading && _rewardedAd == null) break;
      }
      if (_rewardedAd == null) return false;
    }

    final ad = _rewardedAd!;
    _rewardedAd = null;

    bool earned = false;
    final completer = Completer<bool>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadRewardedAd();
        // Panggil callback SETELAH ad ditutup supaya snackbar terlihat
        if (earned) onRewarded();
        completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadRewardedAd();
        debugPrint('[AdmobService] Failed to show ad: $error');
        completer.complete(false);
      },
    );

    ad.show(onUserEarnedReward: (_, __) => earned = true);
    return completer.future;
  }
}
