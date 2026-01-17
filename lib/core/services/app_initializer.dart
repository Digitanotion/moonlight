import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/config/runtime_config.dart';
import 'package:moonlight/core/injection_container.dart' as di;
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'package:moonlight/core/services/current_user_service.dart';
import 'package:moonlight/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:moonlight/features/chat/data/repositories/chat_repository_impl.dart';

class AppInitializer {
  static final AppInitializer _instance = AppInitializer._internal();
  factory AppInitializer() => _instance;
  AppInitializer._internal();

  bool _isInitializing = false;
  Completer<void>? _initializationCompleter;

  /// Full app initialization (similar to main() but for retry scenarios)
  Future<void> initializeApp({bool retry = false}) async {
    if (_isInitializing && !retry) {
      return _initializationCompleter?.future;
    }

    _isInitializing = true;
    _initializationCompleter = Completer<void>();

    try {
      debugPrint('🚀 Starting full app initialization...');

      // 1. Check internet connectivity
      final hasConnection = await _checkInternetConnection();
      if (!hasConnection) {
        throw Exception('No internet connection');
      }

      // 2. Reload RuntimeConfig from server (CRITICAL!)
      await _reloadRuntimeConfig();

      // 3. Reinitialize DioClient with new base URL
      await _reinitializeDioClient();

      // 4. Initialize Pusher Service
      await _initializePusherService();

      // 5. Initialize other real-time services
      await _initializeOtherServices();

      // 6. Mark as initialized
      _isInitializing = false;
      _initializationCompleter?.complete();

      debugPrint('✅ Full app initialization complete');
    } catch (e, stack) {
      debugPrint('❌ Full app initialization failed: $e');
      debugPrint('Stack: $stack');

      _isInitializing = false;
      _initializationCompleter?.completeError(e);
      rethrow;
    }
  }

  /// Initialize just Pusher (lighter operation)
  Future<void> initializePusherOnly({bool retry = false}) async {
    debugPrint('🔧 Starting Pusher-only initialization...');

    try {
      // 1. Check internet
      final hasConnection = await _checkInternetConnection();
      if (!hasConnection) {
        throw Exception('No internet connection');
      }

      // 2. Reload RuntimeConfig if Pusher key is empty
      final currentConfig = GetIt.instance<RuntimeConfig>();
      if (currentConfig.pusherKey.isEmpty) {
        debugPrint('🔄 Pusher key is empty, reloading RuntimeConfig...');
        await _reloadRuntimeConfig();
      }

      // 3. Reset and reinitialize Pusher
      await _resetAndReinitializePusher();

      debugPrint('✅ Pusher-only initialization complete');
    } catch (e, stack) {
      debugPrint('❌ Pusher-only initialization failed: $e');
      debugPrint('Stack: $stack');
      rethrow;
    }
  }

  // ========== PRIVATE METHODS ==========

