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
  final String? otherUserUuid;
  final String? otherUserSlug;

  // For club conversations
  final String? clubUuid;

  const ChatConversations({
    required this.uuid,
    required this.type,
    required this.title,
    this.imageUrl,
    required this.isPinned,
    required this.unreadCount,
    this.otherUserUuid,
    this.otherUserSlug,
    this.clubUuid,
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
      otherUserUuid: json['other_user_uuid'] as String?,
      otherUserSlug: json['other_user_slug'] as String?,
      clubUuid: json['club_uuid'] as String?,
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
    'other_user_uuid': otherUserUuid,
    'other_user_slug': otherUserSlug,
    'club_uuid': clubUuid,
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
    otherUserUuid,
    otherUserSlug,
    clubUuid,
  ];
}
