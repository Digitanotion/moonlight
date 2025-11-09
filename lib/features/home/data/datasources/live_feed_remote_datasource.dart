import 'package:dio/dio.dart';
import 'package:moonlight/core/config/api_toggles.dart';
import 'package:moonlight/core/utils/countries.dart';
import '../models/live_item_model.dart';

abstract class LiveFeedRemoteDataSource {
  Future<({List<LiveItemModel> items, int page, int perPage, int total})>
  getActive({
    String? countryIso, // we receive ISO2 (or null) from the UI/Bloc
    String order,
    int page,
    int perPage,
  });
  Future<int> getViewers({required int liveId});

  // New: pay premium endpoint
  Future<Map<String, dynamic>> payPremium({
    required int liveId,
    required String idempotencyKey,
  });
}

class LiveFeedRemoteDataSourceImpl implements LiveFeedRemoteDataSource {
  final Dio dio;
  LiveFeedRemoteDataSourceImpl(this.dio);

  @override
  Future<({List<LiveItemModel> items, int page, int perPage, int total})>
  getActive({
    String? countryIso,
    String order = 'trending',
    int page = 1,
    int perPage = 20,
  }) async {
    // Encode the country filter the way the backend expects.
    String? countryParam;
    if (countryIso != null) {
      if (kUseCountryNameFilter) {
        // Convert ISO2 -> canonical name (uppercased) e.g. "KE" -> "KENYA"
        final name = countryDisplayName(countryIso);
        countryParam = name.toUpperCase();
      } else {
        // Use ISO2, uppercased e.g. "KE"
        countryParam = countryIso.toUpperCase();
      }
    }

    final resp = await dio.get(
      '/api/v1/live/active',
      queryParameters: {
        if (countryParam != null) 'country': countryParam,
        'order': order,
        'page': page,
        'per_page': perPage,
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
    // Return the parsed JSON map directly to the repository for handling
    return (resp.data as Map<String, dynamic>);
  }
}
