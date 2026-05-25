import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/ad_eligibility_service.dart';
import '../../core/theme/app_theme.dart';

class NativeAdWidget extends StatefulWidget {
  const NativeAdWidget({super.key});

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (!AdEligibilityService.isEligible) return;
    _loadAd();
  }

  void _loadAd() {
    final adUnitId = AppConstants.admobNativeId;
    if (adUnitId.isEmpty) return;

    NativeAd(
      adUnitId: adUnitId,
      factoryId: 'listTile',
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _ad = ad as NativeAd;
            _loaded = true;
          });
        },
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
      request: const AdRequest(),
    ).load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      height: 68,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: AdWidget(ad: _ad!),
      ),
    );
  }
}
