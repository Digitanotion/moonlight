class LiveItem {
  final int id;
  final String uuid;
  final String channel;
  final String? coverUrl; // cover_url → card thumbnail
  final String handle; // MUST be "@user_slug"
  final String role; // rank_tag | "Host"
  final String? countryIso2; // normalized ISO2 (e.g., "KE")
  final String? countryName; // "Kenya"
  final int viewers;
  final String? title;
  final String? startedAt;
  final String? hostUuid;
  final int? isPremium;
  final int? premiumFee;
  final bool? isFollowed;

  /// The host's profile photo. Distinct from [coverUrl] (a custom stream
  /// thumbnail, when the host set one) — the live card falls back to this,
  /// then to initials, when there's no cover image.
  final String? hostAvatarUrl;

  const LiveItem({
    required this.id,
    required this.uuid,
    required this.channel,
    required this.coverUrl,
    required this.handle,
    required this.role,
    required this.countryIso2,
    required this.countryName,
    required this.viewers,
    required this.title,
    required this.startedAt,
    required this.hostUuid,
    required this.isPremium,
    required this.premiumFee,
    this.isFollowed,
    this.hostAvatarUrl,
  });
}
