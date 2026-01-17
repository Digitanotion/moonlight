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

      final updated = state.clubs.map((c) {
        if (c.uuid == clubUuid) {
          return c.copyWith(isMember: true);
        }
        return c;
      }).toList();

      emit(
        state.copyWith(
          clubs: updated,
          successMessage: '🎉 You have joined the club',
        ),
      );
    } on DioException catch (e) {
      String message = 'Unable to join club';

      if (e.response?.statusCode == 409) {
        message = 'You are already a member of this club';
      } else if (e.response?.statusCode == 403) {
        message = 'You are not allowed to join this club';
      } else if (e.response?.statusCode == 404) {
        message = 'Club not found';
      }

      emit(state.copyWith(errorMessage: message));
    } catch (_) {
      emit(
        state.copyWith(errorMessage: 'Something went wrong. Please try again.'),
      );
    } finally {
      final next = {...state.joining}..remove(clubUuid);
      emit(state.copyWith(joining: next));
    }
  }

  /// Optional helper to clear snack triggers after display
  void clearMessages() {
    emit(state.copyWith(errorMessage: null, successMessage: null));
  }

  //ASAS
}
