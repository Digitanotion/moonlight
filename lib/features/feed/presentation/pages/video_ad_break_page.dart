// lib/features/feed/presentation/pages/video_ad_break_page.dart
//
// A full-screen "ad break" between short videos: plays one Google IMA video
// ad (skippable when the ad allows it — the skip timing comes from the ad
// itself) and then returns to the feed. Any problem (no fill, load error,
// timeout) just closes the page, so a failed ad never traps the viewer.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:interactive_media_ads/interactive_media_ads.dart';

class VideoAdBreakPage extends StatefulWidget {
  final String adTagUrl;
  const VideoAdBreakPage({super.key, required this.adTagUrl});

  @override
  State<VideoAdBreakPage> createState() => _VideoAdBreakPageState();
}

class _VideoAdBreakPageState extends State<VideoAdBreakPage>
    with WidgetsBindingObserver {
  static const _loadTimeout = Duration(seconds: 10);
  static const _hardTimeout = Duration(minutes: 2);

  late final AdsLoader _adsLoader;
  AdsManager? _manager;
  bool _started = false;
  bool _finished = false;
  Timer? _loadTimer;
  Timer? _hardTimer;
  AppLifecycleState _lastLifecycle = AppLifecycleState.resumed;

  late final AdDisplayContainer _container = AdDisplayContainer(
    onContainerAdded: (AdDisplayContainer container) {
      _adsLoader = AdsLoader(
        container: container,
        onAdsLoaded: (OnAdsLoadedData data) {
          final manager = data.manager;
          _manager = manager;
          manager.setAdsManagerDelegate(
            AdsManagerDelegate(
              onAdEvent: (AdEvent event) {
                switch (event.type) {
                  case AdEventType.loaded:
                    manager.start();
                  case AdEventType.started:
                    _started = true;
                    _loadTimer?.cancel();
                  case AdEventType.allAdsCompleted:
                  case AdEventType.contentResumeRequested:
                  case AdEventType.skipped:
                    _finish();
                  case _:
                }
              },
              onAdErrorEvent: (AdErrorEvent e) {
                debugPrint('[VideoAd] ad error: ${e.error.message}');
                _finish();
              },
            ),
          );
          manager.init();
        },
        onAdsLoadError: (AdsLoadErrorData data) {
          debugPrint('[VideoAd] load error: ${data.error.message}');
          _finish();
        },
      );
      // Ads can only be requested once the container is in the view tree.
      _adsLoader.requestAds(AdsRequest(adTagUrl: widget.adTagUrl)).catchError((
        Object e,
      ) {
        debugPrint('[VideoAd] request failed: $e');
        _finish();
      });
    },
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // No ad started in time (no fill / slow network): get out of the way.
    _loadTimer = Timer(_loadTimeout, () {
      if (!_started) _finish();
    });
    // Absolute safety net.
    _hardTimer = Timer(_hardTimeout, _finish);
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    _loadTimer?.cancel();
    _hardTimer?.cancel();
    try {
      _manager?.destroy();
    } catch (_) {}
    _manager = null;
    Navigator.of(context).maybePop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _manager?.resume();
      case AppLifecycleState.inactive:
        if (_lastLifecycle == AppLifecycleState.resumed) _manager?.pause();
      case _:
    }
    _lastLifecycle = state;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loadTimer?.cancel();
    _hardTimer?.cancel();
    try {
      _manager?.destroy();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back is blocked while the ad is playing; the ad's own Skip button
      // (when offered) or the timeouts close the page.
      canPop: _finished,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Must stay in the tree for the whole ad.
            _container,
            if (!_started)
              const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white54,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
