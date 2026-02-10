import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/clubs/domain/repositories/clubs_repository.dart';
import 'package:moonlight/features/clubs/domain/entities/club.dart';
import 'package:moonlight/features/clubs/presentation/cubit/search_clubs_state.dart';

class SearchClubsCubit extends Cubit<SearchClubsState> {
  final ClubsRepository repo;
  Timer? _debounceTimer;

  SearchClubsCubit(this.repo) : super(SearchClubsState.initial());

  void search(String query) {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      emit(
        state.copyWith(results: [], loading: false, query: query, error: null),
      );
      return;
    }

    emit(state.copyWith(loading: true, query: query, results: [], error: null));

    try {
      final results = await repo.searchClubs(query);

      emit(state.copyWith(loading: false, results: results));
    } catch (e) {
      emit(
        state.copyWith(
          loading: false,
          error: 'Failed to search clubs. Please try again.',
        ),
      );
    }
  }

  void clear() {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }
    emit(SearchClubsState.initial());
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }
}
