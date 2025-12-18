import 'package:equatable/equatable.dart';
import '../../domain/entities/club_member.dart';
import '../../domain/repositories/clubs_repository.dart';

class ClubMembersState extends Equatable {
  final bool loading;
  final bool loadingMore;
  final ClubMembersMeta? club;
  final List<ClubMember> members;
  final Pagination? pagination;
  final String? error;

  const ClubMembersState({
    required this.loading,
    required this.loadingMore,
    this.club,
    required this.members,
    this.pagination,
    this.error,
  });

  factory ClubMembersState.initial() =>
      const ClubMembersState(loading: false, loadingMore: false, members: []);

  ClubMembersState copyWith({
    bool? loading,
    bool? loadingMore,
    ClubMembersMeta? club,
    List<ClubMember>? members,
    Pagination? pagination,
    String? error,
  }) {
    return ClubMembersState(
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      club: club ?? this.club,
      members: members ?? this.members,
      pagination: pagination ?? this.pagination,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    loading,
    loadingMore,
    club,
    members,
    pagination,
    error,
  ];
}
