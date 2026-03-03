// lib/core/network/dio_client.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

abstract class AuthTokenProvider {
  Future<String?> readToken();
}

class DioClient {
  final Dio dio;

  DioClient(String baseUrl, AuthTokenProvider tokenProvider)
    : dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(
            seconds: 120,
          ), // Increased to 60 seconds for uploads
          headers: {'Accept': 'application/json'},
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          String? token = await tokenProvider.readToken();

          if (token != null && token.startsWith('Bearer ')) {
            token = token.substring(7);
          }

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          // ✅ Set longer timeouts for upload requests
          if (options.method == 'POST' || options.method == 'PUT') {
            if (options.data is FormData) {
              // This is a file upload - increase timeouts even more
              options.sendTimeout = const Duration(seconds: 240);
              options.receiveTimeout = const Duration(seconds: 240);
              print('📤 File upload detected - extended timeouts set');
            }
          }

          print('➡️ ${options.method} ${options.uri}');
          print(
            '   Authorization: ${options.headers['Authorization'] ?? '(none)'}',
          );
          print('   Headers: ${options.headers}');
          print('   Query: ${options.queryParameters}');
          print('   Body: ${options.data}');
          print('   Send Timeout: ${options.sendTimeout}');
          print('   Receive Timeout: ${options.receiveTimeout}');

          handler.next(options);
        },

        onResponse: (resp, handler) {
          print('⬅️ ${resp.statusCode} ${resp.requestOptions.uri}');
          print('   Response headers: ${resp.headers.map}');
          print('   Body: ${resp.data}');
          handler.next(resp);
        },
        onError: (e, handler) {
          print(
            '❌ ${e.response?.statusCode} ${e.requestOptions.method} ${e.requestOptions.uri}',
          );
          print('❌ Error type: ${e.type}');
          print('❌ Message: ${e.message}');

          // ✅ Handle timeout errors gracefully
          if (e.type == DioExceptionType.sendTimeout) {
            e = DioException(
              requestOptions: e.requestOptions,
              error:
                  'Upload is taking longer than expected. Your file might be too large or your connection is slow.',
              type: e.type,
            );
          } else if (e.type == DioExceptionType.receiveTimeout) {
            e = DioException(
              requestOptions: e.requestOptions,
              error: 'Server is taking too long to respond. Please try again.',
              type: e.type,
            );
          }

          handler.next(e);
        },
      ),
    );

    dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestBody: true,
        responseBody: true,
        error: true,
      ),
    );
  }
}
