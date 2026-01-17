import 'package:dio/dio.dart';
import 'package:moonlight/core/network/dio_client.dart';

class BlockedUsersRemoteDataSource {
  final DioClient _dioClient;

  BlockedUsersRemoteDataSource(this._dioClient);

  Future<Map<String, dynamic>> getBlockedUsers({
    int page = 1,
    int perPage = 20,
    String? search,
  }) async {
    final params = {
      'page': page,
      'per_page': perPage,
      if (search != null && search.isNotEmpty) 'search': search,
    };

    final response = await _dioClient.dio.get(
      '/api/v1/settings/blocked-users',
      queryParameters: params,
    );

    return response.data;
  }

  Future<Map<String, dynamic>> searchUsers(String query) async {
    final response = await _dioClient.dio.get(
      '/api/v1/settings/blocked-users/search',
      queryParameters: {'q': query},
    );

    return response.data;
  }

  Future<Map<String, dynamic>> blockUser({
    required String userUuid,
    String? reason,
  }) async {
    final response = await _dioClient.dio.post(
      '/api/v1/settings/blocked-users/$userUuid/block',
      data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );

    return response.data;
  }

  Future<Map<String, dynamic>> unblockUser(String userUuid) async {
    final response = await _dioClient.dio.delete(
      '/api/v1/settings/blocked-users/$userUuid/block',
    );

    return response.data;
  }

  Future<Map<String, dynamic>> toggleBlockUser({
    required String userUuid,
    String? reason,
  }) async {
    final response = await _dioClient.dio.post(
      '/api/v1/settings/blocked-users/$userUuid/toggle',
      data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );

    return response.data;
  }

  Future<Map<String, dynamic>> getBlockStats() async {
    final response = await _dioClient.dio.get(
      '/api/v1/settings/blocked-users/stats',
    );

    return response.data;
  }

  Future<Map<String, dynamic>> checkBlockStatus(String userUuid) async {
    final response = await _dioClient.dio.get(
      '/api/v1/settings/blocked-users/$userUuid/status',
    );

    return response.data;
  }

  Future<Map<String, dynamic>> bulkBlockUsers({
    required List<String> userUuids,
    String? reason,
  }) async {
    final response = await _dioClient.dio.post(
      '/api/v1/settings/blocked-users/bulk',
      data: {
        'user_uuids': userUuids,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );

    return response.data;
  }
}
