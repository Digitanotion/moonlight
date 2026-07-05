// lib/features/feed/data/datasources/feed_remote_datasource.dart

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:moonlight/core/network/dio_client.dart';

class FeedRemoteDataSource {
  final DioClient http;
  FeedRemoteDataSource(this.http);

  Future<Map<String, dynamic>> fetchFeed({
    int page = 1,
    int perPage = 20,
  }) async {
    final res = await http.dio.get(
      '/api/v1/posts',
      queryParameters: {'per_page': perPage, 'page': page},
      options: Options(responseType: ResponseType.json),
    );
    final data = res.data is Map
        ? res.data as Map<String, dynamic>
        : jsonDecode(res.data as String) as Map<String, dynamic>;
    return data;
  }

  Future<Map<String, dynamic>> toggleLike(String postUuid) async {
    final res = await http.dio.post('/api/v1/posts/$postUuid/like');
    return res.data is Map
        ? res.data as Map<String, dynamic>
        : jsonDecode(res.data as String) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> share(String postUuid) async {
    final res = await http.dio.post('/api/v1/posts/$postUuid/share');
    return res.data is Map
        ? res.data as Map<String, dynamic>
        : jsonDecode(res.data as String) as Map<String, dynamic>;
  }

  /// Records a view and returns the server's actual view count.
  Future<int> recordView(String postUuid) async {
    final res = await http.dio.post('/api/v1/posts/$postUuid/view');
    final data = res.data is Map
        ? res.data as Map<String, dynamic>
        : jsonDecode(res.data as String) as Map<String, dynamic>;
    return (data['views'] as num?)?.toInt() ?? 0;
  }
}