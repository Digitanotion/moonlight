// lib/core/services/ad_service.dart

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  // ── CONFIG ──────────────────────────────────────────────────────────────
  static const bool _useTestAds = false;

  // Google's official test ad unit IDs.
  static const String _testInterstitialAndroid =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testInterstitialIOS =
      'ca-app-pub-3940256099942544/4411468910';
  static const String _testBannerAndroid =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testBannerIOS =
      'ca-app-pub-3940256099942544/2934735716';

  // Real ad unit IDs (from AdMob console).
  static const String _prodInterstitialAndroid =
      'ca-app-pub-9544684683357809/8071794223';
  static const String _prodBannerAndroid =
      'ca-app-pub-9544684683357809/7658263624';
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

  // ── Interstitial cadence ─────────────────────────────────────────────────
  // Show an interstitial every N stream views.
  static const int postsPerInterstitial = 9;

  int _postsSinceLastAd = 0;
  InterstitialAd? _cachedInterstitial;
  bool _isLoadingInterstitial = false;

  /// Call once at app startup, before runApp().
  Future<void> init() async {
    await MobileAds.instance.initialize();
    _preloadInterstitial();
  }

  void _preloadInterstitial() {
    // Guard: don't start a second load if one is already in flight
    // or an ad is already cached and ready to show.
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
              // Ad was dismissed — dispose it and immediately preload the
              // next one so it's ready before the user hits the threshold.
              ad.dispose();
              _cachedInterstitial = null;
              _preloadInterstitial();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('⚠️ [AdService] Interstitial failed to show: $error');
              ad.dispose();
              _cachedInterstitial = null;
              // Retry preload so we recover from transient failures.
              _preloadInterstitial();
            },
            onAdShowedFullScreenContent: (_) {
              debugPrint('✅ [AdService] Interstitial shown');
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isLoadingInterstitial = false;
          _cachedInterstitial = null;
          debugPrint('⚠️ [AdService] Interstitial failed to load: $error');
          // Retry after a delay to avoid hammering AdMob on repeated failures.
          Future.delayed(const Duration(minutes: 1), _preloadInterstitial);
        },
      ),
    );
  }

  /// Call every time a stream/post is viewed. Shows a pre-loaded
  /// interstitial once the threshold is reached. Never blocks the UI.
  void onPostViewed() {
    _postsSinceLastAd++;
    if (_postsSinceLastAd < postsPerInterstitial) return;

    final ad = _cachedInterstitial;
    if (ad == null) {
      // No ad cached yet — reset counter so we try again after the
      // next N views, and kick off a preload if one isn't already running.
      _postsSinceLastAd = 0;
      _preloadInterstitial();
      return;
    }

    // Reset counter and show. The fullScreenContentCallback above handles
    // disposal and reloading after the ad is dismissed.
    _postsSinceLastAd = 0;
    _cachedInterstitial = null; // clear before show so callbacks are clean
    ad.show();
  }

  /// Resets the counter without showing — useful after purchase flows.
  void resetCounter() => _postsSinceLastAd = 0;

  // ── Banner factory ───────────────────────────────────────────────────────

  /// Creates and loads a standard 320×50 banner. The caller must call
  /// dispose() on it in their widget's dispose() method.
  BannerAd createBannerAd({
    required VoidCallback onLoaded,
    required void Function(Ad, LoadAdError) onFailed,
  }) {
    return BannerAd(
      size: AdSize.banner,
      adUnitId: bannerUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded(),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          onFailed(ad, error);
        },
      ),
    )..load();
  }
}