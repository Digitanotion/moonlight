// lib/features/live_viewer/presentation/utils/disposal_manager.dart
import 'package:flutter/material.dart';
import 'package:moonlight/core/services/agora_viewer_service.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'package:moonlight/features/live_viewer/data/repositories/viewer_repository_impl.dart';

class LiveViewerDisposalManager {
  static Future<void> disposeEverything({
    required ViewerRepositoryImpl repository,
    required AgoraViewerService agoraService,
    required PusherService pusherService,
    required String livestreamId,
  }) async {
    try {
      debugPrint('🧹 [DISPOSAL] Starting cleanup...');

      // 1. First, dispose the repository
      repository.dispose();
      debugPrint('✅ Repository disposed');

      // 2. Leave Agora channel
      try {
        await agoraService.leave();
        debugPrint('✅ Left Agora channel');
      } catch (e) {
        debugPrint('⚠️ Error leaving Agora: $e');
      }

      // 3. Unsubscribe from all Pusher channels for this livestream
      try {
        final channelsToUnsubscribe = [
          'live.$livestreamId.meta',
          'live.$livestreamId.chat',
          'live.$livestreamId.join',
          'live.$livestreamId',
          'live.$livestreamId.gifts',
        ];

        for (final channel in channelsToUnsubscribe) {
          await pusherService.unsubscribe(channel);
        }
        debugPrint('✅ Unsubscribed from Pusher channels');
      } catch (e) {
        debugPrint('⚠️ Error unsubscribing from Pusher: $e');
      }

      // 4. Clear all handlers for this livestream
      try {
        final channelsToClear = [
          'live.$livestreamId.meta',
          'live.$livestreamId.chat',
          'live.$livestreamId.join',
          'live.$livestreamId',
          'live.$livestreamId.gifts',
        ];

        for (final channel in channelsToClear) {
          pusherService.clearChannelHandlers(channel);
        }
        debugPrint('✅ Cleared Pusher handlers');
      } catch (e) {
        debugPrint('⚠️ Error clearing Pusher handlers: $e');
      }

      debugPrint('✅ All resources cleaned up successfully');
    } catch (e) {
      debugPrint('❌ Error during disposal: $e');
    }
  }
}
