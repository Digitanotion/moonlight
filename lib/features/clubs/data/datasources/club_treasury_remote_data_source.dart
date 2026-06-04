// lib/features/clubs/data/datasources/club_treasury_remote_data_source.dart

import 'package:dio/dio.dart';

class ClubTreasuryRemoteDataSource {
  final Dio dio;
  ClubTreasuryRemoteDataSource(this.dio);

  Future<Map<String, dynamic>> getSummary(String clubUuid) async {
    final res = await dio.get('/api/v1/clubs/$clubUuid/treasury');
    return Map<String, dynamic>.from(res.data['data']);
  }

  Future<void> setPin(
    String clubUuid,
    String newPin, {
    String? currentPin,
  }) async {
    await dio.post(
      '/api/v1/clubs/$clubUuid/treasury/pin',
      data: {
        'new_pin': newPin,
        if (currentPin != null) 'current_pin': currentPin,
      },
    );
  }

  Future<bool> verifyPin(String clubUuid, String pin) async {
    try {
      await dio.post(
        '/api/v1/clubs/$clubUuid/treasury/pin/verify',
        data: {'pin': pin},
      );
      return true;
    } on DioException {
      return false;
    }
  }

  Future<void> updatePolicy(
    String clubUuid,
    Map<String, dynamic> policy,
  ) async {
    await dio.put('/api/v1/clubs/$clubUuid/treasury/policy', data: policy);
  }

  Future<void> updatePayoutProfile(
    String clubUuid,
    Map<String, dynamic> data,
  ) async {
    await dio.put(
      '/api/v1/clubs/$clubUuid/treasury/payout-profile',
      data: data,
    );
  }

  Future<List<Map<String, dynamic>>> getWithdrawalRequests(
    String clubUuid, {
    String? status,
    int page = 1,
  }) async {
    final res = await dio.get(
      '/api/v1/clubs/$clubUuid/treasury/withdrawal-requests',
      queryParameters: {
        if (status != null) 'status': status,
        'page': page,
        'per_page': 20,
      },
    );
    return List<Map<String, dynamic>>.from(res.data['data'] ?? []);
  }

  // ── KEY FIX ───────────────────────────────────────────────────────────────
  // Previously returned res.data['data'] (just the inner object).
  // The cubit does res['data'] and res['message'] on the result, so we must
  // return the FULL response body: {status, message, data: {...}}.
  Future<Map<String, dynamic>> submitWithdrawalRequest(
    String clubUuid,
    Map<String, dynamic> data,
  ) async {
    final res = await dio.post(
      '/api/v1/clubs/$clubUuid/treasury/withdrawal-requests',
      data: data,
    );

    final body = Map<String, dynamic>.from(res.data as Map);

    // Normalise numeric fields the backend sends as strings
    if (body['data'] is Map) {
      final inner = Map<String, dynamic>.from(body['data'] as Map);
      body['data'] = {
        ...inner,
        'amount_coins': int.tryParse('${inner['amount_coins'] ?? 0}') ?? 0,
        'amount_usd': (inner['amount_usd'] as num?)?.toDouble() ?? 0.0,
        'approvals_required':
            int.tryParse('${inner['approvals_required'] ?? 0}') ?? 0,
        'approvals_received':
            int.tryParse('${inner['approvals_received'] ?? 0}') ?? 0,
        'rejections': int.tryParse('${inner['rejections'] ?? 0}') ?? 0,
      };
    }

    return body; // ← full body: {status, message, data: {...}}
  }

  Future<Map<String, dynamic>> getWithdrawalRequest(
    String clubUuid,
    String requestUuid,
  ) async {
    final res = await dio.get(
      '/api/v1/clubs/$clubUuid/treasury/withdrawal-requests/$requestUuid',
    );
    return Map<String, dynamic>.from(res.data['data']);
  }

  Future<Map<String, dynamic>> approveRequest(
    String clubUuid,
    String requestUuid,
    String pin, {
    String? note,
  }) async {
    final res = await dio.post(
      '/api/v1/clubs/$clubUuid/treasury/withdrawal-requests/$requestUuid/approve',
      data: {'pin': pin, if (note != null) 'note': note},
    );
    return Map<String, dynamic>.from(res.data['data']);
  }

  Future<Map<String, dynamic>> rejectRequest(
    String clubUuid,
    String requestUuid,
    String note,
  ) async {
    final res = await dio.post(
      '/api/v1/clubs/$clubUuid/treasury/withdrawal-requests/$requestUuid/reject',
      data: {'note': note},
    );
    return Map<String, dynamic>.from(res.data['data']);
  }

  Future<void> cancelRequest(
    String clubUuid,
    String requestUuid,
    String pin,
  ) async {
    await dio.delete(
      '/api/v1/clubs/$clubUuid/treasury/withdrawal-requests/$requestUuid',
      data: {'pin': pin},
    );
  }

  Future<List<Map<String, dynamic>>> getAuditLog(String clubUuid) async {
    final res = await dio.get('/api/v1/clubs/$clubUuid/treasury/audit-log');
    return List<Map<String, dynamic>>.from(res.data['data'] ?? []);
  }
}
