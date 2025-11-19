part of 'profile_page_cubit.dart';

class ProfilePageState extends Equatable {
  final bool loading;
  final String? error;
  final UserModel? user;
  final ProfileTab tab;

  /// CHANGED: now holds real Post objects, not List<String>
  final List<Post> posts;

  final List<ClubItem> clubs;
  final List<ReplayItem> replays;

  const ProfilePageState({
    required this.loading,
    required this.error,
    required this.user,
    required this.tab,
    required this.posts,
    required this.clubs,
    required this.replays,
  });

  factory ProfilePageState.initial() => const ProfilePageState(
    loading: false,
    error: null,
    user: null,
    tab: ProfileTab.posts,
    posts: [], // now List<Post>
    clubs: [],
    replays: [],
  );

  ProfilePageState copyWith({
    bool? loading,
    String? error,
    UserModel? user,
    ProfileTab? tab,
    List<Post>? posts, // CHANGED: now List<Post>
    List<ClubItem>? clubs,
    List<ReplayItem>? replays,
  }) {
    return ProfilePageState(
      loading: loading ?? this.loading,
      error: error,
      user: user ?? this.user,
      tab: tab ?? this.tab,
      posts: posts ?? this.posts,
      clubs: clubs ?? this.clubs,
      replays: replays ?? this.replays,
    );
  }

  @override
  List<Object?> get props => [
    loading,
    error,
    user,
    tab,
    posts, // now List<Post>
    clubs,
    replays,
  ];
}
