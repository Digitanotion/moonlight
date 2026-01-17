import 'package:dio/dio.dart';
import 'package:moonlight/core/network/dio_client.dart';

class PinRemoteDataSource {
  final DioClient _dioClient;

  PinRemoteDataSource(this._dioClient);

  Future<Map<String, dynamic>> setPin({
    required String pin,
    required String confirmPin,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        '/api/v1/settings/wallet-pin/set',
        data: {'pin': pin, 'confirm_pin': confirmPin},
      );

      return _parseResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to set PIN');
    }
  }

  Future<Map<String, dynamic>> resetPin({
    required String currentPin,
    required String newPin,
    required String confirmNewPin,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        '/api/v1/settings/wallet-pin/reset',
        data: {
          'current_pin': currentPin,
          'new_pin': newPin,
          'confirm_new_pin': confirmNewPin,
        },
      );

      return _parseResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to reset PIN');
    }
  }

  Future<Map<String, dynamic>> verifyPin(String pin) async {
    try {
      // Note: Adjust endpoint based on your actual API
      // If no verify endpoint exists, you can simulate verification
      // by trying to reset with dummy new PIN
      final response = await _dioClient.dio.post(
        '/api/v1/settings/wallet-pin/verify', // Adjust if needed
        data: {'pin': pin},
      );

      return _parseResponse(response);
    } on DioException catch (e) {
      // If endpoint doesn't exist, you can create a mock verification
      // or handle it differently in the repository
      throw _handleDioError(e, 'Failed to verify PIN');
    }
  }

  Future<Map<String, dynamic>> getPinStatus() async {
    try {
      final response = await _dioClient.dio.get(
        '/api/v1/settings/wallet-pin/status',
      );

      return _parseResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to get PIN status');
    }
  }

  Future<Map<String, dynamic>> unlockPin({
    required String method,
    String? securityAnswer,
  }) async {
    try {
      final data = {
        'method': method,
        if (securityAnswer != null) 'security_answer': securityAnswer,
      };

      final response = await _dioClient.dio.post(
        '/api/v1/settings/wallet-pin/unlock',
        data: data,
      );

      return _parseResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to unlock PIN');
    }
  }

  Future<Map<String, dynamic>> getPinHistory({
    int page = 1,
    int perPage = 10,
    String? action,
  }) async {
    try {
      final params = {
        'page': page,
        'per_page': perPage,
        if (action != null) 'action': action,
      };

      final response = await _dioClient.dio.get(
        '/api/v1/settings/wallet-pin/history',
        queryParameters: params,
      );

      return _parseResponse(response);
    } on DioException catch (e) {
      throw _handleDioError(e, 'Failed to get PIN history');
    }
  }

  Map<String, dynamic> _parseResponse(Response response) {
    if (response.statusCode != null &&
        response.statusCode! >= 200 &&
        response.statusCode! < 300) {
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      } else if (response.data != null) {
        return {'status': 'success', 'data': response.data};
      } else {
        return {'status': 'success'};
      }
    }

    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
    );
  }

  DioException _handleDioError(DioException e, String defaultMessage) {
    if (e.response != null) {
      // Pass through the response for detailed error handling in cubit
      return e;
    }

    // Network or other errors
    return DioException(
      requestOptions: e.requestOptions,
      error: defaultMessage,
      type: e.type,
    );
  }
}
