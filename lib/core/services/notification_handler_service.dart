// lib/core/services/notification_handler_service.dart
import 'package:flutter/material.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/features/live_viewer/presentation/pages/live_viewer_from_notification.dart';
import 'package:moonlight/features/chat/presentation/pages/chat_screen.dart';
import 'package:moonlight/features/clubs/presentation/pages/club_profile_screen.dart';
import 'package:moonlight/features/profile_view/presentation/pages/profile_view.dart';
import 'package:moonlight/features/post_view/presentation/pages/post_view_screen.dart';
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
      // Live Stream Notifications
      case 'live_stream_started':
        _handleLiveStreamNotification(payload);
        break;

      // Chat Notifications
      case 'new_message':
      case 'chat.direct.started':
        _handleChatNotification(payload);
        break;

      // Club Notifications
      case 'club.member_added':
      case 'club.member_joined':
      case 'club.role_changed':
      case 'club.ownership_transferred':
      case 'club.donation.received':
      case 'club.donation.confirmed':
        _handleClubNotification(payload);
        break;

      // Social Notifications
      case 'new_follower':
        _handleFollowerNotification(payload);
        break;
      case 'new_comment':
        _handleCommentNotification(payload);
        break;
      case 'new_gift':
        _handleGiftNotification(payload);
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      main_app.MyApp.navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => LiveViewerFromNotification(args: args),
          fullscreenDialog: true,
        ),
      );
    });
  }

  void _handleChatNotification(Map<String, dynamic> payload) {
    // Extract data from payload
    final conversationUuid = payload['conversation_uuid']?.toString() ?? '';
    final senderUuid =
        payload['sender_uuid']?.toString() ??
        payload['actor_uuid']?.toString() ??
        '';
    final senderName =
        payload['sender_name']?.toString() ??
        payload['actor_name']?.toString() ??
        'Someone';
    final messagePreview = payload['message_preview']?.toString() ?? '';

    print('💬 Chat notification from $senderName');
    print('💬 Conversation: $conversationUuid');

    if (conversationUuid.isEmpty) {
      print('❌ No conversation UUID in notification payload');
      return;
    }

    // Navigate to chat conversations list first? Or directly to the conversation?
    // Since ChatScreen requires a ChatConversations object, we might need to create a minimal one
    // or navigate to conversations list and let the user tap on the conversation

    // Option 1: Navigate to conversations list (safer)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      main_app.MyApp.navigatorKey.currentState?.pushNamed(
        RouteNames.conversations,
      );
    });

    // Option 2: If you have a way to open directly to a conversation with just UUID,
    // you would do that here. For now, we'll use conversations list.
  }

  void _handleClubNotification(Map<String, dynamic> payload) {
    final clubUuid = payload['club_uuid']?.toString() ?? '';
    final clubSlug = payload['club_slug']?.toString() ?? '';
    final clubName = payload['club_name']?.toString() ?? 'Club';
    final action = payload['type'] as String? ?? 'club.updated';

    print('👥 Club notification: $action for $clubName');

    // Use clubUuid if available, otherwise try clubSlug
    final identifier = clubUuid.isNotEmpty ? clubUuid : clubSlug;

    if (identifier.isEmpty) {
      print('❌ No club identifier in notification payload');
      return;
    }

    // Navigate to club profile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      main_app.MyApp.navigatorKey.currentState?.pushNamed(
        RouteNames.clubProfile,
        arguments: {'clubUuid': identifier},
      );
    });
  }

  void _handleFollowerNotification(Map<String, dynamic> payload) {
    final followerUuid = payload['follower_uuid']?.toString() ?? '';
    final followerSlug = payload['follower_slug']?.toString() ?? '';
    final followerName = payload['follower_name']?.toString() ?? 'Someone';

    print('👤 New follower: $followerName');

    // Use UUID if available, otherwise use slug
    final userIdentifier = followerUuid.isNotEmpty
        ? followerUuid
        : followerSlug;

    if (userIdentifier.isEmpty) {
      print('❌ No follower identifier in notification payload');
      return;
    }

    // Navigate to profile view
    WidgetsBinding.instance.addPostFrameCallback((_) {
      main_app.MyApp.navigatorKey.currentState?.pushNamed(
        RouteNames.profileView,
        arguments: {'userUuid': followerUuid}, // ProfileView expects 'userUuid'
      );
    });
  }

  void _handleCommentNotification(Map<String, dynamic> payload) {
    final postUuid = payload['post_uuid']?.toString() ?? '';
    final commenterName = payload['commenter_name']?.toString() ?? 'Someone';
    final commentPreview = payload['comment_preview']?.toString() ?? '';

    print('💬 New comment from $commenterName: $commentPreview');

    if (postUuid.isEmpty) {
      print('❌ No post UUID in notification payload');
      return;
    }

    // Navigate to post view
    WidgetsBinding.instance.addPostFrameCallback((_) {
      main_app.MyApp.navigatorKey.currentState?.pushNamed(
        RouteNames.postView,
        arguments: {
          'postId': postUuid,
          'isOwner': false, // Not the owner since they're commenting
        },
      );
    });
  }

  void _handleGiftNotification(Map<String, dynamic> payload) {
    final gifterName = payload['gifter_name']?.toString() ?? 'Someone';
    final giftName = payload['gift_name']?.toString() ?? 'a gift';

    print('🎁 New gift from $gifterName: $giftName');

    // Navigate to wallet to see gifts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      main_app.MyApp.navigatorKey.currentState?.pushNamed(RouteNames.wallet);
    });
  }
}
