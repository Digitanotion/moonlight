// Update ClubMember entity constructor to handle nulls
import 'package:equatable/equatable.dart';

class ClubMember extends Equatable {
  final String uuid;
  final String userSlug;
  final String? username;
  final String fullname;
  final String? avatarUrl;
  final String role; // owner | admin | member
  final bool isOwner;
  final bool isAdmin;
  final bool isSelf;
  final bool canRemove;
  final bool canPromote;
  final bool canDemote;
  final DateTime? joinedAt;
  final int joinedDaysAgo;
  final bool isFollowing;

  ClubMember({
    required this.uuid,
    required this.userSlug,
    this.username,
    required this.fullname,
    this.avatarUrl,
    required this.role,
    required this.isOwner,
    required this.isAdmin,
    required this.isSelf,
    required this.canRemove,
    required this.canPromote,
    required this.canDemote,
    this.joinedAt,
    required this.joinedDaysAgo,
    this.isFollowing = false,
  });

  // Add factory method for parsing JSON
  factory ClubMember.fromJson(Map<String, dynamic> json) {
    return ClubMember(
      uuid: json['uuid']?.toString() ?? '',
      userSlug: json['user_slug']?.toString() ?? '',
      username: json['username']?.toString(),
      fullname: json['fullname']?.toString() ?? '',
      avatarUrl: json['avatar_url']?.toString(),
      role: json['role']?.toString() ?? 'member',
      isOwner: json['is_owner'] == true,
      isAdmin: json['is_admin'] == true,
      isSelf: json['is_self'] == true,
      canRemove: json['can_remove'] == true,
      canPromote: json['can_promote'] == true,
      canDemote: json['can_demote'] == true,
      joinedAt: json['joined_at'] != null
          ? DateTime.tryParse(json['joined_at'].toString())
          : null,
      joinedDaysAgo: (json['joined_days_ago'] as num?)?.toInt() ?? 0,
      isFollowing: json['is_following'] == true,
    );
  }

  // CORRECTED: copyWith should be in ClubMember class
  ClubMember copyWith({
    String? uuid,
    String? userSlug,
    String? username,
    String? fullname,
    String? avatarUrl,
    String? role,
    bool? isOwner,
    bool? isAdmin,
    bool? isSelf,
    bool? canRemove,
    bool? canPromote,
    bool? canDemote,
    DateTime? joinedAt,
    int? joinedDaysAgo,
  }) {
    return ClubMember(
      uuid: uuid ?? this.uuid,
      userSlug: userSlug ?? this.userSlug,
      username: username ?? this.username,
      fullname: fullname ?? this.fullname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      isOwner: isOwner ?? this.isOwner,
      isAdmin: isAdmin ?? this.isAdmin,
      isSelf: isSelf ?? this.isSelf,
      canRemove: canRemove ?? this.canRemove,
      canPromote: canPromote ?? this.canPromote,
      canDemote: canDemote ?? this.canDemote,
      joinedAt: joinedAt ?? this.joinedAt,
      joinedDaysAgo: joinedDaysAgo ?? this.joinedDaysAgo,
    );
  }

  @override
  List<Object?> get props => [
    uuid,
    userSlug,
    username,
    fullname,
    avatarUrl,
    role,
    isOwner,
    isAdmin,
    isSelf,
    canRemove,
    canPromote,
    canDemote,
    joinedAt,
    joinedDaysAgo,
  ];
}

// In a new file or add to existing domain/entities
class ClubMembersResult {
  final ClubMembersMeta club;
  final List<ClubMember> members;
  final Pagination pagination;

  ClubMembersResult({
    required this.club,
    required this.members,
    required this.pagination,
  });

  // Add copyWith for ClubMembersResult too
  ClubMembersResult copyWith({
    ClubMembersMeta? club,
    List<ClubMember>? members,
    Pagination? pagination,
  }) {
    return ClubMembersResult(
      club: club ?? this.club,
      members: members ?? this.members,
      pagination: pagination ?? this.pagination,
    );
  }
}

class Pagination {
  final int currentPage;
  final int perPage;
  final int total;
  final int totalPages;
  final bool hasMore;

  Pagination({
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.totalPages,
    required this.hasMore,
  });

  // Add copyWith for Pagination
  Pagination copyWith({
    int? currentPage,
    int? perPage,
    int? total,
    int? totalPages,
    bool? hasMore,
  }) {
    return Pagination(
      currentPage: currentPage ?? this.currentPage,
      perPage: perPage ?? this.perPage,
      total: total ?? this.total,
      totalPages: totalPages ?? this.totalPages,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class ClubMembersMeta extends Equatable {
  final String uuid;
  final String name;
  final String slug;
  final bool isPrivate;
  final int totalMembers;
  final int adminsCount;
  final int membersCount;
  final bool canManage;
  final bool canInvite;
  final bool canRemove;

  ClubMembersMeta({
    required this.uuid,
    required this.name,
    required this.slug,
    required this.isPrivate,
    required this.totalMembers,
    required this.adminsCount,
    required this.membersCount,
    required this.canManage,
    required this.canInvite,
    required this.canRemove,
  });

  // CORRECTED: copyWith for ClubMembersMeta should return ClubMembersMeta
  ClubMembersMeta copyWith({
    String? uuid,
    String? name,
    String? slug,
    bool? isPrivate,
    int? totalMembers,
    int? adminsCount,
    int? membersCount,
    bool? canManage,
    bool? canInvite,
    bool? canRemove,
  }) {
    return ClubMembersMeta(
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      isPrivate: isPrivate ?? this.isPrivate,
      totalMembers: totalMembers ?? this.totalMembers,
      adminsCount: adminsCount ?? this.adminsCount,
      membersCount: membersCount ?? this.membersCount,
      canManage: canManage ?? this.canManage,
      canInvite: canInvite ?? this.canInvite,
      canRemove: canRemove ?? this.canRemove,
    );
  }

  @override
  List<Object?> get props => [
    uuid,
    name,
    slug,
    isPrivate,
    totalMembers,
    adminsCount,
    membersCount,
    canManage,
    canInvite,
    canRemove,
  ];
}
