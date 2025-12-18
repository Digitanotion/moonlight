import 'package:equatable/equatable.dart';

class ChatUser extends Equatable {
  final String uuid;
  final String userSlug;
  final String fullName;
  final String? avatarUrl;

  const ChatUser({
    required this.uuid,
    required this.userSlug,
    required this.fullName,
    this.avatarUrl,
  });

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    return ChatUser(
      uuid: json['uuid'] as String,
      userSlug: json['user_slug'] as String,
      fullName: (json['full_name'] ?? json['fullname'] ?? '') as String,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'uuid': uuid,
    'user_slug': userSlug,
    'fullname': fullName,
    'avatar_url': avatarUrl,
  };

  @override
  List<Object?> get props => [uuid, userSlug];
}

class MediaAttachment extends Equatable {
  final String uuid;
  final String url;
  final String mimeType;
  final int size;

  const MediaAttachment({
    required this.uuid,
    required this.url,
    required this.mimeType,
    required this.size,
  });

  factory MediaAttachment.fromJson(Map<String, dynamic> json) {
    return MediaAttachment(
      uuid: json['uuid'] as String,
      url: json['url'] as String,
      mimeType: json['mime_type'] as String,
      size: json['size'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'uuid': uuid,
    'url': url,
    'mime_type': mimeType,
    'size': size,
  };

  bool get isImage => mimeType.startsWith('image/');
  bool get isVideo => mimeType.startsWith('video/');
  bool get isAudio => mimeType.startsWith('audio/');

  @override
  List<Object?> get props => [uuid, url];
}

class Message extends Equatable {
  final String uuid;
  final String body;
  final MessageType type;
  final ChatUser sender;
  final List<MediaAttachment> media;
  final List<String> reactions;
  final bool isEdited;
  final DateTime createdAt;
  final DateTime? editedAt;
  final String? replyToUuid;

  const Message({
    required this.uuid,
    required this.body,
    required this.type,
    required this.sender,
    this.media = const [],
    this.reactions = const [],
    this.isEdited = false,
    required this.createdAt,
    this.editedAt,
    this.replyToUuid,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      uuid: json['uuid'] as String,
      body: json['body'] as String,
      type: MessageType.fromString(json['type'] as String),
      sender: ChatUser.fromJson(
        Map<String, dynamic>.from(json['sender'] as Map),
      ),
      media: (json['media'] as List? ?? [])
          .map(
            (m) =>
                MediaAttachment.fromJson(Map<String, dynamic>.from(m as Map)),
          )
          .toList(),
      reactions: List<String>.from(json['reactions'] as List? ?? []),
      isEdited: json['is_edited'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      editedAt: json['edited_at'] != null
          ? DateTime.parse(json['edited_at'] as String).toLocal()
          : null,
      replyToUuid: json['reply_to_uuid'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'uuid': uuid,
    'body': body,
    'type': type.value,
    'sender': sender.toJson(),
    'media': media.map((m) => m.toJson()).toList(),
    'reactions': reactions,
    'is_edited': isEdited,
    'created_at': createdAt.toUtc().toIso8601String(),
    'edited_at': editedAt?.toUtc().toIso8601String(),
    'reply_to_uuid': replyToUuid,
  };

  @override
  List<Object?> get props => [
    uuid,
    body,
    type,
    sender,
    media,
    reactions,
    isEdited,
    createdAt,
    editedAt,
    replyToUuid,
  ];
}

class Conversation extends Equatable {
  final String uuid;
  final String type;
  final String title;
  final String? imageUrl;
  final bool isPinned;
  final int unreadCount;
  final Message? lastMessage;
  final int? memberCount;
  final DateTime? updatedAt;

  const Conversation({
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

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
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

// For paginated responses (following your existing pattern)
// class PaginatedMessages extends Paginated<Message> {
//   const PaginatedMessages({
//     required super.data,
//     required super.currentPage,
//     required super.lastPage,
//     required super.perPage,
//     required super.total,
//     required super.nextPageUrl,
//   });

//   factory PaginatedMessages.fromJson(Map<String, dynamic> json) {
//     final data = (json['data'] as List)
//         .map((m) => Message.fromJson(Map<String, dynamic>.from(m as Map)))
//         .toList();

//     return PaginatedMessages(
//       data: data,
//       currentPage: json['meta']['current_page'] as int,
//       lastPage: json['meta']['last_page'] as int,
//       perPage: json['meta']['per_page'] as int,
//       total: json['meta']['total'] as int,
//       nextPageUrl: json['links']['next'] as String?,
//     );
//   }
// }

enum MessageType {
  text('text'),
  media('media');

  final String value;
  const MessageType(this.value);

  factory MessageType.fromString(String value) {
    switch (value) {
      case 'media':
        return MessageType.media;
      case 'text':
      default:
        return MessageType.text;
    }
  }
}
