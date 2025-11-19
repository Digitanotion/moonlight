// FILE: lib/features/livestream/presentation/bloc/live_host_bloc.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/services/agora_service.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/features/livestream/data/models/premium_package_model.dart';
import 'package:moonlight/features/livestream/data/models/premium_status_model.dart';
import 'package:moonlight/features/livestream/data/repositories/live_session_repository_impl.dart';
import 'package:uuid/uuid.dart';
import 'package:moonlight/features/livestream/domain/entities/live_end_analytics.dart';
import 'package:moonlight/features/livestream/domain/entities/live_join_request.dart';
import 'package:moonlight/features/livestream/domain/entities/live_entities.dart';
import 'package:moonlight/features/livestream/domain/repositories/live_session_repository.dart';
import 'package:moonlight/features/livestream/domain/session/live_session_tracker.dart';

/// Live host bloc (complete file)
/// - Consolidated premium subscription (single)
/// - Guarded PremiumStatusUpdated handler (apply only for current livestream)
/// - PremiumActionFailed does not force-clear isPremium/premiumStatus (server is source-of-truth)

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

  // NEW premium fields
  final bool isPremium;
  final PremiumStatusModel? premiumStatus;
  final bool premiumActionLoading;
  final String? premiumError;

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
    this.isPremium = false,
    this.premiumStatus,
    this.premiumActionLoading = false,
    this.premiumError,
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
    bool? isPremium,
    PremiumStatusModel? premiumStatus,
    bool? premiumActionLoading,
    String? premiumError,
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
      isPremium: isPremium ?? this.isPremium,
      premiumStatus: premiumStatus ?? this.premiumStatus,
      premiumActionLoading: premiumActionLoading ?? this.premiumActionLoading,
      premiumError: premiumError ?? this.premiumError,
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
    isPremium: false,
    premiumStatus: null,
    premiumActionLoading: false,
    premiumError: null,
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

// Premium events
class ActivatePremium extends LiveHostEvent {
  final PremiumPackageModel package;
  ActivatePremium(this.package);
}

class CancelPremium extends LiveHostEvent {}

class PremiumStatusUpdated extends LiveHostEvent {
  final PremiumStatusModel payload;
  PremiumStatusUpdated(this.payload);
}

class PremiumActionFailed extends LiveHostEvent {
  final String message;
  PremiumActionFailed(this.message);
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
  StreamSubscription<PremiumStatusModel>? _premiumSub;

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

    // Only one handler for _ActiveGuestChanged
    on<_ActiveGuestChanged>((e, emit) {
      emit(state.copyWith(activeGuestUuid: e.uuid));
    });

    // Premium handlers
    on<ActivatePremium>(_onActivatePremium);
    on<CancelPremium>(_onCancelPremium);

    // Guarded PremiumStatusUpdated: only apply if it matches current livestream (when possible)
    on<PremiumStatusUpdated>((e, emit) {
      try {
        final currentId = sl<LiveSessionTracker>().current?.livestreamId;
        final payloadId = e.payload.livestreamId;
        if (payloadId != null && currentId != null && payloadId != currentId) {
          debugPrint(
            '🔕 premium event ignored (payload for other livestream): payload=$payloadId current=$currentId',
          );
          return;
        }
      } catch (ex) {
        // If tracker lookup fails, continue and apply update; log for debugging.
        debugPrint('⚠️ premium handler validation error: $ex');
      }

      debugPrint(
        '🔔 Applying premium status update: isPremium=${e.payload.isPremium} livestreamId=${e.payload.livestreamId ?? "?"}',
      );
      emit(
        state.copyWith(
          isPremium: e.payload.isPremium,
          premiumStatus: e.payload,
          premiumActionLoading: false,
          premiumError: null,
        ),
      );
    });

    // PremiumActionFailed: don't aggressively clear server state here; show error and stop loading.
    on<PremiumActionFailed>(
      (e, emit) => emit(
        state.copyWith(
          premiumActionLoading: false,
          premiumError: e.message,
          // keep isPremium/premiumStatus as-is (server push will correct if needed)
        ),
      ),
    );
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

