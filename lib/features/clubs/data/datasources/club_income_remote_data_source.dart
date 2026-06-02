import 'package:dio/dio.dart';

class ClubIncomeRemoteDataSource {
  final Dio dio;
  ClubIncomeRemoteDataSource(this.dio);

  Future<Map<String, dynamic>> getStats(
    String club, {
    String period = 'all',
  }) async {
    final res = await dio.get(
      '/api/v1/clubs/$club/donations/stats',
      queryParameters: {'period': period},
    );
    return res.data['data'];
  }

  Future<List<dynamic>> getTransactions(
    String club, {
    int page = 1,
    String period = 'all', // ← NEW: passed to backend
  }) async {
    final res = await dio.get(
      '/api/v1/clubs/$club/transactions',
      queryParameters: {
        'page': page,
        if (period != 'all') 'period': period, // only send when not 'all'
      },
    );
    return res.data['data'];
  }
}
