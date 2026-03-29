// lib/features/withdrawal/domain/repositories/withdrawal_repository.dart

abstract class WithdrawalRepository {
  // ── Balance ────────────────────────────────────────────────────────────────

  /// Returns the withdrawable balance in cents.
  Future<int> getWithdrawableBalance();

  // ── PIN ────────────────────────────────────────────────────────────────────

  /// Throws an [Exception] if the PIN is wrong or not set.
  Future<void> verifyPin(String pin);

  // ── Banks (Flutterwave) ────────────────────────────────────────────────────

  /// Fetch Flutterwave bank list for a given country name (e.g. "Nigeria").
  Future<List<Map<String, dynamic>>> fetchBanks(String country);

  // ── Account name resolution (Flutterwave) ─────────────────────────────────

  /// Resolve the account holder name for [accountNumber] at [bankCode].
  /// Returns the account name string (e.g. "JOHN DOE").
  /// Throws an [Exception] on failure.
  Future<String> resolveAccountName({
    required String accountNumber,
    required String bankCode,
  });

  // ── Flutterwave bank transfer withdrawal ───────────────────────────────────

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
  });

  // ── PayPal payout withdrawal ───────────────────────────────────────────────

  /// Submit a PayPal withdrawal payout.
  /// [paypalEmailConfirm] is validated client-side and also sent to the server.
  Future<Map<String, dynamic>> createPayPalWithdrawal({
    required double amountUsd,
    required String paypalEmail,
    required String paypalEmailConfirm,
    String? reason,
    required String pin,
    String? idempotencyKey,
  });

  /// Get FX rate preview for USD to local currency
  Future<Map<String, dynamic>> getFxPreview({
    required double amountUsd,
    required String country,
  });
}
