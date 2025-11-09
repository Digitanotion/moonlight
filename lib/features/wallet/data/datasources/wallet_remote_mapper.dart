// lib/features/wallet/data/datasources/wallet_remote_mapper.dart
import '../../domain/models/coin_package.dart';
import '../../domain/models/transaction_model.dart';

class WalletRemoteMapper {
  /// Parse package JSON from the API into CoinPackage.
  /// Accepts several common key variants and normalizes price to USD cents (int).
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

    final priceUsdCents = () {
      // support price_usd_cents, priceUsdCents, priceUSD (cents), or price (dollars)
      if (json['price_usd_cents'] != null && json['price_usd_cents'] is num) {
        return (json['price_usd_cents'] as num).toInt();
      }
      if (json['priceUsdCents'] != null && json['priceUsdCents'] is num) {
        return (json['priceUsdCents'] as num).toInt();
      }
      if (json['priceUSD'] != null && json['priceUSD'] is num) {
        return (json['priceUSD'] as num).toInt();
      }
      if (json['price'] != null) {
        // price might be a float in dollars -> convert to cents
        final p = double.tryParse(json['price'].toString()) ?? 0.0;
        return (p * 100).round();
      }
      // fallback: try to parse any string numeric
      final fallback = json['amount'] ?? json['amount_cents'];
      if (fallback is num) return fallback.toInt();
      return int.tryParse('${fallback ?? 0}') ?? 0;
    }();

    return CoinPackage(
      id: id,
      productId: productId,
      coins: coins,
      priceUsdCents: priceUsdCents,
    );
  }

  /// Parse transaction JSON returned by the API into TransactionModel.
  /// Tolerates multiple key variants and date formats (ISO string or epoch).
  static TransactionModel transactionFromJson(Map<String, dynamic> json) {
    final id = (json['uuid'] ?? json['id'] ?? '').toString();

    final amountPaid = () {
      final v =
          json['amount_paid'] ?? json['amountPaid'] ?? json['amount'] ?? 0;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }();

    final coinsChange = () {
      final v =
          json['coins_change'] ?? json['coinsChange'] ?? json['coins'] ?? 0;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }();

    DateTime parseDate() {
      final raw =
          json['created_at'] ??
          json['createdAt'] ??
          json['date'] ??
          json['timestamp'] ??
          json['time'];

      if (raw == null) return DateTime.now();

      if (raw is String) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) return parsed;
        // try parse as integer string
        final asInt = int.tryParse(raw);
        if (asInt != null) {
          // try ms then seconds
          if (asInt > 1000000000000) {
            return DateTime.fromMillisecondsSinceEpoch(asInt);
          } else {
            return DateTime.fromMillisecondsSinceEpoch(asInt * 1000);
          }
        }
        return DateTime.now();
      }

      if (raw is int) {
        // Heuristic: > 1e12 -> milliseconds, else seconds
        if (raw > 1000000000000) {
          return DateTime.fromMillisecondsSinceEpoch(raw);
        } else {
          return DateTime.fromMillisecondsSinceEpoch(raw * 1000);
        }
      }

      if (raw is double) {
        final asInt = raw.toInt();
        if (asInt > 1000000000000) {
          return DateTime.fromMillisecondsSinceEpoch(asInt);
        } else {
          return DateTime.fromMillisecondsSinceEpoch(asInt * 1000);
        }
      }

      return DateTime.now();
    }

    final date = parseDate();

    final method =
        (json['method'] ??
                json['payment_provider'] ??
                json['provider'] ??
                json['gateway'] ??
                '')
            .toString();

    return TransactionModel(
      id: id,
      date: date,
      method: json['method'] as String? ?? 'unknown',
      type: json['type'] as String? ?? 'transaction',
      amountPaid: (amountPaid).toInt(),
      coinsChange: (coinsChange).toInt(),
    );
  }
}
