// lib/features/chat/data/models/chat_models.dart
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
  final String? uuid; // Make this nullable
  final String url;
  final String mimeType;
  final int size;
  final int? duration;

  MediaAttachment({
    this.uuid, // Nullable
    required this.url,
    required this.mimeType,
    required this.size,
    this.duration,
  });

  factory MediaAttachment.fromJson(Map<String, dynamic> json) {
    return MediaAttachment(
      uuid: json['uuid'] as String?, // Handle null
      url: json['url'] as String,
      mimeType: json['mime_type'] as String,
      size: json['size'] is String
          ? int.parse(json['size'] as String) // Handle string size
          : json['size'] as int, // Handle int size
      duration: json['duration'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    if (uuid != null) 'uuid': uuid,
    'url': url,
    'mime_type': mimeType,
    'size': size,
    if (duration != null) 'duration': duration,
  };

  bool get isImage => mimeType.startsWith('image/');
  bool get isVideo => mimeType.startsWith('video/');
  bool get isAudio => mimeType.startsWith('audio/');

  @override
  List<Object?> get props => [uuid, url]; // uuid can be null
}

/// One emoji's worth of reactions on a message (WhatsApp-style pill).
class MessageReactionGroup extends Equatable {
  final String emoji;
  final int count;

  /// True if the current user is one of the reactors for this emoji.
  final bool mine;

  /// Who reacted with this emoji (may be empty on lightweight payloads).
  final List<ChatUser> users;

  const MessageReactionGroup({
    required this.emoji,
    required this.count,
    this.mine = false,
    this.users = const [],
  });

  MessageReactionGroup copyWith({int? count, bool? mine}) =>
      MessageReactionGroup(
        emoji: emoji,
        count: count ?? this.count,
        mine: mine ?? this.mine,
        users: users,
      );

  factory MessageReactionGroup.fromJson(
    Map<String, dynamic> json, {
    String? myUuid,
  }) {
    final users = (json['users'] as List? ?? [])
        .whereType<Map>()
        .map((u) => ChatUser.fromJson(Map<String, dynamic>.from(u)))
        .toList();
    // When myUuid is supplied (realtime broadcasts) the payload's `me`
    // flag is the *sender's* context — don't trust it, derive from users.
    final mine = myUuid != null
        ? users.any((u) => u.uuid == myUuid)
        : json['me'] == true;
    return MessageReactionGroup(
      emoji: json['emoji'].toString(),
      count: json['count'] is num
          ? (json['count'] as num).toInt()
          : users.length,
      mine: mine,
      users: users,
    );
  }

  Map<String, dynamic> toJson() => {
    'emoji': emoji,
    'count': count,
    'me': mine,
    'users': users.map((u) => u.toJson()).toList(),
  };

  @override
  List<Object?> get props => [emoji, count, mine];
}

class Message extends Equatable {
  final String uuid;
  final String body;
  final MessageType type;
  final ChatUser sender;
  final List<MediaAttachment> media;
  final List<MessageReactionGroup> reactions;
  final bool isEdited;
  final DateTime createdAt;
  final DateTime? editedAt;
  final String? replyToUuid;
  final Message? replyTo; // This is the full reply message object

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
    this.replyTo, // Initialize
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      uuid: json['uuid'] as String,
      body: json['body']?.toString() ?? '',
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
      reactions: _parseReactions(json['reactions']),
      isEdited: json['is_edited'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      editedAt: json['edited_at'] != null
          ? DateTime.parse(json['edited_at'] as String).toLocal()
          : null,
      replyToUuid: json['reply_to_uuid'] as String?,
      replyTo: json['reply_to'] != null
          ? Message.fromReplyToJson(
              Map<String, dynamic>.from(json['reply_to'] as Map),
            )
          : null,
    );
  }

  /// The current user's own reaction emoji, if any.
  String? get myReaction {
    for (final g in reactions) {
      if (g.mine) return g.emoji;
    }
    return null;
  }

  /// Public entry point for parsing a reactions payload (HTTP `data` or a
  /// realtime event). Pass [myUuid] when the payload's `me` flag can't be
  /// trusted (broadcasts).
  static List<MessageReactionGroup> reactionsFromPayload(
    Object? raw, {
    String? myUuid,
  }) =>
      _parseReactions(raw, myUuid: myUuid);

  static List<MessageReactionGroup> _parseReactions(
    Object? raw, {
    String? myUuid,
  }) {
    if (raw is List) {
      // New shape: list of {emoji,count,me,users}. Legacy: list of strings.
      if (raw.isNotEmpty && raw.first is String) {
        return raw
            .map((e) => MessageReactionGroup(emoji: e.toString(), count: 1))
            .toList();
      }
      return raw
          .whereType<Map>()
          .map((m) => MessageReactionGroup.fromJson(
                Map<String, dynamic>.from(m),
                myUuid: myUuid,
              ))
          .toList();
    }
    if (raw is Map && raw['summary'] is List) {
      return (raw['summary'] as List)
          .whereType<Map>()
          .map((m) => MessageReactionGroup.fromJson(
                Map<String, dynamic>.from(m),
                myUuid: myUuid,
              ))
          .toList();
    }
    return const [];
  }

  // Special constructor for reply_to objects (they have less fields)
  factory Message.fromReplyToJson(Map<String, dynamic> json) {
    return Message(
      uuid: json['uuid'] as String,
      body: json['body']?.toString() ?? '',
      type: MessageType.fromString(json['type'] as String),
      sender: ChatUser.fromJson(
        Map<String, dynamic>.from(json['sender'] as Map),
      ),
      media: const [],
      reactions: const [],
      isEdited: false,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      editedAt: json['edited_at'] != null
          ? DateTime.parse(json['edited_at'] as String).toLocal()
          : null,
      replyToUuid: null, // Reply-to messages don't have their own reply_to
      replyTo: null,
    );
  }

  Map<String, dynamic> toJson() => {
    'uuid': uuid,
    'body': body,
    'type': type.value,
    'sender': sender.toJson(),
    'media': media.map((m) => m.toJson()).toList(),
    'reactions': reactions.map((r) => r.toJson()).toList(),
    'is_edited': isEdited,
    'created_at': createdAt.toUtc().toIso8601String(),
    'edited_at': editedAt?.toUtc().toIso8601String(),
    'reply_to_uuid': replyToUuid,
    'reply_to': replyTo?.toJson(),
  };

  Message copyWith({
    String? body,
    bool? isEdited,
    DateTime? editedAt,
    List<MessageReactionGroup>? reactions,
  }) {
    return Message(
      uuid: uuid,
      body: body ?? this.body,
      type: type,
      sender: sender,
      media: media,
      reactions: reactions ?? this.reactions,
      isEdited: isEdited ?? this.isEdited,
      createdAt: createdAt,
      editedAt: editedAt ?? this.editedAt,
      replyToUuid: replyToUuid,
      replyTo: replyTo,
    );
  }

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
    replyTo,
  ];
}

