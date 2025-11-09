part of 'wallet_cubit.dart';

@immutable
abstract class WalletState extends Equatable {
  @override
  List<Object?> get props => [];
}

class WalletInitial extends WalletState {}

class WalletLoading extends WalletState {}

class WalletLoaded extends WalletState {
  final int balance;
  final double earnedBalance;
  final List<CoinPackage> packages;
  final List<TransactionModel> recent;
  WalletLoaded({
    required this.balance,
    required this.earnedBalance,
    required this.packages,
    required this.recent,
  });
  @override
  List<Object?> get props => [balance, packages, recent];
}

class WalletBusy extends WalletState {}

class WalletError extends WalletState {
  final String message;
  WalletError({required this.message});
  @override
  List<Object?> get props => [message];
}
