import 'package:dio/dio.dart';
import 'package:moonlight/core/network/dio_client.dart'; // ✅ Add import
import 'package:moonlight/core/config/api_toggles.dart';
import 'package:moonlight/core/utils/countries.dart';
import '../models/live_item_model.dart';

abstract class LiveFeedRemoteDataSource {
  Future<({List<LiveItemModel> items, int page, int perPage, int total})>
  getActive({String? countryIso, String order, int page, int perPage});
  Future<int> getViewers({required int liveId});
  Future<Map<String, dynamic>> payPremium({
    required int liveId,
    required String idempotencyKey,
  });
  Future<Map<String, dynamic>> checkPremiumStatus({required int liveId});
}

class LiveFeedRemoteDataSourceImpl implements LiveFeedRemoteDataSource {
  final Dio dio; // Keep this as Dio

  // ✅ Add a factory constructor that accepts DioClient
  factory LiveFeedRemoteDataSourceImpl.fromDioClient(DioClient dioClient) {
    return LiveFeedRemoteDataSourceImpl(dioClient.dio);
  }

  // Original constructor
  LiveFeedRemoteDataSourceImpl(this.dio);

  @override
  Future<({List<LiveItemModel> items, int page, int perPage, int total})>
  getActive({
    String? countryIso,
    String order = 'trending',
    int page = 1,
    int perPage = 20,
  }) async {
    String? countryParam;
    if (countryIso != null) {
      if (kUseCountryNameFilter) {
        final name = countryDisplayName(countryIso);
        countryParam = name.toUpperCase();
      } else {
        countryParam = countryIso.toUpperCase();
      }
    }

    final resp = await dio.get(
      '/api/v1/live/active',
      queryParameters: {
        if (countryParam != null) 'country': countryParam,
        'order': order,
        'page': page,
        'perPage': perPage,
      },
    );

    final data = (resp.data['data'] as List).cast<Map<String, dynamic>>();
    final items = data.map(LiveItemModel.fromJson).toList();

    final meta = (resp.data['meta'] as Map<String, dynamic>);
    return (
      items: items,
      page: (meta['page'] as num).toInt(),
      perPage: (meta['per_page'] as num).toInt(),
      total: (meta['total'] as num).toInt(),
    );
  }

  @override
  Future<int> getViewers({required int liveId}) async {
    final resp = await dio.get('/api/v1/live/$liveId/stats');
    return (resp.data['viewers'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<Map<String, dynamic>> payPremium({
    required int liveId,
    required String idempotencyKey,
  }) async {
    final resp = await dio.post(
      '/api/v1/live/$liveId/pay-premium',
      data: {'idempotency_key': idempotencyKey},
    );
    return (resp.data as Map<String, dynamic>);
  }

  @override
  Future<Map<String, dynamic>> checkPremiumStatus({required int liveId}) async {
    try {
      final response = await dio.get('/api/v1/live/$liveId/premium/status');

      final data = response.data as Map<String, dynamic>;
      return data;
    } on DioException catch (e) {
      if (e.response != null) {
        final errorData = e.response!.data as Map<String, dynamic>;
        throw Exception(
          errorData['message'] ?? 'Failed to check premium status',
        );
      }
      throw Exception('Network error while checking premium status');
    } catch (e) {
      throw Exception('Failed to check premium status: $e');
    }
  }
}
