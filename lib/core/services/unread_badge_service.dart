import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/services/realtime_unread_service.dart';

/// A simplified service for accessing unread counts
/// This can be used directly in widgets
class UnreadBadgeService {
  static final UnreadBadgeService _instance = UnreadBadgeService._internal();
  factory UnreadBadgeService() => _instance;
  UnreadBadgeService._internal();

  RealtimeUnreadService? _realtimeService;

  RealtimeUnreadService get _service {
    if (_realtimeService == null) {
      _realtimeService = GetIt.instance<RealtimeUnreadService>();
    }
    return _realtimeService!;
  }

  // Initialize the service
  Future<void> initialize() async {
    try {
      // Wait for all dependencies to be ready
      await DependencyManager.waitForAllDependencies();

      // Initialize the realtime service
      await _service.initialize();
    } catch (e) {
      debugPrint('UnreadBadgeService initialization error: $e');
    }
  }

  // ValueNotifiers for direct widget binding
  ValueNotifier<int> get messageUnreadCount => _service.messageUnreadCount;
  ValueNotifier<int> get notificationUnreadCount =>
      _service.notificationUnreadCount;

  // Get current counts
  int get messageCount => _service.messageUnreadCount.value;
  int get notificationCount => _service.notificationUnreadCount.value;
  int get totalCount => _service.totalUnreadCount;

  // Refresh counts manually
  Future<void> refresh() async {
    await _service.refreshCounts();
  }

  // Mark notifications as read
  Future<void> markNotificationsAsRead() async {
    await _service.markNotificationsAsRead();
  }

  // Get conversation-specific count
  int getConversationUnreadCount(String conversationUuid) {
    return _service.getConversationUnreadCount(conversationUuid);
  }

  // Check if service is ready
  bool get isReady => _service.isConnected;

  // Disconnect (call when logging out)
  Future<void> disconnect() async {
    await _service.disconnect();
  }
}
