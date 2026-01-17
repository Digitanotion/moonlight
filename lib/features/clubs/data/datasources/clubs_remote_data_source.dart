import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:moonlight/features/clubs/domain/entities/club.dart';

abstract class ClubsRemoteDataSource {
  Future<List<Map<String, dynamic>>> getMyClubs();

  Future<Map<String, dynamic>> getMembersUI({
    required String club,
    Map<String, dynamic>? query,
  });

  Future<void> addMember({
    required String club,
    required Map<String, dynamic> body,
  });

  Future<void> changeMemberRole({
    required String club,
    required String member,
    required String role,
  });

  Future<void> removeMember({required String club, required String member});

  Future<void> transferOwnership({
    required String club,
    required Map<String, dynamic> body,
  });

  Future<void> createClub({required Map<String, dynamic> body});

  Future<void> updateClub({
    required String club,
    required Map<String, dynamic> body,
  });

  Future<void> deleteClub({required String club});
  Future<List<dynamic>> getPublicClubs();

  Future<void> joinClub({required String club});
  Future<void> leaveClub({required String club});
  Future<Club> getClub(String club);
  Future<List<Map<String, dynamic>>> getSuggestedClubs();
  Future<Map<String, dynamic>> getClubProfile(String club);
  Future<Map<String, dynamic>> createClubMultipart({
    required String name,
    String? description,
    String? motto,
    String? location,
    bool isPrivate = false,
    File? coverImage,
  });

  Future<Map<String, dynamic>> updateClubMultipart({
    required String club,
    required String name,
    String? description,
    String? motto,
    String? location,
    bool isPrivate = false,
    File? coverImage,
  });

  Future<List<Map<String, dynamic>>> searchUsers(String query);
  Future<void> donateToClub({
    required String club,
    required int coins,
    String? reason,
    required String idempotencyKey,
  });

  Future<int> getMyBalance();
}

class ClubsRemoteDataSourceImpl implements ClubsRemoteDataSource {
  final Dio dio;

  ClubsRemoteDataSourceImpl(this.dio);

  @override
  Future<List<Map<String, dynamic>>> getMyClubs() async {
    final res = await dio.get('/api/v1/clubs/my');
    return List<Map<String, dynamic>>.from(res.data['data'] ?? []);
  }

  @override
  Future<Map<String, dynamic>> getMembersUI({
    required String club,
    Map<String, dynamic>? query,
  }) async {
    final res = await dio.get(
      '/api/v1/clubs/$club/members/ui',
      queryParameters: query,
    );
    return Map<String, dynamic>.from(res.data['data']);
  }

  @override
  Future<void> addMember({
    required String club,
    required Map<String, dynamic> body,
  }) async {
    await dio.post('/api/v1/clubs/$club/members', data: body);
  }

  @override
  Future<void> changeMemberRole({
    required String club,
    required String member,
    required String role,
  }) async {
    await dio.patch(
      '/api/v1/clubs/$club/members/$member/role',
      data: {'role': role},
    );
  }

  @override
  Future<void> removeMember({
    required String club,
    required String member,
  }) async {
    await dio.delete('/api/v1/clubs/$club/members/$member');
  }

  @override
  Future<void> transferOwnership({
    required String club,
    required Map<String, dynamic> body,
  }) async {
    await dio.post('/api/v1/clubs/$club/transfer-ownership', data: body);
  }

  @override
  Future<void> createClub({required Map<String, dynamic> body}) async {
    await dio.post('/api/v1/clubs', data: body);
  }

  @override
  Future<Map<String, dynamic>> createClubMultipart({
    required String name,
    String? description,
    String? motto,
    String? location,
    bool isPrivate = false,
    File? coverImage,
  }) async {
    final form = FormData.fromMap({
      'name': name,
      if (description != null) 'description': description,
      if (motto != null) 'motto': motto,
      if (location != null) 'location': location,

      // 🔥 IMPORTANT FIX
      'is_private': isPrivate ? 1 : 0,

      if (coverImage != null)
        'cover_image': await MultipartFile.fromFile(
          coverImage.path,
          filename: coverImage.path.split('/').last,
        ),
    });

    final res = await dio.post(
      '/api/v1/clubs',
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );

    return res.data['data'];
  }

  @override
  Future<Map<String, dynamic>> updateClubMultipart({
    required String club,
    required String name,
    String? description,
    String? motto,
    String? location,
    bool? isPrivate,
    File? coverImage,
  }) async {
    final form = FormData.fromMap({
      '_method': 'PUT', // 🔥 CRITICAL: Add this for Laravel
      'name': name,
      if (description != null) 'description': description,
      if (motto != null) 'motto': motto,
      if (location != null) 'location': location,
      'is_private': isPrivate != null ? (isPrivate ? 1 : 0) : 0,
      if (coverImage != null)
        'cover_image': await MultipartFile.fromFile(
          coverImage.path,
          filename: coverImage.path.split('/').last,
        ),
    });

    debugPrint('📤 Sending with _method=PUT');

    // 🔥 Use POST instead of PUT when using _method
    final res = await dio.post('/api/v1/clubs/$club', data: form);

    return res.data['data'];
  }

  @override
  Future<void> updateClub({
    required String club,
    required Map<String, dynamic> body,
  }) async {
    await dio.put('/api/v1/clubs/$club', data: body);
  }

  @override
  Future<void> deleteClub({required String club}) async {
    await dio.delete('/api/v1/clubs/$club');
  }

  @override
  Future<List<dynamic>> getPublicClubs() async {
    final res = await dio.get('/api/v1/clubs');

    final data = res.data;

    if (data is Map<String, dynamic> && data['data'] is List) {
      return List<dynamic>.from(data['data']);
    }

    return [];
  }

  @override
  Future<void> joinClub({required String club}) {
    return dio.post('/api/v1/clubs/$club/join');
  }

  @override
  Future<void> leaveClub({required String club}) {
    return dio.delete('/api/v1/clubs/$club/join');
  }

  @override
  Future<List<Map<String, dynamic>>> getSuggestedClubs() async {
    final res = await dio.get('/api/v1/clubs/suggested');
    return List<Map<String, dynamic>>.from(res.data['data'] ?? []);
  }

  Future<Club> getClub(String club) async {
    final res = await dio.get('/api/v1/clubs/$club');
    return Club.fromJson(res.data['data']);
  }

  Future<Map<String, dynamic>> getClubProfile(String club) async {
    final res = await dio.get('/api/v1/clubs/$club/profile');
    return Map<String, dynamic>.from(res.data['data']);
  }

  @override
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final res = await dio.get(
      '/api/v1/users/search',
      queryParameters: {'q': query},
    );

    return List<Map<String, dynamic>>.from(res.data['data'] ?? []);
  }

  @override
  Future<void> donateToClub({
    required String club,
    required int coins,
    String? reason,
    required String idempotencyKey,
  }) async {
    await dio.post(
      '/api/v1/clubs/$club/donate',
      data: {
        'coins': coins,
        'reason': reason ?? '',
        // 'idempotency_key': idempotencyKey,
      },
    );
  }

  Future<int> getMyBalance() async {
    final res = await dio.get(
      '/api/v1/wallet',
      options: Options(responseType: ResponseType.json),
    );

    final data = res.data is Map
        ? res.data as Map<String, dynamic>
        : jsonDecode(res.data as String) as Map<String, dynamic>;

    return data['data']['balance'] as int;
  }
}
