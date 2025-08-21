import 'package:dio/dio.dart';
import '../models/interest_model.dart';

abstract class InterestsRemoteDataSource {
  Future<List<InterestModel>> fetchInterests();
  Future<void> saveUserInterests(List<String> ids);
}

class InterestsRemoteDataSourceImpl implements InterestsRemoteDataSource {
  final Dio client;
  final String baseUrl;
  InterestsRemoteDataSourceImpl({required this.client, required this.baseUrl});

  @override
  Future<List<InterestModel>> fetchInterests() async {
    final res = await client.get('$baseUrl/interests');
    final data = (res.data as List)
        .map((e) => InterestModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return data;
  }

  @override
  Future<void> saveUserInterests(List<String> ids) async {
    await client.post('$baseUrl/user/interests', data: {'interests': ids});
  }
}
