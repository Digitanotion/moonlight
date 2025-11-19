class WalletModel {
  final String id;
  final String userIdInternal;
  final String userUuid;
  final int balance;
  final int usdEquivalentCents;
  final int earningsCents;
  final int withdrawableCents;
  final int bonusCents;
  final String? updatedAt;

  WalletModel({
    required this.id,
    required this.userIdInternal,
    required this.userUuid,
    required this.balance,
    required this.usdEquivalentCents,
    required this.earningsCents,
    required this.withdrawableCents,
    required this.bonusCents,
    this.updatedAt,
  });

  factory WalletModel.fromMap(Map<String, dynamic> m) => WalletModel(
    id: (m['id'] ?? '').toString(),
    userIdInternal: (m['user_id_internal'] ?? '').toString(),
    userUuid: (m['user_uuid'] ?? '').toString(),
    balance: (m['balance'] is int)
        ? m['balance'] as int
        : int.tryParse('${m['balance'] ?? 0}') ?? 0,
    usdEquivalentCents: (m['usd_equivalent_cents'] is int)
        ? m['usd_equivalent_cents'] as int
        : int.tryParse('${m['usd_equivalent_cents'] ?? 0}') ?? 0,
    earningsCents: (m['earnings_cents'] is int)
        ? m['earnings_cents'] as int
        : int.tryParse('${m['earnings_cents'] ?? 0}') ?? 0,
    withdrawableCents: (m['withdrawable_cents'] is int)
        ? m['withdrawable_cents'] as int
        : int.tryParse('${m['withdrawable_cents'] ?? 0}') ?? 0,
    bonusCents: (m['bonus_cents'] is int)
        ? m['bonus_cents'] as int
        : int.tryParse('${m['bonus_cents'] ?? 0}') ?? 0,
    updatedAt: m['updated_at']?.toString(),
  );
}
