import 'package:bloc/bloc.dart';
import 'package:moonlight/features/clubs/domain/entities/club_member.dart';
import 'club_members_state.dart';
import '../../domain/repositories/clubs_repository.dart';

class ClubMembersCubit extends Cubit<ClubMembersState> {
  final ClubsRepository repo;
  final String club;

  ClubMembersCubit({required this.repo, required this.club})
    : super(ClubMembersState.initial());

  int _page = 1;
  bool _hasMore = true;

  Future<void> load({bool refresh = false}) async {
    try {
      print('🔄 Cubit: Loading members for club: $club');

      if (!refresh) {
        emit(state.copyWith(loading: true, error: null));
      }

      final result = await repo.getClubMembersUI(club: club);

      print('✅ Cubit: Successfully loaded ${result.members.length} members');
      print('✅ Cubit: Club name: ${result.club.name}');

      emit(
        state.copyWith(
          loading: false,
          club: result.club,
          members: result.members,
          pagination: result.pagination,
          error: null,
        ),
      );
    } catch (e) {
      print('❌ Cubit: Error loading members: $e');
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore || state.loadingMore) return;

    emit(state.copyWith(loadingMore: true));

    try {
      _page += 1;

      final result = await repo.getClubMembersUI(club: club, page: _page);

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

  // 🔧 Mutations

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
}
