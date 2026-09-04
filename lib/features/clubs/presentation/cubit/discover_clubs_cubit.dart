import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/clubs/domain/repositories/clubs_repository.dart';
import 'discover_clubs_state.dart';

class DiscoverClubsCubit extends Cubit<DiscoverClubsState> {
  final ClubsRepository repo;

  DiscoverClubsCubit(this.repo) : super(DiscoverClubsState.initial());

  Future<void> load() async {
    try {
      emit(state.copyWith(loading: true, errorMessage: null));
      final clubs = await repo.getPublicClubs();

      emit(
        state.copyWith(
          loading: false,
          clubs: clubs.where((c) => !c.isPrivate).toList(),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          loading: false,
          errorMessage: 'Failed to load clubs ${e}',
        ),
      );
    }
  }

  Future<void> join(String clubUuid) async {
    if (state.joining.contains(clubUuid)) return;

    emit(
      state.copyWith(
        joining: {...state.joining, clubUuid},
        errorMessage: null,
        successMessage: null,
      ),
    );

    try {
      await repo.joinClub(clubUuid);
      _markJoined(clubUuid, '🎉 You have joined the club');
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;

      if (code == 409) {
        // Already a member — that's a success from the user's point of view.
        _markJoined(clubUuid, null);
      } else if (code == 403) {
        emit(
          state.copyWith(errorMessage: 'You are not allowed to join this club'),
        );
      } else if (code == 404) {
        emit(state.copyWith(errorMessage: 'Club not found'));
      } else {
        // 5xx / timeout / network: the request may well have gone through
        // server-side (a failing post-commit notification used to 500 a
        // successful join). Verify against "my clubs" before crying wolf.
        await _verifyJoin(clubUuid);
      }
    } catch (_) {
      await _verifyJoin(clubUuid);
    } finally {
      emit(state.copyWith(joining: {...state.joining}..remove(clubUuid)));
    }
  }

  void _markJoined(String clubUuid, String? successMessage) {
    final updated = state.clubs
        .map((c) => c.uuid == clubUuid ? c.copyWith(isMember: true) : c)
        .toList();
    emit(state.copyWith(clubs: updated, successMessage: successMessage));
  }

  Future<void> _verifyJoin(String clubUuid) async {
    try {
      final mine = await repo.getMyClubs();
      if (mine.any((c) => c.uuid == clubUuid)) {
        _markJoined(clubUuid, '🎉 You have joined the club');
        return;
      }
    } catch (_) {
      /* fall through to the error below */
    }
    emit(
      state.copyWith(errorMessage: 'Something went wrong. Please try again.'),
    );
  }

  /// Optional helper to clear snack triggers after display
  void clearMessages() {
    emit(state.copyWith(errorMessage: null, successMessage: null));
  }

  //ASAS
}
