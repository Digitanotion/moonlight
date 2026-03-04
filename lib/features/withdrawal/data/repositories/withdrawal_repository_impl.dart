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
  Future<Map<String, dynamic>> createWithdrawalRequest({
    required int amountUsdCents,
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
  }) async {
    final key = idempotencyKey ?? const Uuid().v4();
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
      idempotencyKey: key,
    );
  }
}
