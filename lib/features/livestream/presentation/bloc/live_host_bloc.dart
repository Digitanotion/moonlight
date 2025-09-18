import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/livestream/domain/entities/live_join_request.dart';
import 'package:moonlight/features/livestream/domain/entities/live_entities.dart';
import 'package:moonlight/features/livestream/domain/repositories/live_session_repository.dart';

// ===== State =====
class LiveHostState {
  final bool isLive;
  final bool isPaused;
  final int elapsedSeconds;
  final int viewers;
  final String topic;
  final List<LiveChatMessage> messages;
  final bool chatVisible;
  final LiveJoinRequest? pendingRequest;

  // NEW (gift toast)
  final GiftEvent? gift;
  final bool showGiftToast;

  const LiveHostState({
    required this.isLive,
    required this.isPaused,
    required this.elapsedSeconds,
    required this.viewers,
    required this.topic,
    required this.messages,
    required this.chatVisible,
    this.pendingRequest,
    this.gift,
    this.showGiftToast = false,
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
    GiftEvent? gift,
    bool? showGiftToast,
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
      gift: gift ?? this.gift,
      showGiftToast: showGiftToast ?? this.showGiftToast,
    );
  }

  static LiveHostState initial(
    String topic, {
    int initialViewers = 0,
    int initialElapsed = 0,
  }) => LiveHostState(
    isLive: true,
    isPaused: false,
    elapsedSeconds: initialElapsed,
    viewers: initialViewers,
    topic: topic,
    messages: const [],
    chatVisible: true,
    pendingRequest: null,
    gift: null,
    showGiftToast: false,
  );
}

// ===== Events =====
abstract class LiveHostEvent {}

class LiveStarted extends LiveHostEvent {
  final String topic;
  final int initialViewers;
  final String startedAtIso;
  LiveStarted(
    this.topic, {
    this.initialViewers = 0,
    required this.startedAtIso,
  });
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

class PauseStatusChanged extends LiveHostEvent {
  final bool paused;
  PauseStatusChanged(this.paused);
}

// NEW
class GiftArrived extends LiveHostEvent {
  final GiftEvent gift;
  GiftArrived(this.gift);
}

class LiveEndedReceived extends LiveHostEvent {}

class JoinHandledReceived extends LiveHostEvent {
  final JoinHandled payload;
  JoinHandledReceived(this.payload);
}

// ===== Bloc =====
class LiveHostBloc extends Bloc<LiveHostEvent, LiveHostState> {
  final LiveSessionRepository repo;
  Timer? _timer;
  StreamSubscription<int>? _vSub;
  StreamSubscription<LiveChatMessage>? _cSub;
  StreamSubscription<LiveJoinRequest>? _rSub;
  StreamSubscription<bool>? _pSub;

  // NEW
  StreamSubscription<GiftEvent>? _gSub;
  StreamSubscription<void>? _eSub;
  StreamSubscription<JoinHandled>? _jhSub;

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
    on<PauseStatusChanged>(
      (e, emit) => emit(state.copyWith(isPaused: e.paused)),
    );

    // NEW handlers
    on<GiftArrived>((e, emit) {
      emit(state.copyWith(gift: e.gift, showGiftToast: true));
      _autoHide(() => add(_HideGiftToast()));
    });
    on<LiveEndedReceived>((e, emit) async {
      await _cleanDown();
      emit(state.copyWith(isLive: false));
    });
    on<JoinHandledReceived>((e, emit) {
      // Clear card no matter where it was accepted/declined from
      emit(state.copyWith(clearRequest: true));
    });
    on<_HideGiftToast>((e, emit) => emit(state.copyWith(showGiftToast: false)));
  }

  Future<void> _onStart(LiveStarted e, Emitter<LiveHostState> emit) async {
    // initial elapsed from started_at
    int initialElapsed = 0;
    try {
      final started = DateTime.parse(e.startedAtIso).toUtc();
      initialElapsed = DateTime.now().toUtc().difference(started).inSeconds;
      if (initialElapsed < 0) initialElapsed = 0;
    } catch (_) {}

    emit(
      LiveHostState.initial(
        e.topic,
        initialViewers: e.initialViewers,
        initialElapsed: initialElapsed,
      ),
    );

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => add(LiveTick()));

    try {
      await repo.startSession(topic: e.topic);
    } catch (_) {
      // keep UI alive
    }

    await _vSub?.cancel();
    _vSub = repo.viewersStream().listen((v) => add(ViewerCountUpdated(v)));

    await _cSub?.cancel();
    _cSub = repo.chatStream().listen((m) => add(IncomingMessage(m)));

    await _rSub?.cancel();
    _rSub = repo.joinRequestStream().listen((r) => add(IncomingJoinRequest(r)));

    await _pSub?.cancel();
    _pSub = repo.pauseStream().listen((p) => add(PauseStatusChanged(p)));

    // NEW
    await _gSub?.cancel();
    _gSub = repo.giftsStream().listen((g) => add(GiftArrived(g)));

    await _eSub?.cancel();
    _eSub = repo.endedStream().listen((_) => add(LiveEndedReceived()));

    await _jhSub?.cancel();
    _jhSub = repo.joinHandledStream().listen(
      (j) => add(JoinHandledReceived(j)),
    );
  }

  void _onTick(LiveTick e, Emitter<LiveHostState> emit) {
    if (!state.isPaused) {
      emit(state.copyWith(elapsedSeconds: state.elapsedSeconds + 1));
    }
  }

  Future<void> _onTogglePause(
    TogglePause e,
    Emitter<LiveHostState> emit,
  ) async {
    final next = !state.isPaused;
    emit(state.copyWith(isPaused: next)); // optimistic
    repo.setLocalPause(next); // instant local mute
    await repo.togglePause(); // server will broadcast too
  }

  Future<void> _onEnd(EndPressed e, Emitter<LiveHostState> emit) async {
    await _cleanDown();
    emit(state.copyWith(isLive: false));
  }

  Future<void> _onAccept(
    AcceptJoinRequest e,
    Emitter<LiveHostState> emit,
  ) async {
    await repo.acceptJoinRequest(e.id);
    // Do not clear immediately; wait for server echo (join.handled)
  }

  Future<void> _onDecline(
    DeclineJoinRequest e,
    Emitter<LiveHostState> emit,
  ) async {
    await repo.declineJoinRequest(e.id);
    // Also wait for echo to clear
  }

  void _autoHide(void Function() cb) {
    Future.delayed(const Duration(seconds: 4), cb);
  }

  Future<void> _cleanDown() async {
    _timer?.cancel();
    await _vSub?.cancel();
    await _cSub?.cancel();
    await _rSub?.cancel();
    await _pSub?.cancel();
    await _gSub?.cancel();
    await _eSub?.cancel();
    await _jhSub?.cancel();
    await repo.endSession(); // idempotent
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    _vSub?.cancel();
    _cSub?.cancel();
    _rSub?.cancel();
    _pSub?.cancel();
    _gSub?.cancel();
    _eSub?.cancel();
    _jhSub?.cancel();
    // End session idempotently; server ignores if already ended
    return super.close().whenComplete(() async {
      try {
        await repo.endSession();
      } catch (_) {}
      repo.dispose();
    });
  }
}

// private event
class _HideGiftToast extends LiveHostEvent {}
