// lib/features/withdrawal/presentation/cubit/withdrawal_cubit.dart

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import '../../domain/repositories/withdrawal_repository.dart';

part 'withdrawal_state.dart';

class WithdrawalCubit extends Cubit<WithdrawalState> {
  final WithdrawalRepository repository;

  // ── Retry cache ────────────────────────────────────────────────────────────
  Map<String, dynamic>? _lastWithdrawalData;
  String? _lastPin;

  WithdrawalCubit({required this.repository}) : super(WithdrawalInitial());

  // ── Balance ────────────────────────────────────────────────────────────────

  /// Load the user's current withdrawable balance.
  Future<void> loadBalance() async {
    emit(WithdrawalLoading());
    try {
      final balance = await repository.getWithdrawableBalance();
      emit(WithdrawalBalanceLoaded(balance: balance));
    } catch (e) {
      emit(WithdrawalError(message: _clean(e.toString())));
    }
  }

  Future<void> loadFxPreview({
    required double amountUsd,
    required String country,
  }) async {
    if (amountUsd < 100) {
      emit(
        WithdrawalFxPreviewLoaded(
          amountUsd: amountUsd,
          country: country,
          localAmount: 0,
          localCurrency: 'USD',
          rate: 0,
          note: 'Minimum withdrawal is \$100.00',
        ),
      );
      return;
    }

    emit(const WithdrawalFxPreviewLoading());

    try {
      final result = await repository.getFxPreview(
        amountUsd: amountUsd,
        country: country,
      );

      emit(
        WithdrawalFxPreviewLoaded(
          amountUsd: amountUsd,
          country: country,
          localAmount: (result['they_receive']['amount'] as num).toDouble(),
          localCurrency: result['they_receive']['currency'] as String,
          rate: (result['rate'] as num).toDouble(),
          note:
              result['note'] as String? ??
              'Rate is indicative. Final amount set at transfer time.',
        ),
      );
    } catch (e) {
      emit(WithdrawalFxPreviewError(e.toString()));
    }
  }

  // ── Banks ──────────────────────────────────────────────────────────────────

  /// Fetch Flutterwave bank list for a given country name (e.g. "Nigeria").
  Future<List<Map<String, dynamic>>> fetchBanks(String country) {
    return repository.fetchBanks(country);
  }

  // ── Account name resolution (Flutterwave) ──────────────────────────────────

  /// Resolve the account holder name for [accountNumber] at [bankCode].
  /// Emits [WithdrawalAccountNameLoading] → [WithdrawalAccountNameLoaded] or
  /// [WithdrawalAccountNameError].
  /// The previous balance state is preserved; the page re-syncs it via the
  /// builder, so this does not overwrite [WithdrawalBalanceLoaded].
  Future<void> resolveAccountName({
    required String accountNumber,
    required String bankCode,
  }) async {
    if (accountNumber.length < 8 || bankCode.isEmpty) return;

    emit(WithdrawalAccountNameLoading());

    try {
      final name = await repository.resolveAccountName(
        accountNumber: accountNumber,
        bankCode: bankCode,
      );
      emit(WithdrawalAccountNameLoaded(accountName: name));
    } catch (e) {
      emit(WithdrawalAccountNameError(message: _clean(e.toString())));
    }
  }

  // ── Flutterwave withdrawal ─────────────────────────────────────────────────

  /// Submit a Flutterwave bank-transfer withdrawal.
  Future<void> submitWithdrawal({
    required double amountUsdCents,
    required String bankAccountName,
    required String bankAccountNumber,
    required String bankName,
    required String bankCode,
    required String country,
    String? swift,
    String? email,
    String? phone,
    String? reason,
    required String pin,
  }) async {
    _lastWithdrawalData = {
      'type': 'flutterwave',
      'amountUsdCents': amountUsdCents,
      'bankAccountName': bankAccountName,
      'bankAccountNumber': bankAccountNumber,
      'bankName': bankName,
      'bankCode': bankCode,
      'country': country,
      'swift': swift,
      'email': email,
      'phone': phone,
      'reason': reason,
    };
    _lastPin = pin;

    emit(WithdrawalSubmitting());

    try {
      final result = await repository.createWithdrawalRequest(
        amountUsdCents: amountUsdCents,
        bankAccountName: bankAccountName,
        bankAccountNumber: bankAccountNumber,
        bankName: bankName,
        bankCode: bankCode,
        country: country,
        swift: swift,
        email: email,
        phone: phone,
        reason: reason,
        pin: pin,
      );

      _clearRetryCache();
      emit(WithdrawalSuccess(transactionData: result));
    } catch (e) {
      emit(WithdrawalError(message: _clean(e.toString())));
    }
  }

  // ── PayPal withdrawal ──────────────────────────────────────────────────────

  /// Submit a PayPal payout withdrawal.
  Future<void> submitPayPalWithdrawal({
    required double amountUsd,
    required String paypalEmail,
    required String paypalEmailConfirm,
    String? reason,
    required String pin,
  }) async {
    _lastWithdrawalData = {
      'type': 'paypal',
      'amountUsd': amountUsd,
      'paypalEmail': paypalEmail,
      'paypalEmailConfirm': paypalEmailConfirm,
      'reason': reason,
    };
    _lastPin = pin;

    emit(WithdrawalSubmitting());

    try {
      final result = await repository.createPayPalWithdrawal(
        amountUsd: amountUsd,
        paypalEmail: paypalEmail,
        paypalEmailConfirm: paypalEmailConfirm,
        reason: reason,
        pin: pin,
      );

      _clearRetryCache();
      emit(WithdrawalSuccess(transactionData: result));
    } catch (e) {
      emit(WithdrawalError(message: _clean(e.toString())));
    }
  }

  // ── Retry ──────────────────────────────────────────────────────────────────

  Future<void> retryWithdrawal() async {
    if (_lastWithdrawalData == null || _lastPin == null) return;
    final d = _lastWithdrawalData!;

    if (d['type'] == 'paypal') {
      await submitPayPalWithdrawal(
        amountUsd: d['amountUsd'],
        paypalEmail: d['paypalEmail'],
        paypalEmailConfirm: d['paypalEmailConfirm'],
        reason: d['reason'],
        pin: _lastPin!,
      );
    } else {
      await submitWithdrawal(
        amountUsdCents: d['amountUsdCents'],
        bankAccountName: d['bankAccountName'],
        bankAccountNumber: d['bankAccountNumber'],
        bankName: d['bankName'],
        bankCode: d['bankCode'],
        country: d['country'],
        swift: d['swift'],
        email: d['email'],
        phone: d['phone'],
        reason: d['reason'],
        pin: _lastPin!,
      );
    }
  }

  // ── Reset ──────────────────────────────────────────────────────────────────

  void reset() {
    _clearRetryCache();
    emit(WithdrawalInitial());
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _clearRetryCache() {
    _lastWithdrawalData = null;
    _lastPin = null;
  }

  String _clean(String s) {
    return s
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^exception:\s*'), '')
        .trim();
  }
}
