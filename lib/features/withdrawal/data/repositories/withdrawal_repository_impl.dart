// lib/features/withdrawal/data/repositories/withdrawal_repository_impl.dart

import 'package:uuid/uuid.dart';
import '../../domain/repositories/withdrawal_repository.dart';
import '../datasources/withdrawal_remote_datasource.dart';

class WithdrawalRepositoryImpl implements WithdrawalRepository {
  final WithdrawalRemoteDataSource remote;
  WithdrawalRepositoryImpl(this.remote);

  @override
  Future<int> getWithdrawableBalance() => remote.getWithdrawableBalance();

  @override
  Future<void> verifyPin(String pin) => remote.verifyPin(pin);

  @override
  Future<List<Map<String, dynamic>>> fetchBanks(String country) =>
      remote.fetchBanks(country);

  @override
  Future<String> resolveAccountName({
    required String accountNumber,
    required String bankCode,
  }) => remote.resolveAccountName(
    accountNumber: accountNumber,
    bankCode: bankCode,
  );

  @override
  Future<Map<String, dynamic>> createWithdrawalRequest({
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
    String? idempotencyKey,
  }) {
    return remote.createWithdrawalRequest(
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
      idempotencyKey: idempotencyKey ?? const Uuid().v4(),
    );
  }

  @override
  Future<Map<String, dynamic>> createPayPalWithdrawal({
    required double amountUsd,
    required String paypalEmail,
    required String paypalEmailConfirm,
    String? reason,
    required String pin,
    String? idempotencyKey,
  }) {
    return remote.createPayPalWithdrawal(
      amountUsd: amountUsd,
      paypalEmail: paypalEmail,
      paypalEmailConfirm: paypalEmailConfirm,
      reason: reason,
      pin: pin,
      idempotencyKey: idempotencyKey ?? const Uuid().v4(),
    );
  }
}
