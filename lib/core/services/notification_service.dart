import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/services/notification_handler_service.dart';
import 'package:moonlight/main.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // In NotificationService class, update the initialize method:
  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) async {
        print('🎯 NOTIFICATION CLICKED!');

        final payload = _parseNotificationPayload(details.payload);

        if (payload != null) {
          print('✅ Parsed payload: $payload');
          _handleNotificationNavigation(payload);
        } else {
          print('❌ Could not parse payload: ${details.payload}');
        }
      },
    );

    // Create notification channel for Android 8.0+
    await _createNotificationChannel();

    print('✅ NotificationService initialized');
  }

  // ✅ Handle properly when user clicks on the push notification
  void _handleNotificationNavigation(Map<String, dynamic> payload) {
    print('🎯 Notification tapped in foreground: $payload');
    NotificationHandlerService().handleNotificationClick(payload);
  }

  // Add this helper function to NotificationService
  Map<String, dynamic>? _parseNotificationPayload(String? payloadString) {
    if (payloadString == null || payloadString.isEmpty) {
      return null;
    }

    try {
      // Try to parse as JSON first
      return jsonDecode(payloadString) as Map<String, dynamic>;
    } catch (e) {
      print('⚠️ JSON parse failed, trying alternative parsing...');

      // If it's already a Map string representation like "{key: value}"
      if (payloadString.startsWith('{') && payloadString.endsWith('}')) {
        try {
          // Convert Dart Map string to JSON format
          // This is a simple conversion - may need adjustment for complex cases
          var jsonStr = payloadString
              .replaceAllMapped(
                RegExp(r'([a-zA-Z0-9_]+):'),
                (match) => '"${match.group(1)}":',
              )
              .replaceAllMapped(
                RegExp(r': ([a-zA-Z0-9_@./#&+-]+)(?=[,}])'),
                (match) => ': "${match.group(1)}"',
              );

          return jsonDecode(jsonStr) as Map<String, dynamic>;
        } catch (e2) {
          print('❌ Alternative parsing failed: $e2');
        }
      }
    }

    return null;
  }

  Future<void> _createNotificationChannel() async {
    AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id - MUST match manifest
      'High Importance Notifications', // title
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 1000, 500]),
      // playSound: true,
      // sound: const RawResourceAndroidNotificationSound('notification'),
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    print('✅ Notification channel created');
  }

  Future<void> showNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
    String? channelId = 'high_importance_channel',
  }) async {
    print('🎯 Attempting to show notification: $title');
    print('🎯 Payload type: ${payload?.runtimeType}');
    print('🎯 Payraw: $payload');

    AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription:
              'This channel is used for important notifications.',
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'ticker',
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 1000, 500]),
        );

    const DarwinNotificationDetails iosNotificationDetails =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosNotificationDetails,
    );

    // FIX: Convert payload to JSON string
    String? payloadJson;
    if (payload != null) {
      try {
        payloadJson = jsonEncode(payload);
        print('🎯 Payload JSON encoded: $payloadJson');
      } catch (e) {
        print('❌ Error encoding payload to JSON: $e');
        payloadJson = null;
      }
    }

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: payloadJson, // Use JSON string
    );

    print('📱 Local notification shown: $title - $body');
  }
}
