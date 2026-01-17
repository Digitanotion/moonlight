import 'package:dio/dio.dart';

class ClubIncomeRemoteDataSource {
  final Dio dio;
  ClubIncomeRemoteDataSource(this.dio);

  Future<Map<String, dynamic>> getStats(String club) async {
    final res = await dio.get('/api/v1/clubs/$club/donations/stats');
    return res.data['data'];
  }

  Future<List<dynamic>> getTransactions(String club, {int page = 1}) async {
    final res = await dio.get(
      '/api/v1/clubs/$club/transactions',
      queryParameters: {'page': page},
    );
    return res.data['data'];
  }
}
