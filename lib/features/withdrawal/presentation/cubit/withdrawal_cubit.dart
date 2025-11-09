import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import '../../domain/repositories/withdrawal_repository.dart';

part 'withdrawal_state.dart';

class WithdrawalCubit extends Cubit<WithdrawalState> {
  final WithdrawalRepository repository;

  // For retry functionality
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

  /// Verify PIN + submit withdrawal request
  Future<void> submitWithdrawal({
    required int amountUsdCents,
    required String bankAccountName,
    required String bankAccountNumber,
    required String bankName,
    required String country,
    String? swift,
    String? email,
    String? phone,
    String? reason,
    required String pin,
  }) async {
    // Save for retry
    _lastWithdrawalData = {
      'amountUsdCents': amountUsdCents,
      'bankAccountName': bankAccountName,
      'bankAccountNumber': bankAccountNumber,
      'bankName': bankName,
      'country': country,
      'swift': swift,
      'email': email,
      'phone': phone,
      'reason': reason,
    };
    _lastPin = pin;

    emit(WithdrawalSubmitting());

    try {
      // 1️⃣ Verify PIN
      await repository.verifyPin(pin);

      // 2️⃣ Execute withdrawal request
      final result = await repository.createWithdrawalRequest(
        amountUsdCents: amountUsdCents,
        bankAccountName: bankAccountName,
        bankAccountNumber: bankAccountNumber,
        bankName: bankName,
        country: country,
        swift: swift,
        email: email,
        phone: phone,
        reason: reason,
        pin: pin,
      );

      // 3️⃣ Emit success
      emit(WithdrawalSuccess(transactionData: result));

      // Clear last data
      _lastWithdrawalData = null;
      _lastPin = null;
    } catch (e) {
      emit(WithdrawalError(message: _short(e.toString())));
    }
  }

  /// Retry last withdrawal
  Future<void> retryWithdrawal() async {
    if (_lastWithdrawalData == null || _lastPin == null) return;

    await submitWithdrawal(
      amountUsdCents: _lastWithdrawalData!['amountUsdCents'],
      bankAccountName: _lastWithdrawalData!['bankAccountName'],
      bankAccountNumber: _lastWithdrawalData!['bankAccountNumber'],
      bankName: _lastWithdrawalData!['bankName'],
      country: _lastWithdrawalData!['country'],
      swift: _lastWithdrawalData!['swift'],
      email: _lastWithdrawalData!['email'],
      phone: _lastWithdrawalData!['phone'],
      reason: _lastWithdrawalData!['reason'],
      pin: _lastPin!,
    );
  }

  /// Reset to initial state
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
