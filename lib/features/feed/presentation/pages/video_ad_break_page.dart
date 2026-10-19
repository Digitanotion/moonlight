// lib/features/feed/presentation/pages/video_ad_break_page.dart
//
// A full-screen "ad break" between short videos: plays one Google IMA video
// ad and then returns to the feed. The viewer is never trapped:
//  • while the ad loads there's a Close button, and it gives up after 6s;
//  • once playing, "Skip in 10s" counts down to a Skip button (or the ad's
//    own skip, if it offers one sooner);
//  • back and swipe-up work whenever closing is allowed;
//  • any error / no fill closes the page straight away.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:interactive_media_ads/interactive_media_ads.dart';

class VideoAdBreakPage extends StatefulWidget {
  final String adTagUrl;

  /// Called once when the break closes: true if an ad actually played.
  final ValueChanged<bool>? onClosed;

  const VideoAdBreakPage({super.key, required this.adTagUrl, this.onClosed});

  @override
  State<VideoAdBreakPage> createState() => _VideoAdBreakPageState();
}

class _VideoAdBreakPageState extends State<VideoAdBreakPage>
    with WidgetsBindingObserver {
  static const _loadTimeout = Duration(seconds: 6);
  static const _skipAfter = 10; // seconds of playback before our Skip
  static const _hardTimeout = Duration(minutes: 2);

  late final AdsLoader _adsLoader;
  AdsManager? _manager;
  bool _started = false;
  bool _finished = false;
  Timer? _loadTimer;
  Timer? _hardTimer;
  Timer? _skipTimer;
  int _skipIn = _skipAfter;

  /// Close / back / swipe allowed: always while loading, and once the
  /// skip countdown has run out.
  bool get _canClose => _finished || !_started || _skipIn <= 0;
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
                    _onStarted();
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

  void _onStarted() {
    if (_started || !mounted) return;
    _loadTimer?.cancel();
    setState(() {
      _started = true;
      _skipIn = _skipAfter;
    });
    _skipTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _skipIn--);
      if (_skipIn <= 0) t.cancel();
    });
  }

  bool _reported = false;

  void _cleanup() {
    if (!_reported) {
      _reported = true;
      widget.onClosed?.call(_started);
    }
    _loadTimer?.cancel();
    _hardTimer?.cancel();
    _skipTimer?.cancel();
    try {
      _manager?.destroy();
    } catch (_) {}
    _manager = null;
  }

  /// Leaves the ad break. Uses pop(), not maybePop(): maybePop() asks the
  /// PopScope, which still said "can't pop" — that's what left the spinner
  /// running forever when an ad failed to load.
  void _finish() {
    if (_finished || !mounted) return;
    setState(() => _finished = true);
    _cleanup();
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent) Navigator.of(context).pop();
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
    _cleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return PopScope(
      canPop: _canClose,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_finished) {
          _finished = true;
          _cleanup();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          // Swipe up to move on, like the next short video.
          onVerticalDragEnd: (d) {
            if (_canClose && (d.primaryVelocity ?? 0) < -300) _finish();
          },
          child: Stack(
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
              Positioned(
                top: top + 12,
                left: 12,
                child: const _Pill(child: Text('Ad', style: _pillText)),
              ),
              Positioned(
                top: top + 8,
                right: 12,
                child: !_started
                    ? _PillButton(
                        key: const ValueKey('ad-close'),
                        onTap: _finish,
                        icon: Icons.close,
                        label: 'Close',
                      )
                    : _skipIn > 0
                    ? _Pill(
                        key: const ValueKey('ad-skip-countdown'),
                        child: Text('Skip in ${_skipIn}s', style: _pillText),
                      )
                    : _PillButton(
                        key: const ValueKey('ad-skip'),
                        onTap: _finish,
                        icon: Icons.skip_next_rounded,
                        label: 'Skip ad',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _pillText = TextStyle(
  color: Colors.white,
  fontSize: 13,
  fontWeight: FontWeight.w600,
);

class _Pill extends StatelessWidget {
  final Widget child;
  const _Pill({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white24),
    ),
    child: child,
  );
}

class _PillButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String label;
  const _PillButton({
    super.key,
    required this.onTap,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: _Pill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: _pillText),
          const SizedBox(width: 4),
          Icon(icon, color: Colors.white, size: 18),
        ],
      ),
    ),
  );
}
