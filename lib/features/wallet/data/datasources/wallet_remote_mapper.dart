// lib/features/wallet/data/datasources/wallet_remote_mapper.dart
import '../../domain/models/coin_package.dart';
import '../../domain/models/transaction_model.dart';

/// Coin rate: 1 coin = $0.01 USD
///   coins → USD : coins * 0.01   (20 coins = $0.20)
///   USD → coins : usd / 0.01     ($0.20 = 20 coins)
///
/// price_usd_cents is a DOUBLE stored as dollars (e.g. 0.20, 1.39, 10.50).
/// Flutter reads it directly for display — no division needed.
/// Flutter sends it back to /purchase as-is.
class WalletRemoteMapper {
  /// Parse package JSON → CoinPackage
  static CoinPackage packageFromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['uuid'] ?? json['code'] ?? '').toString();
    final productId =
        (json['product_id'] ?? json['productId'] ?? json['sku'] ?? '')
            .toString();

    final coins = () {
      final v = json['coins'] ?? json['coin'] ?? 0;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }();

    // ✅ price_usd_cents is a DOUBLE (dollars): 0.20, 1.39, 10.50
    // Do NOT call .toInt() — that truncates 0.20 → 0
    final priceUsdCents = () {
      final raw = json['price_usd_cents'];
      if (raw is num) return raw.toDouble();
      if (raw is String) return double.tryParse(raw) ?? 0.0;
      return 0.0;
    }();

    return CoinPackage(
      id: id,
      productId: productId,
      coins: coins,
      priceUsdCents: priceUsdCents, // double dollars e.g. 0.20
    );
  }

  /// Parse transaction JSON → TransactionModel
  ///
  /// Server /purchase response shape:
  /// {
  ///   "data": {
  ///     "transaction": { uuid, amount_paid, coins_change, ... },  ← unwrap this
  ///     "coin_balance": 20,
  ///     "coins_added": 20
  ///   }
  /// }
  ///
  /// amount_paid is stored as DOUBLE dollars (e.g. 0.20, 1.39).
  /// Receipt screen: display directly as "$0.20" (no division needed).
  static TransactionModel transactionFromJson(Map<String, dynamic> json) {
    // ✅ Unwrap nested transaction key if present
    // datasource passes the full data{} map; transaction sits inside it
    final txnJson = (json['transaction'] is Map)
        ? Map<String, dynamic>.from(json['transaction'] as Map)
        : json;

    final id = (txnJson['uuid'] ?? txnJson['id'] ?? '').toString();

    // ✅ amount_paid is DOUBLE dollars (e.g. 0.20 = $0.20)
    final amountPaid = () {
      final v =
          txnJson['amount_paid'] ??
          txnJson['amountPaid'] ??
          txnJson['amount'] ??
          0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }();

    final coinsChange = () {
      final v =
          txnJson['coins_change'] ??
          txnJson['coins_added'] ??
          txnJson['coins'] ??
          0;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }();

    DateTime parseDate() {
      final raw =
          txnJson['created_at'] ??
          txnJson['createdAt'] ??
          txnJson['date'] ??
          txnJson['timestamp'] ??
          txnJson['time'];
      if (raw == null) return DateTime.now();
      if (raw is String) {
        final p = DateTime.tryParse(raw);
        if (p != null) return p;
        final asInt = int.tryParse(raw);
        if (asInt != null)
          return asInt > 1000000000000
              ? DateTime.fromMillisecondsSinceEpoch(asInt)
              : DateTime.fromMillisecondsSinceEpoch(asInt * 1000);
        return DateTime.now();
      }
      if (raw is int)
        return raw > 1000000000000
            ? DateTime.fromMillisecondsSinceEpoch(raw)
            : DateTime.fromMillisecondsSinceEpoch(raw * 1000);
      if (raw is double) {
        final i = raw.toInt();
        return i > 1000000000000
            ? DateTime.fromMillisecondsSinceEpoch(i)
            : DateTime.fromMillisecondsSinceEpoch(i * 1000);
      }
      return DateTime.now();
    }

    return TransactionModel(
      id: id,
      date: parseDate(),
      method: txnJson['method'] as String? ?? 'unknown',
      type: txnJson['type'] as String? ?? 'transaction',
      amountPaid: amountPaid, // ✅ double dollars e.g. 0.20
      coinsChange: coinsChange, // e.g. 20
    );
  }
}
