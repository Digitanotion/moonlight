// lib/core/services/ad_service.dart

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  // ── CONFIG ────────────────────────────────────────────────────────────────
  //
  // Debug builds ALWAYS use Google's test ad units — they fill 100% of the
  // time and (unlike serving live ads to a dev device) never risk an AdMob
  // policy strike. Release builds use the real units.
  static bool get _useTestAds => kDebugMode;

  // Google's official always-fill test ad units.
  static const _testInterstitial = {
    'android': 'ca-app-pub-3940256099942544/1033173712',
    'ios': 'ca-app-pub-3940256099942544/4411468910',
  };
  static const _testBanner = {
    'android': 'ca-app-pub-3940256099942544/6300978111',
    'ios': 'ca-app-pub-3940256099942544/2934735716',
  };

  // Real ad units (AdMob console).
  static const _prodInterstitial = {
    'android': 'ca-app-pub-9544684683357809/8071794223',
    'ios': 'REPLACE_WITH_REAL_ID',
  };
  static const _prodBanner = {
    'android': 'ca-app-pub-9544684683357809/7658263624',
    'ios': 'REPLACE_WITH_REAL_ID',
  };

  String _pick(Map<String, String> table) {
    final key = Platform.isIOS ? 'ios' : 'android';
    return table[key]!;
  }

  String get _interstitialUnitId =>
      _pick(_useTestAds ? _testInterstitial : _prodInterstitial);
  String get bannerUnitId =>
      _pick(_useTestAds ? _testBanner : _prodBanner);

  bool _initialized = false;

  /// Runs in the background at launch. Ad calls before this completes just
  /// no-op; they start working once it's done.
  Future<void> init() async {
    if (_initialized) return;

    // Physical test devices that should always get test ads even on a
    // release build. Add hashed IDs from logcat ("Use RequestConfiguration
    // to set testDeviceIds: ['ABCDEF...']").
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(testDeviceIds: const <String>[]),
    );

    await MobileAds.instance.initialize();
    _initialized = true;
    _preloadInterstitial();
  }

  // ── Interstitial ──────────────────────────────────────────────────────────
  // Shown once every N "post opened" events. One tap-through in ~12 opens is
  // deliberately light — the feed is the main surface and shouldn't feel spammy.
  static const int postsPerInterstitial = 12;

  int _postsSinceLastAd = 0;
  InterstitialAd? _cachedInterstitial;
  bool _isLoadingInterstitial = false;
  int _interstitialRetry = 0;

  void _preloadInterstitial() {
    if (!_initialized) return;
    if (_isLoadingInterstitial || _cachedInterstitial != null) return;
    _isLoadingInterstitial = true;

    InterstitialAd.load(
      adUnitId: _interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _isLoadingInterstitial = false;
          _interstitialRetry = 0;
          _cachedInterstitial = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _cachedInterstitial = null;
              _preloadInterstitial();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('⚠️ [Ads] interstitial show failed: $error');
              ad.dispose();
              _cachedInterstitial = null;
              _preloadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isLoadingInterstitial = false;
          _cachedInterstitial = null;
          debugPrint('⚠️ [Ads] interstitial load failed: ${error.code} ${error.message}');
          // Back off exponentially (30s, 1m, 2m, 4m …) capped at ~15m so we
          // don't hammer AdMob when there's simply no fill.
          _interstitialRetry = (_interstitialRetry + 1).clamp(1, 5);
          final wait = Duration(seconds: 30 * (1 << (_interstitialRetry - 1)));
          Future.delayed(wait, _preloadInterstitial);
        },
      ),
    );
  }

  /// Call on every "post opened". Shows a cached interstitial once the
  /// threshold is hit; never blocks and never shows if nothing is cached.
  void onPostViewed() {
    _postsSinceLastAd++;
    if (_postsSinceLastAd < postsPerInterstitial) return;

    final ad = _cachedInterstitial;
    if (ad == null) {
      // Don't reset the counter — try again on the very next open once an
      // ad is finally cached, rather than waiting another full cycle.
      _preloadInterstitial();
      return;
    }

    _postsSinceLastAd = 0;
    _cachedInterstitial = null;
    ad.show();
  }

  void resetCounter() => _postsSinceLastAd = 0;

  // ── Banner ───────────────────────────────────────────────────────────────

  /// Builds an anchored **adaptive** banner sized to [width] (px). Adaptive
  /// banners have far higher fill and fit the device properly, unlike the
  /// fixed 320×50. Returns null if the size can't be resolved (rare) — the
  /// caller should then render nothing.
  Future<BannerAd?> createAdaptiveBanner({
    required double width,
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  }) async {
    if (!_initialized) {
      onFailed();
      return null;
    }
    final size = await AdSize.getAnchoredAdaptiveBannerAdSize(
      Orientation.portrait,
      width.truncate(),
    );
    if (size == null) {
      onFailed();
      return null;
    }
    return BannerAd(
      size: size,
      adUnitId: bannerUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded(),
        onAdFailedToLoad: (ad, error) {
          debugPrint('⚠️ [Ads] banner load failed: ${error.code} ${error.message}');
          ad.dispose();
          onFailed();
        },
      ),
    )..load();
  }
}
