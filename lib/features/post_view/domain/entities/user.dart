class AppUser {
  final String id;
  final String name;
  final String avatarUrl;
  final String countryFlagEmoji; // using emoji for simplicity
  final String roleLabel; // Superstar / VIP / Active member / Nominal member
  final String roleColor; // hex

  /// Whether the current viewer already follows this user. Only populated
  /// where the server has that context cheaply (e.g. the post feed); other
  /// call sites default this to false.
  final bool isFollowing;

  const AppUser({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.countryFlagEmoji,
    required this.roleLabel,
    required this.roleColor,
    this.isFollowing = false,
  });

  AppUser copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    String? countryFlagEmoji,
    String? roleLabel,
    String? roleColor,
    bool? isFollowing,
  }) => AppUser(
    id: id ?? this.id,
    name: name ?? this.name,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    countryFlagEmoji: countryFlagEmoji ?? this.countryFlagEmoji,
    roleLabel: roleLabel ?? this.roleLabel,
    roleColor: roleColor ?? this.roleColor,
    isFollowing: isFollowing ?? this.isFollowing,
  );
}
