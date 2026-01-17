part of 'set_new_pin_cubit.dart';

abstract class SetNewPinState extends Equatable {
  const SetNewPinState();

  @override
  List<Object> get props => [];
}

class SetNewPinInitial extends SetNewPinState {}

class SetNewPinLoading extends SetNewPinState {}

class SetNewPinSuccess extends SetNewPinState {
  final String message;
  final Map<String, dynamic> data;

  const SetNewPinSuccess(this.message, {this.data = const {}});

  @override
  List<Object> get props => [message, data];
}

class SetNewPinError extends SetNewPinState {
  final String message;
  final SetNewPinErrorType errorType;

  const SetNewPinError(this.message, this.errorType);

  @override
  List<Object> get props => [message, errorType];
}
