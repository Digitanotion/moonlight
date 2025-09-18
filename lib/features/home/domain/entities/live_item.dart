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
  });
}
