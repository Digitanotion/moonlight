import 'package:moonlight/features/post_view/domain/entities/user.dart';

class Post {
  final String id;
  final AppUser author;
  final String mediaUrl; // photo/video
  final String? thumbUrl;
  final String? mediaType; // e.g. "image/jpeg", "video/mp4" (nullable)
  final String caption;
  final List<String> tags;
  final DateTime createdAt;
  final int likes;
  final int commentsCount;
  final int shares;
  final bool isLiked;
  final int views;

  const Post({
    required this.id,
    required this.author,
    required this.mediaUrl,
    this.thumbUrl, // ✅ initialized (nullable, defaults to null)
    this.mediaType, // ✅ initialized (nullable, defaults to null)

    required this.caption,
    required this.tags,
    required this.createdAt,
    this.likes = 0,
    this.commentsCount = 0,
    this.shares = 0,
    this.isLiked = false,
    this.views = 0,
  });

  // Convenience:
  bool get isVideo {
    if (mediaType?.startsWith('video/') == true) return true;
    final u = mediaUrl.toLowerCase();
    return u.endsWith('.mp4') ||
        u.endsWith('.mov') ||
        u.endsWith('.m4v') ||
        u.contains('video=');
  }

  Post copyWith({
    String? id,
    AppUser? author,
    String? mediaUrl,
    String? thumbUrl,
    String? mediaType,
    String? caption,
    List<String>? tags,
    DateTime? createdAt,
    int? likes,
    bool? isLiked,
    int? commentsCount,
    int? shares,
    int? views,
  }) => Post(
    id: id ?? this.id,
    author: author ?? this.author,
    mediaUrl: mediaUrl ?? this.mediaUrl,
    thumbUrl: thumbUrl ?? this.thumbUrl,
    mediaType: mediaType ?? this.mediaType,
    caption: caption ?? this.caption,
    tags: tags ?? this.tags,
    createdAt: createdAt ?? this.createdAt,
    likes: likes ?? this.likes,
    commentsCount: commentsCount ?? this.commentsCount,
    shares: shares ?? this.shares,
    isLiked: isLiked ?? this.isLiked,
    views: views ?? this.views,
  );

  @override
  List<Object?> get props => [
    id, author, mediaUrl, caption, tags, createdAt,
    likes, commentsCount, shares, isLiked, views, // NEW
  ];
}
