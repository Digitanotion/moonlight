// lib/features/agents/data/agent_remote_data_source.dart
//
// Thin raw-Map data source over the Moonlight Agents endpoints (same
// lightweight pattern as OfferwallRemoteDataSource).

import 'package:dio/dio.dart';

class AgentRemoteDataSource {
  final Dio dio;
  AgentRemoteDataSource(this.dio);

  Map<String, dynamic> _data(Response res) =>
      Map<String, dynamic>.from((res.data as Map)['data'] as Map);

  List<Map<String, dynamic>> _list(Response res) =>
      List<Map<String, dynamic>>.from(
        ((res.data as Map)['data'] as List? ?? const []),
      );

  Future<Map<String, dynamic>> me() async =>
      _data(await dio.get('/api/v1/agents/me'));

  Future<List<Map<String, dynamic>>> directory({
    String? country,
    String? q,
  }) async => _list(
    await dio.get(
      '/api/v1/agents',
      queryParameters: {
        if (country != null && country.isNotEmpty) 'country': country,
        if (q != null && q.isNotEmpty) 'q': q,
      },
    ),
  );

  Future<Map<String, dynamic>> detail(String code) async =>
      _data(await dio.get('/api/v1/agents/$code'));

  Future<Map<String, dynamic>> create(FormData form) async =>
      _data(await dio.post('/api/v1/agents', data: form));

  Future<Map<String, dynamic>> update(FormData form) async =>
      _data(await dio.post('/api/v1/agents/me', data: form));

  /// Returns null on success, otherwise the server's reason.
  Future<String?> join(String code) async {
    try {
      await dio.post('/api/v1/agents/join', data: {'code': code});
      return null;
    } on DioException catch (e) {
      final d = e.response?.data;
      return (d is Map ? d['message'] : null)?.toString() ??
          'Could not apply the agent code.';
    }
  }

  Future<List<Map<String, dynamic>>> members() async =>
      _list(await dio.get('/api/v1/agents/me/members'));

  Future<List<Map<String, dynamic>>> commissions() async =>
      _list(await dio.get('/api/v1/agents/me/commissions'));

  Future<List<Map<String, dynamic>>> withdrawals() async =>
      _list(await dio.get('/api/v1/agents/me/withdrawals'));

  Future<String> withdraw(Map<String, dynamic> body) async {
    final res = await dio.post('/api/v1/agents/me/withdraw', data: body);
    return ((res.data as Map)['message'] ?? 'Withdrawal submitted.').toString();
  }
}

/// Pulls the server's validation/error message out of a DioException.
String agentErrorMessage(Object e) {
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map && d['message'] != null) return d['message'].toString();
  }
  return 'Something went wrong. Please try again.';
}
