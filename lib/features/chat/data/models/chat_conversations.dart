import 'package:equatable/equatable.dart';
import 'package:moonlight/features/chat/data/models/chat_models.dart';

class ChatConversations extends Equatable {
  final String uuid;
  final String type;
  final String title;
  final String? imageUrl;
  final bool isPinned;
  final int unreadCount;
  final Message? lastMessage;
  final int? memberCount;
  final DateTime? updatedAt;

  const ChatConversations({
    required this.uuid,
    required this.type,
    required this.title,
    this.imageUrl,
    required this.isPinned,
    required this.unreadCount,
    this.lastMessage,
    this.memberCount,
    this.updatedAt,
  });

  factory ChatConversations.fromJson(Map<String, dynamic> json) {
    return ChatConversations(
      uuid: json['uuid'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      imageUrl: json['image_url'] as String?, // Cast to nullable
      isPinned: json['is_pinned'] as bool? ?? false,
      unreadCount: json['unread_count'] as int? ?? 0,
      lastMessage: json['last_message'] != null
          ? Message.fromJson(
              Map<String, dynamic>.from(json['last_message'] as Map),
            )
          : null,
      memberCount: json['member_count'] as int?,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String).toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'uuid': uuid,
    'type': type,
    'title': title,
    'image_url': imageUrl,
    'is_pinned': isPinned,
    'unread_count': unreadCount,
    'last_message': lastMessage?.toJson(),
    'member_count': memberCount,
    'updated_at': updatedAt?.toUtc().toIso8601String(),
  };

  bool get isGroup => type == 'club';
  bool get isDirect => type == 'direct';

  @override
  List<Object?> get props => [
    uuid,
    type,
    title,
    imageUrl,
    isPinned,
    unreadCount,
    lastMessage,
    memberCount,
    updatedAt,
  ];
}
