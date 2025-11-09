class CategoryDto {
  final String id;
  final String name;
  CategoryDto({required this.id, required this.name});

  factory CategoryDto.fromJson(Map<String, dynamic> j) =>
      CategoryDto(id: j['id'].toString(), name: j['name'] ?? '');
}

class PreviewDto {
  final bool ready;
  final String bestTime;
  final int low;
  final int high;

  PreviewDto({
    required this.ready,
    required this.bestTime,
    required this.low,
    required this.high,
  });

  factory PreviewDto.fromJson(Map<String, dynamic> j) {
    final ev = (j['estimated_viewers'] as List?) ?? [0, 0];
    return PreviewDto(
      ready: j['ready'] == true,
      bestTime: (j['best_time'] ?? 'Now').toString(),
      low: ev.isNotEmpty ? int.tryParse(ev[0].toString()) ?? 0 : 0,
      high: ev.length > 1 ? int.tryParse(ev[1].toString()) ?? 0 : 0,
    );
  }
}

class FirstBonusDto {
  final bool eligible;
  FirstBonusDto({required this.eligible});
  factory FirstBonusDto.fromJson(Map<String, dynamic> j) =>
      FirstBonusDto(eligible: j['eligible'] == true);
}

class StartLiveResponse {
  // existing transport fields
  final int livestreamId; // numeric (for sockets)
  final String channel;
  final String uidType;
  final String uid;
  final String rtcRole;
  final String startedAt; // ISO8601 string from API
  final bool bonusAwarded;
  final String appId;
  final String rtcToken;
  final String? expiresAt;

  // NEW: host + stream bits used by UI
  final String hostDisplayName;
  final String hostUuid;
  final String hostBadge;
  final String? hostAvatarUrl;

  final String streamTitle;
  final int streamViewers;

  StartLiveResponse({
    required this.livestreamId,
    required this.channel,
    required this.uidType,
    required this.uid,
    required this.rtcRole,
    required this.startedAt,
    required this.bonusAwarded,
    required this.appId,
    required this.rtcToken,
    this.expiresAt,
    required this.hostDisplayName,
    required this.hostUuid,
    required this.hostBadge,
    required this.hostAvatarUrl,
    required this.streamTitle,
    required this.streamViewers,
  });

  factory StartLiveResponse.fromJson(Map<String, dynamic> j) {
    final agora = (j['agora'] as Map?) ?? const {};
    final host = (j['host'] as Map?) ?? const {};
    final stream = (j['stream'] as Map?) ?? const {};

    return StartLiveResponse(
      livestreamId: int.tryParse(j['livestream_id'].toString()) ?? 0,
      channel: j['channel']?.toString() ?? '',
      uidType: j['uid_type']?.toString() ?? 'userAccount',
      uid: j['uid']?.toString() ?? '',
      rtcRole: j['rtc_role']?.toString() ?? 'publisher',
      startedAt: (j['started_at'] ?? stream['started_at'])?.toString() ?? '',
      bonusAwarded: j['bonus_awarded'] == true,
      appId: agora['app_id']?.toString() ?? '',
      rtcToken: agora['rtc_token']?.toString() ?? '',
      expiresAt: agora['expires_at']?.toString(),

      hostDisplayName: (host['display_name'] ?? 'Host').toString(),
      hostBadge: (host['badge'] ?? 'Host').toString(),
      hostUuid: (host['host_uuid'] ?? 'Host').toString(),
      hostAvatarUrl: host['avatar_url'] as String?,
      streamTitle: (stream['title'] ?? 'Live').toString(),
      streamViewers: int.tryParse('${stream['viewers'] ?? 0}') ?? 0,
    );
  }
}
