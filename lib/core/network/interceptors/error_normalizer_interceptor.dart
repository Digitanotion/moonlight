// lib/core/network/interceptors/error_normalizer_interceptor.dart
import 'package:dio/dio.dart';

class ApiException implements Exception {
  final int? code;
  final String message;
  final Map<String, dynamic>? errors;
  final dynamic data;
  ApiException({this.code, required this.message, this.errors, this.data});
  @override
  String toString() => 'ApiException($code): $message';
}

class ErrorNormalizerInterceptor extends Interceptor {
  @override
  void onError(DioError err, ErrorInterceptorHandler handler) {
    final resp = err.response;
    if (resp != null && resp.data != null) {
      try {
        final data = resp.data;
        String message = data['message']?.toString() ?? 'Unknown error';
        final errors = data['errors'] is Map ? Map<String, dynamic>.from(data['errors']) : null;
        final code = resp.statusCode;
        final apiEx = ApiException(code: code, message: message, errors: errors, data: data);
        return handler.next(DioError(requestOptions: err.requestOptions, response: resp, error: apiEx, type: err.type));
      } catch (e) {}
    }
    handler.next(err);
  }
}
