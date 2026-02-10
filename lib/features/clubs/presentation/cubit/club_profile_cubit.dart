import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/clubs/domain/repositories/clubs_repository.dart';
import 'club_profile_state.dart';

class ClubProfileCubit extends Cubit<ClubProfileState> {
  final ClubsRepository repository;

  ClubProfileCubit(this.repository)
    : super(const ClubProfileState(loading: true));

  Future<void> load(String clubUuid) async {
    try {
      emit(state.copyWith(loading: true, error: null, success: null));
      final profile = await repository.getClubProfile(clubUuid);
      emit(state.copyWith(loading: false, profile: profile));
    } catch (e) {
      emit(
        state.copyWith(loading: false, error: 'Failed to load club profile'),
      );
    }
  }

  Future<void> joinClub() async {
    if (state.joining || state.profile?.isMember == true) return;

    emit(state.copyWith(joining: true, error: null, success: null));

    try {
      await repository.joinClub(state.profile!.uuid);

      // Update the club profile using copyWith
      final updatedProfile = state.profile!.copyWith(
        isMember: true,
        membersCount: state.profile!.membersCount + 1,
      );

      emit(
        state.copyWith(
          profile: updatedProfile,
          joining: false,
          success: '🎉 Successfully joined the club!',
        ),
      );
    } catch (e) {
      emit(state.copyWith(joining: false, error: 'Failed to join club'));
    }
  }

  void clearMessages() {
    emit(state.copyWith(error: null, success: null));
  }
}