/// Realtime payload for the `message.reaction` Pusher event. Carries the
/// full grouped reaction set for one message; `mine` is resolved against
/// [myUuid] because a broadcast can't know each viewer.
class MessageReactionEvent {
  final String messageUuid;
  final List<MessageReactionGroup> reactions;

  const MessageReactionEvent({
    required this.messageUuid,
    required this.reactions,
  });

  factory MessageReactionEvent.fromJson(
    Map<String, dynamic> json, {
    String? myUuid,
  }) {
    return MessageReactionEvent(
      messageUuid: (json['message_uuid'] ?? json['uuid'] ?? '').toString(),
      reactions:
          Message.reactionsFromPayload(json['reactions'], myUuid: myUuid),
    );
  }
}

/// Lightweight realtime payload for the `message.updated` Pusher event —
/// the server only sends the changed fields, keyed by message uuid.
class MessageEditEvent {
  final String uuid;
  final String body;
  final DateTime? editedAt;

  const MessageEditEvent({
    required this.uuid,
    required this.body,
    this.editedAt,
  });

  factory MessageEditEvent.fromJson(Map<String, dynamic> json) {
    return MessageEditEvent(
      uuid: json['uuid'] as String,
      body: json['body']?.toString() ?? '',
      editedAt: json['edited_at'] != null
          ? DateTime.tryParse(json['edited_at'] as String)?.toLocal()
          : null,
    );
  }
}

/// Realtime payload for the `conversation.read` Pusher event — a participant
/// advanced their read cursor.
class ConversationReadEvent {
  final String userUuid;
  final DateTime? lastReadAt;

  const ConversationReadEvent({required this.userUuid, this.lastReadAt});

  factory ConversationReadEvent.fromJson(Map<String, dynamic> json) {
    return ConversationReadEvent(
      userUuid: (json['user_uuid'] ?? '').toString(),
      lastReadAt: json['last_read_at'] != null
          ? DateTime.tryParse(json['last_read_at'] as String)?.toLocal()
          : null,
    );
  }
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
      imageUrl: json['image_url'] as String?,
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
