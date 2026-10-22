import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonlight/features/home/domain/entities/live_item.dart';
import 'package:moonlight/features/home/domain/repositories/live_feed_repository.dart';
import 'package:moonlight/features/home/presentation/bloc/live_feed/live_feed_bloc.dart';
import 'package:moonlight/features/home/presentation/bloc/live_feed/live_feed_event.dart';
import 'package:moonlight/features/home/presentation/bloc/live_feed/live_feed_state.dart';

const _live = LiveItem(
  id: 1,
  uuid: 'u1',
  channel: 'live_1',
  coverUrl: null,
  handle: '@host',
  role: 'Host',
  countryIso2: null,
  countryName: null,
  viewers: 3,
  title: 'Hello',
  startedAt: null,
  hostUuid: 'h1',
  isPremium: 0,
  premiumFee: 0,
);

/// Fails the first [failures] calls, then returns one live.
class _FlakyRepo implements LiveFeedRepository {
  _FlakyRepo(this.failures);
  int failures;
  int calls = 0;

  @override
  Future<({List<LiveItem> items, int page, int perPage, int total})>
  fetchActive({
    String? countryIso,
    String order = 'trending',
    int page = 1,
    int perPage = 20,
  }) async {
    calls++;
    if (failures-- > 0) throw Exception('network');
    return (items: [_live], page: 1, perPage: 20, total: 1);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('a failed first load retries on its own and shows the lives', () {
    fakeAsync((async) {
      final repo = _FlakyRepo(1);
      final bloc = LiveFeedBloc(repo)..add(LiveFeedStarted());
      async.flushMicrotasks();
      expect(bloc.state.status, LiveFeedStatus.failure);

      async.elapse(const Duration(seconds: 3));
      expect(repo.calls, 2);
      expect(bloc.state.items, [_live]);
      expect(bloc.state.status, LiveFeedStatus.success);
      bloc.close();
    });
  });

  test('a background refresh picks up new lives without a reload', () {
    fakeAsync((async) {
      final repo = _FlakyRepo(0);
      final bloc = LiveFeedBloc(repo)..add(LiveFeedSilentRefresh());
      async.flushMicrotasks();
      expect(bloc.state.items, [_live]);
      bloc.close();
    });
  });
}
