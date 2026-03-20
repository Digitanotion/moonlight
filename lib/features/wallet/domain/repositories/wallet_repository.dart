// lib/features/wallet/domain/repositories/wallet_repository.dart
import '../models/coin_package.dart';
import '../models/transaction_model.dart';

/// Repository contract for wallet-related operations.
abstract class WalletRepository {
  // ── Read ──────────────────────────────────────────────────────────────────

  Future<int> fetchBalance();
  Future<double> fetchEarned();
  Future<List<CoinPackage>> fetchPackages();
  Future<List<TransactionModel>> fetchRecentActivity();

  // ── Purchases ─────────────────────────────────────────────────────────────

  /// Purchase using a Google Play purchase token.
  ///
  /// [priceUsdCents] — price extracted from Google Play's ProductDetails
  ///   (skuDetails.priceAmountMicros / 10000). This is the authoritative price
  ///   in USD cents regardless of the user's local currency display.
  ///   e.g. $0.99 → 99  |  $4.99 → 499  |  $9.99 → 999
  ///   The server uses this to compute coins = priceUsdCents / 0.01.
  ///   Pass 0 only if unavailable — server will fall back to the DB value.
  Future<TransactionModel> purchaseWithToken({
    required String productId,
    required String purchaseToken,
    required double? priceUsdCents, // ✅ from Google Play ProductDetails
    String? packageCode,
    String? idempotencyKey,
    String? actual_price_paid,
    String? actual_price_currency,
  });

  /// Legacy compatibility — throws UnsupportedError in remote-only mode.
  Future<TransactionModel> purchasePackage(String packageId);

  /// Purchase-and-gift atomically.
  Future<Map<String, dynamic>> purchaseAndGift({
    required String productId,
    required String purchaseToken,
    required String giftCode,
    required String toUserUuid,
    String? livestreamId,
    String? idempotencyKey,
  });

  // ── Gifts & transfers ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> gift({
    required String giftCode,
    required String toUserUuid,
    String? livestreamId,
    String? pin,
    String? idempotencyKey,
  });

  Future<Map<String, dynamic>> createTransferRequest({
    required String toUserUuid,
    required int coins,
    String? reason,
    required String pin,
    String? idempotencyKey,
  });

  // ── Withdrawals ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createWithdrawRequest({
    required double amountUsdCents,
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

  // ── PIN ──────────────────────────────────────────────────────────────────

  Future<void> setPin(String pin);
  Future<bool> verifyPin(String pin);
}
