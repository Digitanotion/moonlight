// lib/core/services/notification_handler_service.dart
import 'package:flutter/material.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/features/live_viewer/presentation/pages/live_viewer_from_notification.dart';
import 'package:moonlight/main.dart' as main_app;

class NotificationHandlerService {
  static final NotificationHandlerService _instance =
      NotificationHandlerService._internal();

  factory NotificationHandlerService() => _instance;
  NotificationHandlerService._internal();

  /// Handle notification click based on payload
  void handleNotificationClick(Map<String, dynamic> payload) {
    print('🔔 Handling notification click: ${payload['type']}');

    final type = payload['type'] as String? ?? '';

    switch (type) {
      case 'live_stream_started':
        _handleLiveStreamNotification(payload);
        break;
      case 'new_message':
        _handleMessageNotification(payload);
        break;
      case 'new_follower':
        _handleFollowerNotification(payload);
        break;
      default:
        print('⚠️ Unknown notification type: $type');
    }
  }

  void _handleLiveStreamNotification(Map<String, dynamic> payload) {
    // Use the EXACT same args structure as LiveTileGrid
    final args = {
      'id':
          int.tryParse(
            payload['id']?.toString() ??
                payload['livestream_id']?.toString() ??
                '0',
          ) ??
          0,
      'uuid':
          payload['uuid']?.toString() ??
          payload['livestream_uuid']?.toString() ??
          '',
      'channel': payload['channel']?.toString() ?? '',
      'hostUuid':
          payload['hostUuid']?.toString() ??
          payload['host_uuid']?.toString() ??
          '',
      'hostName':
          payload['hostName']?.toString() ??
          payload['host_slug']?.toString() ??
          '',
      'hostAvatar':
          payload['hostAvatar']?.toString() ??
          payload['host_avatar']?.toString() ??
          '',
      'title':
          payload['title']?.toString() ??
          payload['livestream_title']?.toString() ??
          'Live Stream',
      'startedAt':
          payload['startedAt']?.toString() ??
          payload['timestamp']?.toString() ??
          DateTime.now().toIso8601String(),
      'role': payload['role']?.toString() ?? 'viewer',
      'isPremium':
          (payload['isPremium']?.toString() == '1' ||
              payload['is_premium']?.toString() == '1')
          ? 1
          : 0,
      'premiumFee':
          int.tryParse(
            payload['premiumFee']?.toString() ??
                payload['premium_fee']?.toString() ??
                '0',
          ) ??
          0,
      'livestreamId':
          payload['livestreamId']?.toString() ??
          payload['livestream_uuid']?.toString() ??
          '',
      'livestreamIdNumeric':
          int.tryParse(
            payload['livestreamIdNumeric']?.toString() ??
                payload['livestream_id']?.toString() ??
                '0',
          ) ??
          0,
    };

    print('🎥 Opening live stream from notification: ${args['id']}');
    print('🎥 Notification args: $args');

    // In NotificationHandlerService._handleLiveStreamNotification()
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🎥 Opening live stream from notification: ${args['id']}');

      // Navigate using the new wrapper
      main_app.MyApp.navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => LiveViewerFromNotification(args: args),
          fullscreenDialog: true,
        ),
      );
    });
  }

  void _handleMessageNotification(Map<String, dynamic> payload) {
    // Handle message notifications
    final conversationId = payload['conversation_id']?.toString() ?? '';
    print('💬 Opening conversation: $conversationId');

    // Navigate to chat
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   main_app.MyApp.navigatorKey.currentState?.pushNamed(
    //     RouteNames.chatConversation,
    //     arguments: {'conversationId': conversationId},
    //   );
    // });
  }

  void _handleFollowerNotification(Map<String, dynamic> payload) {
    // Handle follower notifications
    final followerId = payload['follower_id']?.toString() ?? '';
    print('👤 Opening follower profile: $followerId');

    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   main_app.MyApp.navigatorKey.currentState?.pushNamed(
    //     RouteNames.profile,
    //     arguments: {'userId': followerId},
    //   );
    // });
  }
}
