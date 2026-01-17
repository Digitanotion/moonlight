import 'dart:async';
import 'package:bloc/bloc.dart';
import '../../domain/entities/club_member.dart';
import 'club_members_state.dart';
import '../../domain/repositories/clubs_repository.dart';

enum MembersFilter { all, recentlyJoined }

class ClubMembersCubit extends Cubit<ClubMembersState> {
  final ClubsRepository repo;
  final String club;

  ClubMembersCubit({required this.repo, required this.club})
    : super(ClubMembersState.initial());

  int _page = 1;
  bool _hasMore = true;
  String _search = '';
  MembersFilter _filter = MembersFilter.all;
  Timer? _debounce;

  /// ✅ ADDITIVE: expose current filter to UI
  MembersFilter get currentFilter => _filter;

  // ───────────────── LOAD ─────────────────

  Future<void> load({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      _hasMore = true;
    }

    emit(state.copyWith(loading: true, error: null));

    try {
      final result = await repo.getClubMembersUI(
        club: club,
        page: _page,
        search: _search.isEmpty ? null : _search,
        sort: _filter == MembersFilter.recentlyJoined ? 'joined_at' : null,
        order: _filter == MembersFilter.recentlyJoined ? 'desc' : null,
      );

      _hasMore = result.pagination.hasMore;

      emit(
        state.copyWith(
          loading: false,
          club: result.club,
          members: refresh
              ? result.members
              : (_page == 1
                    ? result.members
                    : [...state.members, ...result.members]),
          pagination: result.pagination,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  // ───────────────── PAGINATION ─────────────────

  Future<void> loadMore() async {
    if (!_hasMore || state.loadingMore || _search.isNotEmpty) return;

    emit(state.copyWith(loadingMore: true));

    try {
      _page += 1;

      final result = await repo.getClubMembersUI(
        club: club,
        page: _page,
        sort: _filter == MembersFilter.recentlyJoined ? 'joined_at' : null,
        order: _filter == MembersFilter.recentlyJoined ? 'desc' : null,
      );

      _hasMore = result.pagination.hasMore;

      emit(
        state.copyWith(
          loadingMore: false,
          members: [...state.members, ...result.members],
          pagination: result.pagination,
        ),
      );
    } catch (e) {
      _page -= 1;
      emit(state.copyWith(loadingMore: false, error: e.toString()));
    }
  }

  // ───────────────── SEARCH ─────────────────

  void search(String query) {
    _search = query.trim();

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _page = 1;
      _hasMore = false; // search does not paginate
      load(refresh: true);
    });
  }

  void clearSearch() {
    _search = '';
    _page = 1;
    _hasMore = true;
    load(refresh: true);
  }

  // ───────────────── FILTER ─────────────────

  void setFilter(MembersFilter filter) {
    if (_filter == filter) return;
    _filter = filter;
    _page = 1;
    _hasMore = true;
    load(refresh: true);
  }

  // ───────────────── MUTATIONS ─────────────────

  Future<void> promote(String member) async {
    await repo.changeMemberRole(club: club, member: member, role: 'admin');
    await load(refresh: true);
  }

  Future<void> demote(String member) async {
    await repo.changeMemberRole(club: club, member: member, role: 'member');
    await load(refresh: true);
  }

  Future<void> remove(String member) async {
    await repo.removeMember(club: club, member: member);
    await load(refresh: true);
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
