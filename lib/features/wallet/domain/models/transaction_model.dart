// lib/features/wallet/domain/models/transaction_model.dart

class TransactionModel {
  final String id;
  final DateTime date;
  final String method;
  final String type;

  /// Amount paid in USD dollars (double).
  /// - For 'purchase' rows: stored as double dollars (e.g. 0.20 = $0.20).
  /// - For other rows (gift_out, withdrawal, etc.): server returns cents as int;
  ///   the mapper converts to dollars by dividing by 100.
  ///   See WalletRemoteMapper for full logic.
  final double amountPaid;

  String? amountPaidLocal;

  /// Coins added (positive) or removed (negative).
  final int coinsChange;

  /// Coin balance after this transaction.
  final int? balanceAfter;

  /// Display name of related user (sender / recipient), if applicable.
  /// Populated from meta.from_user_name / meta.to_user_name, or null.
  final String? relatedUserName;

  /// Raw meta map from server (for any extra display data).
  final Map<String, dynamic>? meta;

  TransactionModel({
    required this.id,
    required this.date,
    required this.method,
    required this.type,
    required this.amountPaid,
    this.amountPaidLocal,
    required this.coinsChange,
    this.balanceAfter,
    this.relatedUserName,
    this.meta,
  });

  @override
  String toString() =>
      'Transaction(id: $id, type: $type, amount: \$$amountPaid, coinsChange: $coinsChange)';
}
