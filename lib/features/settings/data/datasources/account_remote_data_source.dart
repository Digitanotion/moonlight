import 'package:dio/dio.dart';
import 'package:moonlight/core/errors/exceptions.dart';
import 'package:moonlight/features/settings/domain/entities/notification_settings.dart';

abstract class AccountRemoteDataSource {
  Future<void> deactivate({
    required String confirm,
    String? password,
    String? reason,
  });
  Future<void> reactivate();
  Future<void> deleteAccount({required String confirm, String? password});

  Future<NotificationSettings> getNotificationSettings();
  Future<void> updateNotificationSettings(NotificationSettings settings);
  Future<Map<String, dynamic>> getDeletionStatus();
  Future<void> requestDeletion({
    required String confirm,
    String? password,
    required String reason,
    String? feedback,
  });
  Future<void> cancelDeletion({required String confirm});
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
        '/api/v1/me/deactivate',
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
  Future<NotificationSettings> getNotificationSettings() async {
    try {
      final response = await dio.get('/api/v1/settings/account/notifications');

      if (response.statusCode == 200) {
        final data = response.data['data'];
        return NotificationSettings.fromJson(data);
      } else {
        throw ServerException('Failed to fetch notification settings');
      }
    } on DioException catch (e) {
      throw ServerException(_msg(e));
    }
  }

  @override
  Future<void> updateNotificationSettings(NotificationSettings settings) async {
    try {
      await dio.post(
        '/api/v1/settings/account/notifications',
        data: settings.toJson(),
      );
    } on DioException catch (e) {
      throw ServerException(_msg(e));
    }
  }

  @override
  Future<void> reactivate() async {
    try {
      await dio.post('/api/v1/me/reactivate');
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
        '/api/v1/me',
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

  @override
  Future<Map<String, dynamic>> getDeletionStatus() async {
    try {
      final response = await dio.get('/api/v1/me/delete/status');
      return response.data['data'] ?? {};
    } on DioException catch (e) {
      throw ServerException(_msg(e));
    }
  }

  @override
  Future<void> requestDeletion({
    required String confirm,
    String? password,
    required String reason,
    String? feedback,
  }) async {
    try {
      await dio.post(
        '/api/v1/me/delete/request',
        data: {
          'confirm': confirm,
          if (password != null && password.isNotEmpty) 'password': password,
          'reason': reason,
          if (feedback != null && feedback.isNotEmpty) 'feedback': feedback,
        },
      );
    } on DioException catch (e) {
      throw ServerException(_msg(e));
    }
  }

  @override
  Future<void> cancelDeletion({required String confirm}) async {
    try {
      await dio.post('/api/v1/me/delete/cancel', data: {'confirm': confirm});
    } on DioException catch (e) {
      throw ServerException(_msg(e));
    }
  }
}
