// lib/features/notifications/data/models/notification_model.dart

class NotificationActor {
  final String uuid;
  final String slug;
  final String fullname;
  final String avatarUrl;

  const NotificationActor({
    required this.uuid,
    required this.slug,
    required this.fullname,
    required this.avatarUrl,
  });

  factory NotificationActor.fromJson(Map<String, dynamic> j) =>
      NotificationActor(
        uuid: j['uuid']?.toString() ?? '',
        slug: j['user_slug']?.toString() ?? '',
        fullname: j['fullname']?.toString() ?? '',
        avatarUrl: j['avatar_url']?.toString() ?? '',
      );
}

class NotificationMeta {
  final String? postUuid;   // uuid of the post (for navigation)
  final int? postId;        // numeric id (fallback)
  final int? commentId;
  final int? parentCommentId;
  final bool isReply;
  final String? userUuid;   // for follow notifications
  final String? liveUuid;   // for live stream notifications

  const NotificationMeta({
    this.postUuid,
    this.postId,
    this.commentId,
    this.parentCommentId,
    this.isReply = false,
    this.userUuid,
    this.liveUuid,
  });

  factory NotificationMeta.fromJson(Map<String, dynamic> j) =>
      NotificationMeta(
        postUuid: j['post_uuid']?.toString(),
        postId: (j['post_id'] as num?)?.toInt(),
        commentId: (j['comment_id'] as num?)?.toInt(),
        parentCommentId: (j['parent_comment_id'] as num?)?.toInt(),
        isReply: j['is_reply'] == true,
        userUuid: j['user_uuid']?.toString(),
        liveUuid: j['live_uuid']?.toString(),
      );

  static NotificationMeta empty() => const NotificationMeta();
}

class NotificationModel {
  final String id;
  final String type;       // e.g. "post.comment_replied", "post.liked"
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final String actionUrl;
  final NotificationActor? actor;
  final NotificationMeta meta;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    required this.actionUrl,
    this.actor,
    required this.meta,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final actorJson = data['actor'] as Map<String, dynamic>?;
    final metaJson = data['meta'] as Map<String, dynamic>?;

    return NotificationModel(
      id: json['id']?.toString() ?? '',
      type: data['type']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      body: data['body']?.toString() ?? '',
      isRead: json['read_at'] != null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      actionUrl: data['action_url']?.toString() ?? '',
      actor: actorJson != null ? NotificationActor.fromJson(actorJson) : null,
      meta: metaJson != null
          ? NotificationMeta.fromJson(metaJson)
          : NotificationMeta.empty(),
    );
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) =>
      NotificationModel.fromJson(map);

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
        id: id,
        type: type,
        title: title,
        body: body,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        actionUrl: actionUrl,
        actor: actor,
        meta: meta,
      );
}