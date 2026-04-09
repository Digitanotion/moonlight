// ============================================================================
// lib/features/withdrawal/presentation/cubit/withdrawal_cubit.dart
//
// Fix: submitWithdrawal() and submitPayPalWithdrawal() now emit
// WithdrawalPending (not WithdrawalSuccess) because the API returning 201
// only means Flutterwave *queued* the transfer. The real outcome is async.
//
// Your UI should:
//   WithdrawalPending  → show "Processing" screen, NOT a success dialog
//   WithdrawalSuccess  → reserved for future confirmed-success webhook signal
//   WithdrawalError    → show error + refund message (coins already returned)
// ============================================================================

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import '../../domain/repositories/withdrawal_repository.dart';

part 'withdrawal_state.dart';

class WithdrawalCubit extends Cubit<WithdrawalState> {
  final WithdrawalRepository repository;

  Map<String, dynamic>? _lastWithdrawalData;
  String? _lastPin;

  WithdrawalCubit({required this.repository}) : super(WithdrawalInitial());

  // ── Balance ────────────────────────────────────────────────────────────────

  Future<void> loadBalance() async {
    emit(WithdrawalLoading());
    try {
      final balance = await repository.getWithdrawableBalance();
      emit(WithdrawalBalanceLoaded(balance: balance));
    } catch (e) {
      emit(WithdrawalError(message: _clean(e.toString())));
    }
  }

  // ── FX preview ─────────────────────────────────────────────────────────────

  Future<void> loadFxPreview({
    required double amountUsd,
    required String country,
  }) async {
    if (amountUsd < 100) return;

    emit(const WithdrawalFxPreviewLoading());

    try {
      final result = await repository.getFxPreview(
        amountUsd: amountUsd,
        country: country,
      );

      final localAmount = (result['local_amount'] as num?)?.toDouble() ?? 0.0;
      final localCurrency = (result['local_currency'] as String?) ?? 'USD';
      final rate = (result['rate'] as num?)?.toDouble() ?? 0.0;
      final note =
          (result['note'] as String?) ??
          'Rate is indicative. Final amount set at transfer time.';

      emit(
        WithdrawalFxPreviewLoaded(
          amountUsd: amountUsd,
          country: country,
          localAmount: localAmount,
          localCurrency: localCurrency,
          rate: rate,
          note: note,
        ),
      );
    } catch (e) {
      emit(WithdrawalFxPreviewError(_clean(e.toString())));
    }
  }

  // ── Banks ──────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchBanks(String country) {
    return repository.fetchBanks(country);
  }

  // ── Account name resolution ────────────────────────────────────────────────

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

      // ── FIX: Emit Pending, NOT Success ────────────────────────────────────
      // The server returns 201 when Flutterwave *queues* the transfer.
      // The transfer may still fail (e.g. insufficient NGN balance).
      // The user will be notified via push notification when the outcome is known.
      // Show a "Processing" screen — never a success dialog at this point.
      final reference = (result['reference'] as String?) ?? '';
      emit(
        WithdrawalPending(
          reference: reference,
          amountUsd: amountUsdCents,
          method: 'flutterwave',
          transactionData: result,
        ),
      );
    } catch (e) {
      // The server already refunded the coins before returning this error.
      // Show the error message directly — it will mention that coins were returned.
      _lastPin = null;
      emit(WithdrawalError(message: _clean(e.toString())));
    }
  }

  // ── PayPal withdrawal ──────────────────────────────────────────────────────

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

      final reference = (result['reference'] as String?) ?? '';
      emit(
        WithdrawalPending(
          reference: reference,
          amountUsd: amountUsd,
          method: 'paypal',
          transactionData: result,
        ),
      );
    } catch (e) {
      _lastPin = null;
      emit(WithdrawalError(message: _clean(e.toString())));
    }
  }

  // ── Retry ──────────────────────────────────────────────────────────────────

  Future<void> retryWithdrawal() async {
    final data = _lastWithdrawalData;
    final pin = _lastPin;

    if (data == null || pin == null) {
      emit(
        const WithdrawalError(message: 'Please re-enter your PIN to retry.'),
      );
      return;
    }

    if (data['type'] == 'paypal') {
      await submitPayPalWithdrawal(
        amountUsd: data['amountUsd'] as double,
        paypalEmail: data['paypalEmail'] as String,
        paypalEmailConfirm: data['paypalEmailConfirm'] as String,
        reason: data['reason'] as String?,
        pin: pin,
      );
    } else {
      await submitWithdrawal(
        amountUsdCents: data['amountUsdCents'] as double,
        bankAccountName: data['bankAccountName'] as String,
        bankAccountNumber: data['bankAccountNumber'] as String,
        bankName: data['bankName'] as String,
        bankCode: data['bankCode'] as String,
        country: data['country'] as String,
        swift: data['swift'] as String?,
        email: data['email'] as String?,
        phone: data['phone'] as String?,
        reason: data['reason'] as String?,
        pin: pin,
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

  String _clean(String s) => s
      .replaceFirst(RegExp(r'^Exception:\s*', caseSensitive: false), '')
      .trim();
}
