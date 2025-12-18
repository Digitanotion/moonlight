import 'dart:convert';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:dio/dio.dart';

class ProfileRemoteDataSource {
  final DioClient http;
  ProfileRemoteDataSource(this.http);

  Future<Map<String, dynamic>> getUser(String uuid) async {
    final res = await http.dio.get('/api/v1/users/$uuid');
    return res.data is Map
        ? res.data as Map<String, dynamic>
        : jsonDecode(res.data as String) as Map<String, dynamic>;
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
    return res.data is Map
        ? res.data as Map<String, dynamic>
        : jsonDecode(res.data as String) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> followUser(String uuid) async {
    final res = await http.dio.post('/api/v1/users/$uuid/follow');
    return res.data is Map
        ? res.data as Map<String, dynamic>
        : jsonDecode(res.data as String) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> unfollowUser(String uuid) async {
    final res = await http.dio.delete('/api/v1/users/$uuid/follow');
    return res.data is Map
        ? res.data as Map<String, dynamic>
        : jsonDecode(res.data as String) as Map<String, dynamic>;
  }
}
