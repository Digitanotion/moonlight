// lib/core/network/interceptors/retry_interceptor.dart
import 'dart:math';
import 'package:dio/dio.dart';

class RetryInterceptor extends Interceptor {
  final int maxRetries;
  RetryInterceptor({this.maxRetries = 3});

  /// Status codes that represent a *transient* server condition and are
  /// safe to retry. Everything else in the 4xx range is a permanent
  /// client/validation/permission error — retrying it just delays the
  /// error the user needs to see, and for financial writes (withdrawals,
  /// purchases) re-attempts the operation against the payment provider.
  static const _retryableStatus = {408, 425, 429, 500, 502, 503, 504};

  static const _retryableTypes = {
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.connectionError,
  };

  bool _methodIsRetryable(RequestOptions options) {
    final method = options.method.toUpperCase();
    if (method == 'GET' || method == 'HEAD') return true;
    // A non-GET is only safe to replay if it carries an idempotency key
    // the server honours.
    if (method == 'POST' || method == 'PUT' || method == 'PATCH') {
      final idemp = options.headers['Idempotency-Key'] as String?;
      return idemp != null && idemp.isNotEmpty;
    }
    return false;
  }

  bool _shouldRetry(RequestOptions options, DioException err) {
    if (!_methodIsRetryable(options)) return false;

    // Transport-level failure (never reached the server, or no complete
    // response) — retrying is worthwhile.
    if (_retryableTypes.contains(err.type)) return true;

    // Got a response — only retry the explicitly transient ones. A 400 /
    // 401 / 403 / 422 must surface immediately.
    final status = err.response?.statusCode;
    if (status != null) return _retryableStatus.contains(status);

    // Unknown / unclassified error with no response — treat as transient.
    return err.type == DioExceptionType.unknown;
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final opts = err.requestOptions;
    final retries = (opts.extra['retry_count'] as int?) ?? 0;

    if (retries >= maxRetries || !_shouldRetry(opts, err)) {
      return handler.next(err);
    }

    final backoff = pow(2, retries) * 200;
    await Future.delayed(
      Duration(milliseconds: backoff.toInt() + Random().nextInt(100)),
    );
    opts.extra['retry_count'] = retries + 1;

    try {
      final response = await err.requestOptions.extra['dio'].fetch(opts);
      return handler.resolve(response);
    } catch (e) {
      return handler.next(err);
    }
  }
}
