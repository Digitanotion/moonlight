// lib/features/video_call/data/models/video_call_session_model.dart

class VideoCallUserSummary {
  final String userSlug;
  final String displayName;
  final String? avatarUrl;

  VideoCallUserSummary({
    required this.userSlug,
    required this.displayName,
    this.avatarUrl,
  });

  factory VideoCallUserSummary.fromMap(Map<String, dynamic> map) {
    return VideoCallUserSummary(
      userSlug: (map['user_slug'] ?? '').toString(),
      displayName: (map['display_name'] ?? '').toString(),
      avatarUrl: map['avatar_url']?.toString(),
    );
  }
}

class VideoCallAgoraCredentials {
  final String channelName;
  final int uid;
  final String token;

  VideoCallAgoraCredentials({
    required this.channelName,
    required this.uid,
    required this.token,
  });

  factory VideoCallAgoraCredentials.fromMap(Map<String, dynamic> map) {
    return VideoCallAgoraCredentials(
      channelName: (map['channel_name'] ?? '').toString(),
      uid: int.tryParse('${map['uid'] ?? 0}') ?? 0,
      token: (map['token'] ?? '').toString(),
    );
  }
}

class VideoCallSessionModel {
  final String uuid;
  final String status; // pending|ringing|active|completed|rejected|no_answer|cancelled
  final String channelName;
  final String initiatedFrom;
  final int? livestreamId;
  final int rateCoinsPerMinute;
  final int totalMinutesRequested;
  final int totalCoinsHeld;
  final int totalCoinsSettled;
  final int totalCoinsRefunded;
  final DateTime? connectedAt;
  final DateTime? endsAt;
  final DateTime? endedAt;
  final String? endedReason;
  final int? remainingSeconds;
  final VideoCallUserSummary? caller;
  final VideoCallUserSummary? callee;
  final VideoCallAgoraCredentials? agora;

  VideoCallSessionModel({
    required this.uuid,
    required this.status,
    required this.channelName,
    required this.initiatedFrom,
    this.livestreamId,
    required this.rateCoinsPerMinute,
    required this.totalMinutesRequested,
    required this.totalCoinsHeld,
    required this.totalCoinsSettled,
    required this.totalCoinsRefunded,
    this.connectedAt,
    this.endsAt,
    this.endedAt,
    this.endedReason,
    this.remainingSeconds,
    this.caller,
    this.callee,
    this.agora,
  });

  factory VideoCallSessionModel.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    return VideoCallSessionModel(
      uuid: (map['uuid'] ?? '').toString(),
      status: (map['status'] ?? '').toString(),
      channelName: (map['channel_name'] ?? '').toString(),
      initiatedFrom: (map['initiated_from'] ?? '').toString(),
      livestreamId: map['livestream_id'] == null ? null : int.tryParse('${map['livestream_id']}'),
      rateCoinsPerMinute:
          int.tryParse('${map['rate_coins_per_minute'] ?? 0}') ?? 0,
      totalMinutesRequested:
          int.tryParse('${map['total_minutes_requested'] ?? 0}') ?? 0,
      totalCoinsHeld: int.tryParse('${map['total_coins_held'] ?? 0}') ?? 0,
      totalCoinsSettled:
          int.tryParse('${map['total_coins_settled'] ?? 0}') ?? 0,
      totalCoinsRefunded:
          int.tryParse('${map['total_coins_refunded'] ?? 0}') ?? 0,
      connectedAt: parseDate(map['connected_at']),
      endsAt: parseDate(map['ends_at']),
      endedAt: parseDate(map['ended_at']),
      endedReason: map['ended_reason']?.toString(),
      remainingSeconds: map['remaining_seconds'] == null
          ? null
          : int.tryParse('${map['remaining_seconds']}'),
      caller: map['caller'] is Map
          ? VideoCallUserSummary.fromMap(
              (map['caller'] as Map).cast<String, dynamic>(),
            )
          : null,
      callee: map['callee'] is Map
          ? VideoCallUserSummary.fromMap(
              (map['callee'] as Map).cast<String, dynamic>(),
            )
          : null,
      agora: map['agora'] is Map
          ? VideoCallAgoraCredentials.fromMap(
              (map['agora'] as Map).cast<String, dynamic>(),
            )
          : null,
    );
  }
}

class VideoCallDirectoryUserModel {
  final String userSlug;
  final String displayName;
  final String? avatarUrl;
  final int? age;
  final String? country;
  final bool isOnline;
  final bool videoCallEnabled;
  final bool isBoosted;

  VideoCallDirectoryUserModel({
    required this.userSlug,
    required this.displayName,
    this.avatarUrl,
    this.age,
    this.country,
    required this.isOnline,
    required this.videoCallEnabled,
    required this.isBoosted,
  });

  factory VideoCallDirectoryUserModel.fromMap(Map<String, dynamic> map) {
    return VideoCallDirectoryUserModel(
      userSlug: (map['user_slug'] ?? '').toString(),
      displayName: (map['display_name'] ?? '').toString(),
      avatarUrl: map['avatar_url']?.toString(),
      age: map['age'] == null ? null : int.tryParse('${map['age']}'),
      country: map['country']?.toString(),
      isOnline: map['is_video_call_online'] == true,
      videoCallEnabled: map['video_call_enabled'] == true,
      isBoosted: map['is_boosted'] == true,
    );
  }
}