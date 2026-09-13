// lib/features/offerwall/presentation/cubit/offerwall_cubit.dart

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:moonlight/core/network/error_parser.dart';
import 'package:moonlight/features/offerwall/data/datasources/offerwall_remote_data_source.dart';

class OfferwallState extends Equatable {
  final bool loading;
  final bool activating;
  final bool activated;
  final int activationCostCoins;
  final int balanceUsdCents;
  final int lifetimeEarnedUsdCents;
  final int minWithdrawUsdCents;
  final int maxWithdrawUsdCents;
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> withdrawals;
  final String? error;

  const OfferwallState({
    this.loading = false,
    this.activating = false,
    this.activated = false,
    this.activationCostCoins = 100,
    this.balanceUsdCents = 0,
    this.lifetimeEarnedUsdCents = 0,
    this.minWithdrawUsdCents = 1500,
    this.maxWithdrawUsdCents = 10000,
    this.transactions = const [],
    this.withdrawals = const [],
    this.error,
  });

  double get balanceUsd => balanceUsdCents / 100;

  OfferwallState copyWith({
    bool? loading,
    bool? activating,
    bool? activated,
    int? activationCostCoins,
    int? balanceUsdCents,
    int? lifetimeEarnedUsdCents,
    int? minWithdrawUsdCents,
    int? maxWithdrawUsdCents,
    List<Map<String, dynamic>>? transactions,
    List<Map<String, dynamic>>? withdrawals,
    bool clearError = false,
    String? error,
  }) {
    return OfferwallState(
      loading: loading ?? this.loading,
      activating: activating ?? this.activating,
      activated: activated ?? this.activated,
      activationCostCoins: activationCostCoins ?? this.activationCostCoins,
      balanceUsdCents: balanceUsdCents ?? this.balanceUsdCents,
      lifetimeEarnedUsdCents:
          lifetimeEarnedUsdCents ?? this.lifetimeEarnedUsdCents,
      minWithdrawUsdCents: minWithdrawUsdCents ?? this.minWithdrawUsdCents,
      maxWithdrawUsdCents: maxWithdrawUsdCents ?? this.maxWithdrawUsdCents,
      transactions: transactions ?? this.transactions,
      withdrawals: withdrawals ?? this.withdrawals,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    loading,
    activating,
    activated,
    activationCostCoins,
    balanceUsdCents,
    lifetimeEarnedUsdCents,
    minWithdrawUsdCents,
    maxWithdrawUsdCents,
    transactions,
    withdrawals,
    error,
  ];
}

class OfferwallCubit extends Cubit<OfferwallState> {
  final OfferwallRemoteDataSource ds;
  OfferwallCubit(this.ds) : super(const OfferwallState());

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final status = await ds.getStatus();
      emit(
        state.copyWith(
          loading: false,
          activated: status['activated'] == true,
          activationCostCoins: (status['activation_cost_coins'] ?? 100) as int,
          balanceUsdCents: (status['balance_usd_cents'] ?? 0) as int,
          lifetimeEarnedUsdCents:
              (status['lifetime_earned_usd_cents'] ?? 0) as int,
          minWithdrawUsdCents:
              (status['min_withdraw_usd_cents'] ?? 1500) as int,
          maxWithdrawUsdCents:
              (status['max_withdraw_usd_cents'] ?? 10000) as int,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, error: apiErrorMessage(e)));
    }
  }

  Future<bool> activate() async {
    emit(state.copyWith(activating: true, clearError: true));
    try {
      await ds.activate();
      emit(state.copyWith(activating: false, activated: true));
      return true;
    } catch (e) {
      emit(state.copyWith(activating: false, error: apiErrorMessage(e)));
      return false;
    }
  }

  Future<void> loadTransactions() async {
    try {
      final items = await ds.getTransactions();
      emit(state.copyWith(transactions: items));
    } catch (e) {
      emit(state.copyWith(error: apiErrorMessage(e)));
    }
  }

  Future<void> loadWithdrawals() async {
    try {
      final items = await ds.getWithdrawals();
      emit(state.copyWith(withdrawals: items));
    } catch (e) {
      emit(state.copyWith(error: apiErrorMessage(e)));
    }
  }

  /// Returns the server's confirmation message on success, or throws with a
  /// user-facing message on failure (caller shows it via TopSnack).
  Future<String> requestWithdrawal({
    required int amountUsdCents,
    required String paymentMethod,
    String? bankAccountName,
    String? bankAccountNumber,
    String? bankName,
    String? bankCode,
    String? bankCountry,
    String? paypalEmail,
  }) async {
    final idempotencyKey =
        'offerwall_wd_${DateTime.now().microsecondsSinceEpoch}';
    try {
      final res = await ds.requestWithdrawal({
        'amount_usd_cents': amountUsdCents,
        'payment_method': paymentMethod,
        'idempotency_key': idempotencyKey,
        if (bankAccountName != null) 'bank_account_name': bankAccountName,
        if (bankAccountNumber != null) 'bank_account_number': bankAccountNumber,
        if (bankName != null) 'bank_name': bankName,
        if (bankCode != null) 'bank_code': bankCode,
        if (bankCountry != null) 'bank_country': bankCountry,
        if (paypalEmail != null) 'paypal_email': paypalEmail,
      });

      // Reflect the reserved amount locally right away rather than waiting
      // for a full reload — the request already deducted it server-side.
      emit(
        state.copyWith(balanceUsdCents: state.balanceUsdCents - amountUsdCents),
      );
      unawaited(loadWithdrawals());

      return (res['message'] as String?) ??
          'Your withdrawal is processing and will take up to 3 working days to be approved.';
    } catch (e) {
      throw Exception(apiErrorMessage(e));
    }
  }
}
