// lib/core/services/video_cache_manager.dart
//
// Disk cache for feed / slider video files. Before this, the only
// "caching" was VideoPreloadService keeping a handful of initialized
// VideoPlayerControllers alive in memory — so scrolling back to a video
// you watched a minute ago re-downloaded the whole file.
//
// This adds a bounded on-disk cache (flutter_cache_manager) so a video
// the user has already fetched plays from a local file on the next
// visit, and survives the controller being disposed / the app being
// backgrounded.
//
// Bounded on purpose: video files are large. `maxNrOfCacheObjects` and
// `stalePeriod` keep total disk use in check; the cache manager evicts
// the least-recently-used entries past the cap.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class VideoCacheManager {
  VideoCacheManager._();

  static const key = 'moonlightVideoCache';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      // Re-validate / drop files older than this.
      stalePeriod: const Duration(days: 7),
      // Hard cap on cached video files. At a rough few MB each this keeps
      // the cache in the low hundreds of MB worst case.
      maxNrOfCacheObjects: 60,
    ),
  );

  /// Returns a locally cached [File] for [url] if one already exists on
  /// disk (and is still valid), else null. Never triggers a download.
  static Future<File?> cachedFileFor(String url) async {
    if (url.isEmpty) return null;
    try {
      final info = await instance.getFileFromCache(url);
      if (info != null && await info.file.exists()) return info.file;
    } catch (e) {
      debugPrint('⚠️ [VideoCache] cache lookup failed: $e');
    }
    return null;
  }

  /// Ensures [url] is downloaded into the disk cache. Awaitable, but
  /// callers that only want to warm the cache can fire-and-forget.
  /// Returns the cached [File], or null on failure.
  static Future<File?> ensureCached(String url) async {
    if (url.isEmpty) return null;
    try {
      return await instance.getSingleFile(url);
    } catch (e) {
      debugPrint('⚠️ [VideoCache] download failed for ${_short(url)}: $e');
      return null;
    }
  }

  static String _short(String url) =>
      url.length > 48 ? '…${url.substring(url.length - 48)}' : url;
}
