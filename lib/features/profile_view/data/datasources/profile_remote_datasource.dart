// lib/features/profile_view/data/datasources/profile_remote_datasource.dart
import 'dart:convert';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/features/profile_view/data/datasources/follow_list_remote_datasource.dart';
export 'follow_list_remote_datasource.dart';

class ProfileRemoteDataSource {
  final DioClient http;
  ProfileRemoteDataSource(this.http);

  // ── Existing methods (unchanged) ──────────────────────────────────────────

  Future<Map<String, dynamic>> getUser(String uuid) async {
    final res = await http.dio.get('/api/v1/users/$uuid');
    return _toMap(res.data);
  }

  Future<Map<String, dynamic>> getUserPosts(
    String uuid, {
    int page = 1,
    int perPage = 20,
  }) async {
    final res = await http.dio.get(
      '/api/v1/users/$uuid/posts',
      queryParameters: {'per_page': perPage, 'page': page},
    );
    return _toMap(res.data);
  }

  Future<Map<String, dynamic>> followUser(String uuid) async {
    final res = await http.dio.post('/api/v1/users/$uuid/follow');
    return _toMap(res.data);
  }

  Future<Map<String, dynamic>> unfollowUser(String uuid) async {
    final res = await http.dio.delete('/api/v1/users/$uuid/follow');
    return _toMap(res.data);
  }

  Future<Map<String, dynamic>> blockUser(String uuid, {String? reason}) async {
    final body = <String, dynamic>{};
    if (reason != null && reason.isNotEmpty) body['reason'] = reason;
    final res = await http.dio.post(
      '/api/v1/settings/blocked-users/$uuid/block',
      data: body,
    );
    return _toMap(res.data);
  }

  // ── New: follow-list datasource (shared instance) ─────────────────────────

  late final FollowListRemoteDataSource followList = FollowListRemoteDataSource(
    http,
  );

  Map<String, dynamic> _toMap(dynamic raw) {
    return raw is Map
        ? raw.cast<String, dynamic>()
        : jsonDecode(raw as String) as Map<String, dynamic>;
  }
}
