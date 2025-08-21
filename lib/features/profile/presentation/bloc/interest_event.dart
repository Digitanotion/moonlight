import 'package:equatable/equatable.dart';

abstract class InterestEvent extends Equatable {
  const InterestEvent();
  @override
  List<Object?> get props => [];
}

class LoadInterests extends InterestEvent {
  const LoadInterests();
}

class ToggleInterest extends InterestEvent {
  final String interestId;
  const ToggleInterest(this.interestId);
  @override
  List<Object?> get props => [interestId];
}

class SubmitInterests extends InterestEvent {
  const SubmitInterests();
}
