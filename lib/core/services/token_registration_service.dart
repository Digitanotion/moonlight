// lib/core/services/token_registration_service.dart
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:moonlight/core/config/runtime_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moonlight/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:moonlight/core/network/dio_client.dart';

class TokenRegistrationService {
  final AuthLocalDataSource authLocalDataSource;
  final RuntimeConfig runtimeConfig;
  final DioClient? dioClient; // Optional, for future use

  // Singleton instance
  static TokenRegistrationService? _instance;

  // Private constructor
  TokenRegistrationService._internal({
    required this.authLocalDataSource,
    required this.runtimeConfig,
    this.dioClient,
  });

  factory TokenRegistrationService({
    required AuthLocalDataSource authLocalDataSource,
    required RuntimeConfig runtimeConfig,
    DioClient? dioClient,
  }) {
    if (_instance == null) {
      _instance = TokenRegistrationService._internal(
        authLocalDataSource: authLocalDataSource,
        runtimeConfig: runtimeConfig,
        dioClient: dioClient,
      );
    }
    return _instance!;
  }

  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;

  // Storage keys
  static const String _fcmTokenKey = 'fcm_token';
  static const String _fcmTokenRegisteredKey = 'fcm_token_registered';
  static const String _lastRegistrationAttemptKey =
      'fcm_last_registration_attempt';

  bool _dependenciesSet = false;
  String? _apiBaseUrl;

  /// Initialize with dependencies from your DI container
  Future<void> setDependencies({required String apiBaseUrl}) async {
    if (_dependenciesSet) {
      if (kDebugMode) {
        print('📱 TokenRegistrationService dependencies already set');
      }
      return;
    }

    _apiBaseUrl = apiBaseUrl;
    _dependenciesSet = true;

    if (kDebugMode) {
      print('✅ TokenRegistrationService dependencies set');
    }

    // Now initialize Firebase messaging
    await _initializeFirebaseMessaging();
  }

  Future<void> _initializeFirebaseMessaging() async {
    try {
      // Enable foreground notifications
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Request permissions
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (kDebugMode) {
        print(
          '📱 Notification permission status: ${settings.authorizationStatus}',
        );
      }

      // Get or generate token
      await _handleTokenRegistration();

      // Listen for token refresh (important!)
      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
        if (kDebugMode) {
          print('📱 FCM Token refreshed: $newToken');
        }
        await _registerToken(newToken, isRefresh: true);
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Firebase Messaging setup error: $e');
      }
    }
  }

  Future<void> _handleTokenRegistration() async {
    try {
      // Get current token
      final token = await _firebaseMessaging.getToken();

      if (token != null) {
        if (kDebugMode) {
          print('📱 FCM Token: $token');
        }

        // Check if token has changed
        final prefs = await SharedPreferences.getInstance();
        final savedToken = prefs.getString(_fcmTokenKey);
        final tokenRegistered = prefs.getBool(_fcmTokenRegisteredKey) ?? false;
        final lastAttempt = prefs.getString(_lastRegistrationAttemptKey);

        // Check if we should attempt registration
        final shouldRegister = await _shouldAttemptRegistration(
          savedToken: savedToken,
          tokenRegistered: tokenRegistered,
          lastAttempt: lastAttempt,
          newToken: token,
        );

        if (shouldRegister) {
          // Token is new or changed, register it
          final success = await _registerToken(token);

          if (success) {
            // Save to preferences
            await prefs.setString(_fcmTokenKey, token);
            await prefs.setBool(_fcmTokenRegisteredKey, true);
            await prefs.setString(
              _lastRegistrationAttemptKey,
              DateTime.now().toIso8601String(),
            );
          }
        } else {
          if (kDebugMode) {
            print('📱 Token already registered or recently attempted');
          }
        }
      } else {
        if (kDebugMode) {
          print('📱 No FCM token available');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Token handling error: $e');
      }
    }
  }

  Future<bool> _shouldAttemptRegistration({
    required String? savedToken,
    required bool tokenRegistered,
    required String? lastAttempt,
    required String newToken,
  }) async {
    // If token changed
    if (savedToken != newToken) {
      return true;
    }

    // If never registered
    if (!tokenRegistered) {
      return true;
    }

    // Check last attempt time (avoid spamming)
    if (lastAttempt != null) {
      final lastAttemptTime = DateTime.parse(lastAttempt);
      final now = DateTime.now();
      final hoursSinceLastAttempt = now.difference(lastAttemptTime).inHours;

      // Don't attempt if less than 1 hour since last attempt
      if (hoursSinceLastAttempt < 1) {
        return false;
      }
    }

    return true;
  }

  Future<bool> _registerToken(String token, {bool isRefresh = false}) async {
    try {
      // Check if dependencies are set
      if (authLocalDataSource == null || _apiBaseUrl == null) {
        if (kDebugMode) {
          print(
            '⚠️ TokenRegistrationService not initialized with dependencies',
          );
        }
        return false;
      }

      // Get auth token
      final authToken = await authLocalDataSource!.getAuthToken();
      if (authToken == null || authToken.isEmpty) {
        if (kDebugMode) {
          print('📱 No auth token available, deferring token registration');
        }
        return false;
      }

      final platform = _getPlatform();
      final endpoint = '$_apiBaseUrl/api/v1/notifications/device-token';

      if (kDebugMode) {
        print('🔗 Registering token at: $endpoint');
        print('📱 Platform: $platform');
        print('🔑 Auth token available: ${authToken.isNotEmpty}');
      }

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'device_token': token, 'platform': platform}),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print(
            '✅ Device token ${isRefresh ? 'refreshed' : 'registered'} successfully',
          );
        }
        return true;
      } else {
        if (kDebugMode) {
          print(
            '❌ Failed to register token: ${response.statusCode} - ${response.body}',
          );
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error registering device token: $e');
      }
      return false;
    }
  }

  String _getPlatform() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'android';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'ios';
    } else {
      return 'web';
    }
  }

  /// Manually trigger token registration (for testing)
  Future<bool> registerTokenManually() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        return await _registerToken(token);
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Manual token registration failed: $e');
      }
      return false;
    }
  }

  /// Get current FCM token
  Future<String?> getCurrentToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fcmTokenKey);
  }

  /// Get registration status
  Future<Map<String, dynamic>> getRegistrationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_fcmTokenKey);
    final registered = prefs.getBool(_fcmTokenRegisteredKey) ?? false;
    final lastAttempt = prefs.getString(_lastRegistrationAttemptKey);

    return {
      'has_token': token != null,
      'token_preview': token != null ? '${token.substring(0, 20)}...' : null,
      'is_registered': registered,
      'last_attempt': lastAttempt,
      'auth_token_available':
          (await authLocalDataSource?.getAuthToken())?.isNotEmpty ?? false,
    };
  }

  /// Clear all FCM data (for logout)
  Future<void> clearFcmData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_fcmTokenKey);
      await prefs.remove(_fcmTokenRegisteredKey);
      await prefs.remove(_lastRegistrationAttemptKey);

      if (kDebugMode) {
        print('✅ FCM data cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error clearing FCM data: $e');
      }
    }
  }
}
