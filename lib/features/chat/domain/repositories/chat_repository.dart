import 'dart:io';

import 'package:moonlight/features/chat/data/models/chat_conversations.dart';
import 'package:moonlight/features/chat/data/models/chat_models.dart';
import 'package:moonlight/features/chat/domain/entities/chat_paginated.dart';

abstract class ChatRepository {
  // ========== CONVERSATIONS ==========
  Future<List<ChatConversations>> getConversations();
  Future<ChatConversations> startDirectConversation(String userUuid);
  Future<Conversation> getClubConversation(String clubSlugOrUuid);
  Future<List<Conversation>> searchConversations(String query);

  // ========== MESSAGES ==========
  Future<ChatPaginated<Message>> getMessages(
    String conversationUuid, {
    int page,
    int perPage,
  });
  Future<Message> sendTextMessage(
    String conversationUuid, {
    required String body,
    String? replyToUuid,
  });
  Future<Message> sendMediaMessage(
    String conversationUuid, {
    required File file,
    String? body,
    String? replyToUuid,
    void Function(int sent, int total)? onSendProgress, // Add this
  });
  Future<Message> editMessage(String messageUuid, String newBody);
  Future<void> deleteMessage(String messageUuid);
  Future<void> reactToMessage(String messageUuid, String emoji);
  Future<void> markConversationAsRead(String conversationUuid);
  // Future<ChatPaginated<Message>> searchMessages(
  //   String conversationUuid,
  //   String query, {
  //   int page,
  // });

  // ========== TYPING ==========
  Future<void> sendTypingIndicator(String conversationUuid);

  // ========== CONVERSATION STATE ==========
  Future<void> pinConversation(String conversationUuid);
  Future<void> muteConversation(String conversationUuid);
  Future<void> archiveConversation(String conversationUuid);

  // ========== UNREAD COUNTS ==========
  Future<Map<String, dynamic>> getUnreadCounts();

  // ========== REAL-TIME STREAMS ==========
  // Following your ParticipantsRepository pattern
  Stream<Message> messageStream();
  Stream<Map<String, dynamic>> conversationUpdateStream();
  Stream<String> typingStartedStream();
  Stream<String> conversationReadStream();

  // ========== LIFECYCLE ==========
  void bindConversationEvents(String conversationUuid);
  void unbindConversationEvents(String conversationUuid);
  Future<void> dispose();
}
