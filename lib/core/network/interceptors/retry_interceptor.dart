// lib/core/network/interceptors/retry_interceptor.dart
import 'dart:math';
import 'package:dio/dio.dart';

class RetryInterceptor extends Interceptor {
  final int maxRetries;
  RetryInterceptor({this.maxRetries = 3});

  bool _shouldRetry(RequestOptions options, DioError err) {
    if (options.method.toUpperCase() == 'GET') return true;
    if (options.method.toUpperCase() == 'POST') {
      final idemp = options.headers['Idempotency-Key'] as String?;
      if (idemp != null && idemp.isNotEmpty) return true;
    }
    return false;
  }

  @override
  Future<void> onError(DioError err, ErrorInterceptorHandler handler) async {
    final opts = err.requestOptions;
    final retries = (opts.extra['retry_count'] as int?) ?? 0;

    if (retries >= maxRetries || !_shouldRetry(opts, err)) {
      return handler.next(err);
    }

    final backoff = pow(2, retries) * 200;
    await Future.delayed(Duration(milliseconds: backoff.toInt() + Random().nextInt(100)));
    opts.extra['retry_count'] = retries + 1;

    try {
      final response = await err.requestOptions.extra['dio'].fetch(opts);
      return handler.resolve(response);
    } catch (e) {
      return handler.next(err);
    }
  }
}
