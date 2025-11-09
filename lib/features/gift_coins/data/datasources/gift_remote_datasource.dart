import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:moonlight/core/network/dio_client.dart';
import '../../domain/entities/gift_user.dart';

class GiftRemoteDataSource {
  final DioClient http;

  GiftRemoteDataSource(this.http);

  /// Get current user's coin balance
  Future<int> getBalance() async {
    final res = await http.dio.get(
      '/api/v1/wallet',
      options: Options(responseType: ResponseType.json),
    );

    final data = res.data is Map
        ? res.data as Map<String, dynamic>
        : jsonDecode(res.data as String) as Map<String, dynamic>;

    return data['data']['balance'] as int;
  }

  /// Search users by query string
  Future<List<GiftUser>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];

    final res = await http.dio.get(
      '/api/v1/users/search',
      queryParameters: {'q': query},
      options: Options(responseType: ResponseType.json),
    );

    final data = res.data is Map
        ? res.data as Map<String, dynamic>
        : jsonDecode(res.data as String) as Map<String, dynamic>;

    final users = (data['data'] as List).map((u) {
      return GiftUser(
        username: u['user_slug'] ?? '',
        fullName: u['fullname'] ?? '',
        avatar: u['avatar_url'] ?? '',
        uuid: u['uuid'].toString(),
      );
    }).toList();

    return users;
  }

  /// Verify user's wallet PIN
  Future<void> verifyPin(String pin) async {
    final res = await http.dio.post(
      '/api/v1/wallet/pin/verify',
      data: {'pin': pin},
      options: Options(responseType: ResponseType.json),
    );

    if (res.statusCode != 200) {
      final msg = res.data is Map
          ? res.data['message'] ?? 'PIN verification failed'
          : 'PIN verification failed';
      throw Exception(msg);
    }
  }

  /// Transfer coins to another user
  Future<void> transferCoins({
    required String toUserUuid,
    required int coins,
    required String pin,
    String? reason,
    String? idempotencyKey,
  }) async {
    final body = {
      'to_user_uuid': toUserUuid,
      'coins': coins,
      'pin': pin,
      if (reason != null) 'reason': reason,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
    };

    final res = await http.dio.post(
      '/api/v1/wallet/transfer-request',
      data: body,
      options: Options(
        responseType: ResponseType.json,
        headers: {
          if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
        },
      ),
    );

    if (res.statusCode == 201) return; // success
    if (res.statusCode == 422) {
      final errors = res.data['errors'];
      throw Exception(errors.values.first.first.toString());
    }
    if (res.statusCode == 409) {
      throw Exception('Duplicate transfer request');
    }

    throw Exception('Failed to transfer coins');
  }
}
