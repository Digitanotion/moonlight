// lib/features/post_view/data/models/post_dto.dart
import '../../domain/entities/post.dart';
import 'user_dto.dart';

class PostDto {
  final String id; // convenience
  final String uuid; // canonical id
  final AppUserDto author;
  final String mediaUrl;
  final String? thumbUrl; // optional video/image thumbnail
  final String? mediaType; // e.g. "image/jpeg", "video/mp4"
  final String caption;
  final List<String> tags;
  final DateTime createdAt;
  final int likes;
  final int commentsCount;
  final int shares;
  final int views;
  final bool isLiked;

  const PostDto({
    required this.id,
    required this.uuid,
    required this.author,
    required this.mediaUrl,
    this.thumbUrl,
    this.mediaType,
    required this.caption,
    required this.tags,
    required this.createdAt,
    required this.likes,
    required this.commentsCount,
    required this.shares,
    required this.views,
    required this.isLiked,
  });

  factory PostDto.fromMap(Map<String, dynamic> m) {
    // tolerant helper: tries keys in order and returns first non-null
    T? _pick<T>(List<Object> keys) {
      for (final k in keys) {
        final v = m[k];
        if (v != null) return v as T;
      }
      return null;
    }

    final idOrUuid = _pick<Object>(['uuid', 'id']);
    final createdStr = _pick<String>(['createdAt', 'created_at']);
    final createdAt = DateTime.tryParse(createdStr ?? '') ?? DateTime.now();

    // author map (tolerant)
    Map<String, dynamic> _authorMap() {
      final raw = _pick<Object>(['author']);
      if (raw is Map) return raw.cast<String, dynamic>();
      return <String, dynamic>{};
    }

    // tags as list (tolerant to string/comma-separated just in case)
    List<String> _tags() {
      final raw = _pick<Object>(['tags']);
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      } else if (raw is String) {
        // handle "tag1,tag2"
        return raw
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return const [];
    }

    final mediaUrl = _pick<String>(['mediaUrl', 'media_url']) ?? '';

    return PostDto(
      id: '${_pick<Object>(['id', 'uuid']) ?? idOrUuid ?? ''}',
      uuid: '${idOrUuid ?? ''}',
      author: AppUserDto.fromMap(_authorMap()),
      mediaUrl: mediaUrl,
      thumbUrl: _pick<String>(['thumbUrl', 'thumb_url']),
      mediaType: _pick<String>(['mediaType', 'media_type']),
      caption: _pick<String>(['caption']) ?? '',
      tags: _tags(),
      createdAt: createdAt,
      likes: (_pick<num>(['likes']) ?? 0).toInt(),
      commentsCount: (_pick<num>(['commentsCount', 'comments_count']) ?? 0)
          .toInt(),
      shares: (_pick<num>(['shares']) ?? 0).toInt(),
      views: (_pick<num>(['views']) ?? 0).toInt(),
      isLiked: (_pick<bool>(['isLiked', 'is_liked']) ?? false),
    );
  }

  Post toEntity() => Post(
    id: uuid, // use uuid everywhere internally
    author: author.toEntity(),
    mediaUrl: mediaUrl,
    thumbUrl: thumbUrl,
    mediaType: mediaType,
    caption: caption,
    tags: tags,
    createdAt: createdAt,
    likes: likes,
    commentsCount: commentsCount,
    shares: shares,
    views: views,
    isLiked: isLiked,
  );
}
