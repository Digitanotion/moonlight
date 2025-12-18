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

  Future<void> _onLoadTrendingContent(
    LoadTrendingContent event,
    Emitter<SearchState> emit,
  ) async {
    emit(
      state.copyWith(
        isLoadingTrending: true,
        isLoadingUsers: true,
        isLoadingClubs: true,
      ),
    );

    final trendingTagsResult = await getTrendingTags();
    final suggestedUsersResult = await getSuggestedUsers();
    final popularClubsResult = await getPopularClubs();

    emit(
      state.copyWith(
        trendingTags: trendingTagsResult.getOrElse(() => []),
        suggestedUsers: suggestedUsersResult.getOrElse(() => []),
        popularClubs: popularClubsResult.getOrElse(() => []),
        isLoadingTrending: false,
        isLoadingUsers: false,
        isLoadingClubs: false,
      ),
    );
  }

  Future<void> _onSearchQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) async {
    if (event.query.isEmpty) {
      emit(const SearchState());
      return;
    }

    emit(state.copyWith(query: event.query, status: SearchStatus.loading));

    final result = await searchContent(event.query);

    result.fold(
      (_) => emit(
        state.copyWith(
          status: SearchStatus.failure,
          errorMessage: 'Something went wrong. Please try again.',
        ),
      ),
      (results) => emit(
        state.copyWith(
          results: results,
          status: results.isEmpty ? SearchStatus.empty : SearchStatus.success,
        ),
      ),
    );
  }

  void _onClearSearch(ClearSearch event, Emitter<SearchState> emit) {
    emit(const SearchState());
  }
}
