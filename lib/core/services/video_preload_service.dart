// lib/core/services/video_preload_service.dart
//
// Pre-initializes VideoPlayerControllers for posts the user is likely to
// open next (the next few items in the feed as they scroll), so tapping
// into a post attaches an already-buffering (or fully ready) controller
// instead of starting a cold network request from zero.
//
// This does NOT persist video bytes to disk — it keeps a small number of
// live, initialized VideoPlayerController instances in memory, evicting
// the oldest ones once the cache exceeds `maxCached`. That's enough to
// eliminate the "opens post → blank black box → buffers for 2s" gap for
// anything the user scrolled past recently, without the complexity/disk
// cost of a full video caching layer.

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

class VideoPreloadService {
  VideoPreloadService._();
  static final VideoPreloadService instance = VideoPreloadService._();

  /// Max number of initialized controllers kept alive at once. Each one
  /// holds a decoder + buffered frames, so keep this modest. Bumped
  /// slightly to comfortably fit the feed's preload-ahead window (4
  /// items) without evicting one that's about to be needed.
  static const int maxCached = 6;

  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, Future<void>> _initFutures = {};
  // Tracks insertion order so we can evict the least-recently-used entry.
  final List<String> _order = [];

  bool _isVideoUrl(String url) {
    final u = url.toLowerCase();
    return u.endsWith('.mp4') ||
        u.endsWith('.mov') ||
        u.endsWith('.m4v') ||
        u.endsWith('.mkv') ||
        u.endsWith('.webm');
  }

  /// Kick off initialization for [url] if it's not already cached or in
  /// flight. Fire-and-forget — call this from feed scroll handling for
  /// the next few upcoming items. Safe to call repeatedly; it no-ops if
  /// already cached/loading.
  void preload(String url) {
    if (url.isEmpty || !_isVideoUrl(url)) return;
    if (_controllers.containsKey(url) || _initFutures.containsKey(url)) {
      return;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controllers[url] = controller;
    _order.remove(url);
    _order.add(url);

    final future = controller
        .initialize()
        .then((_) {
          // Keep it muted and paused — this is a background warm-up, not
          // playback. The screen that actually uses it decides play state.
          controller.setVolume(0);
        })
        .catchError((e, st) {
          debugPrint('⚠️ [VideoPreload] Failed to preload $url: $e');
          // Clean up a failed preload so a later real attempt isn't stuck
          // pointing at a broken controller.
          _controllers.remove(url);
          _order.remove(url);
        });

    _initFutures[url] = future;
    future.whenComplete(() => _initFutures.remove(url));

    _evictIfNeeded();
  }

  /// Preload several upcoming URLs at once — convenience for feed scroll
  /// handling where you want to warm the next N items in one call.
  void preloadAll(Iterable<String> urls) {
    for (final url in urls) {
      preload(url);
    }
  }

  /// Returns an already-initialized controller for [url] if one is
  /// cached and ready, or null if nothing is cached / it's still loading.
  /// The caller (post view screen) should fall back to creating its own
  /// controller when this returns null — same as if preloading never
  /// happened, just without the head start.
  VideoPlayerController? takeIfReady(String url) {
    final c = _controllers[url];
    if (c == null) return null;
    if (!c.value.isInitialized) return null;

    // Hand ownership to the caller: remove from our cache so we don't
    // dispose it out from under whoever is now using it, and so a repeat
    // visit to the same post starts a fresh controller rather than
    // reusing one that may have been seeked/paused/muted by a previous
    // viewing.
    _controllers.remove(url);
    _order.remove(url);
    return c;
  }

  /// If [url] is still mid-preload (not yet ready), returns the in-flight
  /// future so a caller can await it instead of starting a second,
  /// redundant network request for the same video.
  Future<void>? inFlight(String url) => _initFutures[url];

  void _evictIfNeeded() {
    while (_controllers.length > maxCached && _order.isNotEmpty) {
      final oldest = _order.removeAt(0);
      _controllers.remove(oldest)?.dispose();
    }
  }

  /// Call on logout / low-memory situations to release everything.
  void clear() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    _order.clear();
    _initFutures.clear();
  }
}