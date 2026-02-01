class HostGiftBroadcast {
  final String serverTxnId;
  final String giftId;
  final String giftCode;
  final String? giftName;
  int quantity;
  int coinsSpent;
  final String senderUuid;
  final String senderDisplayName;
  final String? senderAvatar;
  final DateTime timestamp;
  final int? comboIndex;
  final int? comboWindowMs;

  HostGiftBroadcast({
    required this.serverTxnId,
    required this.giftId,
    required this.giftCode,
    this.giftName,
    required this.quantity,
    required this.coinsSpent,
    required this.senderUuid,
    required this.senderDisplayName,
    this.senderAvatar,
    required this.timestamp,
    this.comboIndex,
    this.comboWindowMs,
  });

  factory HostGiftBroadcast.fromJson(Map<String, dynamic> m) {
    final sender = (m['sender'] is Map)
        ? (m['sender'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    return HostGiftBroadcast(
      serverTxnId:
          (m['server_txn_id'] ??
                  DateTime.now().millisecondsSinceEpoch.toString())
              .toString(),
      giftId: (m['gift_id'] ?? '').toString(),
      giftCode: (m['gift_code'] ?? m['gift'] ?? '').toString(),
      giftName: (m['gift_code'] ?? m['gift'] ?? '').toString(),
      quantity: (m['quantity'] is int)
          ? m['quantity'] as int
          : int.tryParse('${m['quantity'] ?? 1}') ?? 1,
      coinsSpent: (m['coins_spent'] is int)
          ? m['coins_spent'] as int
          : int.tryParse('${m['coins_spent'] ?? m['coins'] ?? 0}') ?? 0,
      senderUuid: (sender['user_uuid'] ?? sender['uuid'] ?? '').toString(),
      senderDisplayName: (sender['display_name'] ?? sender['name'] ?? 'user')
          .toString(),
      senderAvatar:
          (sender['avatar'] ?? sender['avatar_url'] ?? '').toString().isEmpty
          ? null
          : (sender['avatar'] ?? sender['avatar_url']),
      timestamp:
          DateTime.tryParse(
            (m['timestamp'] ?? DateTime.now().toIso8601String()).toString(),
          ) ??
          DateTime.now(),
      comboIndex: (m['combo'] is Map) ? (m['combo']['index'] as int?) ?? 0 : 0,
      comboWindowMs: (m['combo'] is Map)
          ? (m['combo']['window_ms'] as int?) ?? 2000
          : 2000,
    );
  }
}
