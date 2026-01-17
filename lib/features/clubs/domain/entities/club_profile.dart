import 'package:equatable/equatable.dart';

class ClubProfile extends Equatable {
  final String uuid;
  final String slug;
  final String name;
  final String? description;
  final String? motto;
  final String? location;
  final int membersCount;
  final String? coverImageUrl;
  final bool isMember;
  final bool isCreator;
  final bool isPrivate;

  // income / stats
  final int totalIncomeCoins;
  final int basicStats;

  // relations
  final List<ClubProfileMember> membersYouKnow;
  final ClubProfileAdmin admin;

  const ClubProfile({
    required this.uuid,
    required this.slug,
    required this.name,
    this.description,
    this.motto,
    this.location,
    required this.membersCount,
    this.coverImageUrl,
    required this.isMember,
    required this.isCreator,
    required this.isPrivate,
    required this.totalIncomeCoins,
    required this.basicStats,
    required this.membersYouKnow,
    required this.admin,
  });

  factory ClubProfile.fromJson(Map<String, dynamic> json) {
    return ClubProfile(
      uuid: json['uuid'],
      slug: json['slug'],
      name: json['name'],
      description: json['description'],
      membersCount: json['membersCount'] ?? 0,
      coverImageUrl: json['coverImageUrl'],
      isMember: json['isMember'] == true,
      isCreator: json['isCreator'] == true,
      isPrivate: json['isPrivate'] == true,
      location: json['location'],
      motto: json['motto'],
      totalIncomeCoins: json['totalIncomeCoins'] ?? 0,
      basicStats: json['basicStats'] ?? 0,
      membersYouKnow: (json['membersYouKnows'] as List? ?? [])
          .map((e) => ClubProfileMember.fromJson(e))
          .toList(),
      admin: ClubProfileAdmin.fromJson(json['admin']),
    );
  }

  @override
  List<Object?> get props => [
    uuid,
    slug,
    name,
    description,
    membersCount,
    coverImageUrl,
    isMember,
    isCreator,
    isPrivate,
    location,
    motto,
    totalIncomeCoins,
    basicStats,
    membersYouKnow,
    admin,
  ];
}

/* ───────── MEMBERS YOU KNOW ───────── */

class ClubProfileMember extends Equatable {
  final String uuid;
  final String fullname;
  final String? avatarUrl;

  const ClubProfileMember({
    required this.uuid,
    required this.fullname,
    this.avatarUrl,
  });

  factory ClubProfileMember.fromJson(Map<String, dynamic> json) {
    return ClubProfileMember(
      uuid: json['uuid'],
      fullname: json['fullname'],
      avatarUrl: json['avatar_url'],
    );
  }

  @override
  List<Object?> get props => [uuid, fullname, avatarUrl];
}

/* ───────── ADMIN ───────── */

class ClubProfileAdmin extends Equatable {
  final String uuid;
  final String fullname;
  final String? avatarUrl;

  const ClubProfileAdmin({
    required this.uuid,
    required this.fullname,
    this.avatarUrl,
  });

  factory ClubProfileAdmin.fromJson(Map<String, dynamic> json) {
    return ClubProfileAdmin(
      uuid: json['uuid'],
      fullname: json['fullname'],
      avatarUrl: json['avatar_url'],
    );
  }

  @override
  List<Object?> get props => [uuid, fullname, avatarUrl];
}
