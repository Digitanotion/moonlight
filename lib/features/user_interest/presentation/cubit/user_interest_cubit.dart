import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../profile_setup/domain/usecases/update_interests.dart';

part 'user_interest_state.dart';

class UserInterestCubit extends Cubit<UserInterestState> {
  final UpdateInterests updateInterests;
  UserInterestCubit(this.updateInterests) : super(UserInterestState.initial());

  void toggle(String key) {
    final s = Set<String>.from(state.selected);
    if (s.contains(key)) {
      s.remove(key);
    } else {
      // no imposed limit now; set one if needed
      s.add(key);
    }
    emit(state.copyWith(selected: s.toList()));
  }

  Future<void> submit() async {
    emit(state.copyWith(submitting: true, error: null));
    try {
      await updateInterests(state.selected);
      emit(state.copyWith(submitting: false, success: true));
    } catch (e) {
      emit(state.copyWith(submitting: false, error: e.toString()));
    }
  }
}
