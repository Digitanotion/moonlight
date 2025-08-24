part of 'profile_page_cubit.dart';

class ProfilePageState extends Equatable {
  final bool loading;
  final String? error;
  final UserModel? user;
  final ProfileTab tab;

  // content lists (mock for now)
  final List<String> posts; // image urls
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
    posts: [],
    clubs: [],
    replays: [],
  );

  ProfilePageState copyWith({
    bool? loading,
    String? error,
    UserModel? user,
    ProfileTab? tab,
    List<String>? posts,
    List<ClubItem>? clubs,
    List<ReplayItem>? replays,
  }) => ProfilePageState(
    loading: loading ?? this.loading,
    error: error,
    user: user ?? this.user,
    tab: tab ?? this.tab,
    posts: posts ?? this.posts,
    clubs: clubs ?? this.clubs,
    replays: replays ?? this.replays,
  );

  @override
  List<Object?> get props => [loading, error, user, tab, posts, clubs, replays];
}
