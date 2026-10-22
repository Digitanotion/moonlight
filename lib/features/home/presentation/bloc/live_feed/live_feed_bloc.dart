import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'live_feed_event.dart';
import 'live_feed_state.dart';
import '../../../domain/repositories/live_feed_repository.dart';

class LiveFeedBloc extends Bloc<LiveFeedEvent, LiveFeedState> {
  final LiveFeedRepository repo;
  String? _countryIso;
  String _order = 'trending';

  /// A failed load used to leave the lives empty until a manual refresh
  /// (the videos still filled the grid, so nothing looked wrong). Now it
  /// quietly retries a few times.
  Timer? _retry;
  int _retries = 0;
  static const _retryDelays = [2, 4, 8, 15];

  void _scheduleRetry() {
    if (_retries >= _retryDelays.length || isClosed) return;
    _retry?.cancel();
    _retry = Timer(Duration(seconds: _retryDelays[_retries++]), () {
      if (!isClosed) add(LiveFeedSilentRefresh());
    });
  }

  LiveFeedBloc(this.repo) : super(const LiveFeedState()) {
    on<LiveFeedStarted>(_onStarted);
    on<LiveFeedLoadMore>(_onLoadMore);
    on<LiveFeedRefresh>(_onRefresh);
    on<LiveFeedCountryChanged>(_onCountryChanged);
    on<LiveFeedSilentRefresh>(_onSilentRefresh);
  }

  @override
  Future<void> close() {
    _retry?.cancel();
    return super.close();
  }

  Future<void> _onSilentRefresh(
    LiveFeedSilentRefresh e,
    Emitter<LiveFeedState> emit,
  ) async {
    // Don't fight a load in progress or throw away pages the user scrolled.
    if (state.status == LiveFeedStatus.loading || state.page > 1) return;
    final country = _countryIso;
    try {
      final res = await repo.fetchActive(
        countryIso: country,
        order: _order,
        page: 1,
      );
      if (country != _countryIso) return; // country changed meanwhile
      _retries = 0;
      emit(
        state.copyWith(
          status: res.items.isEmpty
              ? LiveFeedStatus.empty
              : LiveFeedStatus.success,
          items: res.items,
          page: res.page,
          perPage: res.perPage,
          total: res.total,
          hasMore: (res.page * res.perPage) < res.total,
        ),
      );
    } catch (_) {
      if (state.items.isEmpty) _scheduleRetry();
    }
  }

  Future<void> _onStarted(
    LiveFeedStarted e,
    Emitter<LiveFeedState> emit,
  ) async {
    _countryIso = e.countryIso;
    _order = e.order;
    emit(
      state.copyWith(
        status: LiveFeedStatus.loading,
        items: [],
        page: 0,
        total: 0,
        selectedCountryIso: _countryIso,
        setSelectedCountryIso: true,
      ),
    );
    try {
      final res = await repo.fetchActive(
        countryIso: _countryIso,
        order: _order,
        page: 1,
      );
      final hasMore = (res.page * res.perPage) < res.total;
      _retries = 0;
      emit(
        state.copyWith(
          status: res.items.isEmpty
              ? LiveFeedStatus.empty
              : LiveFeedStatus.success,
          items: res.items,
          page: res.page,
          perPage: res.perPage,
          total: res.total,
          hasMore: hasMore,
          selectedCountryIso: _countryIso,
          setSelectedCountryIso: true,
        ),
      );
    } catch (err) {
      emit(
        state.copyWith(status: LiveFeedStatus.failure, error: err.toString()),
      );
      _scheduleRetry();
    }
  }

  Future<void> _onLoadMore(
    LiveFeedLoadMore e,
    Emitter<LiveFeedState> emit,
  ) async {
    if (!state.hasMore || state.status == LiveFeedStatus.loading) return;
    emit(state.copyWith(status: LiveFeedStatus.loading));
    try {
      final res = await repo.fetchActive(
        countryIso: _countryIso,
        order: _order,
        page: state.page + 1,
        perPage: state.perPage,
      );
      final items = [...state.items, ...res.items];
      final hasMore = (res.page * res.perPage) < res.total;
      emit(
        state.copyWith(
          status: LiveFeedStatus.success,
          items: items,
          page: res.page,
          total: res.total,
          hasMore: hasMore,
        ),
      );
    } catch (err) {
      emit(
        state.copyWith(status: LiveFeedStatus.failure, error: err.toString()),
      );
    }
  }

  Future<void> _onRefresh(
    LiveFeedRefresh e,
    Emitter<LiveFeedState> emit,
  ) async {
    add(LiveFeedStarted(countryIso: _countryIso, order: _order));
  }

  Future<void> _onCountryChanged(
    LiveFeedCountryChanged e,
    Emitter<LiveFeedState> emit,
  ) async {
    _countryIso = e.countryIso; // null => All
    add(LiveFeedStarted(countryIso: _countryIso, order: _order));
  }
}
