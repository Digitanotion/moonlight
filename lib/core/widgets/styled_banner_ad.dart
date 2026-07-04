// lib/core/widgets/styled_banner_ad.dart

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:moonlight/core/services/ad_service.dart';
import 'package:moonlight/core/theme/app_colors.dart';

class StyledBannerAd extends StatefulWidget {
  final bool collapseOnFailure;
  const StyledBannerAd({super.key, this.collapseOnFailure = false});

  @override
  State<StyledBannerAd> createState() => _StyledBannerAdState();
}

class _StyledBannerAdState extends State<StyledBannerAd> {
  BannerAd? _bannerAd;
  bool _loaded = false;
  bool _failed = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _bannerAd = AdService.instance.createBannerAd(
      onLoaded: () {
        if (_disposed) return;
        setState(() => _loaded = true);
      },
      onFailed: (ad, error) {  // ← fixed: accepts (Ad, LoadAdError)
        if (_disposed) return;
        setState(() => _failed = true);
      },
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed && widget.collapseOnFailure) {
      return const SizedBox.shrink();
    }

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
              color: Colors.white.withOpacity(0.32),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: _loaded && _bannerAd != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AdWidget(ad: _bannerAd!),
                  )
                : _failed
                    ? const SizedBox.shrink()
                    : Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.6,
                            color: Colors.white.withOpacity(0.25),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}