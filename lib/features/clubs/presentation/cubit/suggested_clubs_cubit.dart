import 'package:bloc/bloc.dart';
import '../../domain/repositories/clubs_repository.dart';
import 'suggested_clubs_state.dart';

class SuggestedClubsCubit extends Cubit<SuggestedClubsState> {
  final ClubsRepository repo;

  SuggestedClubsCubit(this.repo) : super(SuggestedClubsState.initial());

  Future<void> load() async {
    emit(state.copyWith(loading: true));
    try {
      final clubs = await repo.getSuggestedClubs();
      emit(state.copyWith(loading: false, clubs: clubs));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  // ✅ NEW: mark club as joined locally
  void markJoined(String clubUuid) {
    final updated = Set<String>.from(state.joined)..add(clubUuid);
    emit(state.copyWith(joined: updated));
  }

  bool isJoined(String clubUuid) {
    return state.joined.contains(clubUuid);
  }
}
