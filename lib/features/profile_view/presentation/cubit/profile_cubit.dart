import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:moonlight/core/network/error_parser.dart';
import 'package:moonlight/features/feed/domain/repositories/feed_repository.dart';
import 'package:moonlight/features/post_view/domain/entities/post.dart';
import 'package:moonlight/features/profile_view/domain/repositories/profile_repository.dart';

class ProfileState extends Equatable {
  final UserProfile? user;
  final List<Post> posts;
  final int page;
  final bool hasMore;
  final bool loadingHeader;
  final bool loadingPosts;
  final String? error;

  const ProfileState({
    this.user,
    this.posts = const [],
    this.page = 1,
    this.hasMore = true,
    this.loadingHeader = false,
    this.loadingPosts = false,
    this.error,
  });

  ProfileState copyWith({
    UserProfile? user,
    List<Post>? posts,
    int? page,
    bool? hasMore,
    bool? loadingHeader,
    bool? loadingPosts,
    String? error,
  }) {
    return ProfileState(
      user: user ?? this.user,
      posts: posts ?? this.posts,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      loadingHeader: loadingHeader ?? this.loadingHeader,
      loadingPosts: loadingPosts ?? this.loadingPosts,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    user,
    posts,
    page,
    hasMore,
    loadingHeader,
    loadingPosts,
    error,
  ];
}

class ProfileCubit extends Cubit<ProfileState> {
  final ProfileRepository repo;
  ProfileCubit(this.repo) : super(const ProfileState());

  static const _perPage = 20;

  Future<void> load(String userUuid) async {
    emit(
      state.copyWith(
        loadingHeader: true,
        loadingPosts: true,
        error: null,
        page: 1,
      ),
    );
    try {
      final user = await repo.getUser(userUuid);
      final first = await repo.getUserPosts(
        userUuid,
        page: 1,
        perPage: _perPage,
      );
      emit(
        state.copyWith(
          user: user,
          posts: first.data,
          page: 1,
          hasMore: first.hasMore,
          loadingHeader: false,
          loadingPosts: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          loadingHeader: false,
          loadingPosts: false,
          error: apiErrorMessage(e),
        ),
      );
    }
  }

  Future<void> loadMore(String userUuid) async {
    if (!state.hasMore || state.loadingPosts) return;
    emit(state.copyWith(loadingPosts: true));
    try {
      final next = state.page + 1;
      final r = await repo.getUserPosts(
        userUuid,
        page: next,
        perPage: _perPage,
      );
      emit(
        state.copyWith(
          posts: [...state.posts, ...r.data],
          page: next,
          hasMore: r.hasMore,
          loadingPosts: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loadingPosts: false, error: apiErrorMessage(e)));
    }
  }

  Future<void> refresh(String userUuid) => load(userUuid);
}
