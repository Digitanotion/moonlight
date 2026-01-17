part of 'blocked_users_cubit.dart';

enum BlockedUsersStatus { initial, loading, loaded, error, updating, searching }

class BlockedUsersState extends Equatable {
  final BlockedUsersStatus status;
  final List<BlockedUser> blockedUsers;
  final String? error;
  final String? lastAction;
  final String? searchQuery;
  final Map<String, dynamic>? blockStats;
  final Map<String, dynamic>? lastBlockStatus;

  const BlockedUsersState({
    this.status = BlockedUsersStatus.initial,
    this.blockedUsers = const [],
    this.error,
    this.lastAction,
    this.searchQuery,
    this.blockStats,
    this.lastBlockStatus,
  });

  BlockedUsersState copyWith({
    BlockedUsersStatus? status,
    List<BlockedUser>? blockedUsers,
    String? error,
    String? lastAction,
    String? searchQuery,
    Map<String, dynamic>? blockStats,
    Map<String, dynamic>? lastBlockStatus,
  }) {
    return BlockedUsersState(
      status: status ?? this.status,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      error: error,
      lastAction: lastAction,
      searchQuery: searchQuery,
      blockStats: blockStats ?? this.blockStats,
      lastBlockStatus: lastBlockStatus ?? this.lastBlockStatus,
    );
  }

  @override
  List<Object?> get props => [
    status,
    blockedUsers,
    error,
    lastAction,
    searchQuery,
    blockStats,
    lastBlockStatus,
  ];
}
