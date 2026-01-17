import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:moonlight/features/settings/domain/entities/blocked_user.dart';
import 'package:moonlight/features/settings/domain/repositories/blocked_users_repository.dart';

part 'blocked_users_state.dart';

class BlockedUsersCubit extends Cubit<BlockedUsersState> {
  final BlockedUsersRepository _repository;

  BlockedUsersCubit(this._repository) : super(const BlockedUsersState());

  Future<void> loadBlockedUsers() async {
    try {
      emit(state.copyWith(status: BlockedUsersStatus.loading));

      final blockedUsers = await _repository.getBlockedUsers();

      emit(
        state.copyWith(
          status: BlockedUsersStatus.loaded,
          blockedUsers: blockedUsers,
          error: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: BlockedUsersStatus.error,
          error: 'Failed to load blocked users: $e',
        ),
      );
    }
  }

  Future<void> searchUsers(String query) async {
    try {
      emit(state.copyWith(status: BlockedUsersStatus.searching));

      final results = await _repository.searchUsers(query);

      emit(
        state.copyWith(
          status: BlockedUsersStatus.loaded,
          blockedUsers: results,
          searchQuery: query,
          error: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: BlockedUsersStatus.error,
          error: 'Search failed: $e',
        ),
      );
    }
  }

  Future<void> toggleBlockUser(String userId, bool block) async {
    try {
      emit(state.copyWith(status: BlockedUsersStatus.updating));

      BlockedUser updatedUser;

      if (block) {
        updatedUser = await _repository.blockUser(userUuid: userId);
      } else {
        updatedUser = await _repository.unblockUser(userId);
      }

      // Update the local list
      final updatedUsers = state.blockedUsers.map((user) {
        if (user.id == userId) {
          return updatedUser;
        }
        return user;
      }).toList();

      // If blocking a new user, add to list
      if (block && !updatedUsers.any((user) => user.id == userId)) {
        updatedUsers.add(updatedUser);
      }

      // If unblocking, remove from list
      if (!block) {
        updatedUsers.removeWhere((user) => user.id == userId);
      }

      emit(
        state.copyWith(
          status: BlockedUsersStatus.loaded,
          blockedUsers: updatedUsers,
          lastAction: block ? 'User blocked' : 'User unblocked',
          error: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: BlockedUsersStatus.error,
          error: block ? 'Failed to block user' : 'Failed to unblock user',
        ),
      );
    }
  }

  Future<void> getBlockStats() async {
    try {
      final stats = await _repository.getBlockStats();
      emit(state.copyWith(blockStats: stats));
    } catch (e) {
      // Don't change status, just log error
      print('Failed to get block stats: $e');
    }
  }

  Future<void> checkBlockStatus(String userUuid) async {
    try {
      final status = await _repository.checkBlockStatus(userUuid);
      emit(state.copyWith(lastBlockStatus: status));
    } catch (e) {
      print('Failed to check block status: $e');
    }
  }

  void clearError() {
    emit(state.copyWith(error: null));
  }

  void clearSearch() {
    emit(state.copyWith(searchQuery: null));
  }
}
