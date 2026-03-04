// lib/features/withdrawal/presentation/cubit/withdrawal_cubit.dart

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

  /// Load user's current withdrawable balance
  Future<void> loadBalance() async {
    emit(WithdrawalLoading());
    try {
      final balance = await repository.getWithdrawableBalance();
      emit(WithdrawalBalanceLoaded(balance: balance));
    } catch (e) {
      emit(WithdrawalError(message: _short(e.toString())));
    }
  }

  /// Fetch bank list for a given country from Flutterwave (via backend)
  Future<List<Map<String, dynamic>>> fetchBanks(String country) async {
    return await repository.fetchBanks(country);
  }

  /// Submit withdrawal — PIN verification + Flutterwave transfer
  Future<void> submitWithdrawal({
    required int amountUsdCents,
    required String bankAccountName,
    required String bankAccountNumber,
    required String bankName,
    required String bankCode, // ← Flutterwave bank code
    required String country,
    String? swift,
    String? email,
    String? phone,
    String? reason,
    required String pin,
  }) async {
    _lastWithdrawalData = {
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
      // 1. Verify PIN
      await repository.verifyPin(pin);

      // 2. Execute withdrawal (Flutterwave instant transfer)
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

      emit(WithdrawalSuccess(transactionData: result));

      _lastWithdrawalData = null;
      _lastPin = null;
    } catch (e) {
      emit(WithdrawalError(message: _short(e.toString())));
    }
  }

  /// Retry last withdrawal
  Future<void> retryWithdrawal() async {
    if (_lastWithdrawalData == null || _lastPin == null) return;
    final d = _lastWithdrawalData!;
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

  void reset() {
    emit(WithdrawalInitial());
    _lastWithdrawalData = null;
    _lastPin = null;
  }

  String _short(String s) {
    if (s.contains('Exception:')) s = s.replaceFirst('Exception:', '');
    return s.trim();
  }
}
