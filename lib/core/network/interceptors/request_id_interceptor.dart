// lib/core/network/interceptors/request_id_interceptor.dart
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

class RequestIdInterceptor extends Interceptor {
  final Uuid _uuid = const Uuid();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['X-Request-ID'] = options.headers['X-Request-ID'] ?? _uuid.v4();
    handler.next(options);
  }
}
