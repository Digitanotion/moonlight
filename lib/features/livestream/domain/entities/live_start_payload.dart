class LiveStartPayload {
  final int livestreamId;
  final String channel;
  final String uidType;
  final String uid;
  final String rtcRole;
  final String startedAt;
  final bool bonusAwarded;
  final String appId;
  final String rtcToken;
  final String? expiresAt;

  // UI/host/stream fields
  final String? hostDisplayName;
  final String? hostBadge;
  final String? hostAvatarUrl;
  final String? hostUuid;
  final String? streamTitle;
  final int? initialViewers;

  // ← ADD THESE TWO
  final bool micOn;
  final bool camOn;

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
    this.micOn = true, // ← ADD (defaults to true = on, safe fallback)
    this.camOn = true, // ← ADD
  });
}
