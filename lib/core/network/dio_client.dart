// lib/core/network/dio_client.dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // for debugPrint

/// Anything that can provide a token (e.g., SharedPreferences-backed class)
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
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 20),
          headers: {'Accept': 'application/json'},
          // Let Dio auto-set content-type (JSON vs multipart) per request
          // contentType: null,
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Read token from the provided source
          String? token = await tokenProvider.readToken();

          // Sanitize accidental "Bearer " prefix if caller saved it that way
          if (token != null && token.startsWith('Bearer ')) {
            token = token.substring(7);
          }

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          // Helpful one-liners while debugging
          print('➡️  ${options.method} ${options.uri}');
          print(
            '   Authorization: ${options.headers['Authorization'] ?? '(none)'}',
          );
          print('➡️ ${options.method} ${options.uri}');
          print('   Headers: ${options.headers}');
          print('   Query: ${options.queryParameters}');
          print('   Body: ${options.data}');

          handler.next(options);
        },

        onResponse: (resp, handler) {
          print('⬅️ ${resp.statusCode} ${resp.requestOptions.uri}');
          print('   Response headers: ${resp.headers.map}');
          print('   Body: ${resp.data}');
          handler.next(resp);
        },
        onError: (e, handler) {
          // Compact error visibility
          print(
            '❌ ${e.response?.statusCode} ${e.requestOptions.method} ${e.requestOptions.uri}',
          );
          handler.next(e);
          //New Patch
          // Normalize messages for UI
          // final data = e.response?.data;
          // final msg = (data is Map && data['message'] is String)
          //     ? data['message'] as String
          //     : 'Something went wrong. Please try again.';
          // handler.next(e..error = msg);
        },
      ),
    );

    // Optional: verbose logs (disable for release)
    // dio.interceptors.add(LogInterceptor(
    //   requestHeader: true,
    //   requestBody: true,
    //   responseHeader: false,
    //   responseBody: false,
    //   error: true,
    // ));
  }
}
