// In clubs_repository.dart - update method signatures
import 'dart:io';

import 'package:moonlight/features/clubs/domain/entities/club.dart';
import 'package:moonlight/features/clubs/domain/entities/club_member.dart';
import 'package:moonlight/features/clubs/domain/entities/suggested_club.dart';
import 'package:moonlight/features/clubs/domain/entities/club_profile.dart';
import 'package:moonlight/features/clubs/domain/entities/user_search_result.dart';

abstract class ClubsRepository {
  /// Profile → My Clubs
  Future<List<Club>> getMyClubs();

  /// Members UI
  Future<ClubMembersResult> getClubMembersUI({
    required String club,
    int page = 1, // Add default value
    int perPage = 20, // Add default value
    String? role,
    String? search,
    String? sort,
    String? order,
  });

  /// Mutations
  Future<void> addMember({
    required String club,
    required String identifier,
    String role = 'member', // Add default value
  });

  Future<void> changeMemberRole({
    required String club,
    required String member,
    required String role,
  });

  Future<void> removeMember({required String club, required String member});

  Future<void> transferOwnership({
    required String club,
    required String identifier,
  });

  Future<void> createClub({
    required String name,
    String? description,
    bool isPrivate = false, // Add default value
    String? coverImageUrl,
    String? motto,
    String? location,
  });

  Future<ClubProfile> createClubMultipart({
    required String name,
    String? description,
    String? motto,
    String? location,
    bool isPrivate = false,
    File? coverImage,
  });

  Future<ClubProfile> updateClubMultipart({
    required String club,
    required String name,
    String? description,
    String? motto,
    String? location,
    bool isPrivate = false,
    File? coverImage,
  });

  Future<void> updateClub({
    required String club,
    String? name,
    String? description,
    bool? isPrivate,
    String? coverImageUrl,
  });

  Future<void> deleteClub({required String club});

  /// Discover / Public
  Future<List<Club>> getPublicClubs();

  /// Join / Leave
  Future<void> joinClub(String club);
  Future<Club> getClub(String club);
  Future<void> leaveClub(String club);

  /// Suggested
  Future<List<SuggestedClub>> getSuggestedClubs();
  Future<ClubProfile> getClubProfile(String club);
  Future<List<UserSearchResult>> searchUsers(String query);
  Future<void> donateToClub({
    required String club,
    required int coins,
    String? reason,
    required String idempotencyKey,
  });

  Future<int> getMyBalance();
  Future<List<Club>> searchClubs(String query);
  Future<BulkAddResult> bulkAddMembers({
    required String club,
    required List<BulkMember> members,
  });
}

class BulkAddResult {
  final List<BulkAddSuccess> success;
  final List<BulkAddFailure> failed;
  final BulkAddSummary summary;

  BulkAddResult({
    required this.success,
    required this.failed,
    required this.summary,
  });

  factory BulkAddResult.fromJson(Map<String, dynamic> json) {
    return BulkAddResult(
      success:
          (json['success'] as List?)
              ?.map((e) => BulkAddSuccess.fromJson(e))
              .toList() ??
          [],
      failed:
          (json['failed'] as List?)
              ?.map((e) => BulkAddFailure.fromJson(e))
              .toList() ??
          [],
      summary: BulkAddSummary.fromJson(json['summary']),
    );
  }
}

class BulkAddSuccess {
  final String identifier;
  final String uuid;
  final String userSlug;
  final String fullname;
  final String role;

  BulkAddSuccess({
    required this.identifier,
    required this.uuid,
    required this.userSlug,
    required this.fullname,
    required this.role,
  });

  factory BulkAddSuccess.fromJson(Map<String, dynamic> json) {
    return BulkAddSuccess(
      identifier: json['identifier'] as String,
      uuid: json['uuid'] as String,
      userSlug: json['user_slug'] as String,
      fullname: json['fullname'] as String,
      role: json['role'] as String? ?? 'member',
    );
  }
}

class BulkAddFailure {
  final String identifier;
  final String error;

  BulkAddFailure({required this.identifier, required this.error});

  factory BulkAddFailure.fromJson(Map<String, dynamic> json) {
    return BulkAddFailure(
      identifier: json['identifier'] as String,
      error: json['error'] as String,
    );
  }
}

class BulkAddSummary {
  final int total;
  final int successCount;
  final int failedCount;

  BulkAddSummary({
    required this.total,
    required this.successCount,
    required this.failedCount,
  });

  factory BulkAddSummary.fromJson(Map<String, dynamic> json) {
    return BulkAddSummary(
      total: json['total'] as int,
      successCount: json['success_count'] as int,
      failedCount: json['failed_count'] as int,
    );
  }
}

class BulkMember {
  final String identifier;
  final String? role;

  BulkMember({required this.identifier, this.role});

  Map<String, dynamic> toJson() => {
    'identifier': identifier,
    if (role != null) 'role': role,
  };
}
