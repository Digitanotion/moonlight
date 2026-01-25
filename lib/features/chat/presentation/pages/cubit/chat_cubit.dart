import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/services/current_user_service.dart';
import 'package:moonlight/features/chat/data/models/chat_conversations.dart';
import 'package:moonlight/features/chat/data/models/chat_models.dart';
import 'package:moonlight/features/chat/domain/entities/chat_paginated.dart';
import 'package:moonlight/features/chat/domain/repositories/chat_repository.dart';
import 'package:moonlight/features/chat/presentation/widgets/upload_progress.dart';
import 'package:moonlight/features/chat/presentation/widgets/upload_progress_widget.dart'
    hide UploadStatus;

part 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  final ChatRepository _repository;

  StreamSubscription<Message>? _messageSubscription;
  StreamSubscription<String>? _typingSubscription;

  String? _currentConversationUuid;
  final Map<String, UploadProgress> _currentUploads = {};

  // Pagination
  int _currentPage = 1;
  int _lastPage = 1;
  bool _hasMoreMessages = true;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  final CurrentUserService? _currentUserService;
  final List<Message> _allMessages = [];
  final Set<String> _loadedPageMessages = <String>{};

  ChatCubit(this._repository, [this._currentUserService])
    : super(ChatInitial());

  /* -------------------------------------------------------------------------- */
  /*                               CONVERSATIONS                                 */
  /* -------------------------------------------------------------------------- */

  Future<void> loadConversations() async {
    emit(ChatLoading());
    try {
      final conversations = await _repository.getConversations();
      emit(ChatConversationsLoaded(conversations));
    } catch (e) {
      emit(ChatError(e.toString(), null));
    }
  }

  Future<void> startDirectConversation(String userUuid) async {
    emit(ChatLoading());
    try {
      final conversation = await _repository.startDirectConversation(userUuid);
      emit(ChatDirectConversationStarted(conversation));
    } catch (e) {
      emit(ChatError(e.toString(), null));
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
      emit(ChatError(e.toString(), null));
    }
  }

  /* -------------------------------------------------------------------------- */
  /*                                   MESSAGES                                  */
  /* -------------------------------------------------------------------------- */

  Future<void> loadMessages(
    String conversationUuid, {
    bool loadMore = false,
  }) async {
    // Prevent duplicate calls
    if (_isLoading) return;

    if (!loadMore) {
      clearConversation();
      _currentConversationUuid = conversationUuid;
      _currentPage = 1;
      _hasMoreMessages = true;
      _allMessages.clear();
      _loadedPageMessages.clear();
      _isLoading = true;

      emit(ChatMessagesLoading());
    } else {
      // Prevent loading more while already loading
      if (_isLoading || !_hasMoreMessages) return;
      _isLoading = true;
      _isLoadingMore = true;

      emit(
        ChatMessagesLoadingMore(
          messages: List.from(_allMessages),
          hasMore: _hasMoreMessages,
          conversationUuid: conversationUuid,
        ),
      );
    }

    try {
      debugPrint(
        '📄 Loading messages page $_currentPage for $conversationUuid',
      );

      final result = await _repository.getMessages(
        conversationUuid,
        page: _currentPage,
        perPage: 30,
      );

      // Store last page for future reference
      _lastPage = result.lastPage;

      // Filter out already loaded messages
      final newMessages = result.data.where((message) {
        final messageKey = '${message.uuid}_page_$_currentPage';
        return !_loadedPageMessages.contains(messageKey);
      }).toList();

      // Track loaded messages
      for (final message in newMessages) {
        _loadedPageMessages.add('${message.uuid}_page_$_currentPage');
      }

      if (!loadMore) {
        // Initial load - start from the last page to get newest messages
        _currentPage = _lastPage;

        if (_lastPage > 1) {
          // Get the last page (newest messages)
          final lastPageResult = await _repository.getMessages(
            conversationUuid,
            page: _lastPage,
            perPage: 30,
          );

          // Track messages from last page
          for (final message in lastPageResult.data) {
            _loadedPageMessages.add('${message.uuid}_page_$_lastPage');
          }

          _allMessages.addAll(lastPageResult.data);

          // Set up for loading older messages
          _currentPage = _lastPage - 1;
          _hasMoreMessages = _currentPage >= 1;
        } else {
          // Only one page, just add it
          _allMessages.addAll(newMessages);
          _hasMoreMessages = false;
        }
      } else {
        // Loading more (older messages)
        // Add to the beginning since these are older messages
        _allMessages.insertAll(0, newMessages);

        // Move to next older page
        _currentPage--;
        _hasMoreMessages = _currentPage >= 1;
      }

      // Remove duplicates by UUID
      final uniqueMessages = _removeDuplicates(_allMessages);
      _allMessages.clear();
      _allMessages.addAll(uniqueMessages);

      // Sort by creation date (oldest to newest)
      _allMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      debugPrint('📊 Total messages after loading: ${_allMessages.length}');
      debugPrint('📊 Has more messages: $_hasMoreMessages');
      debugPrint('📊 Current page: $_currentPage');

      emit(
        ChatMessagesLoaded(
          messages: List.from(_allMessages),
          hasMore: _hasMoreMessages,
          conversationUuid: conversationUuid,
        ),
      );

      if (!loadMore) {
        _setupRealTimeListeners(conversationUuid);
        markAsRead(conversationUuid);
      }
    } catch (e) {
      debugPrint('❌ Error loading messages: $e');
      emit(ChatError(e.toString(), _currentConversationUuid));
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
    }
  }

  Future<void> loadMoreMessages() async {
    if (!_hasMoreMessages || _currentConversationUuid == null || _isLoading) {
      return;
    }

    await loadMessages(_currentConversationUuid!, loadMore: true);
  }

  List<Message> _removeDuplicates(List<Message> messages) {
    final seenUuids = <String>{};
    final uniqueMessages = <Message>[];

    for (final message in messages) {
      if (!seenUuids.contains(message.uuid)) {
        uniqueMessages.add(message);
        seenUuids.add(message.uuid);
      }
    }

    return uniqueMessages;
  }

  Future<void> sendMediaMessage({
    required String conversationUuid,
    required File file,
    String? body,
    String? replyToUuid,
  }) async {
    final fileId =
        '${DateTime.now().millisecondsSinceEpoch}_${file.path.hashCode}';
    final fileName = file.path.split('/').last;
    final fileType = _getFileType(file);

    // Create progress controllers
    final progressController = StreamController<double>();
    final statusController = StreamController<UploadStatus>();

    // Add to current uploads
    _currentUploads[fileId] = UploadProgress(
      fileId: fileId,
      fileName: fileName,
      fileType: fileType,
      progressController: progressController,
      statusController: statusController,
    );

    // Emit uploading state
    emit(
      ChatUploadingMedia(
        messages: _getCurrentMessages(),
        conversationUuid: conversationUuid,
        uploads: Map.from(_currentUploads),
      ),
    );

    try {
      // Update status to preparing
      statusController.add(UploadStatus.preparing);

      // 1. Upload file to your backend with progress tracking
      final message = await _repository.sendMediaMessage(
        conversationUuid,
        file: file,
        body: body,
        replyToUuid: replyToUuid,
        // If your repository supports progress callbacks, use them
        onSendProgress: (sent, total) {
          if (total > 0) {
            final progress = sent / total;
            progressController.add(progress);

            // Update progress in the map
            if (_currentUploads.containsKey(fileId)) {
              _currentUploads[fileId] = _currentUploads[fileId]!.copyWith(
                progress: progress,
                status: UploadStatus.uploading,
              );

              // Emit updated state
              emit(
                ChatUploadingMedia(
                  messages: _getCurrentMessages(),
                  conversationUuid: conversationUuid,
                  uploads: Map.from(_currentUploads),
                ),
              );
            }
          }
        },
      );

      // 2. Update status to success
      statusController.add(UploadStatus.success);

      // 3. Add the message to local list
      _allMessages.add(message);

      // 4. Sort messages by creation date
      _allMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // 5. Clean up upload progress
      await Future.delayed(
        const Duration(milliseconds: 500),
      ); // Show success briefly
      _currentUploads.remove(fileId);
      await progressController.close();
      await statusController.close();

      // 6. Emit success state with the new message
      emit(
        ChatMessageSent(
          messages: List.from(_allMessages),
          conversationUuid: conversationUuid,
        ),
      );
    } catch (e) {
      debugPrint('❌ Error uploading media: $e');

      // Update status to failed
      statusController.add(UploadStatus.failed);

      // Keep in uploads for retry
      if (_currentUploads.containsKey(fileId)) {
        _currentUploads[fileId] = _currentUploads[fileId]!.copyWith(
          status: UploadStatus.failed,
        );
      }

      // Emit failed state
      emit(
        ChatUploadingMedia(
          messages: _getCurrentMessages(),
          conversationUuid: conversationUuid,
          uploads: Map.from(_currentUploads),
        ),
      );

      // Re-throw error to be caught by UI
      rethrow;
    }
  }

  List<Message> _getCurrentMessages() {
    if (state is ChatMessagesLoaded) {
      return (state as ChatMessagesLoaded).messages;
    } else if (state is ChatMessagesLoadingMore) {
      return (state as ChatMessagesLoadingMore).messages;
    } else if (state is ChatMessageSent) {
      return (state as ChatMessageSent).messages;
    } else if (state is ChatMessageReceived) {
      return (state as ChatMessageReceived).messages;
    } else if (state is ChatMessageUpdated) {
      return (state as ChatMessageUpdated).messages;
    } else if (state is ChatMessageDeleted) {
      return (state as ChatMessageDeleted).messages;
    } else if (state is ChatUploadingMedia) {
      return (state as ChatUploadingMedia).messages;
    }
    return [];
  }

  void retryUpload(String fileId) {
    final upload = _currentUploads[fileId];
    if (upload != null && upload.status == UploadStatus.failed) {
      // Reset progress and status
      upload.progressController?.add(0.0);
      upload.statusController?.add(UploadStatus.preparing);

      // Retry logic...
    }
  }

  void cancelUpload(String fileId) {
    final upload = _currentUploads[fileId];
    if (upload != null) {
      upload.statusController?.add(UploadStatus.cancelled);
      upload.progressController?.close();
      upload.statusController?.close();
      _currentUploads.remove(fileId);
    }
  }

  String _getFileType(File file) {
    final path = file.path.toLowerCase();
    if (path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.gif')) {
      return 'Image';
    } else if (path.endsWith('.mp4') ||
        path.endsWith('.mov') ||
        path.endsWith('.avi')) {
      return 'Video';
    } else if (path.endsWith('.pdf')) {
      return 'PDF Document';
    } else if (path.endsWith('.mp3') || path.endsWith('.wav')) {
      return 'Audio';
    } else {
      return 'File';
    }
  }

  // In ChatCubit - sendTextMessage method should already have replyToUuid
  Future<void> sendTextMessage({
    required String conversationUuid,
    required String body,
    String? replyToUuid,
  }) async {
    try {
      final message = await _repository.sendTextMessage(
        conversationUuid,
        body: body,
        replyToUuid: replyToUuid, // Make sure this is passed
      );

      _allMessages.add(message);

      emit(
        ChatMessageSent(
          messages: List.from(_allMessages),
          conversationUuid: conversationUuid,
        ),
      );
    } catch (e) {
      emit(ChatError(e.toString(), _currentConversationUuid));
    }
  }

  // Future<void> sendMediaMessage({
  //   required String conversationUuid,
  //   required File file,
  //   String? body,
  //   String? replyToUuid,
  // }) async {
  //   emit(ChatUploadingMedia());

  //   try {
  //     final message = await _repository.sendMediaMessage(
  //       conversationUuid,
  //       file: file,
  //       body: body,
  //       replyToUuid: replyToUuid,
  //     );

  //     _allMessages.add(message);

  //     emit(
  //       ChatMessageSent(
  //         messages: List.from(_allMessages),
  //         conversationUuid: conversationUuid,
  //       ),
  //     );
  //   } catch (e) {
  //     emit(ChatError(e.toString(), _currentConversationUuid));
  //   }
  // }

  Future<void> editMessage({
    required String messageUuid,
    required String newBody,
  }) async {
    try {
      final updated = await _repository.editMessage(messageUuid, newBody);
      final index = _allMessages.indexWhere((m) => m.uuid == messageUuid);

      if (index != -1) {
        _allMessages[index] = updated;
        emit(
          ChatMessageUpdated(
            messages: List.from(_allMessages),
            conversationUuid: _currentConversationUuid!,
          ),
        );
      }
    } catch (e) {
      emit(ChatError(e.toString(), _currentConversationUuid));
    }
  }

  Future<void> deleteMessage(String messageUuid) async {
    try {
      await _repository.deleteMessage(messageUuid);
      _allMessages.removeWhere((m) => m.uuid == messageUuid);

      emit(
        ChatMessageDeleted(
          messages: List.from(_allMessages),
          conversationUuid: _currentConversationUuid!,
        ),
      );
    } catch (e) {
      emit(ChatError(e.toString(), _currentConversationUuid));
    }
  }

  Future<void> reactToMessage({
    required String messageUuid,
    required String emoji,
  }) async {
    try {
      await _repository.reactToMessage(messageUuid, emoji);
    } catch (e) {
      emit(ChatError(e.toString(), _currentConversationUuid));
    }
  }

  /* -------------------------------------------------------------------------- */
  /*                              TYPING INDICATOR                               */
  /* -------------------------------------------------------------------------- */

  Future<void> sendTypingIndicator() async {
    if (_currentConversationUuid == null) return;
    try {
      await _repository.sendTypingIndicator(_currentConversationUuid!);
    } catch (_) {}
  }

  /* -------------------------------------------------------------------------- */
  /*                         CONVERSATION STATE ACTIONS                          */
  /* -------------------------------------------------------------------------- */

  Future<void> markAsRead(String conversationUuid) async {
    try {
      await _repository.markConversationAsRead(conversationUuid);
    } catch (_) {}
  }

  Future<void> pinConversation(String conversationUuid) async {
    try {
      await _repository.pinConversation(conversationUuid);
    } catch (e) {
      emit(ChatError(e.toString(), _currentConversationUuid));
    }
  }

  Future<void> muteConversation(String conversationUuid) async {
    try {
      await _repository.muteConversation(conversationUuid);
    } catch (e) {
      emit(ChatError(e.toString(), _currentConversationUuid));
    }
  }

  Future<void> archiveConversation(String conversationUuid) async {
    try {
      await _repository.archiveConversation(conversationUuid);
    } catch (e) {
      emit(ChatError(e.toString(), _currentConversationUuid));
    }
  }

  /* -------------------------------------------------------------------------- */
  /*                                  REALTIME                                   */
  /* -------------------------------------------------------------------------- */

  void _setupRealTimeListeners(String conversationUuid) {
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();

    try {
      _repository.bindConversationEvents(conversationUuid);
    } catch (e) {
      debugPrint('❌ Error binding conversation events: $e');
      return;
    }

    _messageSubscription = _repository.messageStream().listen(
      (message) {
        if (_currentConversationUuid != conversationUuid) return;
        if (_allMessages.any((m) => m.uuid == message.uuid)) return;

        _allMessages.add(message);

        // Check if message is from current user
        final isFromCurrentUser = _isMessageFromCurrentUser(message);

        emit(
          ChatMessageReceived(
            messages: List.from(_allMessages),
            conversationUuid: conversationUuid,
            isFromCurrentUser: isFromCurrentUser,
          ),
        );
      },
      onError: (e) {
        debugPrint('❌ Error in message stream: $e');
      },
    );

    _typingSubscription = _repository.typingStartedStream().listen(
      (userUuid) {
        emit(ChatTypingStarted(userUuid: userUuid));

        Future.delayed(const Duration(seconds: 3), () {
          if (state is ChatTypingStarted &&
              (state as ChatTypingStarted).userUuid == userUuid) {
            emit(ChatTypingStopped());
          }
        });
      },
      onError: (e) {
        debugPrint('❌ Error in typing stream: $e');
      },
    );
  }

  bool _isMessageFromCurrentUser(Message message) {
    try {
      final currentUserUuid = _currentUserService?.currentUser?.id;
      return message.sender?.uuid == currentUserUuid;
    } catch (e) {
      debugPrint('Error checking message sender: $e');
      return false;
    }
  }

  /* -------------------------------------------------------------------------- */
  /*                                   CLEANUP                                   */
  /* -------------------------------------------------------------------------- */

  void clearConversation() {
    final uuid = _currentConversationUuid;

    _currentConversationUuid = null;
    _allMessages.clear();
    _loadedPageMessages.clear();

    _messageSubscription?.cancel();
    _typingSubscription?.cancel();

    if (uuid != null) {
      _repository.unbindConversationEvents(uuid);
    }

    emit(ChatInitial());
  }

  @override
  Future<void> close() {
    clearConversation();
    return super.close();
  }
}