  Future<void> _onActivatePremium(
    ActivatePremium e,
    Emitter<LiveHostState> emit,
  ) async {
    final pkg = e.package;

    // Optimistically show a pending premium badge and loading state
    final tracker = sl<LiveSessionTracker>();
    final current = tracker.current;
    final livestreamId = current?.livestreamId ?? -1;

    emit(
      state.copyWith(
        premiumActionLoading: true,
        isPremium: true,
        premiumStatus: PremiumStatusModel(
          type: 'pending',
          livestreamId: livestreamId,
          isPremium: true,
          package: PremiumPackageSummary(
            id: pkg.id,
            name: pkg.title,
            coins: pkg.coins,
          ),
        ),
        premiumError: null,
      ),
    );

    try {
      final idemp = const Uuid().v4();
      final res = await repo.activatePremium(
        livestreamId: livestreamId,
        packageId: pkg.id,
        idempotencyKey: idemp,
      );

      // server responded — update with true server value (may also be 'pending')
      emit(
        state.copyWith(
          premiumActionLoading: false,
          isPremium: res.isPremium,
          premiumStatus: res,
          premiumError: null,
        ),
      );
    } catch (err) {
      debugPrint('❌ activate premium failed: $err');
      emit(
        state.copyWith(
          premiumActionLoading: false,
          premiumError: 'Failed to activate premium',
          // keep isPremium/premiumStatus as-is (optimistic pending will be overridden by pusher if server later pushes)
        ),
      );
    }
  }

  Future<void> _onCancelPremium(
    CancelPremium e,
    Emitter<LiveHostState> emit,
  ) async {
    // show loading
    emit(state.copyWith(premiumActionLoading: true, premiumError: null));
    try {
      final idemp = const Uuid().v4();
      final livestreamId = _resolveTrackerIdFromRepo();
      final res = await repo.cancelPremium(
        livestreamId: livestreamId,
        idempotencyKey: idemp,
      );

      emit(
        state.copyWith(
          premiumActionLoading: false,
          isPremium: res.isPremium,
          premiumStatus: res,
          premiumError: null,
        ),
      );
    } catch (err) {
      debugPrint('❌ cancel premium failed: $err');
      emit(
        state.copyWith(
          premiumActionLoading: false,
          premiumError: 'Failed to cancel premium',
        ),
      );
    }
  }

  /// Resolve livestream id from repo/tracker. Throws helpful StateError if missing.
  int _resolveTrackerIdFromRepo() {
    final tracker = sl<LiveSessionTracker>();
    final current = tracker.current;
    if (current == null) {
      throw StateError('No active live session (tracker.current == null).');
    }
    return current.livestreamId;
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
    await _premiumSub?.cancel();

    // FIXED: Remove Agora listener (if attached)
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

    // ---- premium subscription (single) ----
    try {
      await _premiumSub?.cancel();
      _premiumSub = repo.premiumStatusStream().listen(
        (p) {
          debugPrint(
            '🔔 premium event in bloc (stream): isPremium=${p.isPremium} livestreamId=${p.livestreamId ?? "?"}',
          );
          add(PremiumStatusUpdated(p));
        },
        onError: (e) {
          debugPrint('⚠️ premium stream error: $e');
        },
      );
      debugPrint('✅ premiumStatusStream subscribed');
    } catch (e) {
      debugPrint('⚠️ premium subscription failed: $e');
    }

    // FIXED: Use addListener for ValueNotifier instead of stream.listen
    _setupAgoraListener();

    debugPrint('✅ All stream subscriptions setup');
  }

  // FIXED: Add methods for ValueNotifier listener management
  void _setupAgoraListener() {
    try {
      agoraService.primaryRemoteUid.addListener(_onAgoraRemoteUidChanged);
    } catch (_) {
      // ignore if not attachable
    }
  }

  void _removeAgoraListener() {
    try {
      agoraService.primaryRemoteUid.removeListener(_onAgoraRemoteUidChanged);
    } catch (_) {
      // ignore if listener wasn't attached
    }
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
    await _premiumSub?.cancel();

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
    await _premiumSub?.cancel();

    // FIXED: Remove Agora listener
    _removeAgoraListener();

    // End session idempotently; server ignores if already ended
    return super.close().whenComplete(() async {
      try {
        await repo.endSession();
      } catch (_) {}
      try {
        repo.dispose();
      } catch (_) {}
    });
  }
}
