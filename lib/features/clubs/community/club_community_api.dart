// lib/features/clubs/community/club_community_api.dart
//
// Club community feed (members only): posts, like/dislike, comments.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/network/dio_client.dart';

class CommunityAuthor {
  final String uuid;
  final String slug;
  final String name;
  final String? avatarUrl;
  const CommunityAuthor({
    required this.uuid,
    required this.slug,
    required this.name,
    this.avatarUrl,
  });

  factory CommunityAuthor.fromJson(Map<String, dynamic>? j) => CommunityAuthor(
    uuid: (j?['uuid'] ?? '').toString(),
    slug: (j?['user_slug'] ?? '').toString(),
    name: (j?['display_name'] ?? j?['user_slug'] ?? 'Member').toString(),
    avatarUrl: j?['avatar_url']?.toString(),
  );
}

class CommunityMedia {
  final String type; // image | video | audio
  final String url;
  final int? duration;
  const CommunityMedia({required this.type, required this.url, this.duration});

  factory CommunityMedia.fromJson(Map<String, dynamic> j) => CommunityMedia(
    type: (j['type'] ?? 'image').toString(),
    url: (j['url'] ?? '').toString(),
    duration: (j['duration'] as num?)?.toInt(),
  );
}

/// Like/dislike state shared by posts and comments.
class Reactions {
  final int likes;
  final int dislikes;
  final String? mine; // like | dislike | null
  const Reactions(this.likes, this.dislikes, this.mine);

  /// Optimistic tap on [value] (tapping your current choice clears it).
  Reactions tap(String value) {
    var l = likes, d = dislikes;
    if (mine == 'like') l--;
    if (mine == 'dislike') d--;
    final next = mine == value ? null : value;
    if (next == 'like') l++;
    if (next == 'dislike') d++;
    return Reactions(l, d, next);
  }
}

class CommunityPost {
  final String uuid;
  final String? body;
  final List<CommunityMedia> media;
  final CommunityAuthor author;
  final Reactions reactions;
  final int comments;
  final bool canDelete;
  final DateTime createdAt;
  const CommunityPost({
    required this.uuid,
    required this.body,
    required this.media,
    required this.author,
    required this.reactions,
    required this.comments,
    required this.canDelete,
    required this.createdAt,
  });

  CommunityPost copyWith({Reactions? reactions, int? comments}) =>
      CommunityPost(
        uuid: uuid,
        body: body,
        media: media,
        author: author,
        reactions: reactions ?? this.reactions,
        comments: comments ?? this.comments,
        canDelete: canDelete,
        createdAt: createdAt,
      );

  factory CommunityPost.fromJson(Map<String, dynamic> j) => CommunityPost(
    uuid: j['uuid'].toString(),
    body: j['body']?.toString(),
    media: ((j['media'] as List?) ?? const [])
        .map(
          (m) => CommunityMedia.fromJson(Map<String, dynamic>.from(m as Map)),
        )
        .toList(),
    author: CommunityAuthor.fromJson(
      j['author'] is Map ? Map<String, dynamic>.from(j['author'] as Map) : null,
    ),
    reactions: Reactions(
      (j['likes_count'] as num?)?.toInt() ?? 0,
      (j['dislikes_count'] as num?)?.toInt() ?? 0,
      j['my_reaction']?.toString(),
    ),
    comments: (j['comments_count'] as num?)?.toInt() ?? 0,
    canDelete: j['can_delete'] == true,
    createdAt:
        DateTime.tryParse('${j['created_at']}')?.toLocal() ?? DateTime.now(),
  );
}

class CommunityComment {
  final String uuid;
  final String body;
  final CommunityAuthor author;
  final Reactions reactions;
  final bool canDelete;
  final DateTime createdAt;
  final List<CommunityComment> replies;
  const CommunityComment({
    required this.uuid,
    required this.body,
    required this.author,
    required this.reactions,
    required this.canDelete,
    required this.createdAt,
    required this.replies,
  });

