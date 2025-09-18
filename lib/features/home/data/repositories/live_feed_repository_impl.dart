import '../../domain/entities/live_item.dart';
import '../../domain/repositories/live_feed_repository.dart';
import '../datasources/live_feed_remote_datasource.dart';

class LiveFeedRepositoryImpl implements LiveFeedRepository {
  final LiveFeedRemoteDataSource remote;
  LiveFeedRepositoryImpl(this.remote);

  @override
  Future<({List<LiveItem> items, int page, int perPage, int total})>
  fetchActive({
    String? countryIso,
    String order = 'trending',
    int page = 1,
    int perPage = 20,
  }) {
    return remote.getActive(
      countryIso: countryIso,
      order: order,
      page: page,
      perPage: perPage,
    );
  }

  @override
  Future<int> fetchViewers({required int liveId}) =>
      remote.getViewers(liveId: liveId);
}
