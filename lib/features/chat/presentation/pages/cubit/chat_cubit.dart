import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/chat/data/models/chat_models.dart';
import 'package:moonlight/features/chat/domain/entities/chat_paginated.dart';
import 'package:moonlight/features/chat/domain/repositories/chat_repository.dart';

part 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  final ChatRepository _repository;
  StreamSubscription<Message>? _messageSubscription;
  StreamSubscription<String>? _typingSubscription;
  String? _currentConversationUuid;

  // Pagination tracking
  int _currentPage = 1;
  bool _hasMoreMessages = true;
  final List<Message> _allMessages = [];

  ChatCubit(this._repository) : super(ChatInitial());

  // ========== CONVERSATIONS ==========

  Future<void> loadConversations() async {
    emit(ChatLoading());
    try {
      final conversations = await _repository.getConversations();
      emit(ChatConversationsLoaded(conversations));
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> startDirectConversation(String userUuid) async {
    emit(ChatLoading());
    try {
      final conversation = await _repository.startDirectConversation(userUuid);
      emit(ChatDirectConversationStarted(conversation));
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> getClubConversation(String clubSlugOrUuid) async {
    emit(ChatLoading());
    try {
      final conversation = await _repository.getClubConversation(
        clubSlugOrUuid,
      );
      emit(ChatClubConversationLoaded(conversation));
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  // ========== MESSAGES ==========

  Future<void> loadMessages(
    String conversationUuid, {
    bool loadMore = false,
  }) async {
    if (!loadMore) {
      _currentConversationUuid = conversationUuid;
      _currentPage = 1;
      _hasMoreMessages = true;
      _allMessages.clear();
      emit(ChatMessagesLoading());
    }

    try {
      final result = await _repository.getMessages(
        conversationUuid,
        page: _currentPage,
        perPage: 50,
      );

      if (loadMore) {
        // Add to beginning for pagination (older messages)
        _allMessages.insertAll(0, result.data.reversed.toList());
      } else {
        // New load, set messages
        _allMessages.addAll(result.data.reversed.toList());
      }

      _hasMoreMessages = result.hasNextPage;

      emit(
        ChatMessagesLoaded(
          messages: List.from(_allMessages),
          hasMore: _hasMoreMessages,
          conversationUuid: conversationUuid,
        ),
      );

      // Setup real-time listeners for this conversation
      if (!loadMore) {
        _setupRealTimeListeners(conversationUuid);
      }
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> loadMoreMessages() async {
    if (!_hasMoreMessages || _currentConversationUuid == null) return;

    _currentPage++;
    await loadMessages(_currentConversationUuid!, loadMore: true);
  }

  Future<void> sendTextMessage({
    required String conversationUuid,
    required String body,
    String? replyToUuid,
  }) async {
    try {
      final message = await _repository.sendTextMessage(
        conversationUuid,
        body: body,
        replyToUuid: replyToUuid,
      );

      // Add to local list
      _allMessages.add(message);

      emit(
        ChatMessageSent(
          messages: List.from(_allMessages),
          conversationUuid: conversationUuid,
        ),
      );
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> sendMediaMessage({
    required String conversationUuid,
    required File file,
    String? body,
    String? replyToUuid,
  }) async {
    emit(ChatUploadingMedia());

    try {
      final message = await _repository.sendMediaMessage(
        conversationUuid,
        file: file,
        body: body,
        replyToUuid: replyToUuid,
      );

      // Add to local list
      _allMessages.add(message);

      emit(
        ChatMessageSent(
          messages: List.from(_allMessages),
          conversationUuid: conversationUuid,
        ),
      );
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> editMessage({
    required String messageUuid,
    required String newBody,
  }) async {
    try {
      final updatedMessage = await _repository.editMessage(
        messageUuid,
        newBody,
      );

      // Update in local list
      final index = _allMessages.indexWhere((m) => m.uuid == messageUuid);
      if (index != -1) {
        _allMessages[index] = updatedMessage;

        emit(
          ChatMessageUpdated(
            messages: List.from(_allMessages),
            conversationUuid: _currentConversationUuid!,
          ),
        );
      }
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> deleteMessage(String messageUuid) async {
    try {
      await _repository.deleteMessage(messageUuid);

      // Remove from local list
      _allMessages.removeWhere((m) => m.uuid == messageUuid);

      emit(
        ChatMessageDeleted(
          messages: List.from(_allMessages),
          conversationUuid: _currentConversationUuid!,
        ),
      );
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> reactToMessage({
    required String messageUuid,
    required String emoji,
  }) async {
    try {
      await _repository.reactToMessage(messageUuid, emoji);
      // Note: Real-time event will update the message via Pusher
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  // ========== TYPING ==========

  Future<void> sendTypingIndicator() async {
    if (_currentConversationUuid == null) return;

    try {
      await _repository.sendTypingIndicator(_currentConversationUuid!);
    } catch (e) {
      // Don't emit error for typing indicators
      print('Error sending typing indicator: $e');
    }
  }

  // ========== CONVERSATION STATE ==========

  Future<void> markAsRead(String conversationUuid) async {
    try {
      await _repository.markConversationAsRead(conversationUuid);
    } catch (e) {
      print('Error marking as read: $e');
    }
  }

  Future<void> pinConversation(String conversationUuid) async {
    try {
      await _repository.pinConversation(conversationUuid);
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> muteConversation(String conversationUuid) async {
    try {
      await _repository.muteConversation(conversationUuid);
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> archiveConversation(String conversationUuid) async {
    try {
      await _repository.archiveConversation(conversationUuid);
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  // ========== REAL-TIME ==========

  void _setupRealTimeListeners(String conversationUuid) {
    // Clean up previous listeners
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();

    // Bind to conversation events
    _repository.bindConversationEvents(conversationUuid);

    // Listen for new messages
    _messageSubscription = _repository.messageStream().listen((message) {
      // Add to local list
      _allMessages.add(message);

      emit(
        ChatMessageReceived(
          messages: List.from(_allMessages),
          conversationUuid: conversationUuid,
        ),
      );
    });

    // Listen for typing indicators
    _typingSubscription = _repository.typingStartedStream().listen((userUuid) {
      // Get current user UUID from your auth service
      final currentUserUuid = _getCurrentUserUuid();

      if (userUuid != currentUserUuid) {
        emit(ChatTypingStarted(userUuid: userUuid));

        // Auto-clear typing indicator after 3 seconds
        Future.delayed(Duration(seconds: 3), () {
          if (state is ChatTypingStarted &&
              (state as ChatTypingStarted).userUuid == userUuid) {
            emit(ChatTypingStopped());
          }
        });
      }
    });
  }

  String _getCurrentUserUuid() {
    // TODO: Implement using your CurrentUserService or AuthLocalDataSource
    return '';
  }

  // ========== CLEANUP ==========

  void clearConversation() {
    _currentConversationUuid = null;
    _allMessages.clear();
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    _repository.unbindConversationEvents(_currentConversationUuid ?? '');
    emit(ChatInitial());
  }

  @override
  Future<void> close() {
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    if (_currentConversationUuid != null) {
      _repository.unbindConversationEvents(_currentConversationUuid!);
    }
    return super.close();
  }
}
