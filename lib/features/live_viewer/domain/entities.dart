import 'package:equatable/equatable.dart';

class HostInfo extends Equatable {
  final String name;
  final String title; // "Talking about Mental Health"
  final String subtitle; // "Mental health Coach. 1.2M Fans"
  final String badge; // "Superstar"
  final String avatarUrl;
  final bool isFollowed;

  const HostInfo({
    required this.name,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.avatarUrl,
    this.isFollowed = false,
  });

  HostInfo copyWith({bool? isFollowed}) => HostInfo(
    name: name,
    title: title,
    subtitle: subtitle,
    badge: badge,
    avatarUrl: avatarUrl,
    isFollowed: isFollowed ?? this.isFollowed,
  );

  @override
  List<Object?> get props => [
    name,
    title,
    subtitle,
    badge,
    avatarUrl,
    isFollowed,
  ];
}

class ChatMessage extends Equatable {
  final String id;
  final String username;
  final String text;

  const ChatMessage({
    required this.id,
    required this.username,
    required this.text,
  });

  @override
  List<Object?> get props => [id, username, text];
}

class GuestJoinNotice extends Equatable {
  final String username; // "Jane_Star"
  final String message; // "has joined the stream as a guest!"
  const GuestJoinNotice({required this.username, required this.message});
  @override
  List<Object?> get props => [username, message];
}

class GiftNotice extends Equatable {
  final String from; // "Sarah"
  final String giftName; // "Golden Crown"
  final int coins; // 500
  const GiftNotice({
    required this.from,
    required this.giftName,
    required this.coins,
  });
  @override
  List<Object?> get props => [from, giftName, coins];
}

// === GIFTS: domain models (additive) ===

class GiftItem {
  final String id;
  final String code;
  final String title;
  final String imageUrl;
  final int coins;
  final bool active;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? updatedAt;

  const GiftItem({
    required this.id,
    required this.code,
    required this.title,
    required this.imageUrl,
    required this.coins,
    required this.active,
    this.startsAt,
    this.endsAt,
    this.updatedAt,
  });

  factory GiftItem.fromJson(Map<String, dynamic> m) {
    return GiftItem(
      id: '${m['id']}',
      code: '${m['code']}',
      title: '${m['title']}',
      imageUrl: '${m['image_url']}',
      coins: (m['coins'] as num).toInt(),
      active: m['active'] == true,
      startsAt: m['starts_at'] == null
          ? null
          : DateTime.tryParse('${m['starts_at']}'),
      endsAt: m['ends_at'] == null
          ? null
          : DateTime.tryParse('${m['ends_at']}'),
      updatedAt: m['updated_at'] == null
          ? null
          : DateTime.tryParse('${m['updated_at']}'),
    );
  }
}

class GiftBroadcast {
  final String type; // "gift.sent"
  final String livestreamId;
  final String serverTxnId;
  final int seqNo;
  final String giftCode;
  final String? giftId;
  final int quantity;
  final int coinsSpent;
  final String senderUuid;
  final String senderDisplayName;
  final DateTime timestamp;
  final int? comboIndex;
  final int? comboWindowMs;

  GiftBroadcast({
    required this.type,
    required this.livestreamId,
    required this.serverTxnId,
    required this.seqNo,
    required this.giftCode,
    required this.giftId,
    required this.quantity,
    required this.coinsSpent,
    required this.senderUuid,
    required this.senderDisplayName,
    required this.timestamp,
    this.comboIndex,
    this.comboWindowMs,
  });

  factory GiftBroadcast.fromJson(Map<String, dynamic> m) {
    int _intFrom(dynamic v, {int fallback = 0}) {
      if (v == null) return fallback;
      if (v is num) return v.toInt();
      if (v is String) {
        final parsed = int.tryParse(v);
        if (parsed != null) return parsed;
        // try parse double then toInt
        final dbl = double.tryParse(v.replaceAll('%', ''));
        if (dbl != null) return dbl.toInt();
      }
      return fallback;
    }

    final sender = (m['sender'] is Map)
        ? (m['sender'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};

    final comboMap = (m['combo'] is Map)
        ? (m['combo'] as Map).cast<String, dynamic>()
        : null;

    return GiftBroadcast(
      type: '${m['type'] ?? ''}',
      livestreamId: '${m['livestream_id'] ?? ''}',
      serverTxnId: '${m['server_txn_id'] ?? ''}',
      seqNo: _intFrom(m['seq_no'], fallback: 0),
      giftCode: '${m['gift_code'] ?? ''}',
      // gift_id can be uuid string in your catalog; keep as nullable String? But your model expects int.
      // If backend uses uuid string for gift_id, you'll want String? type. For now parse numeric if possible.
      giftId: '${m['gift_id'] ?? ''}',
      quantity: _intFrom(m['quantity'], fallback: 1),
      coinsSpent: _intFrom(m['coins_spent'], fallback: 0),
      senderUuid: '${sender['user_uuid'] ?? ''}',
      senderDisplayName:
          '${sender['display_name'] ?? sender['displayName'] ?? ''}',
      timestamp: DateTime.tryParse('${m['timestamp'] ?? ''}') ?? DateTime.now(),
      comboIndex: comboMap == null
          ? null
          : _intFrom(comboMap['index'], fallback: 1),
      comboWindowMs: comboMap == null
          ? null
          : _intFrom(comboMap['window_ms'], fallback: 0),
    );
  }
}

class GiftSendResult {
  final String serverTxnId;
  final int newBalanceCoins;
  final GiftBroadcast broadcast;

  GiftSendResult({
    required this.serverTxnId,
    required this.newBalanceCoins,
    required this.broadcast,
  });
}
