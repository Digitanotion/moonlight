// lib/features/wallet/domain/repositories/wallet_repository.dart
import '../../data/datasources/remote_wallet_datasource.dart'
    show RemoteWalletDataSource; // optional - remove if not needed
import '../models/coin_package.dart';
import '../models/transaction_model.dart';

/// Repository contract for wallet-related operations.
/// Implementations may be remote-only or combine remote + local caches.
abstract class WalletRepository {
  // --- Read operations (remote only) ---
  /// Fetch the user's current wallet balance (coins).
  Future<int> fetchBalance();

  /// Fetch the user's earned amount (e.g., USD or other metric).
  Future<double> fetchEarned();

  /// Fetch available coin packages that can be purchased.
  Future<List<CoinPackage>> fetchPackages();

  /// Fetch recent wallet activity (transactions).
  Future<List<TransactionModel>> fetchRecentActivity();

  // --- Money operations (remote only) ---

  /// Purchase using a platform (Google Play) purchase token.
  /// - [productId] is the platform SKU/product id.
  /// - [purchaseToken] is the platform purchase token.
  /// - [packageCode] optional mapping to a package code.
  /// - [idempotencyKey] optional idempotency key to prevent double purchases.
  Future<TransactionModel> purchaseWithToken({
    required String productId,
    required String purchaseToken,
    String? packageCode,
    String? idempotencyKey,
  });

  /// Legacy/compatibility method used by older UI code.
  /// Implementations may throw UnsupportedError if not supported.
  Future<TransactionModel> purchasePackage(String packageId);

  /// Purchase-and-gift (atomic): purchase coins and gift them to another user.
  /// Returns a map that typically contains the gift event and created transactions.
  Future<Map<String, dynamic>> purchaseAndGift({
    required String productId,
    required String purchaseToken,
    required String giftCode,
    required String toUserUuid,
    String? livestreamId,
    String? idempotencyKey,
  });

  /// Gift using existing wallet balance (no purchase).
  /// Returns a map with the gift event and any related transactions.
  Future<Map<String, dynamic>> gift({
    required String giftCode,
    required String toUserUuid,
    String? livestreamId,
    String? pin,
    String? idempotencyKey,
  });

  /// Create a transfer request (coins) to another user.
  /// Returns a map containing the created transfer request or errors.
  Future<Map<String, dynamic>> createTransferRequest({
    required String toUserUuid,
    required int coins,
    String? reason,
    required String pin,
    String? idempotencyKey,
  });

  /// Create a withdraw request (fiat).
  /// Returns a map containing the created withdraw request or errors.
  Future<Map<String, dynamic>> createWithdrawRequest({
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

  // --- Pin management ---
  /// Set a wallet PIN.
  Future<void> setPin(String pin);

  /// Verify the provided PIN. Returns true if valid.
  Future<bool> verifyPin(String pin);
}
