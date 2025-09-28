part of 'participants_bloc.dart';

class ParticipantsState extends Equatable {
  final bool loading;
  final bool paging;
  final bool hasMore;
  final int page;
  final String? roleFilter;
  final List<Participant> items;
  final String? error;

  const ParticipantsState({
    required this.loading,
    required this.paging,
    required this.hasMore,
    required this.page,
    required this.items,
    required this.roleFilter,
    required this.error,
  });

  const ParticipantsState.initial()
    : loading = false,
      paging = false,
      hasMore = false,
      page = 0,
      items = const [],
      roleFilter = null,
      error = null;

  ParticipantsState copyWith({
    bool? loading,
    bool? paging,
    bool? hasMore,
    int? page,
    List<Participant>? items,
    String? roleFilter,
    String? error,
  }) {
    return ParticipantsState(
      loading: loading ?? this.loading,
      paging: paging ?? this.paging,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      items: items ?? this.items,
      roleFilter: roleFilter ?? this.roleFilter,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    loading,
    paging,
    hasMore,
    page,
    roleFilter,
    items,
    error,
  ];
}
