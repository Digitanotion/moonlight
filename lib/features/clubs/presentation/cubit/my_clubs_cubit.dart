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
}
