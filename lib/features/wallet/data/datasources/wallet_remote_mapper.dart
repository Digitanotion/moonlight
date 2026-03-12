// lib/features/wallet/data/datasources/wallet_remote_mapper.dart
import '../../domain/models/coin_package.dart';
import '../../domain/models/transaction_model.dart';

/// ─── COIN RATES ──────────────────────────────────────────────────────────────
///
/// Purchase side:  1 coin = $0.01 USD
///   coins → USD:  coins * 0.01     (20 coins = $0.20)
///   USD → coins:  usd / 0.01       ($0.20 = 20 coins)
///
/// Withdrawal/earning side: 1 coin = $0.005 USD  →  200 coins = $1.00
///
/// ─── price_usd_cents COLUMN ──────────────────────────────────────────────────
///
/// Despite the name, price_usd_cents is a DOUBLE stored as DOLLARS:
///   e.g.  p1 = 0.20,  p4 = 0.50,  p6 = 1.39,  p8 = 10.50
/// Display directly as "$0.20" — NO division needed.
///
/// ─── amountPaid in WalletTransactionResource ─────────────────────────────────
///
/// WalletTransactionResource returns:
///   'amountPaid' => (int) $this->amount_paid
///
/// What is stored in amount_paid per type:
///   purchase   → double dollars (0.20 …) — int cast → 0 on server (server bug)
///   gift_out   → 0
///   earning    → cents (e.g. 50 = $0.50 streamer share)
///   withdrawal → cents (e.g. 10000 = $100.00)
///   transfer   → 0
///
/// Mapper heuristics:
///   • type == 'purchase', raw == 0  → recover from meta['price_display']
///   • type == 'purchase', raw > 10  → assume cents, divide by 100
///   • type == 'purchase', raw <= 10 → already dollars (e.g. server fixed)
///   • other types, raw > 0          → cents, divide by 100
///
class WalletRemoteMapper {
  // ── Package ──────────────────────────────────────────────────────────────────

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

    // price_usd_cents is DOUBLE dollars: 0.20, 1.39, 10.50
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
      priceUsdCents: priceUsdCents,
    );
  }

  // ── Transaction ───────────────────────────────────────────────────────────────

  /// Parse transaction JSON → TransactionModel.
  ///
  /// Call sites:
  ///   1. /purchase response  → caller passes data['data'];
  ///      transaction is nested under data['data']['transaction']
  ///   2. /transactions list  → each item is a flat transaction object
  static TransactionModel transactionFromJson(Map<String, dynamic> json) {
    // Unwrap nested transaction key if present (purchase response shape)
    final txnJson = (json['transaction'] is Map)
        ? Map<String, dynamic>.from(json['transaction'] as Map)
        : json;

    final id = (txnJson['uuid'] ?? txnJson['id'] ?? '').toString();
    final type = txnJson['type'] as String? ?? 'transaction';

    // meta map for extra context
    final meta = txnJson['meta'] is Map
        ? Map<String, dynamic>.from(txnJson['meta'] as Map)
        : <String, dynamic>{};

    // ── amountPaid → double dollars ─────────────────────────────────────────────
    final amountPaid = () {
      final raw =
          txnJson['amount_paid'] ??
          txnJson['amountPaid'] ??
          txnJson['amount'] ??
          0;
      double rawDouble;
      if (raw is num) {
        rawDouble = raw.toDouble();
      } else {
        rawDouble = double.tryParse(raw.toString()) ?? 0.0;
      }

      if (type == 'purchase') {
        if (rawDouble <= 0) {
          // Recover from meta.price_display e.g. "$0.20"
          final display = meta['price_display'] as String?;
          if (display != null) {
            final stripped = display.replaceAll(RegExp(r'[^\d.]'), '');
            return double.tryParse(stripped) ?? 0.0;
          }
          return 0.0;
        }
        // If server sent cents (> 10 is a reliable heuristic since max purchase is ~$10.50)
        // if (rawDouble > 10) return rawDouble / 100.0;
        return rawDouble; // already dollars
      }

      // Non-purchase types: stored as cents
      // if (rawDouble > 0) return rawDouble / 100.0;
      return 0.0;
    }();

    // ── coinsChange ─────────────────────────────────────────────────────────────
    final coinsChange = () {
      final v =
          txnJson['coins_change'] ??
          txnJson['coinsChange'] ??
          txnJson['coins_added'] ??
          txnJson['coins'] ??
          0;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }();

    // ── balanceAfter ────────────────────────────────────────────────────────────
    final balanceAfter = () {
      final v = txnJson['balance_after'] ?? txnJson['balanceAfter'];
      if (v == null) return null;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }();

    // ── date ─────────────────────────────────────────────────────────────────────
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
        if (asInt != null) {
          return asInt > 1000000000000
              ? DateTime.fromMillisecondsSinceEpoch(asInt)
              : DateTime.fromMillisecondsSinceEpoch(asInt * 1000);
        }
        return DateTime.now();
      }
      if (raw is int) {
        return raw > 1000000000000
            ? DateTime.fromMillisecondsSinceEpoch(raw)
            : DateTime.fromMillisecondsSinceEpoch(raw * 1000);
      }
      if (raw is double) {
        final i = raw.toInt();
        return i > 1000000000000
            ? DateTime.fromMillisecondsSinceEpoch(i)
            : DateTime.fromMillisecondsSinceEpoch(i * 1000);
      }
      return DateTime.now();
    }

    // ── relatedUserName ──────────────────────────────────────────────────────────
    // gift_out / transfer_out → to_user_name (recipient)
    // earning / transfer_in   → from_user_name (sender)
    final relatedUserName = () {
      final toName = (meta['to_user_name'] ?? meta['to_username']) as String?;
      final fromName =
          (meta['from_user_name'] ?? meta['from_username']) as String?;
      if (type == 'gift_out' || type == 'transfer_out') return toName;
      if (type == 'earning' || type == 'transfer_in') return fromName;
      return null;
    }();

    return TransactionModel(
      id: id,
      date: parseDate(),
      method: (txnJson['method'] ?? txnJson['type'] ?? 'unknown') as String,
      type: type,
      amountPaid: amountPaid,
      coinsChange: coinsChange,
      balanceAfter: balanceAfter,
      relatedUserName: relatedUserName,
      meta: meta,
    );
  }
}
