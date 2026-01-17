import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:moonlight/core/services/app_initializer.dart';
import 'package:moonlight/core/services/current_user_service.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'package:get_it/get_it.dart';

class ServiceRegistrationManager {
  static final ServiceRegistrationManager _instance =
      ServiceRegistrationManager._internal();
  factory ServiceRegistrationManager() => _instance;
  ServiceRegistrationManager._internal();

  final AppInitializer _appInitializer = AppInitializer();
  bool _isRegistered = false;
  bool _isRegistering = false;
  Completer<void>? _registrationCompleter;
  Timer? _reconnectionTimer;

  /// Register all real-time services (Pusher, etc.)
  Future<void> registerServices({bool retry = false}) async {
    debugPrint('🎯 ServiceRegistrationManager.registerServices() called');

    if (_isRegistering && !retry) {
      debugPrint('⚠️ Already registering, returning existing future');
      return _registrationCompleter?.future;
    }

    _isRegistering = true;
    _registrationCompleter = Completer<void>();

    try {
      debugPrint('🚀 Starting service registration process...');

      // 1. Check if user is authenticated
      final currentUserService = GetIt.instance<CurrentUserService>();
      final currentUser = await currentUserService.getCurrentUserId();

      if (currentUser == null) {
        debugPrint('⚠️ User not authenticated, skipping service registration');
        _isRegistering = false;
        _registrationCompleter?.complete();
        return;
      }

      // 2. Check internet connection FIRST
      debugPrint('🌐 Checking internet connection...');
      final hasInternet = await _checkInternetConnection();
      if (!hasInternet) {
        debugPrint('❌ NO INTERNET CONNECTION DETECTED');
        throw Exception('No internet connection available'); // This gets thrown
      }

      debugPrint('✅ Internet connection available');

      // 3. Initialize Pusher and other services
      debugPrint('🔧 Initializing Pusher services...');
      await _appInitializer.initializePusherOnly(retry: retry);

      // 4. Mark as registered ONLY if successful
      _isRegistered = true;
      _isRegistering = false;

      debugPrint('✅ All services registered successfully');
      _registrationCompleter?.complete(); // This completes WITHOUT error
    } catch (e, stack) {
      debugPrint('❌ Service registration FAILED: $e');
      debugPrint('Stack: $stack');

      _isRegistering = false;
      _isRegistered = false;

      // CRITICAL FIX: Complete the completer WITH ERROR
      if (!_registrationCompleter!.isCompleted) {
        _registrationCompleter?.completeError(e, stack);
      }

      // Re-throw to propagate the error
      rethrow; // ADD THIS LINE!
    }
  }

  // Add this helper method
  Future<bool> _checkInternetConnection() async {
    try {
      debugPrint('🔍 Performing internet connectivity check...');
      final dio = Dio();

      // Try a reliable endpoint
      final response = await dio.get(
        'https://www.google.com',
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );

      debugPrint('✅ Internet check passed: Status ${response.statusCode}');
      return true;
    } catch (e) {
      debugPrint('❌ Internet check failed: $e');
      return false;
    }
  }

  /// Full app reinitialization (use when Pusher key is empty)
  Future<void> reinitializeApp() async {
    debugPrint('🔄 Starting full app reinitialization...');

    try {
      await _appInitializer.initializeApp(retry: true);
      _isRegistered = true;
      debugPrint('✅ Full app reinitialization complete');
    } catch (e, stack) {
      debugPrint('❌ Full app reinitialization failed: $e');
      debugPrint('Stack: $stack');
      rethrow;
    }
  }

  /// Unregister all services (on logout)
  Future<void> unregisterServices() async {
    debugPrint('🔄 Unregistering all services...');

    _stopReconnectionMonitor();
    _isRegistered = false;
    _isRegistering = false;

    try {
      if (GetIt.instance.isRegistered<PusherService>()) {
        final pusher = GetIt.instance<PusherService>();
        await pusher.disconnect();
        debugPrint('✅ Pusher disconnected');
      }
    } catch (e) {
      debugPrint('⚠️ Error disconnecting Pusher: $e');
    }

    // Clear any pending registration
    _registrationCompleter?.complete();
    _registrationCompleter = null;
  }

  /// Check service registration status
  bool get isRegistered => _isRegistered;
  bool get isRegistering => _isRegistering;

  /// Force reconnection
  Future<void> reconnect() async {
    if (!_isRegistered) {
      await registerServices(retry: true);
      return;
    }

    try {
      if (GetIt.instance.isRegistered<PusherService>()) {
        final pusher = GetIt.instance<PusherService>();
        if (!pusher.isConnected) {
          debugPrint('🔄 Attempting to reconnect Pusher...');
          await pusher.connect();
        }
      }
    } catch (e) {
      debugPrint('❌ Reconnection failed: $e');
      await registerServices(retry: true);
    }
  }

  // ========== PRIVATE METHODS ==========

  Future<void> _cleanupPartialRegistration() async {
    try {
      if (GetIt.instance.isRegistered<PusherService>()) {
        final pusher = GetIt.instance<PusherService>();
        await pusher.disconnect();
      }
    } catch (e) {
      // Ignore errors during cleanup
    }
  }

  void _startReconnectionMonitor() {
    _stopReconnectionMonitor();

    _reconnectionTimer = Timer.periodic(const Duration(minutes: 1), (
      timer,
    ) async {
      try {
        if (GetIt.instance.isRegistered<PusherService>()) {
          final pusher = GetIt.instance<PusherService>();
          if (!pusher.isConnected && _isRegistered) {
            debugPrint('🔌 Pusher disconnected, attempting reconnection...');
            await reconnect();
          }
        }
      } catch (e) {
        debugPrint('⚠️ Reconnection monitor error: $e');
      }
    });
  }

  void _stopReconnectionMonitor() {
    _reconnectionTimer?.cancel();
    _reconnectionTimer = null;
  }
}
