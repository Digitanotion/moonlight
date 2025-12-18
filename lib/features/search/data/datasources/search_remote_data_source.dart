import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:moonlight/core/errors/exceptions.dart';
import 'package:moonlight/core/network/dio_client.dart';
import '../models/search_models.dart';

abstract class SearchRemoteDataSource {
  Future<List<dynamic>> search(String query);
  Future<List<TagModel>> getTrendingTags();
  Future<List<UserModel>> getSuggestedUsers();
  Future<List<ClubModel>> getPopularClubs();
}

class SearchRemoteDataSourceImpl implements SearchRemoteDataSource {
  final DioClient http;
  SearchRemoteDataSourceImpl(this.http);

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    if (data is String) {
      try {
        final m = jsonDecode(data);
        if (m is Map) return m.cast<String, dynamic>();
      } catch (_) {}
    }
    return {};
  }

  @override
  Future<List<dynamic>> search(String query) async {
    try {
      final res = await http.dio.get(
        '/api/v1/search',
        queryParameters: {'q': query},
      );

      final map = _asMap(res.data);
      final users = (map['users'] as List? ?? [])
          .map((e) => UserModel.fromMap((e as Map).cast<String, dynamic>()))
          .toList();

      final clubs = (map['clubs'] as List? ?? [])
          .map((e) => ClubModel.fromMap((e as Map).cast<String, dynamic>()))
          .toList();

      final tags = (map['tags'] as List? ?? [])
          .map((e) => TagModel.fromMap((e as Map).cast<String, dynamic>()))
          .toList();

      return [...users, ...clubs, ...tags];
    } on DioException catch (e) {
      throw ServerException(e.message ?? 'Search failed');
    }
  }

  @override
  Future<List<TagModel>> getTrendingTags() async {
    try {
      final res = await http.dio.get('/api/v1/search/trending-tags');
      final map = _asMap(res.data);
      return (map['data'] as List? ?? [])
          .map((e) => TagModel.fromMap((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException {
      throw ServerException('Failed to load trending tags');
    }
  }

  @override
  Future<List<UserModel>> getSuggestedUsers() async {
    try {
      final res = await http.dio.get('/api/v1/search/suggested-users');
      final map = _asMap(res.data);
      return (map['data'] as List? ?? [])
          .map((e) => UserModel.fromMap((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException {
      throw ServerException('Failed to load suggested users');
    }
  }

  @override
  Future<List<ClubModel>> getPopularClubs() async {
    try {
      final res = await http.dio.get('/api/v1/search/popular-clubs');
      final map = _asMap(res.data);
      return (map['data'] as List? ?? [])
          .map((e) => ClubModel.fromMap((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException {
      throw ServerException('Failed to load popular clubs');
    }
  }
}
