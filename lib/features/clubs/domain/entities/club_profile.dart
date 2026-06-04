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
  final double basicStats; // ← double, API sends 42.86

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
      uuid: json['uuid'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      motto: json['motto'] as String?,
      location: json['location'] as String?,
      membersCount: (json['membersCount'] as num?)?.toInt() ?? 0,
      coverImageUrl: json['coverImageUrl'] as String?,
      isMember: json['isMember'] as bool? ?? false,
      isCreator: json['isCreator'] as bool? ?? false,
      isAdmin: json['isAdmin'] as bool? ?? false,
      isPrivate: json['isPrivate'] as bool? ?? false,
      totalIncomeCoins: (json['totalIncomeCoins'] as num?)?.toInt() ?? 0,
      // FIX: cast via num first — API sends this as a double (e.g. 42.86)
      basicStats: (json['basicStats'] as num?)?.toDouble() ?? 0.0,
      // API key is 'membersYouKnows' (with trailing s)
      membersYouKnow:
          ((json['membersYouKnows'] ?? json['membersYouKnow']) as List? ?? [])
              .map((e) => ClubProfileMember.fromJson(e as Map<String, dynamic>))
              .toList(),
      admin: ClubProfileAdmin.fromJson(json['admin'] as Map<String, dynamic>),
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
    double? basicStats, // FIX: was int?, must match field type double
    List<ClubProfileMember>? membersYouKnow,
    ClubProfileAdmin? admin,
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
      admin: admin ?? this.admin,
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
  final String? fullname;
  final String? avatarUrl;

  const ClubProfileMember({required this.uuid, this.fullname, this.avatarUrl});

  factory ClubProfileMember.fromJson(Map<String, dynamic> json) {
    return ClubProfileMember(
      uuid: json['uuid'] as String,
      fullname: json['fullname'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  @override
  List<Object?> get props => [uuid, fullname, avatarUrl];
}

/* ───────── ADMIN ───────── */

class ClubProfileAdmin extends Equatable {
  final String uuid;
  final String? fullname;
  final String? avatarUrl;

  const ClubProfileAdmin({required this.uuid, this.fullname, this.avatarUrl});

  factory ClubProfileAdmin.fromJson(Map<String, dynamic> json) {
    return ClubProfileAdmin(
      uuid: json['uuid'] as String,
      fullname: json['fullname'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  @override
  List<Object?> get props => [uuid, fullname, avatarUrl];
}
