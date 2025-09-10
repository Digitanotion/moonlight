// lib/features/livestream/presentation/cubits/requests_cubit.dart
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:moonlight/features/livestream/domain/repositories/livestream_repository.dart';

// part 'requests_state.dart';

class RequestsCubit extends Cubit<RequestsState> {
  final LivestreamRepository repo;
  final String lsUuid;
  RequestsCubit(this.repo, this.lsUuid) : super(const RequestsState());

  Future<void> poll() async {
    final res = await repo.getRequests(lsUuid);
    res.fold(
      (f) => emit(state.copyWith(error: f.message)),
      (list) => emit(state.copyWith(pending: list)),
    );
  }

  Future<void> accept(String userUuid) async {
    await repo.acceptRequest(lsUuid, userUuid);
    await poll();
  }

  Future<void> decline(String userUuid) async {
    await repo.declineRequest(lsUuid, userUuid);
    await poll();
  }
}

class RequestsState extends Equatable {
  final List<Map<String, dynamic>> pending;
  final String? error;
  const RequestsState({this.pending = const [], this.error});
  RequestsState copyWith({
    List<Map<String, dynamic>>? pending,
    String? error,
  }) => RequestsState(pending: pending ?? this.pending, error: error);
  @override
  List<Object?> get props => [pending, error];
}
