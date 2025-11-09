part of 'withdrawal_cubit.dart';

@immutable
abstract class WithdrawalState extends Equatable {
  const WithdrawalState();

  @override
  List<Object?> get props => [];
}

class WithdrawalInitial extends WithdrawalState {}

class WithdrawalLoading extends WithdrawalState {}

class WithdrawalBalanceLoaded extends WithdrawalState {
  final int balance;
  const WithdrawalBalanceLoaded({required this.balance});

  @override
  List<Object?> get props => [balance];
}

class WithdrawalSubmitting extends WithdrawalState {}

class WithdrawalSuccess extends WithdrawalState {
  final Map<String, dynamic> transactionData;
  const WithdrawalSuccess({required this.transactionData});

  @override
  List<Object?> get props => [transactionData];
}

class WithdrawalError extends WithdrawalState {
  final String message;
  const WithdrawalError({required this.message});

  @override
  List<Object?> get props => [message];
}
