// lib/features/profile_view/presentation/cubit/follow_list_cubit.dart
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:moonlight/features/profile_view/data/datasources/follow_list_remote_datasource.dart';

class FollowTabState extends Equatable {
  final List<FollowListUser> users;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final String? nextCursor;
  final String? error;

  const FollowTabState({
    this.users = const [],
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = true,
    this.nextCursor,
    this.error,
  });

  FollowTabState copyWith({
    List<FollowListUser>? users,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    String? nextCursor,
    String? error,
  }) {
    return FollowTabState(
      users: users ?? this.users,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    users,
    loading,
    loadingMore,
    hasMore,
    nextCursor,
    error,
  ];
}

class FollowListState extends Equatable {
  final FollowTabState followers;
  final FollowTabState following;

  const FollowListState({
    this.followers = const FollowTabState(),
    this.following = const FollowTabState(),
  });

  FollowListState copyWith({
    FollowTabState? followers,
    FollowTabState? following,
  }) {
    return FollowListState(
      followers: followers ?? this.followers,
      following: following ?? this.following,
    );
  }

  @override
  List<Object?> get props => [followers, following];
}

class FollowListCubit extends Cubit<FollowListState> {
  final FollowListRemoteDataSource _ds;
  final String userUuid;

  FollowListCubit(this._ds, {required this.userUuid})
    : super(const FollowListState());

  Future<void> loadAll() async {
    await Future.wait([loadFollowers(), loadFollowing()]);
  }

  Future<void> loadFollowers() async {
    emit(
      state.copyWith(
        followers: state.followers.copyWith(loading: true, error: null),
      ),
    );
    try {
      final result = await _ds.getFollowers(userUuid);
      emit(
        state.copyWith(
          followers: FollowTabState(
            users: result.users,
            loading: false,
            hasMore: result.nextCursor != null,
            nextCursor: result.nextCursor,
          ),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          followers: state.followers.copyWith(
            loading: false,
            error: _friendly(e),
          ),
        ),
      );
    }
  }

  Future<void> loadMoreFollowers() async {
    final tab = state.followers;
    if (tab.loadingMore || !tab.hasMore) return;
    emit(state.copyWith(followers: tab.copyWith(loadingMore: true)));
    try {
      final result = await _ds.getFollowers(userUuid, cursor: tab.nextCursor);
      emit(
        state.copyWith(
          followers: tab.copyWith(
            users: [...tab.users, ...result.users],
            loadingMore: false,
            hasMore: result.nextCursor != null,
            nextCursor: result.nextCursor,
          ),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          followers: tab.copyWith(loadingMore: false, error: _friendly(e)),
        ),
      );
    }
  }

  Future<void> loadFollowing() async {
    emit(
      state.copyWith(
        following: state.following.copyWith(loading: true, error: null),
      ),
    );
    try {
      final result = await _ds.getFollowing(userUuid);
      emit(
        state.copyWith(
          following: FollowTabState(
            users: result.users,
            loading: false,
            hasMore: result.nextCursor != null,
            nextCursor: result.nextCursor,
          ),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          following: state.following.copyWith(
            loading: false,
            error: _friendly(e),
          ),
        ),
      );
    }
  }

  Future<void> loadMoreFollowing() async {
    final tab = state.following;
    if (tab.loadingMore || !tab.hasMore) return;
    emit(state.copyWith(following: tab.copyWith(loadingMore: true)));
    try {
      final result = await _ds.getFollowing(userUuid, cursor: tab.nextCursor);
      emit(
        state.copyWith(
          following: tab.copyWith(
            users: [...tab.users, ...result.users],
            loadingMore: false,
            hasMore: result.nextCursor != null,
            nextCursor: result.nextCursor,
          ),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          following: tab.copyWith(loadingMore: false, error: _friendly(e)),
        ),
      );
    }
  }

  Future<void> toggleFollow(String targetUuid) async {
    // Get current state before toggling
    final currentUser = _findUser(targetUuid);
    if (currentUser == null) return;

    final wasFollowing = currentUser.isFollowing;

    // Optimistically update UI
    _flipInTab(targetUuid, isFollowers: true);
    _flipInTab(targetUuid, isFollowers: false);

    try {
      if (wasFollowing) {
        await _ds.unfollowUser(targetUuid);
      } else {
        await _ds.followUser(targetUuid);
      }
      // Success - no need to revert
    } catch (e) {
      // Revert on error
      _flipInTab(targetUuid, isFollowers: true);
      _flipInTab(targetUuid, isFollowers: false);

      // Show error message
      final errorMsg = _friendly(e);
      // You might want to emit an error state or show a snackbar
      // This depends on your app's error handling strategy
      print('Toggle follow error: $errorMsg');
    }
  }

  void _flipInTab(String uuid, {required bool isFollowers}) {
    final tab = isFollowers ? state.followers : state.following;
    final updated = tab.users.map((u) {
      if (u.uuid != uuid) return u;
      // Create a new user with toggled isFollowing state
      return FollowListUser(
        uuid: u.uuid,
        userSlug: u.userSlug,
        fullname: u.fullname,
        avatarUrl: u.avatarUrl,
        isFollowing: !u.isFollowing, // Toggle the state
      );
    }).toList();

    if (isFollowers) {
      emit(state.copyWith(followers: tab.copyWith(users: updated)));
    } else {
      emit(state.copyWith(following: tab.copyWith(users: updated)));
    }
  }

  FollowListUser? _findUser(String uuid) {
    try {
      return state.followers.users.firstWhere((u) => u.uuid == uuid);
    } catch (_) {}
    try {
      return state.following.users.firstWhere((u) => u.uuid == uuid);
    } catch (_) {}
    return null;
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('401')) return 'Login required.';
    if (s.contains('403')) return 'Access denied.';
    if (s.contains('404')) return 'User not found.';
    return 'Something went wrong.';
  }
}
