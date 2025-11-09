import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/models/coin_package.dart';
import '../../domain/models/transaction_model.dart';
import '../../domain/repositories/wallet_repository.dart';
import 'package:meta/meta.dart';

part 'wallet_state.dart';

class WalletCubit extends Cubit<WalletState> {
  final WalletRepository repo;
  WalletCubit(this.repo) : super(WalletInitial());

  /// Load everything the UI needs. Keeps this idempotent and returns void.
  Future<void> loadAll() async {
    emit(WalletLoading());
    try {
      final results = await Future.wait([
        repo.fetchBalance(),
        repo.fetchEarned(), // returns int (cents) — ensure repo provides this
        repo.fetchPackages(),
        repo.fetchRecentActivity(),
      ]);

      final balance = results[0] as int;
      final earnedCents = results[1] as double;
      final packages = results[2] as List<CoinPackage>;
      final recent = results[3] as List<TransactionModel>;

      emit(
        WalletLoaded(
          balance: balance,
          earnedBalance: earnedCents,
          packages: packages,
          recent: recent,
        ),
      );
    } catch (e) {
      emit(WalletError(message: e.toString()));
    }
  }

  /// If you still keep purchasePackage (legacy), ensure repo.purchasePackage is implemented.
  Future<TransactionModel?> buyPackage(String packageId) async {
    // Optionally emit a busy state that doesn't replace the whole list/summary UI
    emit(WalletBusy());
    try {
      final txn = await repo.purchasePackage(packageId);
      await loadAll(); // refresh after purchase
      return txn;
    } catch (e) {
      emit(WalletError(message: e.toString()));
      return null;
    }
  }

  /// Purchase using Play token (server verification)
  Future<TransactionModel?> purchaseWithToken({
    required String productId,
    required String purchaseToken,
    String? packageCode,
    String? idempotencyKey,
  }) async {
    // Keep UI responsive: Busy state while we contact server
    emit(WalletBusy());
    try {
      final txn = await repo.purchaseWithToken(
        productId: productId,
        purchaseToken: purchaseToken,
        packageCode: packageCode,
        idempotencyKey: idempotencyKey,
      );
      await loadAll();
      return txn;
    } catch (e) {
      emit(WalletError(message: e.toString()));
      return null;
    }
  }

  /// Purchase-and-gift combined flow
  Future<Map<String, dynamic>?> purchaseAndGift({
    required String productId,
    required String purchaseToken,
    required String giftCode,
    required String toUserUuid,
    String? livestreamId,
    String? idempotencyKey,
  }) async {
    emit(WalletBusy());
    try {
      final res = await repo.purchaseAndGift(
        productId: productId,
        purchaseToken: purchaseToken,
        giftCode: giftCode,
        toUserUuid: toUserUuid,
        livestreamId: livestreamId,
        idempotencyKey: idempotencyKey,
      );
      await loadAll();
      return res;
    } catch (e) {
      emit(WalletError(message: e.toString()));
      return null;
    }
  }
}
