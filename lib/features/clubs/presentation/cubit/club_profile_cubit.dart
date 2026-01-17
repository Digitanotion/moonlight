import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/clubs/domain/repositories/clubs_repository.dart';
import 'club_profile_state.dart';

class ClubProfileCubit extends Cubit<ClubProfileState> {
  final ClubsRepository repository;

  ClubProfileCubit(this.repository)
    : super(const ClubProfileState(loading: true));

  Future<void> load(String clubUuid) async {
    try {
      emit(state.copyWith(loading: true));
      final profile = await repository.getClubProfile(clubUuid);
      emit(state.copyWith(loading: false, profile: profile));
    } catch (e) {
      emit(
        state.copyWith(loading: false, error: 'Failed to load club profile'),
      );
    }
  }
}
