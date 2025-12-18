import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/services/pusher_service.dart';
import 'package:moonlight/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:moonlight/features/chat/data/models/chat_models.dart';
import 'package:moonlight/features/chat/data/services/chat_api_service.dart';
import 'package:moonlight/features/chat/domain/entities/chat_paginated.dart';
import 'package:moonlight/features/chat/domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  final DioClient _client;
  final PusherService _pusher;
  final ChatApiService _apiService;
  final AuthLocalDataSource _authLocalDataSource;

  // Stream controllers for real-time events
  final _messageStreamCtrl = StreamController<Message>.broadcast();
  final _conversationUpdateStreamCtrl =
      StreamController<Map<String, dynamic>>.broadcast();
  final _typingStartedStreamCtrl = StreamController<String>.broadcast();
  final _conversationReadStreamCtrl = StreamController<String>.broadcast();

  // Track bound conversation channels
  final Set<String> _boundConversations = {};
  bool _globalEventsBound = false;

  ChatRepositoryImpl(this._client, this._pusher, this._authLocalDataSource)
    : _apiService = ChatApiService(_client);

  // ========== CONVERSATIONS ==========

  @override
  Future<List<Conversation>> getConversations() async {
    try {
      return await _apiService.getConversations();
    } catch (e) {
      _handleError('getConversations', e);
      rethrow;
    }
  }

  @override
  Future<Conversation> startDirectConversation(String userUuid) async {
    try {
      return await _apiService.startDirectConversation(userUuid);
    } catch (e) {
      _handleError('startDirectConversation', e);
      rethrow;
    }
  }

  @override
  Future<Conversation> getClubConversation(String clubSlugOrUuid) async {
    try {
      return await _apiService.getClubConversation(clubSlugOrUuid);
    } catch (e) {
      _handleError('getClubConversation', e);
      rethrow;
    }
  }

  @override
  Future<List<Conversation>> searchConversations(String query) async {
    try {
      return await _apiService.searchConversations(query);
    } catch (e) {
      _handleError('searchConversations', e);
      rethrow;
    }
  }

  // ========== MESSAGES ==========

  @override
  Future<PaginatedMessages> getMessages(
    String conversationUuid, {
    int page = 1,
    int perPage = 50,
  }) async {
    try {
      return await _apiService.getMessages(
        conversationUuid,
        page: page,
        perPage: perPage,
      );
    } catch (e) {
      _handleError('getMessages', e);
      rethrow;
    }
  }

  @override
  Future<Message> sendTextMessage(
    String conversationUuid, {
    required String body,
    String? replyToUuid,
  }) async {
    try {
      return await _apiService.sendTextMessage(
        conversationUuid,
        body: body,
        replyToUuid: replyToUuid,
      );
    } catch (e) {
      _handleError('sendTextMessage', e);
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
      return await _apiService.sendMediaMessage(
        conversationUuid,
        file: file,
        body: body,
        replyToUuid: replyToUuid,
      );
    } catch (e) {
      _handleError('sendMediaMessage', e);
      rethrow;
    }
  }

  @override
  Future<Message> editMessage(String messageUuid, String newBody) async {
    try {
      return await _apiService.editMessage(messageUuid, newBody);
    } catch (e) {
      _handleError('editMessage', e);
      rethrow;
    }
  }

  @override
  Future<void> deleteMessage(String messageUuid) async {
    try {
      await _apiService.deleteMessage(messageUuid);
    } catch (e) {
      _handleError('deleteMessage', e);
      rethrow;
    }
  }

  @override
  Future<void> reactToMessage(String messageUuid, String emoji) async {
    try {
      await _apiService.reactToMessage(messageUuid, emoji);
    } catch (e) {
      _handleError('reactToMessage', e);
      rethrow;
    }
  }

  @override
  Future<void> markConversationAsRead(String conversationUuid) async {
    try {
      await _apiService.markConversationAsRead(conversationUuid);
    } catch (e) {
      _handleError('markConversationAsRead', e);
      rethrow;
    }
  }

  @override
  Future<SearchMessagesResult> searchMessages(
    String conversationUuid,
    String query, {
    int page = 1,
  }) async {
    try {
      return await _apiService.searchMessages(
        conversationUuid,
        query,
        page: page,
      );
    } catch (e) {
      _handleError('searchMessages', e);
      rethrow;
    }
  }

  // ========== TYPING ==========

  @override
  Future<void> sendTypingIndicator(String conversationUuid) async {
    try {
      await _apiService.sendTypingIndicator(conversationUuid);
    } catch (e) {
      _handleError('sendTypingIndicator', e);
      rethrow;
    }
  }

  // ========== CONVERSATION STATE ==========

  @override
  Future<void> pinConversation(String conversationUuid) async {
    try {
      await _apiService.pinConversation(conversationUuid);
    } catch (e) {
      _handleError('pinConversation', e);
      rethrow;
    }
  }

  @override
  Future<void> muteConversation(String conversationUuid) async {
    try {
      await _apiService.muteConversation(conversationUuid);
    } catch (e) {
      _handleError('muteConversation', e);
      rethrow;
    }
  }

  @override
  Future<void> archiveConversation(String conversationUuid) async {
    try {
      await _apiService.archiveConversation(conversationUuid);
    } catch (e) {
      _handleError('archiveConversation', e);
      rethrow;
    }
  }

  // ========== UNREAD COUNTS ==========

  @override
  Future<Map<String, dynamic>> getUnreadCounts() async {
    try {
      return await _apiService.getUnreadCounts();
    } catch (e) {
      _handleError('getUnreadCounts', e);
      rethrow;
    }
  }

  // ========== REAL-TIME STREAMS ==========

  @override
  Stream<Message> messageStream() {
    _bindGlobalEventsIfNeeded();
    return _messageStreamCtrl.stream;
  }

  @override
  Stream<Map<String, dynamic>> conversationUpdateStream() {
    _bindGlobalEventsIfNeeded();
    return _conversationUpdateStreamCtrl.stream;
  }

  @override
  Stream<String> typingStartedStream() {
    _bindGlobalEventsIfNeeded();
    return _typingStartedStreamCtrl.stream;
  }

  @override
  Stream<String> conversationReadStream() {
    _bindGlobalEventsIfNeeded();
    return _conversationReadStreamCtrl.stream;
  }

  // ========== PUSHER EVENT BINDING ==========

  void _bindGlobalEventsIfNeeded() {
    if (_globalEventsBound) return;
    _globalEventsBound = true;

    final currentUserUuid = _getCurrentUserUuid();
    if (currentUserUuid.isEmpty) return;

    final userChannel = 'user.$currentUserUuid';
    _pusher.subscribe(userChannel);

    // Bind conversation updates
    _pusher.bind(userChannel, 'conversation.updated', (data) {
      final normalizedData = _normalizeData(data);
      _conversationUpdateStreamCtrl.add(normalizedData);
    });
  }

  @override
  void bindConversationEvents(String conversationUuid) {
    if (_boundConversations.contains(conversationUuid)) return;
    _boundConversations.add(conversationUuid);

    final channel = 'conversation.$conversationUuid';
    _pusher.subscribe(channel);

    _bindMessageEvents(channel);
    _bindTypingEvents(channel);
    _bindConversationReadEvents(channel);
  }

  void _bindMessageEvents(String channel) {
    // message.sent
    _pusher.bind(channel, 'message.sent', (data) {
      final normalized = _normalizeData(data);
      try {
        final messageData =
            normalized['message'] as Map<String, dynamic>? ?? normalized;
        final message = Message.fromJson(messageData);
        _messageStreamCtrl.add(message);
      } catch (e) {
        print('Error parsing message.sent: $e');
      }
    });

    // message.updated
    _pusher.bind(channel, 'message.updated', (data) {
      final normalized = _normalizeData(data);
      try {
        final messageData =
            normalized['message'] as Map<String, dynamic>? ?? normalized;
        final message = Message.fromJson(messageData);
        _messageStreamCtrl.add(message);
      } catch (e) {
        print('Error parsing message.updated: $e');
      }
    });

    // message.deleted
    _pusher.bind(channel, 'message.deleted', (data) {
      final normalized = _normalizeData(data);
      try {
        final messageUuid = normalized['message_uuid'] as String? ?? '';
        if (messageUuid.isNotEmpty) {
          final deletedMessage = Message(
            uuid: messageUuid,
            body: 'This message was deleted',
            type: MessageType.text,
            sender: ChatUser(
              uuid: '',
              userSlug: '',
              fullName: 'System',
              avatarUrl: null,
            ),
            media: [],
            reactions: [],
            isEdited: false,
            createdAt: DateTime.now(),
          );
          _messageStreamCtrl.add(deletedMessage);
        }
      } catch (e) {
        print('Error handling message.deleted: $e');
      }
    });
  }

  void _bindTypingEvents(String channel) {
    // typing.started
    _pusher.bind(channel, 'typing.started', (data) {
      final normalized = _normalizeData(data);
      final userUuid = normalized['user_uuid'] as String? ?? '';
      if (userUuid.isNotEmpty) {
        _typingStartedStreamCtrl.add(userUuid);
      }
    });
  }

  void _bindConversationReadEvents(String channel) {
    // conversation.read
    _pusher.bind(channel, 'conversation.read', (data) {
      final normalized = _normalizeData(data);
      final userUuid = normalized['user_uuid'] as String? ?? '';
      if (userUuid.isNotEmpty) {
        _conversationReadStreamCtrl.add(userUuid);
      }
    });
  }

  @override
  Future<void> unbindConversationEvents(String conversationUuid) async {
    if (!_boundConversations.contains(conversationUuid)) return;

    final channel = 'conversation.$conversationUuid';

    // Just unsubscribe and clear handlers
    await _pusher.unsubscribe(channel);

    _boundConversations.remove(conversationUuid);
  }

  // ========== UTILITY METHODS ==========

  Map<String, dynamic> _normalizeData(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.cast<String, dynamic>();
    return {};
  }

  String _getCurrentUserUuid() {
    try {
      // First try to get from AuthLocalDataSource
      final userUuid = _authLocalDataSource.getCurrentUserUuid();
      return userUuid.toString();
    } catch (e) {
      print('Error getting current user UUID: $e');
      return '';
    }
  }

  void _handleError(String method, dynamic error) {
    print('ChatRepositoryImpl.$method error: $error');
    // Add your existing error handling logic here
  }

  // ========== LIFECYCLE ==========

  @override
  Future<void> dispose() async {
    // Unbind all conversation events
    for (final conversationUuid in _boundConversations.toList()) {
      await unbindConversationEvents(conversationUuid);
    }
    _boundConversations.clear();

    // Close stream controllers
    await _messageStreamCtrl.close();
    await _conversationUpdateStreamCtrl.close();
    await _typingStartedStreamCtrl.close();
    await _conversationReadStreamCtrl.close();

    // Unbind global events
    final currentUserUuid = _getCurrentUserUuid();
    if (currentUserUuid.isNotEmpty) {
      final userChannel = 'user.$currentUserUuid';
      await _pusher.unsubscribe(userChannel);
    }

    _globalEventsBound = false;
  }
}
