import '../entities/live_item.dart';

abstract class LiveFeedRepository {
  Future<({List<LiveItem> items, int page, int perPage, int total})>
  fetchActive({
    String? countryIso,
    String order = 'trending',
    int page = 1,
    int perPage = 20,
  });

  Future<int> fetchViewers({required int liveId}); // optional stats endpoint

  //Pay for premium access
  Future<Map<String, dynamic>> payPremium({
    required int liveId,
    required String idempotencyKey,
  });

  Future<Map<String, dynamic>> checkPremiumStatus({required int liveId});
}
