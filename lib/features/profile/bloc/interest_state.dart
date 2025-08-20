// lib/features/interests/bloc/interest_state.dart
import '../data/models/interest_model.dart';

abstract class InterestState {}

class InterestInitial extends InterestState {}

class InterestLoading extends InterestState {}

class InterestLoaded extends InterestState {
  final List<Interest> interests;
  InterestLoaded(this.interests);
}

class InterestSaving extends InterestState {}

class InterestSaved extends InterestState {}

class InterestError extends InterestState {
  final String message;
  InterestError(this.message);
}
