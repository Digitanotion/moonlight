import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/services/agora_service.dart';
import 'package:moonlight/features/livestream/domain/entities/live_end_analytics.dart';
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
  final LiveEndAnalytics? endAnalytics;
  final String? activeGuestUuid;

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
    this.endAnalytics,
    this.activeGuestUuid,
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
    LiveEndAnalytics? endAnalytics,
    bool clearEndAnalytics = false,
    String? activeGuestUuid,
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
      endAnalytics: clearEndAnalytics
          ? null
          : (endAnalytics ?? this.endAnalytics),
      activeGuestUuid: activeGuestUuid ?? this.activeGuestUuid,
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
    endAnalytics: null,
    activeGuestUuid: null,
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

class SendChatMessage extends LiveHostEvent {
  final String text;
  SendChatMessage(this.text);
}

// private events
class _HideGiftToast extends LiveHostEvent {}

class _ActiveGuestChanged extends LiveHostEvent {
  final String? uuid;
  _ActiveGuestChanged(this.uuid);
}

// ===== Bloc =====
class LiveHostBloc extends Bloc<LiveHostEvent, LiveHostState> {
  final LiveSessionRepository repo;
  final AgoraService agoraService;
  Timer? _timer;
  StreamSubscription<int>? _vSub;
  StreamSubscription<LiveChatMessage>? _cSub;
  StreamSubscription<LiveJoinRequest>? _rSub;
  StreamSubscription<bool>? _pSub;

  // NEW
  StreamSubscription<GiftEvent>? _gSub;
  StreamSubscription<void>? _eSub;
  StreamSubscription<JoinHandled>? _jhSub;
  StreamSubscription<String?>? _guestSub;

  // FIXED: Remove StreamSubscription for ValueNotifier since we use addListener
  // ValueNotifier uses addListener/removeListener instead of StreamSubscription

  LiveHostBloc(this.repo, this.agoraService)
    : super(LiveHostState.initial('')) {
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
    on<SendChatMessage>((event, emit) async {
      await repo.sendChatMessage(event.text);
      // Message will appear via the existing chat stream - no state change needed
    });
    on<_HideGiftToast>((e, emit) => emit(state.copyWith(showGiftToast: false)));

    // FIXED: Only one handler for _ActiveGuestChanged (removed duplicate)
    on<_ActiveGuestChanged>((e, emit) {
      emit(state.copyWith(activeGuestUuid: e.uuid));
    });
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

    // Start the timer first
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => add(LiveTick()));

    try {
      // Then start the session
      await repo.startSession(topic: e.topic);
      debugPrint('✅ Live session started successfully');
    } catch (error) {
      debugPrint('❌ Failed to start live session: $error');
      // Don't rethrow - keep the UI functional but show error state
      emit(state.copyWith(isLive: false));
      return;
    }

    // Then setup stream subscriptions
    await _setupStreamSubscriptions();
  }

  Future<void> _setupStreamSubscriptions() async {
    // Cancel existing subscriptions first
    await _vSub?.cancel();
    await _cSub?.cancel();
    await _rSub?.cancel();
    await _pSub?.cancel();
    await _gSub?.cancel();
    await _eSub?.cancel();
    await _jhSub?.cancel();
    await _guestSub?.cancel();

    // FIXED: Remove Agora listener
    _removeAgoraListener();

    // Setup new subscriptions
    _vSub = repo.viewersStream().listen((v) {
      debugPrint('👥 Viewer count update: $v');
      add(ViewerCountUpdated(v));
    });

    _cSub = repo.chatStream().listen((m) {
      debugPrint('💬 Chat message received');
      add(IncomingMessage(m));
    });

    _rSub = repo.joinRequestStream().listen((r) {
      debugPrint('🙋 Join request received');
      add(IncomingJoinRequest(r));
    });

    _pSub = repo.pauseStream().listen((p) {
      debugPrint('⏸️ Pause status: $p');
      add(PauseStatusChanged(p));
    });

    _gSub = repo.giftsStream().listen((g) {
      debugPrint('🎁 Gift received');
      add(GiftArrived(g));
    });

    _eSub = repo.endedStream().listen((_) {
      debugPrint('🔴 Live ended event received');
      add(LiveEndedReceived());
    });

    _jhSub = repo.joinHandledStream().listen((j) {
      debugPrint('✅ Join handled: ${j.accepted}');
      add(JoinHandledReceived(j));
    });

    // Enhanced guest subscription
    _guestSub = repo.activeGuestUuidStream().listen((uuid) {
      debugPrint('🎥 Active guest UUID (host view): $uuid');
      add(_ActiveGuestChanged(uuid));
    });

    // FIXED: Use addListener for ValueNotifier instead of stream.listen
    _setupAgoraListener();

    debugPrint('✅ All stream subscriptions setup');
  }

  // FIXED: Add methods for ValueNotifier listener management
  void _setupAgoraListener() {
    agoraService.primaryRemoteUid.addListener(_onAgoraRemoteUidChanged);
  }

  void _removeAgoraListener() {
    agoraService.primaryRemoteUid.removeListener(_onAgoraRemoteUidChanged);
  }

  void _onAgoraRemoteUidChanged() {
    final remoteUid = agoraService.primaryRemoteUid.value;
    debugPrint('🎥 Agora primary remote UID changed: $remoteUid');
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
    try {
      // 1) Call server to end + get analytics
      final analytics = await repo.endAndFetchAnalytics();

      // 2) Local cleanup (mute/leave etc.)
      await _cleanDown();

      // 3) Put analytics in state and flip off isLive (UI will navigate)
      emit(state.copyWith(isLive: false, endAnalytics: analytics));
    } catch (_) {
      // Still attempt to cleanup locally, but keep UX consistent
      await _cleanDown();
      emit(state.copyWith(isLive: false));
    }
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
    await _guestSub?.cancel();

    // FIXED: Remove Agora listener
    _removeAgoraListener();

    await repo.endSession(); // idempotent
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    await _vSub?.cancel();
    await _cSub?.cancel();
    await _rSub?.cancel();
    await _pSub?.cancel();
    await _gSub?.cancel();
    await _eSub?.cancel();
    await _jhSub?.cancel();
    await _guestSub?.cancel();

    // FIXED: Remove Agora listener
    _removeAgoraListener();

    // End session idempotently; server ignores if already ended
    return super.close().whenComplete(() async {
      try {
        await repo.endSession();
      } catch (_) {}
      repo.dispose();
    });
  }
}
