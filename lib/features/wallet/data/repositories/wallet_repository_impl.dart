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

  // ── Read ──────────────────────────────────────────────────────────────────

  @override
  Future<int> fetchBalance() => remote.fetchBalance();

  @override
  Future<double> fetchEarned() => remote.fetchEarned();

  @override
  Future<List<CoinPackage>> fetchPackages() => remote.fetchPackages();

  @override
  Future<List<TransactionModel>> fetchRecentActivity() =>
      remote.fetchRecentActivity();

  // ── Purchases ─────────────────────────────────────────────────────────────

  /// [priceUsdCents] comes from Google Play's ProductDetails.skuDetails
  /// .priceAmountMicros / 10000. Pass it through to the server so the server
  /// can compute coins = priceUsdCents / 0.01 using the real Play price,
  /// not a stale DB value.
  @override
  Future<TransactionModel> purchaseWithToken({
    required String productId,
    required String purchaseToken,
    required int? priceUsdCents, // ✅ from Google Play
    String? packageCode,
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? _uuid.v4();
    return remote.purchase(
      productId: productId,
      purchaseToken: purchaseToken,
      priceUsdCents: priceUsdCents, // ✅ passed to datasource → HTTP body
      packageCode: packageCode,
      idempotencyKey: key,
    );
  }

  @override
  Future<TransactionModel> purchasePackage(String packageId) {
    throw UnsupportedError(
      'purchasePackage(packageId) is not supported. '
      'Use purchaseWithToken(productId, purchaseToken, priceUsdCents).',
    );
  }

  // ── Purchase-and-gift ────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> purchaseAndGift({
    required String productId,
    required String purchaseToken,
    required String giftCode,
    required String toUserUuid,
    String? livestreamId,
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? _uuid.v4();
    return remote.purchaseAndGift(
      productId: productId,
      purchaseToken: purchaseToken,
      giftCode: giftCode,
      toUserUuid: toUserUuid,
      livestreamId: livestreamId,
      idempotencyKey: key,
    );
  }

  // ── Gifts & transfers ────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> gift({
    required String giftCode,
    required String toUserUuid,
    String? livestreamId,
    String? pin,
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? _uuid.v4();
    return remote.gift(
      giftCode: giftCode,
      toUserUuid: toUserUuid,
      livestreamId: livestreamId,
      pin: pin,
      idempotencyKey: key,
    );
  }

  @override
  Future<Map<String, dynamic>> createTransferRequest({
    required String toUserUuid,
    required int coins,
    String? reason,
    required String pin,
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? _uuid.v4();
    return remote.createTransferRequest(
      toUserUuid: toUserUuid,
      coins: coins,
      reason: reason,
      pin: pin,
      idempotencyKey: key,
    );
  }

  // ── Withdrawals ──────────────────────────────────────────────────────────

  @override
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
    return remote.createWithdrawRequest(
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

  // ── PIN ──────────────────────────────────────────────────────────────────

  @override
  Future<void> setPin(String pin) => remote.setPin(pin);

  @override
  Future<bool> verifyPin(String pin) => remote.verifyPin(pin);
}
