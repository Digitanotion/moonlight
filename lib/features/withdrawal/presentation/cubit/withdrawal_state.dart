// ============================================================================
// lib/features/withdrawal/presentation/cubit/withdrawal_state.dart
//
// Adds WithdrawalPending state so Flutter can show a "processing" screen
// instead of a success dialog immediately after the API responds.
//
// The API returning 201 only means Flutterwave *queued* the transfer.
// The actual outcome arrives via webhook (async). Flutter should show
// "Withdrawal Processing" until the user is notified of the real result.
// ============================================================================

part of 'withdrawal_cubit.dart';

@immutable
sealed class WithdrawalState extends Equatable {
  const WithdrawalState();

  @override
  List<Object?> get props => [];
}

final class WithdrawalInitial extends WithdrawalState {}

final class WithdrawalLoading extends WithdrawalState {}

final class WithdrawalSubmitting extends WithdrawalState {}

final class WithdrawalBalanceLoaded extends WithdrawalState {
  final int balance;
  const WithdrawalBalanceLoaded({required this.balance});

  @override
  List<Object?> get props => [balance];
}

// ── NEW: Transfer is queued, outcome is async ─────────────────────────────────
// Show a "We're processing your withdrawal" screen.
// The user will be notified (push + in-app) when it succeeds or fails.
final class WithdrawalPending extends WithdrawalState {
  final String reference;
  final double amountUsd;
  final String method; // 'flutterwave' | 'paypal'
  final Map<String, dynamic> transactionData;

  const WithdrawalPending({
    required this.reference,
    required this.amountUsd,
    required this.method,
    required this.transactionData,
  });

  @override
  List<Object?> get props => [reference, amountUsd, method];
}

// ── KEEP: Only emit this when we have confirmed success (future use) ───────────
final class WithdrawalSuccess extends WithdrawalState {
  final Map<String, dynamic> transactionData;
  const WithdrawalSuccess({required this.transactionData});

  @override
  List<Object?> get props => [transactionData];
}

final class WithdrawalError extends WithdrawalState {
  final String message;
  const WithdrawalError({required this.message});

  @override
  List<Object?> get props => [message];
}

final class WithdrawalFxPreviewLoading extends WithdrawalState {
  const WithdrawalFxPreviewLoading();
}

final class WithdrawalFxPreviewLoaded extends WithdrawalState {
  final double amountUsd;
  final String country;
  final double localAmount;
  final String localCurrency;
  final double rate;
  final String note;

  const WithdrawalFxPreviewLoaded({
    required this.amountUsd,
    required this.country,
    required this.localAmount,
    required this.localCurrency,
    required this.rate,
    required this.note,
  });

  @override
  List<Object?> get props => [
    amountUsd,
    country,
    localAmount,
    localCurrency,
    rate,
  ];
}

final class WithdrawalFxPreviewError extends WithdrawalState {
  final String message;
  const WithdrawalFxPreviewError(this.message);

  @override
  List<Object?> get props => [message];
}

final class WithdrawalAccountNameLoading extends WithdrawalState {}

final class WithdrawalAccountNameLoaded extends WithdrawalState {
  final String accountName;
  const WithdrawalAccountNameLoaded({required this.accountName});

  @override
  List<Object?> get props => [accountName];
}

final class WithdrawalAccountNameError extends WithdrawalState {
  final String message;
  const WithdrawalAccountNameError({required this.message});

  @override
  List<Object?> get props => [message];
}
