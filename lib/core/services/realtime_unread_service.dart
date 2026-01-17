import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'package:moonlight/features/auth/data/datasources/auth_local_datasource.dart';

class RealtimeUnreadService {
  static final RealtimeUnreadService _instance =
      RealtimeUnreadService._internal();
  factory RealtimeUnreadService() => _instance;
  RealtimeUnreadService._internal();

  // ValueNotifiers for reactive updates
  final ValueNotifier<int> messageUnreadCount = ValueNotifier<int>(0);
  final ValueNotifier<int> notificationUnreadCount = ValueNotifier<int>(0);
  final ValueNotifier<Map<String, int>> conversationUnreadCounts =
      ValueNotifier<Map<String, int>>({});

  // References to your existing services
  PusherService? _pusherService;
  StreamSubscription<ConnectionState>? _connectionSubscription;

  String? _currentUserUuid;
  bool _isInitialized = false;
  bool _isSubscribed = false;

  // Get current user from AuthLocalDataSource
  Future<String?> _getCurrentUserUuid() async {
    try {
      final authLocal = GetIt.instance<AuthLocalDataSource>();
      final userData = await authLocal.getCurrentUserUuid();
      return userData;
    } catch (e) {
      debugPrint('Error getting user UUID: $e');
      return null;
    }
  }

  // Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _currentUserUuid = await _getCurrentUserUuid();
      if (_currentUserUuid == null) {
        debugPrint(
          'RealtimeUnreadService: No user UUID found, skipping initialization',
        );
        return;
      }

      debugPrint(
        'RealtimeUnreadService: Initializing for user $_currentUserUuid',
      );

      // Get your existing PusherService from GetIt
      _pusherService = GetIt.instance<PusherService>();

      if (_pusherService == null) {
        debugPrint('RealtimeUnreadService: PusherService not registered');
        return;
      }

      // Wait for Pusher to be initialized
      if (!_pusherService!.isInitialized) {
        debugPrint(
          'RealtimeUnreadService: Waiting for PusherService to initialize...',
        );
        // You might want to listen for connection state changes
        await _waitForPusherInitialization();
      }

      // Listen for connection state changes
      _setupConnectionListener();

      _isInitialized = true;

      // Fetch initial counts
      await _fetchInitialCounts();

