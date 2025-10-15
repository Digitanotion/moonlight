import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/features/post_view/domain/repositories/post_repository.dart';
import '../../domain/entities/comment.dart';
import '../models/comment_dto.dart';
import '../models/post_dto.dart';

class PostRemoteDataSource {
  final DioClient http;
  PostRemoteDataSource(this.http);

  String _p(String postUuid, [String s = '']) => '/api/v1/posts/$postUuid$s';

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    if (data is String) {
      try {
        final m = jsonDecode(data);
        if (m is Map) return m.cast<String, dynamic>();
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic> _unwrap(dynamic raw) {
    final m = _asMap(raw);
    if (m['data'] is Map) return (m['data'] as Map).cast<String, dynamic>();
    return m;
  }

  Future<PostDto> getPost(String postUuid) async {
    final res = await http.dio.get(_p(postUuid));
    final map = _unwrap(res.data); // accept both {data:{...}} and flat
    return PostDto.fromMap(map);
  }

  Future<PostDto> editCaption(String postUuid, String caption) async {
    final res = await http.dio.put(_p(postUuid), data: {'caption': caption});
    return PostDto.fromMap(_unwrap(res.data));
  }

  Future<void> deletePost(String postUuid) async {
    await http.dio.delete(_p(postUuid));
  }

  Future<PostDto> toggleLike(String postUuid) async {
    // hit like endpoint
    await http.dio.post(_p(postUuid, '/like'));
    // then refetch full post (and unwrap)
    final res = await http.dio.get(
      _p(postUuid),
      options: Options(
        // ensure we don’t get a stale cached body after mutating
        headers: {'Cache-Control': 'no-cache'},
      ),
    );
    return PostDto.fromMap(_unwrap(res.data));
  }

  Future<int> share(String postUuid) async {
    final res = await http.dio.post(_p(postUuid, '/share'));
    final m = _unwrap(res.data);
    return (m['shares'] as num?)?.toInt() ?? 0;
  }

  Future<void> report(String postUuid, String reason) async {
    await http.dio.post(_p(postUuid, '/report'), data: {'reason': reason});
  }

  Future<CommentsPageResult> getComments(
    String postUuid, {
    int page = 1,
    int perPage = 50,
  }) async {
    final res = await http.dio.get(
      _p(postUuid, '/comments'),
      queryParameters: {'page': page, 'per_page': perPage},
    );
    final m = _asMap(res.data);

    final data = ((m['data'] as List?) ?? const [])
        .map((e) => CommentDto.fromMap((e as Map).cast<String, dynamic>()))
        .map((e) => e.toEntity())
        .toList();

    final meta = (m['meta'] as Map?)?.cast<String, dynamic>() ?? const {};
    final links = (m['links'] as Map?)?.cast<String, dynamic>() ?? const {};
    final current = (meta['current_page'] as num?)?.toInt() ?? page;
    final total = (meta['total'] as num?)?.toInt() ?? data.length;
    final hasNext = links['next'] != null;

    return CommentsPageResult(
      data: data,
      currentPage: current,
      perPage: perPage,
      total: total,
      hasNext: hasNext,
    );
  }

  Future<Comment> addComment(String postUuid, String text) async {
    final res = await http.dio.post(
      _p(postUuid, '/comments'),
      data: {'text': text},
    );
    return CommentDto.fromMap(_unwrap(res.data)).toEntity();
  }

  Future<Comment> addReply(
    String postUuid,
    String commentUuid,
    String text,
  ) async {
    final res = await http.dio.post(
      _p(postUuid, '/comments/$commentUuid/reply'),
      data: {'text': text},
    );
    return CommentDto.fromMap(_unwrap(res.data)).toEntity();
  }

  /// Return ONLY the updated likes count; let the Cubit merge into state.
  Future<int> toggleCommentLike(String postUuid, String commentUuid) async {
    final res = await http.dio.post(
      _p(postUuid, '/comments/$commentUuid/like'),
    );
    final m = _unwrap(res.data);
    return (m['likes'] as num?)?.toInt() ?? 0;
  }
}
