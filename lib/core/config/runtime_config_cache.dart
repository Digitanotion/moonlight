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

  /// Load config with cache-first strategy
  Future<RuntimeConfig> loadWithCache({
    required Future<RuntimeConfig> Function() fetchFresh,
    bool forceRefresh = false,
  }) async {
    debugPrint('🔧 RuntimeConfigCache: Loading with cache-first strategy');

    // 1. Try to load from cache first (if not forcing refresh)
    if (!forceRefresh) {
      final cachedConfig = await getCachedConfig();
      if (cachedConfig != null && _isCacheValid()) {
        debugPrint('✅ RuntimeConfigCache: Using valid cached config');
        // Start background refresh without waiting
        unawaited(_refreshInBackground(fetchFresh));
        return cachedConfig;
      }
    }

    // 2. If no valid cache, fetch fresh
    debugPrint('🔄 RuntimeConfigCache: Fetching fresh config');
    try {
      final freshConfig = await fetchFresh();
      await cacheConfig(freshConfig);
      debugPrint('✅ RuntimeConfigCache: Fresh config loaded and cached');
      return freshConfig;
    } catch (e) {
      // 3. If fetch fails, try cache as fallback
      debugPrint('⚠️ RuntimeConfigCache: Fresh fetch failed, trying cache: $e');
      final cachedConfig = await getCachedConfig();
      if (cachedConfig != null) {
        debugPrint('✅ RuntimeConfigCache: Using stale cache as fallback');
        return cachedConfig;
      }
      rethrow;
    }
  }

  /// Get cached config
  Future<RuntimeConfig?> getCachedConfig() async {
    try {
      final jsonStr = _prefs.getString(_configKey);
      if (jsonStr == null || jsonStr.isEmpty) {
        return null;
      }

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

  /// Cache the config
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

  /// Check if cache is still valid
  bool _isCacheValid() {
    try {
      final cachedTimestamp = _prefs.getInt(_cacheTimestampKey) ?? 0;
      if (cachedTimestamp == 0) return false;

      final cachedTime = DateTime.fromMillisecondsSinceEpoch(cachedTimestamp);
      final now = DateTime.now();
      final age = now.difference(cachedTime);

      return age < _cacheValidityDuration;
    } catch (e) {
      return false;
    }
  }

  /// Refresh config in background
  Future<void> _refreshInBackground(
    Future<RuntimeConfig> Function() fetchFresh,
  ) async {
    try {
      debugPrint('🔄 RuntimeConfigCache: Starting background refresh');
      final freshConfig = await fetchFresh();
      await cacheConfig(freshConfig);
      debugPrint('✅ RuntimeConfigCache: Background refresh completed');
    } catch (e) {
      debugPrint('⚠️ RuntimeConfigCache: Background refresh failed: $e');
      // Silently fail - we already have cached config
    }
  }

  /// Clear cache (for debugging or force refresh)
  Future<void> clearCache() async {
    await _prefs.remove(_configKey);
    await _prefs.remove(_cacheTimestampKey);
    debugPrint('🧹 RuntimeConfigCache: Cache cleared');
  }
}
