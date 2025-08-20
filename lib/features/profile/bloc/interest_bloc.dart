// lib/features/interests/bloc/interest_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/models/interest_model.dart';
import '../data/repositories/interest_repository.dart';
import 'interest_event.dart';
import 'interest_state.dart';

class InterestBloc extends Bloc<InterestEvent, InterestState> {
  final InterestRepository repository;

  InterestBloc({required this.repository}) : super(InterestInitial()) {
    on<LoadInterests>(_onLoadInterests);
    on<ToggleInterest>(_onToggleInterest);
    on<SaveInterests>(_onSaveInterests);
  }

  Future<void> _onLoadInterests(
    LoadInterests event,
    Emitter<InterestState> emit,
  ) async {
    emit(InterestLoading());
    try {
      final interests = await repository.fetchInterests();
      emit(InterestLoaded(interests));
    } catch (e) {
      emit(InterestError(e.toString()));
    }
  }

  void _onToggleInterest(ToggleInterest event, Emitter<InterestState> emit) {
    if (state is InterestLoaded) {
      final current = (state as InterestLoaded).interests;
      final updated = current.map((i) {
        if (i.id == event.interestId) {
          return Interest(id: i.id, name: i.name, isSelected: !i.isSelected);
        }
        return i;
      }).toList();
      emit(InterestLoaded(updated));
    }
  }

  Future<void> _onSaveInterests(
    SaveInterests event,
    Emitter<InterestState> emit,
  ) async {
    if (state is InterestLoaded) {
      emit(InterestSaving());
      try {
        final interests = (state as InterestLoaded).interests;
        await repository.saveInterests(interests);
        emit(InterestSaved());
      } catch (e) {
        emit(InterestError(e.toString()));
      }
    }
  }
}
