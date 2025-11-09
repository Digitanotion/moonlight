import 'package:dio/dio.dart';
import 'package:moonlight/core/network/dio_client.dart';

abstract class PinRemoteDataSource {
  /// Sends the pin to remote API. Throws DioError on network / HTTP error.
  Future<void> setPin({required String pin});
}

class PinRemoteDataSourceImpl implements PinRemoteDataSource {
  final Dio client;
  PinRemoteDataSourceImpl({required this.client});

  @override
  Future<void> setPin({required String pin}) async {
    final path = '/api/v1/wallet/pin/set';

    // call
    final resp = await client.post(path, data: {'pin': pin});

    // Normalize body: if resp is a Dio Response, extract resp.data
    final dynamic body = resp is Response ? resp.data : resp;

    // Accept Map responses (most likely) or treat non-map as success if 2xx
    if (body is Map<String, dynamic>) {
      final status = body['status']?.toString().toLowerCase();
      if (status == 'success') {
        return;
      }

      final message = body['message']?.toString() ?? 'Failed to set PIN';
      throw Exception(message);
    }

    // If backend returned a non-map (string / empty), try to infer success
    // If the Dio Response had a statusCode we can check it:
    if (resp is Response && (resp.statusCode != null)) {
      final code = resp.statusCode!;
      if (code >= 200 && code < 300) {
        // treat as success even if body isn't JSON map
        return;
      } else {
        throw Exception('Failed to set PIN (HTTP $code)');
      }
    }

    // Fallback: treat unknown as success (or change to throw if you prefer)
    return;
  }
}
