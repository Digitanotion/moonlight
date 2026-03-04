abstract class WithdrawalRepository {
  Future<int> getWithdrawableBalance();
  Future<void> verifyPin(String pin);

  /// Fetch Flutterwave bank list for a given country name (e.g. "Nigeria")
  Future<List<Map<String, dynamic>>> fetchBanks(String country);

  Future<Map<String, dynamic>> createWithdrawalRequest({
    required int amountUsdCents,
    required String bankAccountName,
    required String bankAccountNumber,
    required String bankName,
    required String bankCode, // ← Flutterwave bank code e.g. "044"
    required String country,
    String? swift,
    String? email,
    String? phone,
    String? reason,
    required String pin,
    String? idempotencyKey,
  });
}
