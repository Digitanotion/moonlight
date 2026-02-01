// lib/core/services/runtime_config_refresh_service.dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/config/runtime_config.dart';
import 'package:moonlight/core/config/runtime_config_cache.dart';
import 'package:moonlight/core/services/connection_monitor.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'package:moonlight/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RuntimeConfigRefreshService {
  static final RuntimeConfigRefreshService _instance =
      RuntimeConfigRefreshService._internal();
  factory RuntimeConfigRefreshService() => _instance;
  RuntimeConfigRefreshService._internal();

  StreamSubscription<ConnectionStatus>? _connectionSubscription;
  bool _isRefreshing = false;
  Timer? _retryTimer;
  int _retryCount = 0;
  final int _maxRetries = 3;

  /// Start monitoring for config refresh opportunities
  Future<void> startMonitoring() async {
    debugPrint('🔧 RuntimeConfigRefreshService: Starting monitoring...');

    final monitor = ConnectionMonitor();

    _connectionSubscription = monitor.statusStream.listen((status) async {
      if (status == ConnectionStatus.connected) {
        debugPrint('📡 Internet restored, checking if config needs refresh...');

        // Wait a moment for network stability
        await Future.delayed(const Duration(seconds: 2));

        await _checkAndRefreshConfig();
      }
    });
  }

  /// Check if config needs refresh and refresh it
  Future<void> _checkAndRefreshConfig() async {
    if (_isRefreshing) return;

    _isRefreshing = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cache = RuntimeConfigCache(prefs);

      // Get current cached config
      final cachedConfig = await cache.getCachedConfig();

      if (cachedConfig == null) {
        debugPrint('📦 No cached config found, fetching fresh...');
        await _fetchAndApplyFreshConfig();
      } else if (cachedConfig.pusherKey.isEmpty ||
          cachedConfig.pusherKey == 'disabled') {
        debugPrint(
          '⚠️ Cached config has empty/disabled Pusher key, refreshing...',
        );
        await _fetchAndApplyFreshConfig();
      } else {
        // Config looks good, just do a silent background refresh
        debugPrint('✅ Config looks good, doing silent refresh...');
        unawaited(_silentRefresh());
      }
    } catch (e) {
      debugPrint('❌ Error checking/refreshing config: $e');
      _scheduleRetry();
    } finally {
      _isRefreshing = false;
    }
  }

  /// Fetch fresh config and apply it
  Future<void> _fetchAndApplyFreshConfig() async {
    debugPrint('🌐 Fetching fresh RuntimeConfig from server...');

    try {
      final prefs = await SharedPreferences.getInstance();
      final cache = RuntimeConfigCache(prefs);

      // Fetch fresh config (using your existing fetch logic)
      final freshConfig = await _fetchFreshConfig();

      if (freshConfig == null) {
        throw Exception('Failed to fetch fresh config');
      }

      // Cache the new config
      await cache.cacheConfig(freshConfig);

      // Update GetIt with new config
      await _updateRuntimeConfigInGetIt(freshConfig);

      // Fix Pusher if needed
      await _fixPusherWithNewConfig(freshConfig);

      debugPrint('✅ Fresh config applied successfully');
      _retryCount = 0; // Reset retry count on success
    } catch (e) {
      debugPrint('❌ Error applying fresh config: $e');
      rethrow;
    }
  }

  /// Fetch fresh config from server
  Future<RuntimeConfig?> _fetchFreshConfig() async {
    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: 'https://svc.moonlightstream.app/api',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      final response = await dio.get('/v1/config');
      final data = response.data as Map<String, dynamic>;

      return RuntimeConfig(
        agoraAppId: data['agora_app_id']?.toString() ?? '',
        apiBaseUrl: (data['api_base_url']?.toString() ?? '').replaceAll(
          RegExp(r'/+$'),
          '',
        ),
        pusherKey: data['pusher_key']?.toString() ?? '',
        pusherCluster: data['pusher_cluster']?.toString() ?? 'mt1',
      );
    } catch (e) {
      debugPrint('❌ Error fetching fresh config: $e');
      return null;
    }
  }

  /// Update RuntimeConfig in GetIt
  Future<void> _updateRuntimeConfigInGetIt(RuntimeConfig newConfig) async {
    if (GetIt.I.isRegistered<RuntimeConfig>()) {
      GetIt.I.unregister<RuntimeConfig>();
    }
    GetIt.I.registerLazySingleton<RuntimeConfig>(() => newConfig);

    debugPrint('🔄 Updated RuntimeConfig in GetIt');
    debugPrint(
      '   Pusher Key: ${newConfig.pusherKey.isEmpty ? "EMPTY" : "SET"}',
    );
  }

  /// Fix Pusher with new config
  Future<void> _fixPusherWithNewConfig(RuntimeConfig config) async {
    if (!GetIt.I.isRegistered<PusherService>()) {
      debugPrint('⚠️ PusherService not registered, skipping fix');
      return;
    }

    final pusher = GetIt.I<PusherService>();

    // Check if Pusher needs fixing
    if (pusher.isInBadState &&
        config.pusherKey.isNotEmpty &&
        config.pusherKey != 'disabled') {
      debugPrint('🔧 Fixing Pusher bad state with new config...');

      try {
        await pusher.fixBadState(
          apiKey: config.pusherKey,
          cluster: config.pusherCluster,
          authEndpoint: '${config.apiBaseUrl}/broadcasting/auth',
          authCallback: (channelName, socketId, options) async {
            final authLocal = GetIt.I<AuthLocalDataSource>();
            final token = await authLocal.readToken();
            if (token == null || token.isEmpty) {
              throw Exception('No auth token for Pusher');
            }

            final dio = GetIt.I<Dio>(instanceName: 'mainDio');
            final response = await dio.post(
              '/broadcasting/auth',
              data: {'socket_id': socketId, 'channel_name': channelName},
              options: Options(
                headers: {
                  'Accept': 'application/json',
                  'Authorization': 'Bearer $token',
                },
              ),
            );
            return response.data;
          },
        );

        debugPrint('✅ Pusher fixed successfully');
      } catch (e) {
        debugPrint('❌ Error fixing Pusher: $e');
      }
    } else {
      debugPrint('✅ Pusher is already in good state');
    }
  }

  /// Silent background refresh (doesn't update GetIt, just caches)
  Future<void> _silentRefresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cache = RuntimeConfigCache(prefs);

      final freshConfig = await _fetchFreshConfig();
      if (freshConfig != null) {
        await cache.cacheConfig(freshConfig);
        debugPrint('✅ Silent background refresh completed');
      }
    } catch (e) {
      debugPrint('⚠️ Silent background refresh failed: $e');
    }
  }

  /// Schedule a retry
  void _scheduleRetry() {
    if (_retryCount >= _maxRetries) {
      debugPrint('⏹️ Max retries reached, giving up');
      return;
    }

    _retryCount++;
    final delay = Duration(seconds: _retryCount * 5); // Exponential backoff

    debugPrint(
      '⏰ Scheduling retry #$_retryCount in ${delay.inSeconds} seconds',
    );

    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () async {
      debugPrint('🔄 Executing retry #$_retryCount');
      await _checkAndRefreshConfig();
    });
  }

  /// Stop monitoring
  Future<void> stopMonitoring() async {
    _connectionSubscription?.cancel();
    _retryTimer?.cancel();
    _isRefreshing = false;
    debugPrint('🛑 RuntimeConfigRefreshService stopped');
  }
}
