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
  final bool isAdmin;
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
    required this.isAdmin,
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
      isMember:
          json['isMember'] ?? false, // Changed from true to false (default)
      isCreator:
          json['isCreator'] ?? false, // Changed from true to false (default)
      isAdmin: json['isAdmin'] ?? false, // Changed from true to false (default)
      isPrivate:
          json['isPrivate'] ?? false, // Changed from true to false (default)
      location: json['location'],
      motto: json['motto'],
      totalIncomeCoins: json['totalIncomeCoins'] ?? 0,
      basicStats: json['basicStats'] ?? 0,
      membersYouKnow:
          (json['membersYouKnow'] as List? ??
                  []) // Fixed typo: membersYouKnows → membersYouKnow
              .map((e) => ClubProfileMember.fromJson(e))
              .toList(),
      admin: ClubProfileAdmin.fromJson(json['admin']),
    );
  }

  ClubProfile copyWith({
    String? uuid,
    String? slug,
    String? name,
    String? description,
    String? motto,
    String? location,
    int? membersCount,
    String? coverImageUrl,
    bool? isPrivate,
    bool? isMember,
    bool? isCreator,
    bool? isAdmin,
    int? totalIncomeCoins,
    int? basicStats,
    List<ClubProfileMember>? membersYouKnow,
    ClubProfileAdmin? admin, // Added missing admin parameter
  }) {
    return ClubProfile(
      uuid: uuid ?? this.uuid,
      slug: slug ?? this.slug,
      name: name ?? this.name,
      description: description ?? this.description,
      motto: motto ?? this.motto,
      location: location ?? this.location,
      membersCount: membersCount ?? this.membersCount,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      isPrivate: isPrivate ?? this.isPrivate,
      isMember: isMember ?? this.isMember,
      isCreator: isCreator ?? this.isCreator,
      isAdmin: isAdmin ?? this.isAdmin,
      totalIncomeCoins: totalIncomeCoins ?? this.totalIncomeCoins,
      basicStats: basicStats ?? this.basicStats,
      membersYouKnow: membersYouKnow ?? this.membersYouKnow,
      admin: admin ?? this.admin, // Added this line
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
    isAdmin,
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
