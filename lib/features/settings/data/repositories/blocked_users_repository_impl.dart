import 'package:moonlight/features/settings/data/datasources/blocked_users_remote_datasource.dart';
import 'package:moonlight/features/settings/domain/entities/blocked_user.dart';
import 'package:moonlight/features/settings/domain/repositories/blocked_users_repository.dart';

class BlockedUsersRepositoryImpl implements BlockedUsersRepository {
  final BlockedUsersRemoteDataSource _remoteDataSource;

  BlockedUsersRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<BlockedUser>> getBlockedUsers({
    int page = 1,
    int perPage = 20,
    String? search,
  }) async {
    try {
      final response = await _remoteDataSource.getBlockedUsers(
        page: page,
        perPage: perPage,
        search: search,
      );

      final data = List<Map<String, dynamic>>.from(response['data'] ?? []);
      final meta = Map<String, dynamic>.from(response['meta'] ?? {});

      return data.map((userData) => _parseBlockedUser(userData)).toList();
    } catch (e) {
      throw Exception('Failed to load blocked users: $e');
    }
  }

  @override
  Future<List<BlockedUser>> searchUsers(String query) async {
    try {
      final response = await _remoteDataSource.searchUsers(query);
      final data = List<Map<String, dynamic>>.from(response['data'] ?? []);

      return data.map((userData) => _parseBlockedUser(userData)).toList();
    } catch (e) {
      throw Exception('Failed to search users: $e');
    }
  }

  @override
  Future<BlockedUser> blockUser({
    required String userUuid,
    String? reason,
  }) async {
    try {
      final response = await _remoteDataSource.blockUser(
        userUuid: userUuid,
        reason: reason,
      );

      final data = Map<String, dynamic>.from(response['data'] ?? {});
      return _parseBlockedUser(data);
    } catch (e) {
      throw Exception('Failed to block user: $e');
    }
  }

  @override
  Future<BlockedUser> unblockUser(String userUuid) async {
    try {
      final response = await _remoteDataSource.unblockUser(userUuid);
      final data = Map<String, dynamic>.from(response['data'] ?? {});
      return _parseBlockedUser(data);
    } catch (e) {
      throw Exception('Failed to unblock user: $e');
    }
  }

  @override
  Future<BlockedUser> toggleBlockUser({
    required String userUuid,
    String? reason,
  }) async {
    try {
      final response = await _remoteDataSource.toggleBlockUser(
        userUuid: userUuid,
        reason: reason,
      );

      final data = Map<String, dynamic>.from(response['data'] ?? {});
      return _parseBlockedUser(data);
    } catch (e) {
      throw Exception('Failed to toggle block user: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> getBlockStats() async {
    try {
      final response = await _remoteDataSource.getBlockStats();
      return Map<String, dynamic>.from(response['data'] ?? {});
    } catch (e) {
      throw Exception('Failed to get block stats: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> checkBlockStatus(String userUuid) async {
    try {
      final response = await _remoteDataSource.checkBlockStatus(userUuid);
      return Map<String, dynamic>.from(response['data'] ?? {});
    } catch (e) {
      throw Exception('Failed to check block status: $e');
    }
  }

  @override
  Future<Map<String, dynamic>> bulkBlockUsers({
    required List<String> userUuids,
    String? reason,
  }) async {
    try {
      final response = await _remoteDataSource.bulkBlockUsers(
        userUuids: userUuids,
        reason: reason,
      );

      return Map<String, dynamic>.from(response['data'] ?? {});
    } catch (e) {
      throw Exception('Failed to bulk block users: $e');
    }
  }

  BlockedUser _parseBlockedUser(Map<String, dynamic> data) {
    return BlockedUser(
      id: data['id'] ?? '',
      displayName: data['display_name'] ?? 'Unknown User',
      username: data['username'],
      email: data['email'],
      avatarUrl: data['avatar_url'],
      isBlocked: data['is_blocked'] ?? false,
      blockedAt: data['blocked_at'] != null
          ? DateTime.tryParse(data['blocked_at'])
          : null,
      mutualConnections: data['mutual_connections'] ?? 0,
      canUnblock: data['can_unblock'] ?? true,
    );
  }
}
