import 'dart:io';

import 'package:moonlight/features/clubs/domain/entities/suggested_club.dart';
import 'package:moonlight/features/clubs/domain/entities/club_profile.dart';
import 'package:moonlight/features/clubs/domain/entities/user_search_result.dart';

import '../../domain/entities/club.dart';
import '../../domain/entities/club_member.dart';
import '../../domain/repositories/clubs_repository.dart'
    hide ClubMembersResult, ClubMembersMeta, Pagination;
import '../datasources/clubs_remote_data_source.dart';

class ClubsRepositoryImpl implements ClubsRepository {
  final ClubsRemoteDataSource remote;

  ClubsRepositoryImpl(this.remote);

  @override
  Future<List<Club>> getMyClubs() async {
    final data = await remote.getMyClubs();
    return data.map((e) => Club.fromJson(e)).toList();
  }

  @override
  Future<ClubMembersResult> getClubMembersUI({
    required String club,
    int page = 1,
    int perPage = 20,
    String? role,
    String? search,
    String? sort,
    String? order,
  }) async {
    try {
      print('🔍 Repository: Fetching members for club: $club');

      final data = await remote.getMembersUI(
        club: club,
        query: {
          'page': page,
          'per_page': perPage,
          if (role != null) 'role': role,
          if (search != null) 'search': search,
          if (sort != null) 'sort': sort,
          if (order != null) 'order': order,
        },
      );

      print('📦 Repository: Raw API response: $data');

      // Check if the response has the expected structure
      final clubMeta = data['club'];
      final membersList = data['members'];
      final pagination = data['pagination'];

      if (clubMeta == null) {
        print('❌ Repository: clubMeta is null');
        throw Exception('Invalid API response: missing club data');
      }

      if (membersList == null) {
        print('❌ Repository: membersList is null');
        throw Exception('Invalid API response: missing members list');
      }

      print('👥 Repository: Parsing ${membersList.length} members');

      final members = (membersList as List).map((m) {
        print('👤 Repository: Parsing member: $m');
        return ClubMember.fromJson(m as Map<String, dynamic>);
      }).toList();

      print('✅ Repository: Successfully parsed ${members.length} members');

      return ClubMembersResult(
        club: ClubMembersMeta(
          uuid: clubMeta['uuid']?.toString() ?? '',
          name: clubMeta['name']?.toString() ?? '',
          slug: clubMeta['slug']?.toString() ?? '',
          isPrivate: clubMeta['is_private'] == true,
          totalMembers: (clubMeta['total_members'] as num?)?.toInt() ?? 0,
          adminsCount: (clubMeta['admins_count'] as num?)?.toInt() ?? 0,
          membersCount: (clubMeta['members_count'] as num?)?.toInt() ?? 0,
          canManage: clubMeta['can_manage'] == true,
          canInvite: clubMeta['can_invite'] == true,
          canRemove: clubMeta['can_remove'] == true,
        ),
        members: members,
        pagination: Pagination(
          currentPage: (pagination?['current_page'] as num?)?.toInt() ?? 1,
          perPage: (pagination?['per_page'] as num?)?.toInt() ?? 20,
          total: (pagination?['total'] as num?)?.toInt() ?? 0,
          totalPages: (pagination?['total_pages'] as num?)?.toInt() ?? 0,
          hasMore: pagination?['has_more'] == true,
        ),
      );
    } catch (e) {
      print('❌ Repository: Error in getClubMembersUI: $e');
      rethrow;
    }
  }

  @override
  Future<void> addMember({
    required String club,
    required String identifier,
    String role = 'member',
  }) {
    return remote.addMember(
      club: club,
      body: {
        if (identifier.contains('@')) 'email': identifier,
        if (!identifier.contains('@')) 'user_slug': identifier,
        'role': role,
      },
    );
  }

  @override
  Future<void> changeMemberRole({
    required String club,
    required String member,
    required String role,
  }) {
    return remote.changeMemberRole(club: club, member: member, role: role);
  }

  @override
  Future<void> removeMember({required String club, required String member}) {
    return remote.removeMember(club: club, member: member);
  }

  @override
  Future<void> transferOwnership({
    required String club,
    required String identifier,
  }) {
    return remote.transferOwnership(
      club: club,
      body: {
        if (identifier.contains('@')) 'email': identifier,
        if (!identifier.contains('@')) 'user_slug': identifier,
      },
    );
  }

  @override
  Future<void> createClub({
    required String name,
    String? description,
    bool isPrivate = false,
    String? coverImageUrl,
    String? motto,
    String? location,
  }) {
    return remote.createClub(
      body: {
        'name': name,
        if (description != null) 'description': description,
        if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
        if (motto != null) 'motto': motto,
        if (location != null) 'location': location,
        'is_private': isPrivate,
      },
    );
  }

  @override
  Future<ClubProfile> createClubMultipart({
    required String name,
    String? description,
    String? motto,
    String? location,
    bool isPrivate = false,
    File? coverImage,
  }) async {
    final data = await remote.createClubMultipart(
      name: name,
      description: description,
      motto: motto,
      location: location,
      isPrivate: isPrivate,
      coverImage: coverImage,
    );

    return ClubProfile.fromJson(data);
  }

  @override
  Future<ClubProfile> updateClubMultipart({
    required String club,
    required String name,
    String? description,
    String? motto,
    String? location,
    bool isPrivate = false,
    File? coverImage,
  }) async {
    final data = await remote.updateClubMultipart(
      club: club,
      name: name,
      description: description,
      motto: motto,
      location: location,
      isPrivate: isPrivate,
      coverImage: coverImage,
    );

    return ClubProfile.fromJson(data);
  }

  @override
  Future<void> updateClub({
    required String club,
    String? name,
    String? description,
    bool? isPrivate,
    String? coverImageUrl,
  }) {
    return remote.updateClub(
      club: club,
      body: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
        if (isPrivate != null) 'is_private': isPrivate,
      },
    );
  }

  @override
  Future<void> deleteClub({required String club}) {
    return remote.deleteClub(club: club);
  }

  @override
  Future<List<Club>> getPublicClubs() async {
    final data = await remote.getPublicClubs();
    return data.map((e) => Club.fromJson(e)).toList();
  }

  @override
  Future<void> joinClub(String club) {
    return remote.joinClub(club: club);
  }

  @override
  Future<void> leaveClub(String club) {
    return remote.leaveClub(club: club);
  }

  @override
  Future<List<SuggestedClub>> getSuggestedClubs() async {
    final data = await remote.getSuggestedClubs();
    return data.map((e) => SuggestedClub.fromJson(e)).toList();
  }

  @override
  Future<Club> getClub(String club) async {
    final data = await remote.getClub(club);
    return data;
  }

  @override
  Future<ClubProfile> getClubProfile(String club) async {
    final data = await remote.getClubProfile(club);
    return ClubProfile.fromJson(data);
  }

  @override
  Future<List<UserSearchResult>> searchUsers(String query) async {
    final data = await remote.searchUsers(query);
    return data.map(UserSearchResult.fromJson).toList();
  }

  @override
  Future<void> donateToClub({
    required String club,
    required int coins,
    String? reason,
    required String idempotencyKey,
  }) {
    return remote.donateToClub(
      club: club,
      coins: coins,
      reason: reason,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<int> getMyBalance() async {
    return remote.getMyBalance();
  }
}
