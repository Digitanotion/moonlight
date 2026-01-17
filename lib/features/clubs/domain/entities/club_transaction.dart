class ClubTransaction {
  final String uuid;
  final String txRef;
  final int coins;
  final String reason;
  final String createdAt;
  final String fullname;
  final String? avatarUrl;

  ClubTransaction({
    required this.uuid,
    required this.txRef,
    required this.coins,
    required this.reason,
    required this.createdAt,
    required this.fullname,
    this.avatarUrl,
  });

  factory ClubTransaction.fromJson(Map<String, dynamic> json) {
    final by = json['performed_by'] ?? {};
    return ClubTransaction(
      uuid: json['uuid'],
      txRef: json['tx_ref'],
      coins: json['coins'],
      reason: json['reason'] ?? '',
      createdAt: json['created_at'],
      fullname: by['fullname'],
      avatarUrl: by['avatar_url'],
    );
  }
}
