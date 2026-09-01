// lib/core/widgets/styled_banner_ad.dart

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:moonlight/core/services/ad_service.dart';
import 'package:moonlight/core/theme/app_colors.dart';

/// An anchored adaptive AdMob banner in a small "SPONSORED" card. Collapses to
/// nothing while loading and on failure (so it never leaves an empty gap), and
/// only shows the card once a real ad is on screen.
class StyledBannerAd extends StatefulWidget {
  const StyledBannerAd({super.key});

  @override
  State<StyledBannerAd> createState() => _StyledBannerAdState();
}

class _StyledBannerAdState extends State<StyledBannerAd> {
  BannerAd? _bannerAd;
  bool _loaded = false;
  bool _disposed = false;
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    // Needs a width — do it after we have MediaQuery.
    final width = MediaQuery.of(context).size.width - 32;
    _load(width);
  }

  Future<void> _load(double width) async {
    final ad = await AdService.instance.createAdaptiveBanner(
      width: width,
      onLoaded: () {
        if (!_disposed) setState(() => _loaded = true);
      },
      onFailed: () {
        if (!_disposed) setState(() => _loaded = false);
      },
    );
    if (_disposed) {
      ad?.dispose();
      return;
    }
    _bannerAd = ad;
  }

  @override
  void dispose() {
    _disposed = true;
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _bannerAd == null) return const SizedBox.shrink();

    final ad = _bannerAd!;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'SPONSORED',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.32),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: ad.size.width.toDouble(),
              height: ad.size.height.toDouble(),
              child: AdWidget(ad: ad),
            ),
          ),
        ],
      ),
    );
  }
}
