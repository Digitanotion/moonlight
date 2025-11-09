// import 'dart:async';
// import '../../domain/models/coin_package.dart';
// import '../../domain/models/transaction_model.dart';

// class LocalWalletDataSource {
//   int _balance = 5200;
//   final List<CoinPackage> _packages = [
//     CoinPackage(id: 'p1', coins: 500, priceUSD: 2500),
//     CoinPackage(id: 'p2', coins: 1000, priceUSD: 5000),
//     CoinPackage(id: 'p3', coins: 2500, priceUSD: 12000),
//     CoinPackage(id: 'p4', coins: 5000, priceUSD: 23000),
//     CoinPackage(id: 'p5', coins: 10000, priceUSD: 45000),
//   ];

//   // final List<TransactionModel> _transactions = [
//   //   TransactionModel(
//   //     id: 't1',
//   //     date: DateTime.now().subtract(Duration(hours: 2)),
//   //     method: 'Gift',
//   //     amountPaid: 0,
//   //     coinsChange: 250,
//   //   ),
//   //   TransactionModel(
//   //     id: 't2',
//   //     date: DateTime.now().subtract(Duration(days: 1)),
//   //     method: 'Coin Purchase',
//   //     amountPaid: 5000,
//   //     coinsChange: 1000,
//   //   ),
//   //   TransactionModel(
//   //     id: 't3',
//   //     date: DateTime.now().subtract(Duration(days: 2)),
//   //     method: 'Gift',
//   //     amountPaid: 0,
//   //     coinsChange: -150,
//   //   ),
//   //   TransactionModel(
//   //     id: 't4',
//   //     date: DateTime.now().subtract(Duration(days: 3)),
//   //     method: 'Transfer',
//   //     amountPaid: 0,
//   //     coinsChange: -300,
//   //   ),
//   // ];

//   Future<T> _simulate<T>(T res, {int ms = 700}) async {
//     await Future.delayed(Duration(milliseconds: ms));
//     return res;
//   }

//   Future<int> getBalance() => _simulate(_balance);

//   Future<List<CoinPackage>> getPackages() =>
//       _simulate(List<CoinPackage>.from(_packages));

//   Future<List<TransactionModel>> getTransactions() =>
//       _simulate(List<TransactionModel>.from(_transactions));

//   Future<TransactionModel> buyPackage(String packageId) async {
//     // find package
//     final pkg = _packages.firstWhere((p) => p.id == packageId);
//     // simulate network
//     await Future.delayed(Duration(milliseconds: 900));
//     // update balance and transactions
//     _balance += pkg.coins;
//     final txn = TransactionModel(
//       id: 'txn_${DateTime.now().millisecondsSinceEpoch}',
//       date: DateTime.now(),
//       method: 'Google Pay', // dummy
//       amountPaid: pkg.priceUSD,
//       coinsChange: pkg.coins,
//     );
//     _transactions.insert(0, txn);
//     return txn;
//   }
// }
