// lib/core/services/video_ad_service.dart
//
// Decides when to show an in-feed video ad break (Google IMA). Settings come
// from the API (/v1/ads/config) so the ad tag and frequency can change
// without an app release. If video ads aren't configured, [handleSwipe]
// returns false and the feed falls back to the AdMob interstitial.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/features/feed/presentation/pages/video_ad_break_page.dart';
import 'package:moonlight/main.dart' show MyApp;
import 'package:dio/dio.dart';

class VideoAdService {
  VideoAdService._();
  static final VideoAdService instance = VideoAdService._();

  /// Google's public skippable sample tag — used ONLY in debug builds when
  /// the server has no tag yet, so the feature can be tried end to end.
  static const _sampleSkippableTag =
      'https://pubads.g.doubleclick.net/gampad/ads?iu=/21775744923/external/single_ad_samples&sz=640x480&cust_params=sample_ct%3Dskippablelinear&ciu_szs=300x250%2C728x90&gdfp_req=1&output=vast&unviewed_position_start=1&env=vp&correlator=';

  bool _loaded = false;
  bool _loading = false;
  bool _enabled = false;
  String _tag = '';
  int _everyN = 4;
  Duration _minGap = const Duration(seconds: 40);

  int _since = 0;
  bool _showing = false;
  DateTime _lastShown = DateTime.fromMillisecondsSinceEpoch(0);

  /// True when video ads are configured and active.
  bool get active => _loaded && _enabled && _tag.isNotEmpty;

  Future<void> _loadConfig() async {
    if (_loaded || _loading) return;
    _loading = true;
    try {
      final res = await sl<Dio>(
        instanceName: 'mainDio',
      ).get('/api/v1/ads/config');
      final v = ((res.data as Map)['video'] as Map?) ?? const {};
      _enabled = v['enabled'] == true;
      _tag = (v['tag_url'] ?? '').toString();
      _everyN = ((v['every_n_videos'] ?? 4) as num).toInt().clamp(1, 50);
      _minGap = Duration(
        seconds: ((v['min_gap_seconds'] ?? 40) as num).toInt(),
      );
    } catch (e) {
      debugPrint('[VideoAd] config fetch failed: $e');
    } finally {
      if (!_enabled && kDebugMode) {
        _enabled = true;
        _tag = _sampleSkippableTag;
      }
      _loaded = true;
      _loading = false;
    }
  }

  /// Call on every short-video swipe. Returns true when video ads own the
  /// ad slot (so the caller must not also show another ad type).
  bool handleSwipe() {
    if (!_loaded) {
      _loadConfig(); // first swipes use the fallback while this loads
      return false;
    }
    if (!active) return false;

    _since++;
    if (_since < _everyN || _showing) return true;
    if (DateTime.now().difference(_lastShown) < _minGap) return true;

    final nav = MyApp.navigatorKey.currentState;
    if (nav == null) return true;

    _since = 0;
    _showing = true;
    _lastShown = DateTime.now();
    nav
        .push(
          PageRouteBuilder<void>(
            opaque: true,
            transitionDuration: const Duration(milliseconds: 180),
            pageBuilder: (_, _, _) => VideoAdBreakPage(adTagUrl: _tag),
            transitionsBuilder: (_, a, _, child) =>
                FadeTransition(opacity: a, child: child),
          ),
        )
        .whenComplete(() {
          _showing = false;
          _lastShown = DateTime.now();
        });
    return true;
  }
}
