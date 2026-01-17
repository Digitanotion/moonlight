import 'package:dio/dio.dart';
import 'package:moonlight/core/network/dio_client.dart';

class ChangeEmailRemoteDataSource {
  final DioClient _dioClient;

  ChangeEmailRemoteDataSource(this._dioClient);

  Future<Map<String, dynamic>> requestEmailChange({
    required String newEmail,
    required String confirmNewEmail,
    required String password,
  }) async {
    final response = await _dioClient.dio.post(
      '/api/v1/settings/account/change-email/request',
      data: {
        'new_email': newEmail,
        'confirm_new_email': confirmNewEmail,
        'password': password,
      },
    );

    return response.data;
  }

  Future<Map<String, dynamic>> verifyEmailChange({
    required int requestId,
    required String verificationCode,
  }) async {
    final response = await _dioClient.dio.post(
      '/api/v1/settings/account/change-email/verify',
      data: {'request_id': requestId, 'verification_code': verificationCode},
    );

    return response.data;
  }

  Future<Map<String, dynamic>> confirmEmailChange({
    required String token,
  }) async {
    final response = await _dioClient.dio.post(
      '/api/v1/settings/account/change-email/confirm',
      data: {'token': token},
    );

    return response.data;
  }

  Future<Map<String, dynamic>> cancelEmailChange({
    required int requestId,
  }) async {
    final response = await _dioClient.dio.post(
      '/api/v1/settings/account/change-email/cancel',
      data: {'request_id': requestId},
    );

    return response.data;
  }

  Future<Map<String, dynamic>> resendVerificationCode({
    required int requestId,
  }) async {
    final response = await _dioClient.dio.post(
      '/api/v1/settings/account/change-email/resend',
      data: {'request_id': requestId},
    );

    return response.data;
  }
}
