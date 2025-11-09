part of 'set_pin_cubit.dart';

abstract class SetPinState extends Equatable {
  const SetPinState();

  @override
  List<Object?> get props => [];
}

class SetPinInitial extends SetPinState {
  const SetPinInitial();
}

class SetPinLoading extends SetPinState {
  const SetPinLoading();
}

class SetPinSuccess extends SetPinState {
  final String message;
  const SetPinSuccess({required this.message});

  @override
  List<Object?> get props => [message];
}

class SetPinFailure extends SetPinState {
  final String message;
  const SetPinFailure({required this.message});

  @override
  List<Object?> get props => [message];
}
