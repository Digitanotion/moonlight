part of 'chat_cubit.dart';

@immutable
abstract class ChatState {
  const ChatState();
}

class ChatInitial extends ChatState {}

class ChatLoading extends ChatState {}

class ChatError extends ChatState {
  final String message;
  String? uuid;
  ChatError(this.message, this.uuid);
}

// Conversation states
class ChatConversationsLoaded extends ChatState {
  final List<ChatConversations> conversations;
  ChatConversationsLoaded(this.conversations);
}

class ChatDirectConversationStarted extends ChatState {
  final ChatConversations conversation;
  ChatDirectConversationStarted(this.conversation);
}

class ChatClubConversationLoaded extends ChatState {
  final Conversation conversation;
  ChatClubConversationLoaded(this.conversation);
}

// Message states
class ChatMessagesLoading extends ChatState {}

class ChatMessagesLoaded extends ChatState {
  final List<Message> messages;
  final bool hasMore;
  final String conversationUuid;

  ChatMessagesLoaded({
    required this.messages,
    required this.hasMore,
    required this.conversationUuid,
  });
}

// UPDATED: Add messages to loading more state
class ChatMessagesLoadingMore extends ChatState {
  final List<Message> messages;
  final bool hasMore;
  final String conversationUuid;

  ChatMessagesLoadingMore({
    required this.messages,
    required this.hasMore,
    required this.conversationUuid,
  });
}

class ChatUploadingMedia extends ChatState {}

class ChatMessageSent extends ChatState {
  final List<Message> messages;
  final String conversationUuid;

  ChatMessageSent({required this.messages, required this.conversationUuid});
}

class ChatMessageReceived extends ChatState {
  final List<Message> messages;
  final String conversationUuid;
  final bool isFromCurrentUser;

  ChatMessageReceived({
    required this.messages,
    required this.conversationUuid,
    this.isFromCurrentUser = false,
  });
}

class ChatMessageUpdated extends ChatState {
  final List<Message> messages;
  final String conversationUuid;

  ChatMessageUpdated({required this.messages, required this.conversationUuid});
}

class ChatMessageDeleted extends ChatState {
  final List<Message> messages;
  final String conversationUuid;

  ChatMessageDeleted({required this.messages, required this.conversationUuid});
}

// Real-time states
class ChatTypingStarted extends ChatState {
  final String userUuid;
  ChatTypingStarted({required this.userUuid});
}

class ChatTypingStopped extends ChatState {}
