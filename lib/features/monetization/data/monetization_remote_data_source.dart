import 'package:dio/dio.dart';

/// Thin raw-Map data source for creator video monetization.
class MonetizationRemoteDataSource {
  final Dio dio;
  MonetizationRemoteDataSource(this.dio);

  Future<Map<String, dynamic>> status() async {
    final res = await dio.get('/api/v1/monetization');
    return Map<String, dynamic>.from((res.data as Map)['data'] as Map);
  }

  Future<Map<String, dynamic>> enroll({
    required String country,
    required int age,
    required String gender,
  }) async {
    final res = await dio.post(
      '/api/v1/monetization/enroll',
      data: {
        'country': country,
        'age': age,
        'gender': gender,
        'interested': true,
      },
    );
    return Map<String, dynamic>.from((res.data as Map)['data'] as Map);
  }
}

String monetizationError(Object e) {
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map && d['message'] != null) return d['message'].toString();
  }
  return 'Something went wrong. Please try again.';
}
