import 'package:dio/dio.dart';
import 'package:moonlight/core/network/dio_client.dart';

class NotificationsRemoteDataSource {
  final DioClient http;
  NotificationsRemoteDataSource(this.http);

  Future<Map<String, dynamic>> fetch({
    required int page,
    required int perPage,
  }) async {
    final res = await http.dio.get(
      '/api/v1/notifications',
      queryParameters: {'page': page, 'per_page': perPage},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<void> markRead(String id) async {
    await http.dio.post('/api/v1/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await http.dio.post('/api/v1/notifications/read-all');
  }
}
