import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';

/// Returns a clean, user-facing message for any error object.
/// Feed this into MoonSnack.error(context, apiErrorMessage(state.error));
String apiErrorMessage(Object? error) {
  if (error == null) return "An unexpected error occurred";

  // 1) Dio-specific handling
  if (error is DioException) {
    // Network/timeout/cancel without a server response
    if (error.response == null) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return "Request timed out. Please try again.";
        case DioExceptionType.connectionError:
          return "Network error. Check your internet connection.";
        case DioExceptionType.cancel:
          return "Request was cancelled.";
        case DioExceptionType.badCertificate:
          return "Secure connection failed.";
        case DioExceptionType.unknown:
        case DioExceptionType.badResponse:
          // fall through; try parse response if present
          break;
      }
    }

    // Server responded – try to extract a clean message
    final res = error.response;
    if (res != null) {
      final data = res.data;

      // If data is already a Map (most common in JSON APIs)
      if (data is Map) {
        // Standard Laravel: { message: "...", errors: { field: [..] } }
        final msg = _stringOrNull(data['message']);
        final errs = data['errors'];
        final validation = _flattenValidationErrors(errs);
        if (validation != null && validation.isNotEmpty) {
          // Show validation messages joined. If there's also a message, prepend once.
          if (msg != null && msg.trim().isNotEmpty) {
            return "$msg: $validation";
          }
          return validation;
        }
        if (msg != null && msg.trim().isNotEmpty) return msg;

        // Other possible shapes from some APIs:
        // { error: "..." } or { error: { message: "..." } }
        final flatError =
            _stringOrNull(data['error']) ??
            _stringOrNull(
              (data['error'] is Map) ? data['error']['message'] : null,
            );
        if (flatError != null && flatError.trim().isNotEmpty) return flatError;

        // No obvious message; stringify safely
        return _safeStringifyMap(data);
      }

      // If data is a String (sometimes servers return a text or HTML error body)
      if (data is String) {
        // Try parse JSON string first
        try {
          final parsed = json.decode(data);
          if (parsed is Map) {
            final msg =
                _stringOrNull(parsed['message']) ??
                _stringOrNull(parsed['error']) ??
                _stringOrNull(
                  (parsed['error'] is Map) ? parsed['error']['message'] : null,
                );
            final validation = _flattenValidationErrors(parsed['errors']);
            if (validation != null && validation.isNotEmpty) {
              return (msg != null && msg.trim().isNotEmpty)
                  ? "$msg: $validation"
                  : validation;
            }
            if (msg != null && msg.trim().isNotEmpty) return msg;
            return _safeStringifyMap(parsed);
          }
          // If parsed is List, join to a readable line
          if (parsed is List) return parsed.map((e) => e.toString()).join(", ");
        } catch (_) {
          // Not JSON; return trimmed text (avoid long HTML)
          final t = data.trim();
          if (t.isEmpty)
            return res.statusMessage ?? "Server error (${res.statusCode})";
          // crude cleanup for HTML bodies
          return t.length > 240 ? "${t.substring(0, 240)}…" : t;
        }
      }

      // Unknown body type
      return res.statusMessage ?? "Server error (${res.statusCode})";
    }

    // Nothing else matched; fall back to Dio's message (sanitized)
    return _cleanTechPrefixes(error.message ?? "Something went wrong");
  }

  // 2) Common Dart exceptions
  if (error is TimeoutException) return "Request timed out. Please try again.";
  if (error is SocketException)
    return "Network unreachable. Please check your connection.";
  if (error is FormatException) return "Invalid response from server.";

  // 3) Your domain Failures or custom errors
  final asString = error.toString();
  // If you have a Failure class with a message, handle it here:
  // if (error is Failure) return error.message;

  // 4) Fallback: clean technical prefixes from exception strings
  return _cleanTechPrefixes(asString);
}

String? _stringOrNull(Object? v) => v == null ? null : v.toString();

/// Laravel validation { errors: { field: ["msg1","msg2"], ... } } -> "msg1, msg2, ..."
String? _flattenValidationErrors(Object? errors) {
  if (errors is Map) {
    final parts = <String>[];
    errors.forEach((key, value) {
      if (value is List) {
        parts.addAll(value.whereType<Object>().map((e) => e.toString()));
      } else if (value != null) {
        parts.add(value.toString());
      }
    });
    if (parts.isNotEmpty) return parts.join(", ");
  }
  return null;
}

String _safeStringifyMap(Map data) {
  // prefer message-like fields if exist
  final msg =
      data['message'] ?? data['error'] ?? data['detail'] ?? data.toString();
  return msg.toString();
}

/// Remove noisy class prefixes like "DioException: " from messages.
String _cleanTechPrefixes(String input) {
  final cleaned = input
      .replaceAll(
        RegExp(r'^DioError(\s*\[.*?\])?:\s*', caseSensitive: false),
        '',
      )
      .replaceAll(
        RegExp(r'^DioException(\s*\[.*?\])?:\s*', caseSensitive: false),
        '',
      )
      .replaceAll(RegExp(r'Unhandled Exception:\s*', caseSensitive: false), '');
  return cleaned.trim().isEmpty
      ? "An unexpected error occurred"
      : cleaned.trim();
}
