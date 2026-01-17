import 'dart:io';
import 'package:dio/dio.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/features/chat/data/models/chat_conversations.dart';
import 'package:moonlight/features/chat/data/models/chat_models.dart';
import 'package:moonlight/features/chat/domain/entities/chat_paginated.dart';

class ChatApiService {
  final DioClient _dioClient;

  ChatApiService(this._dioClient);

  // ========== CONVERSATIONS ==========

  Future<List<ChatConversations>> getConversations() async {
    final response = await _dioClient.dio.get('/api/v1/chat/conversations');
    final data = (response.data as Map)['data'] as List;
    return data
        .map(
          (json) => ChatConversations.fromJson(
            Map<String, dynamic>.from(json as Map),
          ),
        )
        .toList();
  }

  Future<Conversation> startDirectConversation(String userUuid) async {
    final response = await _dioClient.dio.post(
      '/api/v1/chat/direct',
      data: {'user_uuid': userUuid},
    );
    final data = (response.data as Map)['data'] as Map<String, dynamic>;
    return Conversation.fromJson(data);
  }

  Future<Conversation> getClubConversation(String clubSlugOrUuid) async {
    final response = await _dioClient.dio.post(
      '/api/v1/chat/clubs/$clubSlugOrUuid/conversation',
    );
    final data = (response.data as Map)['data'] as Map<String, dynamic>;
    return Conversation.fromJson(data);
  }

  Future<List<Conversation>> searchConversations(String query) async {
    final response = await _dioClient.dio.get(
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
  }

  // ========== MESSAGES ==========

  Future<PaginatedMessages> getMessages(
    String conversationUuid, {
    int page = 1,
    int perPage = 50,
  }) async {
    final response = await _dioClient.dio.get(
      '/api/v1/chat/conversations/$conversationUuid/messages',
      queryParameters: {'page': page, 'per_page': perPage},
    );
    return PaginatedMessages.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Message> sendTextMessage(
    String conversationUuid, {
    required String body,
    String? replyToUuid,
  }) async {
    final data = {'body': body};
    if (replyToUuid != null) {
      data['reply_to_uuid'] = replyToUuid;
    }

    final response = await _dioClient.dio.post(
      '/api/v1/chat/conversations/$conversationUuid/messages',
      data: data,
    );
    final responseData = (response.data as Map)['data'] as Map<String, dynamic>;
    return Message.fromJson(responseData);
  }

  Future<Message> sendMediaMessage(
    String conversationUuid, {
    required File file,
    String? body,
    String? replyToUuid,
  }) async {
    final formData = FormData.fromMap({
      if (body != null && body.isNotEmpty) 'body': body,
      if (replyToUuid != null) 'reply_to_uuid': replyToUuid,
      'media[]': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
      ),
    });

    final response = await _dioClient.dio.post(
      '/api/v1/chat/conversations/$conversationUuid/messages',
      data: formData,
    );
    final responseData = (response.data as Map)['data'] as Map<String, dynamic>;
    return Message.fromJson(responseData);
  }

  Future<Message> editMessage(String messageUuid, String newBody) async {
    final response = await _dioClient.dio.patch(
      '/api/v1/chat/messages/$messageUuid',
      data: {'body': newBody},
    );
    final responseData = (response.data as Map)['data'] as Map<String, dynamic>;
    return Message.fromJson(responseData);
  }

  Future<void> deleteMessage(String messageUuid) async {
    await _dioClient.dio.delete('/api/v1/chat/messages/$messageUuid');
  }

  Future<void> reactToMessage(String messageUuid, String emoji) async {
    await _dioClient.dio.post(
      '/api/v1/chat/messages/$messageUuid/reactions',
      data: {'emoji': emoji},
    );
  }

  Future<void> markConversationAsRead(String conversationUuid) async {
    await _dioClient.dio.post(
      '/api/v1/chat/conversations/$conversationUuid/read',
    );
  }

  Future<SearchMessagesResult> searchMessages(
    String conversationUuid,
    String query, {
    int page = 1,
  }) async {
    final response = await _dioClient.dio.get(
      '/api/v1/chat/conversations/$conversationUuid/messages/search',
      queryParameters: {'q': query, 'page': page},
    );
    return SearchMessagesResult.fromJson(response.data as Map<String, dynamic>);
  }

  // ========== TYPING ==========

  Future<void> sendTypingIndicator(String conversationUuid) async {
    await _dioClient.dio.post(
      '/api/v1/chat/conversations/$conversationUuid/typing',
    );
  }

  // ========== CONVERSATION STATE ==========

  Future<void> pinConversation(String conversationUuid) async {
    await _dioClient.dio.post(
      '/api/v1/chat/conversations/$conversationUuid/pin',
    );
  }

  Future<void> muteConversation(String conversationUuid) async {
    await _dioClient.dio.post(
      '/api/v1/chat/conversations/$conversationUuid/mute',
    );
  }

  Future<void> archiveConversation(String conversationUuid) async {
    await _dioClient.dio.post(
      '/api/v1/chat/conversations/$conversationUuid/archive',
    );
  }

  // ========== UNREAD COUNTS ==========

  Future<Map<String, dynamic>> getUnreadCounts() async {
    final response = await _dioClient.dio.get('/api/v1/chat/unread-count');
    return response.data as Map<String, dynamic>;
  }
}
