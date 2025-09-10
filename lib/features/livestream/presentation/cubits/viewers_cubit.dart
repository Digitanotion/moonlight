// lib/features/livestream/presentation/cubits/viewers_cubit.dart
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:moonlight/features/livestream/domain/repositories/livestream_repository.dart';

// part 'viewers_state.dart';

class ViewersCubit extends Cubit<ViewersState> {
  final LivestreamRepository repo;
  final String lsUuid;
  ViewersCubit(this.repo, this.lsUuid) : super(const ViewersState());

  Future<void> refresh() async {
    final res = await repo.getViewers(lsUuid);
    res.fold(
      (f) => emit(state.copyWith(error: f.message)),
      (m) => emit(
        state.copyWith(
          count: (m['count'] ?? 0) as int,
          users: (m['data'] as List?)?.cast<Map<String, dynamic>>() ?? const [],
        ),
      ),
    );
  }
}

class ViewersState extends Equatable {
  final int count;
  final List<Map<String, dynamic>> users;
  final String? error;
  const ViewersState({this.count = 0, this.users = const [], this.error});
  ViewersState copyWith({
    int? count,
    List<Map<String, dynamic>>? users,
    String? error,
  }) => ViewersState(
    count: count ?? this.count,
    users: users ?? this.users,
    error: error,
  );
  @override
  List<Object?> get props => [count, users, error];
}
