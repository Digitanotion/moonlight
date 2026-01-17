import 'package:moonlight/features/settings/domain/entities/blocked_user.dart';

abstract class BlockedUsersRepository {
  Future<List<BlockedUser>> getBlockedUsers({
    int page,
    int perPage,
    String? search,
  });

  Future<List<BlockedUser>> searchUsers(String query);

  Future<BlockedUser> blockUser({required String userUuid, String? reason});

  Future<BlockedUser> unblockUser(String userUuid);

  Future<BlockedUser> toggleBlockUser({
    required String userUuid,
    String? reason,
  });

  Future<Map<String, dynamic>> getBlockStats();

  Future<Map<String, dynamic>> checkBlockStatus(String userUuid);

  Future<Map<String, dynamic>> bulkBlockUsers({
    required List<String> userUuids,
    String? reason,
  });
}
