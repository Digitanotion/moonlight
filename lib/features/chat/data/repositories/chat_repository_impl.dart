// lib/features/chat/data/repositories/chat_repository_impl.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'package:moonlight/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:moonlight/features/chat/data/models/chat_conversations.dart';
import 'package:moonlight/features/chat/data/models/chat_models.dart';
import 'package:moonlight/features/chat/data/services/chat_api_service.dart';
import 'package:moonlight/features/chat/domain/entities/chat_paginated.dart';
import 'package:moonlight/features/chat/domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  final DioClient _client;
  final PusherService _pusher;
  final AuthLocalDataSource _authLocalDataSource;

  String? _cachedUserUuid;
  String? _cachedAuthToken;

  // Stream controllers for real-time events
  final _messageStreamCtrl = StreamController<Message>.broadcast();
  final _conversationUpdateStreamCtrl =
      StreamController<Map<String, dynamic>>.broadcast();
  final _typingStartedStreamCtrl = StreamController<String>.broadcast();
  final _conversationReadStreamCtrl = StreamController<String>.broadcast();

  final Set<String> _boundConversations = {};
  bool _globalEventsBound = false;
  bool _pusherInitialized = false;

  ChatRepositoryImpl(this._client, this._pusher, this._authLocalDataSource);

  Future<void> initialize() async {
    await _ensureUserUuidLoaded();
    await _ensureAuthTokenLoaded();
    debugPrint('✅ ChatRepository initialized');
  }

  /* -------------------------------------------------------------------------- */
  /*                               UUID HANDLING                                 */
  /* -------------------------------------------------------------------------- */

  Future<void> _ensureUserUuidLoaded() async {
    if (_cachedUserUuid != null) return;
    _cachedUserUuid = await _authLocalDataSource.getCurrentUserUuid();
    debugPrint('🔑 Loaded user UUID: $_cachedUserUuid');
  }

  Future<void> _ensureAuthTokenLoaded() async {
    if (_cachedAuthToken != null) return;
    _cachedAuthToken = await _authLocalDataSource.readToken();
    debugPrint(
      '🔑 Loaded auth token: ${_cachedAuthToken?.substring(0, 20)}...',
    );
  }

  String getCurrentUserUuidSync() {
    return _cachedUserUuid ?? '';
  }

  /* -------------------------------------------------------------------------- */
  /*                               PUSHER SETUP                                  */
  /* -------------------------------------------------------------------------- */

  Future<void> _ensurePusherConnected() async {
    // Check if Pusher is initialized
    if (!_pusher.isInitialized) {
      debugPrint(
        '⚠️ Pusher not initialized - chat real-time features disabled',
      );
      return; // Exit gracefully - app works without real-time
    }

    // Only try to connect if Pusher is initialized
    if (!_pusher.isConnected) {
      debugPrint('🔗 Connecting Pusher for chat...');
      try {
        await _pusher.connect();
        debugPrint('✅ Pusher connected for chat');
      } catch (e) {
        debugPrint('❌ Failed to connect Pusher: $e');
        // Don't rethrow - chat should still work without Pusher
      }
    }
  }

  Future<bool> _isPusherReady() async {
    if (!_pusher.isInitialized) {
      debugPrint('⏳ Pusher not ready yet');
      return false;
    }
    return true;
  }

  /* -------------------------------------------------------------------------- */
  /*                               API METHODS                                   */
  /* -------------------------------------------------------------------------- */

  @override
  Future<List<ChatConversations>> getConversations() async {
    try {
      final response = await _client.dio.get('/api/v1/chat/conversations');
      final data = (response.data as Map)['data'] as List;
      return data
          .map(
            (json) => ChatConversations.fromJson(
              Map<String, dynamic>.from(json as Map),
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting conversations: $e');
      rethrow;
    }
  }

  @override
  Future<ChatConversations> startDirectConversation(String userUuid) async {
    try {
      final response = await _client.dio.post(
        '/api/v1/chat/direct',
        data: {'user_uuid': userUuid},
      );
      final data = (response.data as Map)['data'] as Map<String, dynamic>;
      return ChatConversations.fromJson(data);
    } catch (e) {
      debugPrint('❌ Error starting direct conversation: $e');
      rethrow;
    }
  }

  @override
  Future<Conversation> getClubConversation(String clubSlugOrUuid) async {
    try {
      final response = await _client.dio.post(
        '/api/v1/chat/clubs/$clubSlugOrUuid/conversation',
      );
      final data = (response.data as Map)['data'] as Map<String, dynamic>;
      return Conversation.fromJson(data);
    } catch (e) {
      debugPrint('❌ Error getting club conversation: $e');
      rethrow;
    }
  }

  @override
  Future<List<Conversation>> searchConversations(String query) async {
    try {
      final response = await _client.dio.get(
        '/api/v1/chat/conversations/search',
        queryParameters: {'q': query},
      );
      final data = (response.data as Map)['data'] as List;
      return data
          .map(
            (json) =>
                Conversation.fromJson(Map<String, dynamic>.from(json as Map)),
          )
          .toList();
    } catch (e) {
      debugPrint('❌ Error searching conversations: $e');
      rethrow;
    }
  }

  @override
  Future<PaginatedMessages> getMessages(
    String conversationUuid, {
    int page = 1,
    int perPage = 50,
  }) async {
    try {
      final response = await _client.dio.get(
        '/api/v1/chat/conversations/$conversationUuid/messages',
        queryParameters: {'page': page, 'per_page': perPage},
      );
      return PaginatedMessages.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      debugPrint('❌ Error getting messages: $e');
      rethrow;
    }
  }

  // In ChatRepositoryImpl - make sure API call includes reply_to_uuid
  // In ChatRepositoryImpl - update sendTextMessage to debug the response
  @override
  Future<Message> sendTextMessage(
    String conversationUuid, {
    required String body,
    String? replyToUuid,
  }) async {
    try {
      final data = {'body': body};
      if (replyToUuid != null && replyToUuid.isNotEmpty) {
        data['reply_to_uuid'] = replyToUuid;
      }

      debugPrint('📤 Sending message with reply_to_uuid: $replyToUuid');

      final response = await _client.dio.post(
        '/api/v1/chat/conversations/$conversationUuid/messages',
        data: data,
      );

      final responseData =
          (response.data as Map)['data'] as Map<String, dynamic>;

      debugPrint('✅ Message sent successfully');
      debugPrint(
        '📋 Response contains reply_to: ${responseData.containsKey('reply_to')}',
      );
      if (responseData.containsKey('reply_to')) {
        debugPrint('📋 Reply to object: ${responseData['reply_to']}');
      }

      return Message.fromJson(responseData);
    } catch (e) {
      debugPrint('❌ Error sending text message: $e');
      rethrow;
    }
  }

  @override
  Future<Message> sendMediaMessage(
    String conversationUuid, {
    required File file,
    String? body,
    String? replyToUuid,
  }) async {
    try {
      final formData = FormData.fromMap({
        if (body != null && body.isNotEmpty) 'body': body,
        if (replyToUuid != null) 'reply_to_uuid': replyToUuid,
        'media[]': await MultipartFile.fromFile(
          file.path,
          filename: file.path.split('/').last,
        ),
      });

      final response = await _client.dio.post(
        '/api/v1/chat/conversations/$conversationUuid/messages',
        data: formData,
      );
      final responseData =
          (response.data as Map)['data'] as Map<String, dynamic>;
      return Message.fromJson(responseData);
    } catch (e) {
      debugPrint('❌ Error sending media message: $e');
      rethrow;
    }
  }

  @override
  Future<Message> editMessage(String messageUuid, String newBody) async {
    try {
      final response = await _client.dio.patch(
        '/api/v1/chat/messages/$messageUuid',
        data: {'body': newBody},
      );
      final responseData =
          (response.data as Map)['data'] as Map<String, dynamic>;
      return Message.fromJson(responseData);
    } catch (e) {
      debugPrint('❌ Error editing message: $e');
      rethrow;
    }
  }

  @override
  Future<void> deleteMessage(String messageUuid) async {
    try {
      await _client.dio.delete('/api/v1/chat/messages/$messageUuid');
    } catch (e) {
      debugPrint('❌ Error deleting message: $e');
      rethrow;
    }
  }

  @override
  Future<void> reactToMessage(String messageUuid, String emoji) async {
    try {
      await _client.dio.post(
        '/api/v1/chat/messages/$messageUuid/reactions',
        data: {'emoji': emoji},
      );
    } catch (e) {
      debugPrint('❌ Error reacting to message: $e');
      rethrow;
    }
  }

  @override
  Future<void> markConversationAsRead(String conversationUuid) async {
    try {
      await _client.dio.post(
        '/api/v1/chat/conversations/$conversationUuid/read',
      );
    } catch (e) {
      debugPrint('❌ Error marking conversation as read: $e');
      rethrow;
    }
  }

  @override
  Future<void> sendTypingIndicator(String conversationUuid) async {
    try {
      await _client.dio.post(
        '/api/v1/chat/conversations/$conversationUuid/typing',
        data: {'typing': true},
      );
    } catch (e) {
      debugPrint('❌ Error sending typing indicator: $e');
    }
  }

  /* -------------------------------------------------------------------------- */
  /*                         CONVERSATION STATE ACTIONS                          */
  /* -------------------------------------------------------------------------- */

  @override
  Future<void> pinConversation(String conversationUuid) async {
    try {
      await _client.dio.post(
        '/api/v1/chat/conversations/$conversationUuid/pin',
      );
    } catch (e) {
      debugPrint('❌ Error pinning conversation: $e');
      rethrow;
    }
  }

  @override
  Future<void> muteConversation(String conversationUuid) async {
    try {
      await _client.dio.post(
        '/api/v1/chat/conversations/$conversationUuid/mute',
      );
    } catch (e) {
      debugPrint('❌ Error muting conversation: $e');
      rethrow;
    }
  }

  @override
  Future<void> archiveConversation(String conversationUuid) async {
    try {
      await _client.dio.post(
        '/api/v1/chat/conversations/$conversationUuid/archive',
      );
    } catch (e) {
      debugPrint('❌ Error archiving conversation: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> getUnreadCounts() async {
    try {
      final response = await _client.dio.get('/api/v1/chat/unread-count');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ Error getting unread counts: $e');
      rethrow;
    }
  }

  /* -------------------------------------------------------------------------- */
  /*                             REALTIME STREAMS                                */
  /* -------------------------------------------------------------------------- */

  @override
  Stream<Message> messageStream() {
    _bindGlobalEventsIfNeeded();
    return _messageStreamCtrl.stream;
  }

  @override
  Stream<String> typingStartedStream() {
    _bindGlobalEventsIfNeeded();
    return _typingStartedStreamCtrl.stream;
  }

  @override
  Stream<Map<String, dynamic>> conversationUpdateStream() {
    _bindGlobalEventsIfNeeded();
    return _conversationUpdateStreamCtrl.stream;
  }

  @override
  Stream<String> conversationReadStream() {
    _bindGlobalEventsIfNeeded();
    return _conversationReadStreamCtrl.stream;
  }

  /* -------------------------------------------------------------------------- */
  /*                           PUSHER BINDINGS                                   */
  /* -------------------------------------------------------------------------- */

  Future<void> _bindGlobalEventsIfNeeded() async {
    if (_globalEventsBound) return;

    await _ensureUserUuidLoaded();
    final userUuid = getCurrentUserUuidSync();
    if (userUuid.isEmpty) {
      debugPrint('⚠️ Cannot bind global events: No user UUID');
      return;
    }

    // Check Pusher first
    if (!_pusher.isInitialized) {
      debugPrint('⏭️ Skipping global events binding - Pusher not available');
      return;
    }

    _globalEventsBound = true;

    // Use the user.{uuid} channel that matches your Laravel definition
    final userChannel =
        'private-conversations.$userUuid'; // <-- This now matches user.{uuid} in channels.php
    debugPrint('🔗 Binding to user channel with UUID: $userChannel');

    try {
      await _ensurePusherConnected();
      // Use subscribe (not subscribePrivate) for regular user channel
      await _pusher.subscribe(userChannel);

      _pusher.bind(userChannel, 'conversation.updated', (data) {
        debugPrint('🔄 Conversation updated event: $data');
        _conversationUpdateStreamCtrl.add(_normalizeData(data));
      });

      debugPrint('✅ Global events bound successfully');
    } catch (e) {
      debugPrint('❌ Error binding global events: $e');
      _globalEventsBound = false;
    }
  }

  Future<void> _bindConversationInternal(String conversationUuid) async {
    final channel = 'private-conversations.$conversationUuid';
    debugPrint('🔗 Binding to conversation channel: $channel');

    try {
      await _ensurePusherConnected();
      await _pusher.subscribePrivate(channel);

      // Bind to message.sent event
      // In ChatRepositoryImpl, modify the Pusher binding:
      _pusher.bind(channel, 'message.sent', (data) async {
        debugPrint('📨 Received message.sent event');

        final map = _normalizeData(data);
        final payload = map['message'] ?? map;

        try {
          final message = Message.fromJson(payload);

          // Get current user UUID
          await _ensureUserUuidLoaded();
          final currentUserUuid = getCurrentUserUuidSync();

          // Skip if this message is from current user
          if (message.sender?.uuid == currentUserUuid) {
            debugPrint('👤 Skipping own message from Pusher: ${message.uuid}');
            return;
          }

          debugPrint('👤 Message from other user: ${message.sender?.uuid}');
          _messageStreamCtrl.add(message);
        } catch (e) {
          debugPrint('❌ Error parsing message: $e');
        }
      });

      // Bind to typing.started event
      _pusher.bind(channel, 'typing.started', (data) {
        debugPrint('⌨️ Received typing.started event: $data');
        final map = _normalizeData(data);
        final uuid = map['user_uuid'];
        if (uuid is String) {
          _typingStartedStreamCtrl.add(uuid);
        }
      });

      // Bind to conversation.read event
      _pusher.bind(channel, 'conversation.read', (data) {
        debugPrint('👁️ Received conversation.read event: $data');
        final map = _normalizeData(data);
        final readerUuid = map['user_uuid'];
        if (readerUuid is String) {
          _conversationReadStreamCtrl.add(readerUuid);
        }
      });

      debugPrint('✅ Successfully bound to conversation: $conversationUuid');
    } catch (e) {
      debugPrint('❌ Error binding to conversation $conversationUuid: $e');
      rethrow;
    }
  }

  @override
  void bindConversationEvents(String conversationUuid) async {
    if (_boundConversations.contains(conversationUuid)) {
      debugPrint('ℹ️ Already bound to conversation: $conversationUuid');
      return;
    }

    await _ensureUserUuidLoaded();

    // Quick check - if Pusher isn't initialized, skip binding
    if (!_pusher.isInitialized) {
      debugPrint('⏭️ Skipping conversation binding - Pusher not available');
      debugPrint('ℹ️ Chat will work without real-time updates');
      return;
    }

    debugPrint('🎯 Binding to conversation: $conversationUuid');
    _boundConversations.add(conversationUuid);

    try {
      await _bindConversationInternal(conversationUuid);
    } catch (e) {
      _boundConversations.remove(conversationUuid);
      debugPrint('❌ Failed to bind conversation events: $e');
      // Don't rethrow - continue without real-time
    }
  }

  @override
  Future<bool> isReady() async {
    try {
      await _ensureUserUuidLoaded();
      await _ensureAuthTokenLoaded();

      if (!_pusher.isInitialized) {
        debugPrint('⚠️ ChatRepository not ready: Pusher not initialized');
        return false;
      }

      if (getCurrentUserUuidSync().isEmpty) {
        debugPrint('⚠️ ChatRepository not ready: No user UUID');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('❌ ChatRepository readiness check failed: $e');
      return false;
    }
  }

  @override
  Future<void> unbindConversationEvents(String conversationUuid) async {
    if (!_boundConversations.contains(conversationUuid)) return;

    debugPrint('👋 Unbinding from conversation: $conversationUuid');
    final channel = 'private-conversations.$conversationUuid';

    try {
      await _pusher.unsubscribe(channel);
      _pusher.clearChannelHandlers(channel);
      _boundConversations.remove(conversationUuid);
      debugPrint('✅ Successfully unbound from conversation: $conversationUuid');
    } catch (e) {
      debugPrint('❌ Error unbinding conversation: $e');
    }
  }

  /* -------------------------------------------------------------------------- */
  /*                                UTIL METHODS                                 */
  /* -------------------------------------------------------------------------- */

  Map<String, dynamic> _normalizeData(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.cast<String, dynamic>();
    if (raw is String) {
      try {
        return json.decode(raw) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('❌ Error normalizing string data: $e');
      }
    }
    return {};
  }

  /* -------------------------------------------------------------------------- */
  /*                                DEBUG METHODS                                */
  /* -------------------------------------------------------------------------- */

  void debugPusherState() {
    debugPrint('🔍 ChatRepository Debug:');
    debugPrint('   User UUID: $_cachedUserUuid');
    debugPrint('   Bound conversations: ${_boundConversations.toList()}');
    debugPrint('   Global events bound: $_globalEventsBound');
    _pusher.debugSubscriptions();
  }

  /* -------------------------------------------------------------------------- */
  /*                                CLEANUP                                      */
  /* -------------------------------------------------------------------------- */

  @override
  Future<void> dispose() async {
    debugPrint('🧹 Cleaning up ChatRepository...');

    for (final c in _boundConversations.toList()) {
      await unbindConversationEvents(c);
    }

    await _messageStreamCtrl.close();
    await _typingStartedStreamCtrl.close();
    await _conversationUpdateStreamCtrl.close();
    await _conversationReadStreamCtrl.close();

    _boundConversations.clear();
    _globalEventsBound = false;
    _cachedUserUuid = null;
    _cachedAuthToken = null;

    debugPrint('✅ ChatRepository disposed');
  }
}
