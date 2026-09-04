import 'dart:async';

import 'package:bloc/bloc.dart';
import 'my_clubs_state.dart';
import '../../domain/repositories/clubs_repository.dart';

class MyClubsCubit extends Cubit<MyClubsState> {
  final ClubsRepository repo;

  MyClubsCubit(this.repo) : super(MyClubsState.initial());

  Future<void> load() async {
    emit(state.copyWith(loading: true, error: null));

    try {
      final clubs = await repo.getMyClubs();

      // Owner clubs first
      clubs.sort((a, b) {
        if (a.isCreator && !b.isCreator) return -1;
        if (!a.isCreator && b.isCreator) return 1;
        return b.membersCount.compareTo(a.membersCount);
      });

      emit(state.copyWith(loading: false, clubs: clubs));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
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
