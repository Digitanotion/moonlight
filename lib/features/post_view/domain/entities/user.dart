class AppUser {
  final String id;
  final String name;
  final String avatarUrl;
  final String countryFlagEmoji; // using emoji for simplicity
  final String roleLabel; // Superstar / VIP / Active member / Nominal member
  final String roleColor; // hex

  const AppUser({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.countryFlagEmoji,
    required this.roleLabel,
    required this.roleColor,
  });
}
