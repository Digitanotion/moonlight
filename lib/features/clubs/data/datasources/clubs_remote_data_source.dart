import 'package:dio/dio.dart';

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
}
