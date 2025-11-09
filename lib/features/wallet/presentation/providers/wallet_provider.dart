import 'package:flutter/material.dart';
import '../../domain/models/coin_package.dart';
import '../../domain/models/transaction_model.dart';
import '../../domain/repositories/wallet_repository.dart';

enum WalletState { idle, busy, error, loadingMore }

class WalletProvider extends ChangeNotifier {
  final WalletRepository repo;

  WalletProvider({required this.repo});

  WalletState state = WalletState.idle;
  int balance = 0;
  List<CoinPackage> packages = [];
  List<TransactionModel> recent = [];
  String? errorMessage;

  Future<void> loadAll({bool showLoading = true}) async {
    try {
      if (showLoading) state = WalletState.loadingMore;
      errorMessage = null;
      notifyListeners();

      final results = await Future.wait([
        repo.fetchBalance(),
        repo.fetchPackages(),
        repo.fetchRecentActivity(),
      ]);

      balance = results[0] as int;
      packages = List<CoinPackage>.from(results[1] as List<CoinPackage>);
      recent = List<TransactionModel>.from(
        results[2] as List<TransactionModel>,
      );
      state = WalletState.idle;
      notifyListeners();
    } catch (e, st) {
      state = WalletState.error;
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<TransactionModel?> buyPackage(String id, BuildContext context) async {
    try {
      state = WalletState.busy;
      notifyListeners();
      final txn = await repo.purchasePackage(id);
      // refresh data
      await loadAll(showLoading: false);
      state = WalletState.idle;
      notifyListeners();
      return txn;
    } catch (e) {
      state = WalletState.error;
      errorMessage = e.toString();
      notifyListeners();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Purchase failed: ${e.toString()}')),
      );
      return null;
    }
  }
}
