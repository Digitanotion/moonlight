// lib/core/services/ad_service.dart
//
// CHANGES vs previous version:
//   1. Real Android ad unit IDs filled in (from your AdMob console).
//   2. _useTestAds is STILL TRUE — your app is in the "Requires review"
//      period and these ad units need up to an hour to activate. Flip
//      this to false only once BOTH of these are true:
//        a) AdMob no longer shows "Requires review" for this app
//        b) At least an hour has passed since the ad units were created
//   3. iOS prod constants are left as placeholders — you haven't created
//      iOS ad units yet (this app is currently Android-only per the
//      AdMob screenshots). Fill these in later if you ship iOS.

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  // ── CONFIG ────────────────────────────────────────────────────────────
  // Keep this TRUE until:
  //   1. AdMob no longer shows "Requires review" for Moonlight Livestream App
  //   2. At least 1 hour has passed since you created these ad units
  // Then flip to false to start serving real ads and earning revenue.
  static const bool _useTestAds = false;

  // Google's official test ad unit IDs (safe to use during development).
  static const String _testInterstitialAndroid =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testInterstitialIOS =
      'ca-app-pub-3940256099942544/4411468910';
  static const String _testBannerAndroid =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testBannerIOS = 'ca-app-pub-3940256099942544/2934735716';

  // ── REAL ad unit IDs (from AdMob console) ────────────────────────────
  static const String _prodInterstitialAndroid =
      'ca-app-pub-9544684683357809/8071794223';
  static const String _prodBannerAndroid =
      'ca-app-pub-9544684683357809/7658263624';

  // iOS: no ad units created yet. Fill these in if/when you ship iOS,
  // and create the corresponding ad units in AdMob console first.
  static const String _prodInterstitialIOS = 'REPLACE_WITH_REAL_ID';
  static const String _prodBannerIOS = 'REPLACE_WITH_REAL_ID';

  String get _interstitialUnitId {
    if (_useTestAds) {
      return defaultTargetPlatform == TargetPlatform.iOS
          ? _testInterstitialIOS
          : _testInterstitialAndroid;
    }
    return defaultTargetPlatform == TargetPlatform.iOS
        ? _prodInterstitialIOS
        : _prodInterstitialAndroid;
  }

  String get bannerUnitId {
    if (_useTestAds) {
      return defaultTargetPlatform == TargetPlatform.iOS
          ? _testBannerIOS
          : _testBannerAndroid;
    }
    return defaultTargetPlatform == TargetPlatform.iOS
        ? _prodBannerIOS
        : _prodBannerAndroid;
  }

  // ── Interstitial cadence ──────────────────────────────────────────────
  static const int postsPerInterstitial = 9; // every 8-10 posts (midpoint)

  int _postsSinceLastAd = 0;
  InterstitialAd? _cachedInterstitial;
  bool _isLoadingInterstitial = false;

  /// Call once at app startup, before runApp(). Safe to call multiple
  /// times — MobileAds.instance.initialize() is idempotent internally.
  Future<void> init() async {
    await MobileAds.instance.initialize();
    _preloadInterstitial();
  }

  void _preloadInterstitial() {
    if (_isLoadingInterstitial || _cachedInterstitial != null) return;
    _isLoadingInterstitial = true;

    InterstitialAd.load(
      adUnitId: _interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _isLoadingInterstitial = false;
          _cachedInterstitial = ad;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _cachedInterstitial = null;
              _preloadInterstitial(); // immediately start loading the next one
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('⚠️ [Ads] Interstitial failed to show: $error');
              ad.dispose();
              _cachedInterstitial = null;
              _preloadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('⚠️ [Ads] Interstitial failed to load: $error');
          _isLoadingInterstitial = false;
          _cachedInterstitial = null;
          // Don't hammer retries — try again next time onPostViewed() fires
          // and finds no cached ad.
        },
      ),
    );
  }

  /// Call every time a post is opened/viewed. Internally tracks a
  /// counter and shows the pre-loaded interstitial once the threshold
  /// is hit. No-ops silently if no ad is ready yet (never blocks UI
  /// waiting for an ad — that would feel laggy and broken).
  void onPostViewed() {
    _postsSinceLastAd++;
    if (_postsSinceLastAd < postsPerInterstitial) return;

    final ad = _cachedInterstitial;
    if (ad == null) {
      // Not ready yet — try loading for next time, don't block.
      _preloadInterstitial();
      return;
    }

    _postsSinceLastAd = 0;
    ad.show();
  }

  /// Resets the counter without showing an ad — useful if you ever want
  /// to manually suppress the next scheduled interstitial (e.g. right
  /// after a purchase flow, to avoid bad timing).
  void resetCounter() => _postsSinceLastAd = 0;

  // ── Banner factory ────────────────────────────────────────────────────

  /// Creates a fresh standard banner (320x50). The returned BannerAd must
  /// be disposed by the caller (typically in a StatefulWidget's dispose()).
  /// [onLoaded]/[onFailed] let the caller show a placeholder until the ad
  /// is actually ready, avoiding a blank-box flash.
  BannerAd createBannerAd({
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  }) {
    return BannerAd(
      size: AdSize.banner, // 320x50 — the compact standard size
      adUnitId: bannerUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded(),
        onAdFailedToLoad: (ad, error) {
          debugPrint('⚠️ [Ads] Banner failed to load: $error');
          ad.dispose();
          onFailed();
        },
      ),
    )..load();
  }
}