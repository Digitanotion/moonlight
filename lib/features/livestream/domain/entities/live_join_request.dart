class LiveJoinRequest {
  final String id; // unique id per request
  final String displayName; // e.g., GamerPro_2024
  final String role; // e.g., Ambassador
  final String avatarUrl; // for now you can use a placeholder asset
  final bool online;

  LiveJoinRequest({
    required this.id,
    required this.displayName,
    required this.role,
    required this.avatarUrl,
    this.online = true,
  });
}