  Future<bool> _checkInternetConnection() async {
    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 5)));
      await dio.get('https://www.google.com');
      return true;
    } catch (e) {
      debugPrint('🌐 Internet check failed: $e');
      return false;
    }
  }

  Future<void> _reloadRuntimeConfig() async {
    debugPrint('🔄 Reloading RuntimeConfig from server...');

    try {
      // Call the SplashOptimizer's reload method
      final newConfig = await di.SplashOptimizer.reloadRuntimeConfig();

      // Verify we have a Pusher key
      if (newConfig.pusherKey.isEmpty) {
        throw Exception('Pusher key not configured on server');
      }

      debugPrint('✅ RuntimeConfig reloaded with Pusher key');
    } catch (e) {
      debugPrint('❌ Failed to reload RuntimeConfig: $e');
      rethrow;
    }
  }

  Future<void> _reinitializeDioClient() async {
    debugPrint('🔄 Reinitializing DioClient...');

    try {
      final config = GetIt.instance<RuntimeConfig>();
      final authLocal = GetIt.instance<AuthLocalDataSource>();

      // Unregister old DioClient if exists
      if (GetIt.instance.isRegistered<DioClient>()) {
        GetIt.instance.unregister<DioClient>();
      }

      // Create new DioClient with updated base URL
      final dioClient = DioClient(config.apiBaseUrl, authLocal);
      GetIt.instance.registerSingleton<DioClient>(dioClient);

      // Also update the main Dio instance
      if (GetIt.instance.isRegistered<Dio>(instanceName: 'mainDio')) {
        GetIt.instance.unregister<Dio>(instanceName: 'mainDio');
      }
      GetIt.instance.registerSingleton<Dio>(
        dioClient.dio,
        instanceName: 'mainDio',
      );

      debugPrint(
        '✅ DioClient reinitialized with base URL: ${config.apiBaseUrl}',
      );
    } catch (e) {
      debugPrint('⚠️ Error reinitializing DioClient: $e');
      // Continue anyway - DioClient might work with old config
    }
  }

  Future<void> _resetAndReinitializePusher() async {
    debugPrint('🔄 Resetting and reinitializing Pusher...');

    try {
      // Get fresh config
      final config = GetIt.instance<RuntimeConfig>();

      // Reset Pusher instance
      await _resetPusherInstance();

      // Get fresh Pusher instance
      final pusher = GetIt.instance<PusherService>();
      final authLocal = GetIt.instance<AuthLocalDataSource>();

      // Initialize with fresh config
      await pusher.initialize(
        apiKey: config.pusherKey,
        cluster: config.pusherCluster,
        authEndpoint: '${config.apiBaseUrl}/broadcasting/auth',
        authCallback: (channelName, socketId, options) async {
          final token = await authLocal.readToken();
          if (token == null || token.isEmpty) {
            throw Exception('No auth token');
          }

          final dio = GetIt.instance<Dio>(instanceName: 'mainDio');
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

      // Connect
      await pusher.connect();

      // Wait for connection
      await _waitForPusherConnection(pusher);

      debugPrint('✅ Pusher reinitialized and connected');
    } catch (e, stack) {
      debugPrint('❌ Failed to reinitialize Pusher: $e');
      debugPrint('Stack: $stack');
      rethrow;
    }
  }

  Future<void> _waitForPusherConnection(PusherService pusher) async {
    const timeout = Duration(seconds: 10);
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime) < timeout) {
      if (pusher.isConnected) {
        return;
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }

    throw Exception('Pusher connection timeout');
  }

  Future<void> _initializePusherService() async {
    debugPrint('🔧 Initializing Pusher service...');

    try {
      await _resetAndReinitializePusher();
    } catch (e) {
      debugPrint('❌ Pusher service initialization failed: $e');
      rethrow;
    }
  }

  Future<void> _initializeOtherServices() async {
    debugPrint('🔧 Initializing other real-time services...');

    // Initialize Chat Repository
    try {
      if (GetIt.instance.isRegistered<ChatRepositoryImpl>()) {
        GetIt.instance.unregister<ChatRepositoryImpl>();
      }

      final chatRepo = ChatRepositoryImpl(
        GetIt.instance<DioClient>(),
        GetIt.instance<PusherService>(),
        GetIt.instance<AuthLocalDataSource>(),
      );

      // Trigger initialization
      chatRepo.initialize();
      debugPrint('✅ Chat repository reinitialized');
    } catch (e) {
      debugPrint('⚠️ Chat repository reinitialization skipped: $e');
    }

    debugPrint('✅ Other services initialized');
  }

  Future<void> _resetPusherInstance() async {
    debugPrint('🔄 Resetting Pusher instance...');

    try {
      if (GetIt.instance.isRegistered<PusherService>()) {
        final pusher = GetIt.instance<PusherService>();
        await pusher.disconnect();

        // Try to dispose if available
        try {
          await pusher.dispose();
        } catch (_) {
          // Ignore if dispose doesn't exist
        }

        GetIt.instance.unregister<PusherService>();
      }

      // Register fresh instance
      GetIt.instance.registerLazySingleton<PusherService>(
        () => PusherService(),
      );

      debugPrint('✅ Pusher instance reset');
    } catch (e) {
      debugPrint('⚠️ Error resetting Pusher instance: $e');
      // Force unregister and register fresh
      GetIt.instance.unregister<PusherService>();
      GetIt.instance.registerLazySingleton<PusherService>(
        () => PusherService(),
      );
    }
  }
}
