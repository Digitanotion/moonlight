abstract class WithdrawalRepository {
  Future<int> getWithdrawableBalance();

  Future<void> verifyPin(String pin);

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
  });
}