      debugPrint('RealtimeUnreadService: Initialized successfully');
    } catch (e) {
      debugPrint('RealtimeUnreadService: Initialization error: $e');
      _isInitialized = false;
    }
  }

  Future<void> _waitForPusherInitialization() async {
    int attempts = 0;
    const maxAttempts = 10;
    const delay = Duration(milliseconds: 500);

    while (attempts < maxAttempts && !_pusherService!.isInitialized) {
      debugPrint(
        'Waiting for PusherService initialization... (attempt ${attempts + 1})',
      );
      await Future.delayed(delay);
      attempts++;
    }

    if (!_pusherService!.isInitialized) {
      throw Exception(
        'PusherService not initialized after $maxAttempts attempts',
      );
    }
  }

  void _setupConnectionListener() {
    _connectionSubscription?.cancel();

    _connectionSubscription = _pusherService!.connectionStateStream.listen((
      state,
    ) {
      debugPrint(
        'RealtimeUnreadService: Pusher connection state changed to $state',
      );

      if (state == ConnectionState.connected) {
        _subscribeToUnreadUpdates();
      } else if (state == ConnectionState.disconnected ||
          state == ConnectionState.failed) {
        _isSubscribed = false;
      }
    });
  }

  Future<void> _subscribeToUnreadUpdates() async {
    if (_isSubscribed || _currentUserUuid == null) return;

    try {
      final channelName = 'private-users.$_currentUserUuid.notifications';

      debugPrint('RealtimeUnreadService: Subscribing to $channelName');

      // Subscribe to the private channel
      await _pusherService!.subscribePrivate(channelName);

      // Bind to unread update events
      _pusherService!.bind(
        channelName,
        'chat.unread.updated',
        _handleChatUnreadUpdate,
      );

      _pusherService!.bind(
        channelName,
        'notifications.unread.updated',
        _handleNotificationUnreadUpdate,
      );

      _isSubscribed = true;
      debugPrint('RealtimeUnreadService: Subscribed to unread updates');
    } catch (e) {
      debugPrint(
        'RealtimeUnreadService: Error subscribing to unread updates: $e',
      );
    }
  }

  // Fetch initial counts from API
  Future<void> _fetchInitialCounts() async {
    try {
      debugPrint('RealtimeUnreadService: Fetching initial counts...');

      final dioClient = GetIt.instance<DioClient>();

      // Fetch combined counts
      final response = await dioClient.dio.get(
        '/api/v1/chat/all-unread-counts',
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;

        // Update message counts
        final messagesData = data['messages'] as Map<String, dynamic>? ?? {};
        messageUnreadCount.value = messagesData['total_unread'] as int? ?? 0;

        // Update conversation-specific counts
        final conversationCounts = <String, int>{};
        final conversations = data['conversations'] as List<dynamic>? ?? [];
        for (final conv in conversations) {
          final convMap = conv as Map<String, dynamic>;
          final uuid = convMap['uuid'] as String?;
          final count = convMap['unread_count'] as int?;
          if (uuid != null && count != null) {
            conversationCounts[uuid] = count;
          }
        }
        conversationUnreadCounts.value = conversationCounts;

        // Update notification counts
        final notificationsData =
            data['notifications'] as Map<String, dynamic>? ?? {};
        notificationUnreadCount.value =
            notificationsData['unread_count'] as int? ?? 0;

        debugPrint(
          'RealtimeUnreadService: Initial counts loaded - '
          'Messages: ${messageUnreadCount.value}, '
          'Notifications: ${notificationUnreadCount.value}',
        );
      }
    } catch (e) {
      debugPrint('RealtimeUnreadService: Error fetching initial counts: $e');
    }
  }

  // Handle chat unread updates
  void _handleChatUnreadUpdate(Map<String, dynamic> payload) {
    try {
      final totalUnread = payload['total_unread_messages'] as int? ?? 0;
      messageUnreadCount.value = totalUnread;

      // Update conversation-specific counts
      final byConversation =
          payload['unread_by_conversation'] as Map<String, dynamic>? ?? {};
      final conversationCounts = <String, int>{};
      byConversation.forEach((key, value) {
        if (value is int) {
          conversationCounts[key] = value;
        }
      });
      conversationUnreadCounts.value = conversationCounts;

      debugPrint(
        'RealtimeUnreadService: Chat unread updated - Total: $totalUnread',
      );
    } catch (e) {
      debugPrint(
        'RealtimeUnreadService: Error handling chat unread update: $e',
      );
    }
  }

  // Handle notification unread updates
  void _handleNotificationUnreadUpdate(Map<String, dynamic> payload) {
    try {
      final unreadCount = payload['unread_count'] as int? ?? 0;
      notificationUnreadCount.value = unreadCount;

      debugPrint(
        'RealtimeUnreadService: Notifications unread updated - Count: $unreadCount',
      );
    } catch (e) {
      debugPrint(
        'RealtimeUnreadService: Error handling notification unread update: $e',
      );
    }
  }

  // Clean up subscription
  Future<void> _unsubscribeFromUnreadUpdates() async {
    if (!_isSubscribed || _currentUserUuid == null) return;

    try {
      final channelName = 'private-users.$_currentUserUuid.notifications';

      _pusherService?.unbind(
        channelName,
        'chat.unread.updated',
        _handleChatUnreadUpdate,
      );

      _pusherService?.unbind(
        channelName,
        'notifications.unread.updated',
        _handleNotificationUnreadUpdate,
      );

      await _pusherService?.unsubscribe(channelName);

      _isSubscribed = false;
      debugPrint('RealtimeUnreadService: Unsubscribed from unread updates');
    } catch (e) {
      debugPrint(
        'RealtimeUnreadService: Error unsubscribing from unread updates: $e',
      );
    }
  }

  // Public methods
  Future<void> disconnect() async {
    await _unsubscribeFromUnreadUpdates();
    _connectionSubscription?.cancel();
    _connectionSubscription = null;

    _isInitialized = false;
    debugPrint('RealtimeUnreadService: Disconnected');
  }

  Future<void> refreshCounts() async {
    await _fetchInitialCounts();
  }

  // Helper method to get conversation-specific unread count
  int getConversationUnreadCount(String conversationUuid) {
    return conversationUnreadCounts.value[conversationUuid] ?? 0;
  }

  // Mark notifications as read via API
  Future<void> markNotificationsAsRead() async {
    try {
      final dioClient = GetIt.instance<DioClient>();
      await dioClient.dio.post('/api/v1/notifications/read-all');
      // The real-time update will come via Pusher
    } catch (e) {
      debugPrint('Error marking notifications as read: $e');
      rethrow;
    }
  }

  // Check if service is connected
  bool get isConnected => _pusherService?.isConnected ?? false;

  // Get total unread count (messages + notifications)
  int get totalUnreadCount {
    return messageUnreadCount.value + notificationUnreadCount.value;
  }
}
