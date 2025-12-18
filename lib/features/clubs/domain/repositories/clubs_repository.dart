// In clubs_repository.dart - update method signatures
import 'package:moonlight/features/clubs/domain/entities/club.dart';
import 'package:moonlight/features/clubs/domain/entities/club_member.dart';

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
  Future<void> leaveClub(String club);
}
