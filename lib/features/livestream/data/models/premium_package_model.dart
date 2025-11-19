class PremiumPackageModel {
  final String id;
  final String code;
  final String productId;
  final String title;
  final int coins;
  final int priceUsdCents;
  final bool active;
  final int sortOrder;
  final String? createdAt;
  final String? updatedAt;

  PremiumPackageModel({
    required this.id,
    required this.code,
    required this.productId,
    required this.title,
    required this.coins,
    required this.priceUsdCents,
    required this.active,
    required this.sortOrder,
    this.createdAt,
    this.updatedAt,
  });

  factory PremiumPackageModel.fromMap(Map<String, dynamic> m) =>
      PremiumPackageModel(
        id: (m['id'] ?? '').toString(),
        code: (m['code'] ?? '').toString(),
        productId: (m['product_id'] ?? '').toString(),
        title: (m['title'] ?? '').toString(),
        coins: (m['coins'] is int)
            ? m['coins'] as int
            : int.tryParse('${m['coins'] ?? 0}') ?? 0,
        priceUsdCents: (m['price_usd_cents'] is int)
            ? m['price_usd_cents'] as int
            : int.tryParse('${m['price_usd_cents'] ?? 0}') ?? 0,
        active: (m['active'] == true || m['active'] == 'true'),
        sortOrder: (m['sort_order'] is int)
            ? m['sort_order'] as int
            : int.tryParse('${m['sort_order'] ?? 0}') ?? 0,
        createdAt: m['created_at']?.toString(),
        updatedAt: m['updated_at']?.toString(),
      );
}
