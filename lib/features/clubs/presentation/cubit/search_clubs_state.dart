import 'package:moonlight/features/clubs/domain/entities/club.dart';

class SearchClubsState {
  final List<Club> results;
  final bool loading;
  final String? error;
  final String query;

  SearchClubsState({
    required this.results,
    required this.loading,
    this.error,
    required this.query,
  });

  factory SearchClubsState.initial() =>
      SearchClubsState(results: [], loading: false, error: null, query: '');

  SearchClubsState copyWith({
    List<Club>? results,
    bool? loading,
    String? error,
    String? query,
  }) {
    return SearchClubsState(
      results: results ?? this.results,
      loading: loading ?? this.loading,
      error: error ?? this.error,
      query: query ?? this.query,
    );
  }
}
