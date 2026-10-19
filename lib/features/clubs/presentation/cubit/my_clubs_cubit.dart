import 'dart:async';

import 'package:bloc/bloc.dart';
import 'my_clubs_state.dart';
import '../../domain/repositories/clubs_repository.dart';

class MyClubsCubit extends Cubit<MyClubsState> {
  final ClubsRepository repo;

  MyClubsCubit(this.repo) : super(MyClubsState.initial());

  Timer? _live;

  Future<void> load({bool quiet = false}) async {
    // Quiet reloads (live badges) keep the list on screen, no skeleton.
    if (!quiet) emit(state.copyWith(loading: true, error: null));

    try {
      final clubs = await repo.getMyClubs();

      // Clubs that are live right now first, then owner clubs.
      clubs.sort((a, b) {
        final la = a.liveRooms.isNotEmpty, lb = b.liveRooms.isNotEmpty;
        if (la != lb) return la ? -1 : 1;
        if (a.isCreator && !b.isCreator) return -1;
        if (!a.isCreator && b.isCreator) return 1;
        return b.membersCount.compareTo(a.membersCount);
      });

      if (isClosed) return;
      emit(state.copyWith(loading: false, clubs: clubs));
    } catch (e) {
      if (isClosed || quiet) return;
      emit(state.copyWith(loading: false, error: e.toString()));
    }
    // Keep the live badges fresh while the list is around.
    _live ??= Timer.periodic(const Duration(seconds: 30), (_) {
      if (!state.loading) load(quiet: true);
    });
  }

  @override
  Future<void> close() {
    _live?.cancel();
    return super.close();
  }

  Future<void> refresh() => load();

  /// Optimistically removes [clubUuid] from the list, then confirms with the
  /// server. Restores the list (and re-syncs from the server) if the leave
  /// call actually fails.
  Future<bool> leaveClub(String clubUuid) async {
    final before = state.clubs;
    final target = before.where((c) => c.uuid == clubUuid);
    if (target.isEmpty || target.first.isCreator) return false;

    emit(
      state.copyWith(clubs: before.where((c) => c.uuid != clubUuid).toList()),
    );

    try {
      await repo.leaveClub(clubUuid);
      return true;
    } catch (_) {
      emit(state.copyWith(clubs: before));
      // The leave may still have gone through server-side (e.g. a failing
      // post-commit notification) — reconcile with the server either way.
      unawaited(load());
      return false;
    }
  }
}
