import 'package:dio/dio.dart';
import 'package:moonlight/core/network/dio_client.dart';

class ChangeUsernameRemoteDataSource {
  final DioClient _dioClient;

  ChangeUsernameRemoteDataSource(this._dioClient);

  Future<Map<String, dynamic>> changeUsername({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        '/api/v1/settings/account/change-username',
        data: {'username': username.trim(), 'password': password},
        options: Options(validateStatus: (status) => status! < 500),
      );

      if (response.statusCode != 200) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
        );
      }

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Invalid response format');
      }

      return data;
    } on DioException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to change username: $e');
    }
  }

  Future<Map<String, dynamic>> checkUsername(String username) async {
    try {
      final response = await _dioClient.dio.get(
        '/api/v1/settings/account/check-username',
        queryParameters: {'username': username.trim()},
        options: Options(validateStatus: (status) => status! < 500),
      );

      if (response.statusCode != 200) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
        );
      }

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Invalid response format');
      }

      return data;
    } on DioException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to check username: $e');
    }
  }

  Future<Map<String, dynamic>> getUsernameHistory({
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final response = await _dioClient.dio.get(
        '/api/v1/settings/account/username-history',
        queryParameters: {
          'page': page,
          'per_page': perPage,
          'sort': 'changed_at',
          'order': 'desc',
        },
        options: Options(validateStatus: (status) => status! < 500),
      );

      if (response.statusCode != 200) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
        );
      }

      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Invalid response format');
      }

      return data;
    } on DioException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to get username history: $e');
    }
  }
}
