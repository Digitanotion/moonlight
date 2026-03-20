part of 'withdrawal_cubit.dart';

@immutable
abstract class WithdrawalState extends Equatable {
  const WithdrawalState();

  @override
  List<Object?> get props => [];
}

// ── Lifecycle states ───────────────────────────────────────────────────────

class WithdrawalInitial extends WithdrawalState {}

/// Shown while the wallet balance is being loaded on page open.
class WithdrawalLoading extends WithdrawalState {}

/// Wallet balance has been fetched; holds the withdrawable balance in cents.
class WithdrawalBalanceLoaded extends WithdrawalState {
  final int balance;
  const WithdrawalBalanceLoaded({required this.balance});

  @override
  List<Object?> get props => [balance];
}

/// Submission is in progress (spinner on the button).
class WithdrawalSubmitting extends WithdrawalState {}

/// Withdrawal was accepted by the server.
class WithdrawalSuccess extends WithdrawalState {
  final Map<String, dynamic> transactionData;
  const WithdrawalSuccess({required this.transactionData});

  @override
  List<Object?> get props => [transactionData];
}

/// A terminal error from balance-load, submission, or account resolution.
class WithdrawalError extends WithdrawalState {
  final String message;
  const WithdrawalError({required this.message});

  @override
  List<Object?> get props => [message];
}

// ── Account-name resolution states (Flutterwave only) ─────────────────────

/// Fired when the debounce fires and the API call starts.
class WithdrawalAccountNameLoading extends WithdrawalState {}

/// The Flutterwave account-name lookup returned successfully.
class WithdrawalAccountNameLoaded extends WithdrawalState {
  final String accountName;
  const WithdrawalAccountNameLoaded({required this.accountName});

  @override
  List<Object?> get props => [accountName];
}

/// The account-name lookup failed (invalid number / bank, API error).
class WithdrawalAccountNameError extends WithdrawalState {
  final String message;
  const WithdrawalAccountNameError({required this.message});

  @override
  List<Object?> get props => [message];
}
