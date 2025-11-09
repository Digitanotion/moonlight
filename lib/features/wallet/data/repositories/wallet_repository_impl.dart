// lib/features/wallet/data/repositories/wallet_repository_impl.dart
import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../domain/models/coin_package.dart';
import '../../domain/models/transaction_model.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../datasources/remote_wallet_datasource.dart';

class WalletRepositoryImpl implements WalletRepository {
  final RemoteWalletDataSource remote;
  final Uuid _uuid = const Uuid();

  WalletRepositoryImpl({required this.remote});

  // --- Read operations (remote only) ---
  @override
  Future<int> fetchBalance() async {
    return await remote.fetchBalance();
  }

  @override
  Future<double> fetchEarned() async {
    return await remote.fetchEarned();
  }

  @override
  Future<List<CoinPackage>> fetchPackages() async {
    return await remote.fetchPackages();
  }

  @override
  Future<List<TransactionModel>> fetchRecentActivity() async {
    return await remote.fetchRecentActivity();
  }

  // --- Money operations (remote only) ---
  /// Purchase using Google Play purchase token.
  /// `productId` is the Play SKU, `purchaseToken` is the Play token.
  /// Returns a TransactionModel representing the purchase transaction.
  ///
  @override
  Future<TransactionModel> purchaseWithToken({
    required String productId,
    required String purchaseToken,
    String? packageCode,
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? _uuid.v4();
    final txn = await remote.purchase(
      productId: productId,
      purchaseToken: purchaseToken,
      packageCode: packageCode,
      idempotencyKey: key,
    );
    return txn;
  }

  /// Purchase-and-gift in one atomic operation.
  /// Returns a map with `gift_event` and `transactions`.
  Future<Map<String, dynamic>> purchaseAndGift({
    required String productId,
    required String purchaseToken,
    required String giftCode,
    required String toUserUuid,
    String? livestreamId,
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? _uuid.v4();
    final res = await remote.purchaseAndGift(
      productId: productId,
      purchaseToken: purchaseToken,
      giftCode: giftCode,
      toUserUuid: toUserUuid,
      livestreamId: livestreamId,
      idempotencyKey: key,
    );
    return res;
  }

  /// Gift using existing wallet balance (no purchase)
  Future<Map<String, dynamic>> gift({
    required String giftCode,
    required String toUserUuid,
    String? livestreamId,
    String? pin,
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? _uuid.v4();
    final res = await remote.gift(
      giftCode: giftCode,
      toUserUuid: toUserUuid,
      livestreamId: livestreamId,
      pin: pin,
      idempotencyKey: key,
    );
    return res;
  }

  /// Create transfer request
  Future<Map<String, dynamic>> createTransferRequest({
    required String toUserUuid,
    required int coins,
    String? reason,
    required String pin,
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? _uuid.v4();
    final res = await remote.createTransferRequest(
      toUserUuid: toUserUuid,
      coins: coins,
      reason: reason,
      pin: pin,
      idempotencyKey: key,
    );
    return res;
  }

  /// Create withdraw request
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
  }) async {
    final key = idempotencyKey ?? _uuid.v4();
    final res = await remote.createWithdrawRequest(
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
    return res;
  }

  /// Pin management
  Future<void> setPin(String pin) async {
    await remote.setPin(pin);
  }

  Future<bool> verifyPin(String pin) async {
    return await remote.verifyPin(pin);
  }

  // Keep interface-compatible method for older UI: forward to remote purchase
  @override
  Future<TransactionModel> purchasePackage(String packageId) {
    // Note: this method signature has only packageId (legacy). You must map packageId -> productId + purchaseToken
    // We choose to throw to force the UI to use purchaseWithToken with actual Play tokens.
    throw UnsupportedError(
      'purchasePackage(packageId) is not supported in remote-only mode. Use purchaseWithToken(productId, purchaseToken).',
    );
  }
}
