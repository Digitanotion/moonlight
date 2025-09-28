class Participant {
  final String userUuid;
  final String userSlug;
  final String? avatar;
  final String role; // "audience" | "guest" | "publisher" | …
  final DateTime joinedAt;

  const Participant({
    required this.userUuid,
    required this.userSlug,
    required this.role,
    required this.joinedAt,
    this.avatar,
  });

  Participant copyWith({String? role}) => Participant(
    userUuid: userUuid,
    userSlug: userSlug,
    avatar: avatar,
    role: role ?? this.role,
    joinedAt: joinedAt,
  );
}
