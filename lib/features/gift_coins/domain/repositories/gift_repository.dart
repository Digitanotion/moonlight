import '../entities/gift_user.dart';

abstract class GiftRepository {
  Future<int> getBalance();
  Future<List<GiftUser>> searchUsers(String query);

  /// Transfer coins to another user
  Future<void> transferCoins({
    required String toUserUuid,
    required int coins,
    String? reason,
    required String pin,
    String? idempotencyKey,
  });

  /// Verify PIN before transfer
  Future<void> verifyPin(String pin);
}
