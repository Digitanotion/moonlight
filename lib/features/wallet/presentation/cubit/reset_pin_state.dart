part of 'reset_pin_cubit.dart';

abstract class ResetPinState extends Equatable {
  const ResetPinState();

  @override
  List<Object> get props => [];
}

class ResetPinInitial extends ResetPinState {}

class ResetPinLoading extends ResetPinState {}

class ResetPinCurrentVerified extends ResetPinState {}

class ResetPinSuccess extends ResetPinState {
  final String message;
  final Map<String, dynamic> data;

  const ResetPinSuccess(this.message, {this.data = const {}});

  @override
  List<Object> get props => [message, data];
}

class ResetPinCurrentError extends ResetPinState {
  final String message;

  const ResetPinCurrentError(this.message);

  @override
  List<Object> get props => [message];
}

class ResetPinError extends ResetPinState {
  final String message;
  final ResetPinErrorType errorType;

  const ResetPinError(this.message, this.errorType);

  @override
  List<Object> get props => [message, errorType];
}
