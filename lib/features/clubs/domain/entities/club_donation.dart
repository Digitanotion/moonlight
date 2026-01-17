class ClubDonation {
  final String userUuid;
  final String fullname;
  final String? avatarUrl;
  final int totalCoins;
  final int donationsCount;

  ClubDonation({
    required this.userUuid,
    required this.fullname,
    this.avatarUrl,
    required this.totalCoins,
    required this.donationsCount,
  });

  factory ClubDonation.fromJson(Map<String, dynamic> json) {
    final user = json['user'] ?? {};
    return ClubDonation(
      userUuid: user['uuid'],
      fullname: user['fullname'],
      avatarUrl: user['avatar_url'],
      totalCoins: json['total_coins'] ?? 0,
      donationsCount: json['donations_count'] ?? 0,
    );
  }
}
