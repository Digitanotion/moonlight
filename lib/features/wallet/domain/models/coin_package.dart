class CoinPackage {
  final String id; // package UUID (frontend-facing)
  final String productId; // Google Play SKU: e.g. com.moonlight.coins.p1
  final int coins; // coins (integer)
  final int priceUsdCents; // canonical: USD cents (e.g. 500 => $5.00)

  CoinPackage({
    required this.id,
    required this.productId,
    required this.coins,
    required this.priceUsdCents,
  });

  /// Backwards-compatible alias used in some existing UI code.
  /// Returns cents (integer) to avoid floating rounding issues.
  int get priceUSD => priceUsdCents;

  /// Convenience: human-friendly dollar string (e.g. 5.00)
  String get priceUsdAsString {
    final dollars = priceUsdCents ~/ 100;
    final cents = (priceUsdCents % 100).toString().padLeft(2, '0');
    return '$dollars.$cents';
  }

  /// Factory from API JSON — handles both snake_case and camelCase,
  /// and accepts older fields if backend used slightly different keys.
  factory CoinPackage.fromJson(Map<String, dynamic> json) {
    // tolerate both price_usd_cents and priceUSD or price_usd
    int parsePriceCents() {
      if (json['price_usd_cents'] != null) {
        return (json['price_usd_cents'] as num).toInt();
      }
      if (json['priceUsdCents'] != null) {
        return (json['priceUsdCents'] as num).toInt();
      }
      if (json['priceUSD'] != null) {
        // if backend sent price as cents already in priceUSD field
        return (json['priceUSD'] as num).toInt();
      }
      // last resort: price in dollars as float -> convert to cents
      if (json['price'] != null) {
        final p = double.tryParse(json['price'].toString()) ?? 0.0;
        return (p * 100).round();
      }
      return 0;
    }

    return CoinPackage(
      id: (json['id'] ?? json['uuid'] ?? json['code'] ?? '').toString(),
      productId: (json['product_id'] ?? json['productId'] ?? '').toString(),
      coins: (json['coins'] is num)
          ? (json['coins'] as num).toInt()
          : int.tryParse('${json['coins']}') ?? 0,
      priceUsdCents: parsePriceCents(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'product_id': productId,
    'coins': coins,
    'price_usd_cents': priceUsdCents,
  };
}
