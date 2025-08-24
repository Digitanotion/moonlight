import 'package:dio/dio.dart';
import 'package:moonlight/core/errors/exceptions.dart';

abstract class AccountRemoteDataSource {
  Future<void> deactivate({
    required String confirm,
    String? password,
    String? reason,
  });
  Future<void> reactivate();
  Future<void> deleteAccount({required String confirm, String? password});
}

class AccountRemoteDataSourceImpl implements AccountRemoteDataSource {
  final Dio dio; // already configured with baseUrl + bearer interceptor
  AccountRemoteDataSourceImpl(this.dio);

  @override
  Future<void> deactivate({
    required String confirm,
    String? password,
    String? reason,
  }) async {
    try {
      await dio.post(
        '/v1/me/deactivate',
        data: {
          'confirm': confirm, // "DEACTIVATE"
          if (password != null && password.isNotEmpty) 'password': password,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
      );
    } on DioException catch (e) {
      throw ServerException(_msg(e));
    }
  }

  @override
  Future<void> reactivate() async {
    try {
      await dio.post('/v1/me/reactivate');
    } on DioException catch (e) {
      throw ServerException(_msg(e));
    }
  }

  @override
  Future<void> deleteAccount({
    required String confirm,
    String? password,
  }) async {
    try {
      await dio.delete(
        '/v1/me',
        data: {
          'confirm': confirm, // "DELETE"
          if (password != null && password.isNotEmpty) 'password': password,
        },
      );
    } on DioException catch (e) {
      throw ServerException(_msg(e));
    }
  }

  String _msg(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    return 'HTTP $status ${e.requestOptions.method} ${e.requestOptions.path} ${data is Map ? (data['message'] ?? data.toString()) : ''}'
        .trim();
  }
}
