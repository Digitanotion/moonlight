import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:moonlight/features/search/domain/entities/search_result.dart';
import 'package:moonlight/features/search/domain/usecases/get_popular_clubs.dart';
import 'package:moonlight/features/search/domain/usecases/get_suggested_users.dart';
import 'package:moonlight/features/search/domain/usecases/get_trending_tags.dart';
import 'package:moonlight/features/search/domain/usecases/search_content.dart';

part 'search_event.dart';
part 'search_state.dart';

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final SearchContent searchContent;
  final GetTrendingTags getTrendingTags;
  final GetSuggestedUsers getSuggestedUsers;
  final GetPopularClubs getPopularClubs;

  SearchBloc({
    required this.searchContent,
    required this.getTrendingTags,
    required this.getSuggestedUsers,
    required this.getPopularClubs,
  }) : super(const SearchState()) {
    on<SearchQueryChanged>(_onSearchQueryChanged);
    on<LoadTrendingContent>(_onLoadTrendingContent);
    on<ClearSearch>(_onClearSearch);
  }

  Future<void> _onSearchQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) async {
    if (event.query.isEmpty) {
      emit(
        state.copyWith(query: '', results: [], status: SearchStatus.initial),
      );
      return;
    }

    emit(state.copyWith(query: event.query, status: SearchStatus.loading));

    final result = await searchContent(event.query);
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: SearchStatus.failure,
          errorMessage: 'Search failed',
        ),
      ),
      (results) => emit(
        state.copyWith(
          status: results.isEmpty ? SearchStatus.empty : SearchStatus.success,
          results: results,
        ),
      ),
    );
  }

  Future<void> _onLoadTrendingContent(
    LoadTrendingContent event,
    Emitter<SearchState> emit,
  ) async {
    final trendingTagsResult = await getTrendingTags();
    final suggestedUsersResult = await getSuggestedUsers();
    final popularClubsResult = await getPopularClubs();

    trendingTagsResult.fold(
      (failure) => emit(
        state.copyWith(
          status: SearchStatus.failure,
          errorMessage: 'Failed to load content',
        ),
      ),
      (trendingTags) => emit(state.copyWith(trendingTags: trendingTags)),
    );

    suggestedUsersResult.fold(
      (failure) => null, // Don't fail the whole state for one failed request
      (suggestedUsers) => emit(state.copyWith(suggestedUsers: suggestedUsers)),
    );

    popularClubsResult.fold(
      (failure) => null,
      (popularClubs) => emit(state.copyWith(popularClubs: popularClubs)),
    );
  }

  void _onClearSearch(ClearSearch event, Emitter<SearchState> emit) {
    emit(state.copyWith(query: '', results: [], status: SearchStatus.initial));
  }
}
