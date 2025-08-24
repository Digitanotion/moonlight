import 'package:dio/dio.dart';

String extractApiMessage(Object error) {
  if (error is DioException) {
    // If the server sent a JSON body with "message"
    final response = error.response;
    if (response != null) {
      try {
        final data = response.data;
        if (data is Map && data['error'] != null) {
          return data['error'].toString();
        }
        // fallback: stringify whole body
        return data.toString();
      } catch (_) {
        return response.statusMessage ?? "Unknown server error";
      }
    }
    return error.message ?? "Network error";
  }
  // Not a Dio error, just stringify
  return error.toString();
}
