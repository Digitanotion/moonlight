// lib/features/offerwall/data/datasources/offerwall_remote_data_source.dart
//
// Thin data source over the offerwall ("Earn Cash") endpoints — same
// lightweight raw-Map pattern as ClubTreasuryRemoteDataSource, no separate
// entity/repository layer. Provider postbacks (Adjoe/Torox) never touch the
// client; this only talks to our own backend.

import 'package:dio/dio.dart';

class OfferwallRemoteDataSource {
  final Dio dio;
  OfferwallRemoteDataSource(this.dio);

  Future<Map<String, dynamic>> getStatus() async {
    final res = await dio.get('/api/v1/offerwall');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> activate() async {
    final res = await dio.post('/api/v1/offerwall/activate');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<List<Map<String, dynamic>>> getTransactions() async {
    final res = await dio.get('/api/v1/offerwall/transactions');
    final data = res.data['data'] ?? res.data;
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<List<Map<String, dynamic>>> getWithdrawals() async {
    final res = await dio.get('/api/v1/offerwall/withdrawals');
    final data = res.data['data'] ?? res.data;
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<Map<String, dynamic>> requestWithdrawal(
    Map<String, dynamic> data,
  ) async {
    final res = await dio.post('/api/v1/offerwall/withdraw', data: data);
    return Map<String, dynamic>.from(res.data as Map);
  }
}
