class LiveStartPayload {
  final int livestreamId; // numeric id for sockets (live.{id})
  final String channel;
  final String uidType; // usually "userAccount" or "uid"
  final String uid; // keep as string; Agora svc decides how to use it
  final String rtcRole; // "publisher"
  final String startedAt; // ISO string
  final bool bonusAwarded;
  final String appId; // Agora App ID
  final String rtcToken;
  final String? expiresAt;

  // NEW: UI/host/stream fields
  final String? hostDisplayName;
  final String? hostBadge;
  final String? hostAvatarUrl;
  final String? hostUuid;
  final String? streamTitle;
  final int? initialViewers;

  const LiveStartPayload({
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
    this.hostDisplayName,
    this.hostBadge,
    this.hostAvatarUrl,
    this.hostUuid,
    this.streamTitle,
    this.initialViewers,
  });
}
