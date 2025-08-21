import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:moonlight/core/errors/failures.dart';
import 'package:moonlight/features/profile/domain/usecases/has_completed_selection.dart';
import '../../domain/entities/interest.dart';
import '../../domain/usecases/get_interests.dart';
import '../../domain/usecases/save_user_interests.dart';
import 'interest_event.dart';
import 'interest_state.dart';

class InterestBloc extends Bloc<InterestEvent, InterestState> {
  final GetInterests getInterests;
  final SaveUserInterests saveUserInterests;
  final HasCompletedSelection hasCompletedSelection;

  InterestBloc({
    required this.getInterests,
    required this.saveUserInterests,
    required this.hasCompletedSelection,
  }) : super(InterestState.initial()) {
    on<LoadInterests>(_onLoad);
    on<ToggleInterest>(_onToggle);
    on<SubmitInterests>(_onSubmit);
  }

  Future<void> _onLoad(LoadInterests event, Emitter<InterestState> emit) async {
    emit(state.copyWith(loading: true, error: null, saved: false));
    final Either<Failure, List<Interest>> res = await getInterests();
    res.fold(
      (l) => emit(
        state.copyWith(loading: false, error: l.message ?? 'Failed to load'),
      ),
      (r) => emit(state.copyWith(loading: false, interests: r, error: null)),
    );
  }

  void _onToggle(ToggleInterest event, Emitter<InterestState> emit) {
    final newSelected = Set<String>.from(state.selectedIds);
    if (newSelected.contains(event.interestId)) {
      newSelected.remove(event.interestId);
    } else {
      newSelected.add(event.interestId);
    }
    emit(state.copyWith(selectedIds: newSelected, error: null, saved: false));
  }

  Future<void> _onSubmit(
    SubmitInterests event,
    Emitter<InterestState> emit,
  ) async {
    if (state.selectedIds.isEmpty) return;
    emit(state.copyWith(loading: true, error: null));
    final res = await saveUserInterests(state.selectedIds.toList());
    res.fold(
      (l) => emit(
        state.copyWith(loading: false, error: l.message ?? 'Failed to save'),
      ),
      (_) => emit(
        state.copyWith(
          loading: false,
          saved: true,
          hasCompletedSelection: true,
        ),
      ),
    );
  }
}
