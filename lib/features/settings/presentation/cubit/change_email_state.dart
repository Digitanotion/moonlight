part of 'change_email_cubit.dart';

enum ChangeEmailStatus {
  initial,
  loading,
  success,
  verificationSuccess,
  confirmationSuccess,
  error,
}

class ChangeEmailState extends Equatable {
  final ChangeEmailStatus status;
  final String? error;
  final String? message;
  final Map<String, dynamic>? data;
  final int? currentRequestId;
  final String? verificationToken;

  const ChangeEmailState({
    this.status = ChangeEmailStatus.initial,
    this.error,
    this.message,
    this.data,
    this.currentRequestId,
    this.verificationToken,
  });

  ChangeEmailState copyWith({
    ChangeEmailStatus? status,
    String? error,
    String? message,
    Map<String, dynamic>? data,
    int? currentRequestId,
    String? verificationToken,
  }) {
    return ChangeEmailState(
      status: status ?? this.status,
      error: error,
      message: message,
      data: data ?? this.data,
      currentRequestId: currentRequestId ?? this.currentRequestId,
      verificationToken: verificationToken ?? this.verificationToken,
    );
  }

  @override
  List<Object?> get props => [
    status,
    error,
    message,
    data,
    currentRequestId,
    verificationToken,
  ];
}
