// lib/features/interests/bloc/interest_event.dart
import '../data/models/interest_model.dart';

abstract class InterestEvent {}

class LoadInterests extends InterestEvent {}

class ToggleInterest extends InterestEvent {
  final String interestId;
  ToggleInterest(this.interestId);
}

class SaveInterests extends InterestEvent {}
