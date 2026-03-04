// lib/features/withdrawal/data/datasources/withdrawal_remote_datasource.dart

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:moonlight/core/network/dio_client.dart';

class WithdrawalRemoteDataSource {
  final DioClient http;
  WithdrawalRemoteDataSource(this.http);

  Future<int> getWithdrawableBalance() async {
    final res = await http.dio.get('/api/v1/wallet');
    final data = _extract(res);
    return data['data']['balance'] as int; // ← use withdrawable_cents
  }

  Future<void> verifyPin(String pin) async {
    final res = await http.dio.post(
      '/api/v1/settings/wallet-pin/verify',
      data: {'pin': pin},
    );
    if ((res.statusCode ?? 0) != 200) {
      throw Exception(_extract(res)['message'] ?? 'Invalid PIN');
    }
  }

  Future<List<Map<String, dynamic>>> fetchBanks(String country) async {
    final res = await http.dio.get(
      '/api/v1/wallet/banks',
      queryParameters: {'country': country},
    );
    final data = _extract(res);
    return List<Map<String, dynamic>>.from(data['data'] as List);
  }

  Future<Map<String, dynamic>> createWithdrawalRequest({
    required int amountUsdCents,
    required String bankAccountName,
    required String bankAccountNumber,
    required String bankName,
    required String bankCode, // ← NEW
    required String country,
    String? swift,
    String? email,
    String? phone,
    String? reason,
    required String pin,
    String? idempotencyKey,
  }) async {
    final body = {
      'amount_usd_cents': amountUsdCents,
      'bank_account_name': bankAccountName,
      'bank_account_number': bankAccountNumber,
      'bank_name': bankName,
      'bank_code': bankCode, // ← NEW
      'country': country,
      'pin': pin,
      if (swift != null) 'swift': swift,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (reason != null) 'reason': reason,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
    };

    final res = await http.dio.post(
      '/api/v1/wallet/withdraw-request',
      data: body,
    );
    final statusCode = res.statusCode ?? 0;

    if (statusCode == 201) return _extract(res);
    if (statusCode == 422) {
      final errors = _extract(res)['errors'] as Map?;
      throw Exception(
        errors?.values.first?.first?.toString() ?? 'Validation error',
      );
    }
    if (statusCode == 409) throw Exception('Duplicate withdrawal request');

    throw Exception(_extract(res)['message'] ?? 'Withdrawal failed');
  }

  Map<String, dynamic> _extract(Response res) {
    if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
    return Map<String, dynamic>.from(jsonDecode(res.data as String) as Map);
  }
}
