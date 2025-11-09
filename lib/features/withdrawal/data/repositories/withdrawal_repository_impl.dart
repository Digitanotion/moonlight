import '../../domain/repositories/withdrawal_repository.dart';
import '../datasources/withdrawal_remote_datasource.dart';
import 'package:uuid/uuid.dart';

class WithdrawalRepositoryImpl implements WithdrawalRepository {
  final WithdrawalRemoteDataSource remote;

  WithdrawalRepositoryImpl(this.remote);

  @override
  Future<int> getWithdrawableBalance() => remote.getWithdrawableBalance();

  @override
  Future<void> verifyPin(String pin) => remote.verifyPin(pin);

  @override
  Future<Map<String, dynamic>> createWithdrawalRequest({
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
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? const Uuid().v4();

    print(
      'WITHDRAWAL REQUEST: amount: \$${(amountUsdCents / 100).toStringAsFixed(2)}, '
      'bank: $bankName, account: $bankAccountNumber, name: $bankAccountName',
    );

    return await remote.createWithdrawalRequest(
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
      idempotencyKey: key,
    );
  }
}
