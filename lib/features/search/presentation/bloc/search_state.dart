part of 'search_bloc.dart';

enum SearchStatus { initial, loading, success, empty, failure }

class SearchState extends Equatable {
  final String query;
  final SearchStatus status;
  final List<SearchResult> results;

  final List<TagResult> trendingTags;
  final List<UserResult> suggestedUsers;
  final List<ClubResult> popularClubs;

  final bool isLoadingTrending;
  final bool isLoadingUsers;
  final bool isLoadingClubs;

  final String? errorMessage;

  const SearchState({
    this.query = '',
    this.status = SearchStatus.initial,
    this.results = const [],
    this.trendingTags = const [],
    this.suggestedUsers = const [],
    this.popularClubs = const [],
    this.isLoadingTrending = false,
    this.isLoadingUsers = false,
    this.isLoadingClubs = false,
    this.errorMessage,
  });

  SearchState copyWith({
    String? query,
    SearchStatus? status,
    List<SearchResult>? results,
    List<TagResult>? trendingTags,
    List<UserResult>? suggestedUsers,
    List<ClubResult>? popularClubs,
    bool? isLoadingTrending,
    bool? isLoadingUsers,
    bool? isLoadingClubs,
    String? errorMessage,
  }) {
    return SearchState(
      query: query ?? this.query,
      status: status ?? this.status,
      results: results ?? this.results,
      trendingTags: trendingTags ?? this.trendingTags,
      suggestedUsers: suggestedUsers ?? this.suggestedUsers,
      popularClubs: popularClubs ?? this.popularClubs,
      isLoadingTrending: isLoadingTrending ?? this.isLoadingTrending,
      isLoadingUsers: isLoadingUsers ?? this.isLoadingUsers,
      isLoadingClubs: isLoadingClubs ?? this.isLoadingClubs,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    query,
    status,
    results,
    trendingTags,
    suggestedUsers,
    popularClubs,
    isLoadingTrending,
    isLoadingUsers,
    isLoadingClubs,
    errorMessage,
  ];
}
