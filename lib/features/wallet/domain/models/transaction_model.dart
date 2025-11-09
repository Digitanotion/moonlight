class TransactionModel {
  final String id;
  final DateTime date;
  final String method;
  final String type;
  final int amountPaid; // in naira
  final int coinsChange; // positive or negative

  TransactionModel({
    required this.id,
    required this.date,
    required this.method,
    required this.type,
    required this.amountPaid,
    required this.coinsChange,
  });

  @override
  String toString() =>
      'Transaction(id: $id, amount: $amountPaid), coinsChange=$coinsChange';
}
