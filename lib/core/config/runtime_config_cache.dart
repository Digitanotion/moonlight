// lib/core/config/runtime_config_cache.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'runtime_config.dart';

class RuntimeConfigCache {
  static const _configKey = 'runtime_config_cache';
  static const _cacheTimestampKey = 'runtime_config_cache_timestamp';
  static const Duration _cacheValidityDuration = Duration(hours: 1);

  final SharedPreferences _prefs;

  RuntimeConfigCache(this._prefs);

  // ─────────────────────────────────────────────────────────────────────────
  // NEW: Read from disk only — zero network, called before runApp()
  //
  // This is the key method that lets Phase 1 of SplashOptimizer populate
  // RuntimeConfig instantly from the previous session's cached values,
  // avoiding any network call before the UI is rendered.
  // ─────────────────────────────────────────────────────────────────────────
  Future<RuntimeConfig?> loadFromCacheOnly() async {
    try {
      final jsonStr = _prefs.getString(_configKey);
      if (jsonStr == null || jsonStr.isEmpty) {
        debugPrint('📭 RuntimeConfigCache: No disk cache found');
        return null;
      }

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;

      final apiBaseUrl = json['apiBaseUrl'] as String? ?? '';
      if (apiBaseUrl.isEmpty) {
        debugPrint('📭 RuntimeConfigCache: Cached apiBaseUrl is empty');
        return null;
      }

      final config = RuntimeConfig(
        agoraAppId: json['agoraAppId'] as String? ?? '',
        apiBaseUrl: apiBaseUrl,
        pusherKey: json['pusherKey'] as String? ?? '',
        pusherCluster: json['pusherCluster'] as String? ?? 'mt1',
      );

      debugPrint(
        '✅ RuntimeConfigCache: Loaded from disk (no network) — '
        'api=${config.apiBaseUrl} '
        'pusher=${config.pusherKey.isEmpty ? "EMPTY" : "SET"}',
      );

      return config;
    } catch (e) {
      debugPrint('⚠️ RuntimeConfigCache: loadFromCacheOnly error: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Cache-first strategy (used by Phase 2 / _loadRuntimeConfig)
  // ─────────────────────────────────────────────────────────────────────────
  Future<RuntimeConfig> loadWithCache({
    required Future<RuntimeConfig> Function() fetchFresh,
    bool forceRefresh = false,
  }) async {
    debugPrint('🔧 RuntimeConfigCache: Loading with cache-first strategy');

    if (!forceRefresh) {
      final cachedConfig = await getCachedConfig();
      if (cachedConfig != null && _isCacheValid()) {
        debugPrint('✅ RuntimeConfigCache: Using valid cached config');
        // Refresh in background without blocking
        unawaited(_refreshInBackground(fetchFresh));
        return cachedConfig;
      }
    }

    debugPrint('🔄 RuntimeConfigCache: Fetching fresh config');
    try {
      final freshConfig = await fetchFresh();
      await cacheConfig(freshConfig);
      debugPrint('✅ RuntimeConfigCache: Fresh config loaded and cached');
      return freshConfig;
    } catch (e) {
      debugPrint('⚠️ RuntimeConfigCache: Fetch failed, trying cache: $e');
      final cachedConfig = await getCachedConfig();
      if (cachedConfig != null) {
        debugPrint('✅ RuntimeConfigCache: Using stale cache as fallback');
        return cachedConfig;
      }
      rethrow;
    }
  }

  Future<RuntimeConfig?> getCachedConfig() async {
    try {
      final jsonStr = _prefs.getString(_configKey);
      if (jsonStr == null || jsonStr.isEmpty) return null;

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return RuntimeConfig(
        agoraAppId: json['agoraAppId'] as String? ?? '',
        apiBaseUrl: json['apiBaseUrl'] as String? ?? '',
        pusherKey: json['pusherKey'] as String? ?? '',
        pusherCluster: json['pusherCluster'] as String? ?? 'mt1',
      );
    } catch (e) {
      debugPrint('❌ RuntimeConfigCache: Error reading cache: $e');
      return null;
    }
  }

  Future<void> cacheConfig(RuntimeConfig config) async {
    try {
      final json = {
        'agoraAppId': config.agoraAppId,
        'apiBaseUrl': config.apiBaseUrl,
        'pusherKey': config.pusherKey,
        'pusherCluster': config.pusherCluster,
        'cachedAt': DateTime.now().toIso8601String(),
      };

      await _prefs.setString(_configKey, jsonEncode(json));
      await _prefs.setInt(
        _cacheTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      debugPrint('💾 RuntimeConfigCache: Config cached successfully');
    } catch (e) {
      debugPrint('⚠️ RuntimeConfigCache: Error caching config: $e');
    }
  }

  bool _isCacheValid() {
    try {
      final ts = _prefs.getInt(_cacheTimestampKey) ?? 0;
      if (ts == 0) return false;
      final age = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(ts),
      );
      return age < _cacheValidityDuration;
    } catch (_) {
      return false;
    }
  }

  Future<void> _refreshInBackground(
    Future<RuntimeConfig> Function() fetchFresh,
  ) async {
    try {
      debugPrint('🔄 RuntimeConfigCache: Background refresh starting');
      final freshConfig = await fetchFresh();
      await cacheConfig(freshConfig);
      debugPrint('✅ RuntimeConfigCache: Background refresh complete');
    } catch (e) {
      debugPrint('⚠️ RuntimeConfigCache: Background refresh failed: $e');
    }
  }

  Future<void> clearCache() async {
    await _prefs.remove(_configKey);
    await _prefs.remove(_cacheTimestampKey);
    debugPrint('🧹 RuntimeConfigCache: Cache cleared');
  }
}
