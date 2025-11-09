import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:moonlight/core/network/dio_client.dart';

class WithdrawalRemoteDataSource {
  final DioClient http;

  WithdrawalRemoteDataSource(this.http);

  /// Get current user's withdrawable balance
  Future<int> getWithdrawableBalance() async {
    final res = await http.dio.get(
      '/api/v1/wallet',
      options: Options(responseType: ResponseType.json),
    );

    final data = res.data is Map
        ? res.data as Map<String, dynamic>
        : jsonDecode(res.data as String) as Map<String, dynamic>;

    return data['data']['balance'] as int;
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

  /// Create withdrawal request
  Future<Map<String, dynamic>> createWithdrawalRequest({
    required int amountUsdCents,
    required String bankAccountName,
    required String bankAccountNumber,
    required String bankName,
    required String country,
    String? swift,
    String? email,
    String? phone,
    String? reason,
    required String pin,
    String? idempotencyKey,
  }) async {
    amountUsdCents = amountUsdCents;
    final body = {
      'amount_usd_cents': amountUsdCents,
      'bank_account_name': bankAccountName,
      'bank_account_number': bankAccountNumber,
      'bank_name': bankName,
      'country': country,
      'pin': pin,
      if (swift != null) 'swift': swift,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (reason != null) 'reason': reason,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
    };

    print(body.toString());
    final res = await http.dio.post(
      '/api/v1/wallet/withdraw-request',
      data: body,
      options: Options(
        responseType: ResponseType.json,
        headers: {
          if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
        },
      ),
    );

    print(res.toString());

    if (res.statusCode == 201) {
      return res.data is Map
          ? res.data as Map<String, dynamic>
          : jsonDecode(res.data as String) as Map<String, dynamic>;
    }

    if (res.statusCode == 422) {
      final errors = res.data['errors'];
      throw Exception(errors.values.first.first.toString());
    }
    if (res.statusCode == 409) {
      throw Exception('Duplicate withdrawal request');
    }

    throw Exception('Failed to create withdrawal request');
  }
}
