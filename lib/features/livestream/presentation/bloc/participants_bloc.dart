import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/participant.dart';
import '../../domain/entities/paginated.dart';
import '../../domain/repositories/participants_repository.dart';

part 'participants_event.dart';
part 'participants_state.dart';

class ParticipantsBloc extends Bloc<ParticipantsEvent, ParticipantsState> {
  final ParticipantsRepository repo;
  StreamSubscription<Participant>? _addSub;
  StreamSubscription<String>? _remSub;
  StreamSubscription<MapEntry<String, String>>? _roleSub;

  ParticipantsBloc(this.repo) : super(const ParticipantsState.initial()) {
    on<ParticipantsStarted>(_onStart);
    on<ParticipantsRefreshed>(_onRefresh);
    on<ParticipantsNextPageRequested>(_onNextPage);
    on<ParticipantActionRemove>(_onRemove);
    on<ParticipantActionRole>(_onRole);

    // socket -> state
    on<_SockAdded>(_onSockAdded);
    on<_SockRemoved>(_onSockRemoved);
    on<_SockRoleChanged>(_onSockRole);
  }

  Future<void> _onStart(
    ParticipantsStarted e,
    Emitter<ParticipantsState> emit,
  ) async {
    emit(state.copyWith(loading: true, error: null, roleFilter: e.role));
    try {
      final page = await repo.list(page: 1, role: e.role);
      emit(
        state.copyWith(
          loading: false,
          items: page.data,
          page: page.currentPage,
          hasMore: page.hasMore,
          error: null,
        ),
      );

      // bind sockets
      await _addSub?.cancel();
      await _remSub?.cancel();
      await _roleSub?.cancel();
      _addSub = repo.participantAddedStream().listen((p) => add(_SockAdded(p)));
      _remSub = repo.participantRemovedStream().listen(
        (uuid) => add(_SockRemoved(uuid)),
      );
      _roleSub = repo.roleChangedStream().listen(
        (e) => add(_SockRoleChanged(e.key, e.value)),
      );
    } catch (err) {
      emit(state.copyWith(loading: false, error: _msg(err)));
    }
  }

  Future<void> _onRefresh(
    ParticipantsRefreshed e,
    Emitter<ParticipantsState> emit,
  ) async {
    try {
      final page = await repo.list(page: 1, role: state.roleFilter);
      emit(
        state.copyWith(
          items: page.data,
          page: page.currentPage,
          hasMore: page.hasMore,
          error: null,
        ),
      );
    } catch (err) {
      emit(state.copyWith(error: _msg(err)));
    }
  }

  Future<void> _onNextPage(
    ParticipantsNextPageRequested e,
    Emitter<ParticipantsState> emit,
  ) async {
    if (!state.hasMore || state.paging) return;
    emit(state.copyWith(paging: true, error: null));
    try {
      final next = await repo.list(
        page: state.page + 1,
        role: state.roleFilter,
      );
      emit(
        state.copyWith(
          paging: false,
          page: next.currentPage,
          hasMore: next.hasMore,
          items: [...state.items, ...next.data],
        ),
      );
    } catch (err) {
      emit(state.copyWith(paging: false, error: _msg(err)));
    }
  }

  Future<void> _onRemove(
    ParticipantActionRemove e,
    Emitter<ParticipantsState> emit,
  ) async {
    // optimistic remove
    final prev = state.items;
    emit(
      state.copyWith(
        items: prev.where((p) => p.userUuid != e.userUuid).toList(),
      ),
    );
    try {
      await repo.remove(e.userUuid);
    } catch (err) {
      // revert on error
      emit(state.copyWith(items: prev, error: _msg(err)));
    }
  }

  Future<void> _onRole(
    ParticipantActionRole e,
    Emitter<ParticipantsState> emit,
  ) async {
    // optimistic local change
    final idx = state.items.indexWhere((p) => p.userUuid == e.userUuid);
    if (idx == -1) return;
    final items = [...state.items];
    final old = items[idx];
    items[idx] = old.copyWith(role: e.role);
    emit(state.copyWith(items: items));
    try {
      await repo.changeRole(e.userUuid, e.role);
    } catch (err) {
      // revert on error
      items[idx] = old;
      emit(state.copyWith(items: items, error: _msg(err)));
    }
  }

  void _onSockAdded(_SockAdded e, Emitter<ParticipantsState> emit) {
    // ignore duplicates
    if (state.items.any((p) => p.userUuid == e.p.userUuid)) return;
    emit(state.copyWith(items: [e.p, ...state.items]));
  }

  void _onSockRemoved(_SockRemoved e, Emitter<ParticipantsState> emit) {
    emit(
      state.copyWith(
        items: state.items.where((p) => p.userUuid != e.userUuid).toList(),
      ),
    );
  }

  void _onSockRole(_SockRoleChanged e, Emitter<ParticipantsState> emit) {
    final idx = state.items.indexWhere((p) => p.userUuid == e.userUuid);
    if (idx == -1) return;
    final items = [...state.items];
    items[idx] = items[idx].copyWith(role: e.role);
    emit(state.copyWith(items: items));
  }

  String _msg(Object err) {
    if (err is DioException) {
      final d = err.response?.data;
      if (d is Map && d['message'] is String) return d['message'] as String;
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Future<void> close() async {
    await _addSub?.cancel();
    await _remSub?.cancel();
    await _roleSub?.cancel();
    await repo.dispose();
    return super.close();
  }
}