  CommunityComment withReactions(Reactions r) => CommunityComment(
    uuid: uuid,
    body: body,
    author: author,
    reactions: r,
    canDelete: canDelete,
    createdAt: createdAt,
    replies: replies,
  );

  factory CommunityComment.fromJson(Map<String, dynamic> j) => CommunityComment(
    uuid: j['uuid'].toString(),
    body: (j['body'] ?? '').toString(),
    author: CommunityAuthor.fromJson(
      j['author'] is Map ? Map<String, dynamic>.from(j['author'] as Map) : null,
    ),
    reactions: Reactions(
      (j['likes_count'] as num?)?.toInt() ?? 0,
      (j['dislikes_count'] as num?)?.toInt() ?? 0,
      j['my_reaction']?.toString(),
    ),
    canDelete: j['can_delete'] == true,
    createdAt:
        DateTime.tryParse('${j['created_at']}')?.toLocal() ?? DateTime.now(),
    replies: ((j['replies'] as List?) ?? const [])
        .map(
          (r) => CommunityComment.fromJson(Map<String, dynamic>.from(r as Map)),
        )
        .toList(),
  );
}

class ClubCommunityApi {
  final String club; // uuid or slug
  ClubCommunityApi(this.club);

  Dio get _dio => sl<DioClient>().dio;
  String get _base => '/api/v1/clubs/$club';

  Future<(List<CommunityPost>, bool)> posts({int page = 1}) async {
    final res = await _dio.get('$_base/posts', queryParameters: {'page': page});
    final m = res.data as Map;
    final list = ((m['data'] as List?) ?? const [])
        .map((e) => CommunityPost.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final meta = m['meta'] as Map?;
    final hasMore =
        ((meta?['current_page'] as num?) ?? 1) <
        ((meta?['last_page'] as num?) ?? 1);
    return (list, hasMore);
  }

  Future<CommunityPost> create({
    String? body,
    List<File> files = const [],
    int? voiceSeconds,
  }) async {
    final form = FormData.fromMap({
      if (body != null && body.trim().isNotEmpty) 'body': body.trim(),
      if (voiceSeconds != null) 'voice_note': 1,
      if (voiceSeconds != null) 'voice_duration': voiceSeconds,
      'media[]': [
        for (final f in files)
          await MultipartFile.fromFile(
            f.path,
            filename: f.path.split('/').last,
          ),
      ],
    });
    final res = await _dio.post(
      '$_base/posts',
      data: form,
      options: Options(
        sendTimeout: const Duration(minutes: 3),
        receiveTimeout: const Duration(minutes: 3),
      ),
    );
    return CommunityPost.fromJson(
      Map<String, dynamic>.from((res.data as Map)['data'] as Map),
    );
  }

  Future<void> deletePost(String post) => _dio.delete('$_base/posts/$post');

  Future<void> react(String post, String? value) =>
      _dio.post('$_base/posts/$post/react', data: {'value': value ?? 'none'});

  Future<List<CommunityComment>> comments(String post) async {
    final res = await _dio.get('$_base/posts/$post/comments');
    return (((res.data as Map)['data'] as List?) ?? const [])
        .map(
          (e) => CommunityComment.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<void> addComment(String post, String body, {String? parent}) =>
      _dio.post(
        '$_base/posts/$post/comments',
        data: {'body': body, 'parent_uuid': ?parent},
      );

  Future<void> reactComment(String comment, String? value) => _dio.post(
    '$_base/comments/$comment/react',
    data: {'value': value ?? 'none'},
  );

  Future<void> deleteComment(String comment) =>
      _dio.delete('$_base/comments/$comment');
}

/// Server's message from a failed call, or a friendly fallback.
String communityError(Object e) {
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map && d['message'] != null) return d['message'].toString();
  }
  return 'Something went wrong. Please try again.';
}
