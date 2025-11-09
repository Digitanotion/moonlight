import '../../domain/entities/gift_user.dart';
import '../../domain/repositories/gift_repository.dart';
import '../datasources/gift_remote_datasource.dart';
import 'package:uuid/uuid.dart';

class GiftRepositoryImpl implements GiftRepository {
  final GiftRemoteDataSource remote;

  GiftRepositoryImpl(this.remote);

  @override
  Future<int> getBalance() => remote.getBalance();

  @override
  Future<List<GiftUser>> searchUsers(String query) => remote.searchUsers(query);

  @override
  Future<void> verifyPin(String pin) => remote.verifyPin(pin);

  @override
  Future<void> transferCoins({
    required String toUserUuid,
    required int coins,
    String? reason,
    required String pin,
    String? idempotencyKey,
  }) async {
    final key = idempotencyKey ?? const Uuid().v4();
    print(
      'RAECIPIENT: {$toUserUuid}, coins:{$coins}, reason:{$reason}, pin:{$pin}',
    );
    await remote.transferCoins(
      toUserUuid: toUserUuid,
      coins: coins,
      reason: reason,
      pin: pin,
      idempotencyKey: key,
    );
  }
}
