part of 'search_bloc.dart';

enum SearchStatus { initial, loading, success, empty, failure }

class SearchState extends Equatable {
  final SearchStatus status;
  final String query;
  final List<SearchResult> results;
  final List<TagResult> trendingTags;
  final List<UserResult> suggestedUsers;
  final List<ClubResult> popularClubs;
  final String? errorMessage;

  const SearchState({
    this.status = SearchStatus.initial,
    this.query = '',
    this.results = const [],
    this.trendingTags = const [],
    this.suggestedUsers = const [],
    this.popularClubs = const [],
    this.errorMessage,
  });

  SearchState copyWith({
    SearchStatus? status,
    String? query,
    List<SearchResult>? results,
    List<TagResult>? trendingTags,
    List<UserResult>? suggestedUsers,
    List<ClubResult>? popularClubs,
    String? errorMessage,
  }) {
    return SearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      results: results ?? this.results,
      trendingTags: trendingTags ?? this.trendingTags,
      suggestedUsers: suggestedUsers ?? this.suggestedUsers,
      popularClubs: popularClubs ?? this.popularClubs,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    query,
    results,
    trendingTags,
    suggestedUsers,
    popularClubs,
    errorMessage,
  ];
}
