// lib/features/withdrawal/data/datasources/withdrawal_remote_datasource.dart

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:moonlight/core/network/dio_client.dart';

class WithdrawalRemoteDataSource {
  final DioClient http;
  WithdrawalRemoteDataSource(this.http);

  // ── Balance ────────────────────────────────────────────────────────────────

  Future<int> getWithdrawableBalance() async {
    final res = await http.dio.get('/api/v1/wallet');
    final data = _extract(res);
    // withdrawable_cents is the server-authoritative withdrawable amount.
    return (data['data']['withdrawable_cents'] as num).toInt();
  }

  // ── PIN verify ─────────────────────────────────────────────────────────────

  Future<void> verifyPin(String pin) async {
    final res = await http.dio.post(
      '/api/v1/settings/wallet-pin/verify',
      data: {'pin': pin},
    );
    if ((res.statusCode ?? 0) != 200) {
      throw Exception(_extract(res)['message'] ?? 'Invalid PIN');
    }
  }

  // ── Banks (Flutterwave) ────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchBanks(String country) async {
    final res = await http.dio.get(
      '/api/v1/wallet/banks',
      queryParameters: {'country': country},
    );
    final data = _extract(res);
    return List<Map<String, dynamic>>.from(data['data'] as List);
  }

  // ── Account name resolution (Flutterwave) ─────────────────────────────────

  /// Calls GET /api/v1/wallet/resolve-account and returns the account name.
  /// Throws a human-readable [Exception] on failure.
  Future<String> resolveAccountName({
    required String accountNumber,
    required String bankCode,
  }) async {
    try {
      final res = await http.dio.get(
        '/api/v1/wallet/resolve-account',
        queryParameters: {
          'account_number': accountNumber,
          'bank_code': bankCode,
        },
      );

      final data = _extract(res);
      if ((res.statusCode ?? 0) == 200 && data['status'] == 'success') {
        final name = data['account_name']?.toString() ?? '';
        if (name.isEmpty)
          throw Exception('Account name could not be resolved.');
        return name;
      }

      throw Exception(
        data['message']?.toString() ?? 'Account resolution failed.',
      );
    } on DioException catch (e) {
      final body = e.response?.data;
      final msg =
          (body is Map ? body['message'] : null) ??
          'Could not verify account. Check number and bank.';
      throw Exception(msg.toString());
    }
  }

  // ── Flutterwave withdrawal ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> createWithdrawalRequest({
    required double amountUsdCents,
    required String bankAccountName,
    required String bankAccountNumber,
    required String bankName,
    required String bankCode,
    required String country,
    String? swift,
    String? email,
    String? phone,
    String? reason,
    required String pin,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'payment_method': 'flutterwave',
      'amount_usd_cents': amountUsdCents,
      'bank_account_name': bankAccountName,
      'bank_account_number': bankAccountNumber,
      'bank_name': bankName,
      'bank_code': bankCode,
      'country': country,
      'pin': pin,
      if (swift != null) 'swift': swift,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (reason != null) 'reason': reason,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
    };

    return _postWithdrawRequest(body);
  }

  // ── PayPal withdrawal ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createPayPalWithdrawal({
    required double amountUsd,
    required String paypalEmail,
    required String paypalEmailConfirm,
    String? reason,
    required String pin,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'payment_method': 'paypal',
      'amount_usd_cents': amountUsd,
      'paypal_email': paypalEmail,
      'paypal_email_confirm': paypalEmailConfirm,
      'pin': pin,
      if (reason != null) 'reason': reason,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
    };

    return _postWithdrawRequest(body);
  }

  // ── Shared POST helper ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _postWithdrawRequest(
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await http.dio.post(
        '/api/v1/wallet/withdraw-request',
        data: body,
      );

      final statusCode = res.statusCode ?? 0;
      final data = _extract(res);

      if (statusCode == 201) return data;

      if (statusCode == 422) {
        final errors = data['errors'] as Map?;
        final firstError = errors?.values.first;
        final msg =
            (firstError is List ? firstError.first : firstError)?.toString() ??
            data['message']?.toString() ??
            'Validation error.';
        throw Exception(msg);
      }

      if (statusCode == 409) throw Exception('Duplicate withdrawal request.');
      if (statusCode == 401) throw Exception(data['message'] ?? 'Invalid PIN.');

      throw Exception(data['message']?.toString() ?? 'Withdrawal failed.');
    } on DioException catch (e) {
      // Surface the server error message when available
      final responseData = e.response?.data;
      String msg = 'Network error. Please try again.';
      if (responseData is Map) {
        msg = responseData['message']?.toString() ?? msg;
      }
      throw Exception(msg);
    }
  }

  // ── Extractor ──────────────────────────────────────────────────────────────

  Map<String, dynamic> _extract(Response res) {
    if (res.data is Map) return Map<String, dynamic>.from(res.data as Map);
    return Map<String, dynamic>.from(jsonDecode(res.data as String) as Map);
  }
}
