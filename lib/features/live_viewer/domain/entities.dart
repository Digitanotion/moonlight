// lib/features/live_viewer/domain/entities.dart - ENHANCED VERSION
import 'package:equatable/equatable.dart';

// ============ NETWORK & CONNECTION ENTITIES ============
enum NetworkQuality { unknown, excellent, good, poor, disconnected }

class NetworkStatus extends Equatable {
  final NetworkQuality selfQuality;
  final NetworkQuality hostQuality;
  final NetworkQuality? guestQuality;
  final bool isReconnecting;
  final int reconnectAttempts;
  final DateTime? lastDisconnection;

  const NetworkStatus({
    required this.selfQuality,
    required this.hostQuality,
    this.guestQuality,
    this.isReconnecting = false,
    this.reconnectAttempts = 0,
    this.lastDisconnection,
  });

  NetworkStatus copyWith({
    NetworkQuality? selfQuality,
    NetworkQuality? hostQuality,
    NetworkQuality? guestQuality,
    bool? isReconnecting,
    int? reconnectAttempts,
    DateTime? lastDisconnection,
  }) {
    return NetworkStatus(
      selfQuality: selfQuality ?? this.selfQuality,
      hostQuality: hostQuality ?? this.hostQuality,
      guestQuality: guestQuality ?? this.guestQuality,
      isReconnecting: isReconnecting ?? this.isReconnecting,
      reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
      lastDisconnection: lastDisconnection ?? this.lastDisconnection,
    );
  }

  @override
  List<Object?> get props => [
    selfQuality,
    hostQuality,
    guestQuality,
    isReconnecting,
    reconnectAttempts,
    lastDisconnection,
  ];
}

// ============ CONNECTION ENTITIES ============

enum ConnectionState {
  connecting,
  connected,
  reconnecting,
  disconnected,
  failed,
}

class ConnectionStats extends Equatable {
  final double bitrate; // kbps
  final double packetLoss; // percentage
  final double latency; // ms
  final double jitter; // ms
  final DateTime timestamp;

  const ConnectionStats({
    required this.bitrate,
    required this.packetLoss,
    required this.latency,
    required this.jitter,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [bitrate, packetLoss, latency, jitter, timestamp];
}

// ============ GUEST CONTROLS ============

class GuestControlsState extends Equatable {
  final bool isMicEnabled;
  final bool isCamEnabled;
  final bool isAudioMuted;
  final bool isVideoMuted;

  const GuestControlsState({
    this.isMicEnabled = false,
    this.isCamEnabled = false,
    this.isAudioMuted = true,
    this.isVideoMuted = true,
  });

  GuestControlsState copyWith({
    bool? isMicEnabled,
    bool? isCamEnabled,
    bool? isAudioMuted,
    bool? isVideoMuted,
  }) {
    return GuestControlsState(
      isMicEnabled: isMicEnabled ?? this.isMicEnabled,
      isCamEnabled: isCamEnabled ?? this.isCamEnabled,
      isAudioMuted: isAudioMuted ?? this.isAudioMuted,
      isVideoMuted: isVideoMuted ?? this.isVideoMuted,
    );
  }

  @override
  List<Object?> get props => [
    isMicEnabled,
    isCamEnabled,
    isAudioMuted,
    isVideoMuted,
  ];
}

// ============ VIEW MODES ============

enum ViewMode { viewer, guest, cohost }

// ============ EXISTING ENTITIES (PRESERVED) ============
class HostInfo extends Equatable {
  final String name;
  final String title;
  final String subtitle;
  final String badge;
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
  final bool isHost;

  const ChatMessage({
    required this.id,
    required this.username,
    required this.text,
    this.isHost = false,
  });

  @override
  List<Object?> get props => [id, username, text, isHost];
}

class GuestJoinNotice extends Equatable {
  final String username;
  final String message;
  const GuestJoinNotice({required this.username, required this.message});
  @override
  List<Object?> get props => [username, message];
}

class GiftNotice extends Equatable {
  final String from;
  final String giftName;
  final int coins;
  const GiftNotice({
    required this.from,
    required this.giftName,
    required this.coins,
  });
  @override
  List<Object?> get props => [from, giftName, coins];
}

// ============ GIFTS DOMAIN MODELS ============
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
  final String type;
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
