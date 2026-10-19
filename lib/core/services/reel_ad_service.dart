// lib/core/services/reel_ad_service.dart
//
// In-feed native video ads for the short-video pager. Instead of a
// full-screen interstitial, an ad is its own page between videos — the
// same size as a video, swiped past like any other. Rendered natively by
// the "moonlightReel" factory (android/.../NativeReelAdFactory.kt).
//
// The ad unit comes from the server (/v1/ads/config → feed_native), so it
// can be switched on without an app release. With no unit configured the
// pager falls back to the AdMob interstitial.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class ReelAdService {
  ReelAdService._();
  static final ReelAdService instance = ReelAdService._();

  static const factoryId = 'moonlightReel';

  /// Google's always-fill native video test units.
  static const _testUnit = {
    'android': 'ca-app-pub-3940256099942544/1044960115',
    'ios': 'ca-app-pub-3940256099942544/2521693316',
  };

  String _unitId = '';
  int _everyN = 4;

  /// True when native feed ads are configured.
  bool get available => _unitId.isNotEmpty;

  /// One ad page after this many videos.
  int get everyN => _everyN;

  /// Debug builds always use Google's test unit.
  void configure({
    String androidUnitId = '',
    String iosUnitId = '',
    int? everyN,
  }) {
    final real = Platform.isIOS ? iosUnitId : androidUnitId;
    _unitId = kDebugMode
        ? _testUnit[Platform.isIOS ? 'ios' : 'android']!
        : real.trim();
    if (everyN != null) _everyN = everyN.clamp(2, 50);
  }

  NativeAd? _ready;
  bool _loading = false;
  DateTime _retryAfter = DateTime.fromMillisecondsSinceEpoch(0);
  int _failures = 0;

  /// Starts loading the next ad if none is ready. Never blocks.
  void prefetch({bool muted = true}) {
    if (!available || _ready != null || _loading) return;
    if (DateTime.now().isBefore(_retryAfter)) return;
    _loading = true;
    NativeAd(
      adUnitId: _unitId,
      factoryId: factoryId,
      request: const AdRequest(),
      nativeAdOptions: NativeAdOptions(
        mediaAspectRatio: MediaAspectRatio.any,
        videoOptions: VideoOptions(startMuted: muted),
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          _loading = false;
          _failures = 0;
          _ready = ad as NativeAd;
        },
        onAdFailedToLoad: (ad, error) {
          _loading = false;
          ad.dispose();
          // No fill: back off (1m, 2m, 4m … up to ~16m) before asking again.
          _failures = (_failures + 1).clamp(1, 5);
          _retryAfter = DateTime.now().add(
            Duration(minutes: 1 << (_failures - 1)),
          );
          debugPrint('[ReelAd] load failed: ${error.code} ${error.message}');
        },
      ),
    ).load();
  }

  /// Hands over a loaded ad (the caller owns and disposes it), or null.
  NativeAd? take({bool muted = true}) {
    final ad = _ready;
    _ready = null;
    prefetch(muted: muted);
    return ad;
  }
}
