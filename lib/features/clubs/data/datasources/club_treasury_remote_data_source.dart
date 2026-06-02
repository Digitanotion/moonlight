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

  Future<Map<String, dynamic>> submitWithdrawalRequest(
    String clubUuid,
    Map<String, dynamic> data,
  ) async {
    final res = await dio.post(
      '/api/v1/clubs/$clubUuid/treasury/withdrawal-requests',
      data: data,
    );
    return Map<String, dynamic>.from(res.data['data']);
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
