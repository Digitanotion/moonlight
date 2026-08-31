// lib/core/network/interceptors/error_normalizer_interceptor.dart
import 'dart:convert';

import 'package:dio/dio.dart';

/// A clean, already-humanised API error. `toString()` is JUST the message —
/// no class name, no code prefix — so even code that naively shows
/// `e.toString()` to the user gets something readable.
class ApiException implements Exception {
  final int? code;
  final String message;
  final Map<String, dynamic>? errors;
  final dynamic data;
  ApiException({this.code, required this.message, this.errors, this.data});
  @override
  String toString() => message;
}

/// Turns every DioException into a DioException whose `.error` is an
/// [ApiException] carrying a plain, user-facing message — the server's own
/// `message`/validation text when there is one, otherwise a friendly
/// network/timeout line. Callers should surface `apiErrorMessage(e)` (or
/// just `e.toString()` in a pinch); either way the user never sees
/// "DioException", stack frames, or a raw JSON blob.
class ErrorNormalizerInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final resp = err.response;
    ApiException apiEx;

    if (resp != null && resp.data != null) {
      apiEx = ApiException(
        code: resp.statusCode,
        message: _messageFromBody(resp.data) ??
            _friendlyForStatus(resp.statusCode),
        errors: (resp.data is Map && resp.data['errors'] is Map)
            ? Map<String, dynamic>.from(resp.data['errors'])
            : null,
        data: resp.data,
      );
    } else {
      apiEx = ApiException(
        code: null,
        message: _friendlyForType(err.type),
      );
    }

    handler.next(
      DioException(
        requestOptions: err.requestOptions,
        response: resp,
        type: err.type,
        error: apiEx,
      ),
    );
  }

  String? _messageFromBody(dynamic data) {
    Map? map;
    if (data is Map) {
      map = data;
    } else if (data is String) {
      final t = data.trimLeft();
      if (t.startsWith('{')) {
        try {
          final decoded = jsonDecode(data);
          if (decoded is Map) map = decoded;
        } catch (_) {}
      }
    }
    if (map == null) return null;

    // Laravel validation: { message, errors: { field: [msg, ...] } }
    final errors = map['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      final msg = first is List && first.isNotEmpty
          ? first.first.toString()
          : first.toString();
      if (msg.trim().isNotEmpty) return msg.trim();
    }

    for (final key in const ['message', 'error', 'detail']) {
      final v = map[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      if (v is Map && v['message'] is String) {
        return (v['message'] as String).trim();
      }
    }
    return null;
  }

  String _friendlyForType(DioExceptionType type) {
    switch (type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The request timed out. Please try again.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Check your network and try again.';
      case DioExceptionType.badCertificate:
        return 'Could not establish a secure connection.';
      case DioExceptionType.cancel:
        return 'Request cancelled.';
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return 'Something went wrong. Please try again.';
    }
  }

  String _friendlyForStatus(int? status) {
    switch (status) {
      case 400:
        return 'That request could not be processed.';
      case 401:
        return 'Your session has expired. Please sign in again.';
      case 403:
        return "You don't have permission to do that.";
      case 404:
        return 'Not found.';
      case 419:
        return 'Your session expired. Please try again.';
      case 429:
        return "You're doing that too fast. Please wait a moment.";
      case 500:
      case 502:
      case 503:
      case 504:
        return 'The server is having trouble right now. Please try again shortly.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
