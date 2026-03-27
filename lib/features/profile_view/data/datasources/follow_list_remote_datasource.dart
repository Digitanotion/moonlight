// lib/features/profile_view/data/datasources/follow_list_remote_datasource.dart
import 'dart:convert';
import 'package:moonlight/core/network/dio_client.dart';

class FollowListUser {
  final String uuid;
  final String userSlug;
  final String fullname;
  final String avatarUrl;
  bool isFollowing;

  FollowListUser({
    required this.uuid,
    required this.userSlug,
    required this.fullname,
    required this.avatarUrl,
    this.isFollowing = false,
  });

  factory FollowListUser.fromJson(Map<String, dynamic> j) {
    // Handle case where followed_by_me might be null or empty object
    bool following = false;
    if (j.containsKey('followed_by_me')) {
      final followedByMe = j['followed_by_me'];
      // Convert to boolean if it's a bool, map if it's an object, default false
      if (followedByMe is bool) {
        following = followedByMe;
      } else if (followedByMe is Map) {
        following = false; // Empty object means false
      } else if (followedByMe is String) {
        following = followedByMe.toLowerCase() == 'true';
      }
    }

    return FollowListUser(
      uuid: '${j['uuid'] ?? ''}',
      userSlug: '${j['user_slug'] ?? ''}',
      fullname: '${j['fullname'] ?? j['name'] ?? ''}',
      avatarUrl: '${j['avatar_url'] ?? ''}',
      isFollowing: following,
    );
  }
}

class FollowListResult {
  final List<FollowListUser> users;
  final String? nextCursor;

  const FollowListResult({required this.users, this.nextCursor});
}

class FollowListRemoteDataSource {
  final DioClient http;
  FollowListRemoteDataSource(this.http);

  Future<FollowListResult> getFollowers(
    String userUuid, {
    String? cursor,
    int limit = 20,
  }) async {
    final res = await http.dio.get(
      '/api/v1/users/$userUuid/followers',
      queryParameters: {'limit': limit, if (cursor != null) 'cursor': cursor},
    );
    return _parse(res.data);
  }

  Future<FollowListResult> getFollowing(
    String userUuid, {
    String? cursor,
    int limit = 20,
  }) async {
    final res = await http.dio.get(
      '/api/v1/users/$userUuid/following',
      queryParameters: {'limit': limit, if (cursor != null) 'cursor': cursor},
    );
    return _parse(res.data);
  }

  Future<void> followUser(String uuid) async {
    await http.dio.post('/api/v1/users/$uuid/follow');
  }

  Future<void> unfollowUser(String uuid) async {
    await http.dio.delete('/api/v1/users/$uuid/follow');
  }

  FollowListResult _parse(dynamic raw) {
    final map = raw is Map
        ? raw.cast<String, dynamic>()
        : jsonDecode(raw as String) as Map<String, dynamic>;

    final dataList = (map['data'] as List? ?? [])
        .map((e) => FollowListUser.fromJson((e as Map).cast<String, dynamic>()))
        .toList();

    return FollowListResult(
      users: dataList,
      nextCursor: map['next_cursor'] as String?,
    );
  }
}
