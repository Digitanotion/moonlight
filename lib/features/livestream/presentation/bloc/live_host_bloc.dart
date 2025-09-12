import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/livestream/domain/entities/live_join_request.dart';
import 'package:moonlight/features/livestream/domain/repositories/live_session_repository.dart';

class LiveHostState {
  final bool isLive;
  final bool isPaused;
  final int elapsedSeconds;
  final int viewers;
  final String topic;
  final List<LiveChatMessage> messages;
  final bool chatVisible;
  final LiveJoinRequest? pendingRequest;

  const LiveHostState({
    required this.isLive,
    required this.isPaused,
    required this.elapsedSeconds,
    required this.viewers,
    required this.topic,
    required this.messages,
    required this.chatVisible,
    this.pendingRequest,
  });

  LiveHostState copyWith({
    bool? isLive,
    bool? isPaused,
    int? elapsedSeconds,
    int? viewers,
    String? topic,
    List<LiveChatMessage>? messages,
    bool? chatVisible,
    LiveJoinRequest? pendingRequest,
    bool clearRequest = false,
  }) {
    return LiveHostState(
      isLive: isLive ?? this.isLive,
      isPaused: isPaused ?? this.isPaused,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      viewers: viewers ?? this.viewers,
      topic: topic ?? this.topic,
      messages: messages ?? this.messages,
      chatVisible: chatVisible ?? this.chatVisible,
      pendingRequest: clearRequest
          ? null
          : (pendingRequest ?? this.pendingRequest),
    );
  }

  static LiveHostState initial(String topic) => LiveHostState(
    isLive: true,
    isPaused: false,
    elapsedSeconds: 0,
    viewers: 1800,
    topic: topic,
    messages: const [],
    chatVisible: true,
    pendingRequest: null,
  );
}

abstract class LiveHostEvent {}

class LiveStarted extends LiveHostEvent {
  final String topic;
  LiveStarted(this.topic);
}

class LiveTick extends LiveHostEvent {}

class ViewerCountUpdated extends LiveHostEvent {
  final int viewers;
  ViewerCountUpdated(this.viewers);
}

class IncomingMessage extends LiveHostEvent {
  final LiveChatMessage message;
  IncomingMessage(this.message);
}

class TogglePause extends LiveHostEvent {}

class ToggleChatVisibility extends LiveHostEvent {}

class EndPressed extends LiveHostEvent {}

// NEW: join requests
class IncomingJoinRequest extends LiveHostEvent {
  final LiveJoinRequest req;
  IncomingJoinRequest(this.req);
}

class AcceptJoinRequest extends LiveHostEvent {
  final String id;
  AcceptJoinRequest(this.id);
}

class DeclineJoinRequest extends LiveHostEvent {
  final String id;
  DeclineJoinRequest(this.id);
}

class LiveHostBloc extends Bloc<LiveHostEvent, LiveHostState> {
  final LiveSessionRepository repo;
  Timer? _timer;
  StreamSubscription? _vSub;
  StreamSubscription? _cSub;
  StreamSubscription? _rSub;

  LiveHostBloc(this.repo) : super(LiveHostState.initial('')) {
    on<LiveStarted>(_onStart);
    on<LiveTick>(_onTick);
    on<ViewerCountUpdated>(
      (e, emit) => emit(state.copyWith(viewers: e.viewers)),
    );
    on<IncomingMessage>(
      (e, emit) =>
          emit(state.copyWith(messages: [...state.messages, e.message])),
    );
    on<TogglePause>(_onTogglePause);
    on<ToggleChatVisibility>(
      (e, emit) => emit(state.copyWith(chatVisible: !state.chatVisible)),
    );
    on<EndPressed>(_onEnd);

    on<IncomingJoinRequest>(
      (e, emit) => emit(state.copyWith(pendingRequest: e.req)),
    );
    on<AcceptJoinRequest>(_onAccept);
    on<DeclineJoinRequest>(_onDecline);
  }

  Future<void> _onStart(LiveStarted e, Emitter<LiveHostState> emit) async {
    emit(LiveHostState.initial(e.topic));
    await repo.startSession(topic: e.topic);

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => add(LiveTick()));

    _vSub?.cancel();
    _vSub = repo.viewersStream().listen((v) => add(ViewerCountUpdated(v)));

    _cSub?.cancel();
    _cSub = repo.chatStream().listen((m) => add(IncomingMessage(m)));
    _rSub?.cancel();
    _rSub = repo.joinRequestStream().listen((r) => add(IncomingJoinRequest(r)));
  }

  void _onTick(LiveTick e, Emitter<LiveHostState> emit) {
    if (!state.isPaused) {
      emit(state.copyWith(elapsedSeconds: state.elapsedSeconds + 1));
    }
  }

  void _onTogglePause(TogglePause e, Emitter<LiveHostState> emit) {
    emit(state.copyWith(isPaused: !state.isPaused));
  }

  Future<void> _onEnd(EndPressed e, Emitter<LiveHostState> emit) async {
    await repo.endSession();
    _timer?.cancel();
    _vSub?.cancel();
    _cSub?.cancel();
    _rSub?.cancel();
    emit(state.copyWith(isLive: false));
  }

  Future<void> _onAccept(
    AcceptJoinRequest e,
    Emitter<LiveHostState> emit,
  ) async {
    await repo.acceptJoinRequest(e.id);
    emit(state.copyWith(clearRequest: true));
    // Later: open co-host layout / picture-in-picture etc.
  }

  Future<void> _onDecline(
    DeclineJoinRequest e,
    Emitter<LiveHostState> emit,
  ) async {
    await repo.declineJoinRequest(e.id);
    emit(state.copyWith(clearRequest: true));
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _vSub?.cancel();
    _cSub?.cancel();
    _rSub?.cancel();
    repo.dispose();
    return super.close();
  }
}
