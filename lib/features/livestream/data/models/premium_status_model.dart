class PremiumStatusModel {
  final String type;
  final int livestreamId;
  final bool isPremium;
  final PremiumPackageSummary? package;
  final String? activatedBy;
  final DateTime? activatedAt;
  final DateTime? expiresAt;

  PremiumStatusModel({
    required this.type,
    required this.livestreamId,
    required this.isPremium,
    this.package,
    this.activatedBy,
    this.activatedAt,
    this.expiresAt,
  });

  factory PremiumStatusModel.fromMap(Map<String, dynamic> m) {
    final pkg = m['package'];
    DateTime? parseDt(dynamic s) {
      if (s == null) return null;
      try {
        return DateTime.parse(s.toString()).toUtc();
      } catch (_) {
        return null;
      }
    }

    return PremiumStatusModel(
      type: (m['type'] ?? '').toString(),
      livestreamId: (m['livestream_id'] is int)
          ? m['livestream_id'] as int
          : int.tryParse('${m['livestream_id'] ?? 0}') ?? 0,
      isPremium: (m['is_premium'] == true || m['is_premium'] == 'true'),
      package: pkg == null
          ? null
          : PremiumPackageSummary.fromMap((pkg as Map).cast<String, dynamic>()),
      activatedBy: m['activated_by']?.toString(),
      activatedAt: parseDt(m['activated_at']),
      expiresAt: parseDt(m['expires_at']),
    );
  }
}

class PremiumPackageSummary {
  final String id;
  final String name;
  final int coins;

  PremiumPackageSummary({
    required this.id,
    required this.name,
    required this.coins,
  });

  factory PremiumPackageSummary.fromMap(Map<String, dynamic> m) =>
      PremiumPackageSummary(
        id: (m['id'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        coins: (m['coins'] is int)
            ? m['coins'] as int
            : int.tryParse('${m['coins'] ?? 0}') ?? 0,
      );
}
