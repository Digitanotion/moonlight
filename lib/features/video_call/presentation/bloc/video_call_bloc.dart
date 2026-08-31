// lib/features/video_call/presentation/bloc/video_call_bloc.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:moonlight/core/config/runtime_config.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/services/agora_service.dart';
import 'package:moonlight/core/services/call_kit_service.dart';
import 'package:moonlight/core/services/notification_service.dart';
import 'package:moonlight/core/services/ringtone_player.dart';
import 'package:moonlight/core/services/video_call_agora_service.dart';
import 'package:moonlight/features/video_call/data/models/video_call_session_model.dart';
import 'package:moonlight/features/video_call/domain/repositories/video_call_repository.dart';

// ===== State =====

enum VideoCallPhase {
  idle, // no call in progress
  ringingOutgoing, // I called someone, waiting for them to answer
  ringingIncoming, // someone is calling me, I haven't responded
  connecting, // accepted/joining, Agora not yet joined
  active, // Agora joined, call live
  ended, // call over, showing settlement summary
}

class VideoCallState {
  final VideoCallPhase phase;
  final VideoCallSessionModel? session;
  final bool actionLoading;
  final String? error;
  final bool showExtendPrompt; // true once remainingSeconds <= 30
  // Countdown frozen because the media connection dropped (#3). The
  // server is the source of truth (session.endsAt is pushed forward on
  // resume); this flag drives the "Reconnecting…" UI and stops the
  // client-side auto-end from firing during the freeze.
  final bool isPaused;

  /// True on the CALLER's device, false on the callee's. The paid
  /// countdown (and the client-side auto-end at zero) belongs to the
  /// caller only — the callee just talks, like a normal call.
  final bool isCaller;

  /// The call's end time re-anchored to THIS device's clock from the
  /// server's `remaining_seconds` (now + remaining), so the countdown
  /// never drifts with device-clock skew and both parties agree.
  final DateTime? localEndsAt;

  const VideoCallState({
    required this.phase,
    this.session,
    this.actionLoading = false,
    this.error,
    this.showExtendPrompt = false,
    this.isPaused = false,
    this.isCaller = false,
    this.localEndsAt,
  });

  factory VideoCallState.initial() =>
      const VideoCallState(phase: VideoCallPhase.idle);

  VideoCallState copyWith({
    VideoCallPhase? phase,
    VideoCallSessionModel? session,
    bool clearSession = false,
    bool? actionLoading,
    String? error,
    bool clearError = false,
    bool? showExtendPrompt,
    bool? isPaused,
    bool? isCaller,
    DateTime? localEndsAt,
  }) {
    return VideoCallState(
      phase: phase ?? this.phase,
      session: clearSession ? null : (session ?? this.session),
      actionLoading: actionLoading ?? this.actionLoading,
      error: clearError ? null : (error ?? this.error),
      showExtendPrompt: showExtendPrompt ?? this.showExtendPrompt,
      isPaused: isPaused ?? this.isPaused,
      isCaller: isCaller ?? this.isCaller,
      localEndsAt: localEndsAt ?? this.localEndsAt,
    );
  }

  /// Convenience: the countdown target (local, drift-free), falling back
  /// to the raw server `ends_at` if we never got a `remaining_seconds`.
  DateTime? get countdownEndsAt => localEndsAt ?? session?.endsAt;
}

// ===== Events =====

abstract class VideoCallEvent {}

/// Caller-side: start a new call.
class CallInitiateRequested extends VideoCallEvent {
  final String calleeUserSlug;
  final int minutes;
  final String initiatedFrom;
  final int? livestreamId;
  CallInitiateRequested({
    required this.calleeUserSlug,
    required this.minutes,
    required this.initiatedFrom,
    this.livestreamId,
  });
}

/// Callee-side: accept the incoming call shown on the incoming-call screen.
class CallAcceptRequested extends VideoCallEvent {
  final String sessionUuid;
  CallAcceptRequested(this.sessionUuid);
}

class CallRejectRequested extends VideoCallEvent {
  final String sessionUuid;
  CallRejectRequested(this.sessionUuid);
}

/// Caller-side: fired after receiving the 'video_call_accepted' push —
/// fetches the caller's own Agora token and joins.
class CallJoinRequested extends VideoCallEvent {
  final String sessionUuid;
  CallJoinRequested(this.sessionUuid);
}

/// Callee-side: fired when the receiver accepted via the fallback
/// notification (not CallKit's native UI or IncomingCallScreen) — the
/// actual /accept HTTP call already succeeded via that isolate's
/// guaranteed fire-and-forget path, so this does NOT call repo.accept()
/// again (which could fail as an already-accepted call). Instead it
/// fetches the current session via status() and joins Agora directly —
/// the exact same _joinAgoraFromSession() step _onAccept uses, just
/// without the redundant re-accept.
class CallResumeAfterNotificationAccept extends VideoCallEvent {
  final String sessionUuid;
  CallResumeAfterNotificationAccept(this.sessionUuid);
}

class CallExtendRequested extends VideoCallEvent {
  final int minutes;
  CallExtendRequested(this.minutes);
}

class CallEndRequested extends VideoCallEvent {
  final String? reason;
  CallEndRequested({this.reason});
}

class CallReportRequested extends VideoCallEvent {
  final String reason;
  final String? note;
  CallReportRequested({required this.reason, this.note});
}

/// Internal: fired every second while active, to recompute countdown /
/// trigger the 30s-remaining extend prompt (doc 1C).
class _CallTicked extends VideoCallEvent {}

/// Internal: the remote party's media stream dropped (`visible: false`)
/// or came back (`visible: true`) — drives the network-drop timer
/// freeze (#3). Debounced before it ever reaches the bloc.
class _RemoteMediaChanged extends VideoCallEvent {
  final bool visible;
  _RemoteMediaChanged(this.visible);
}

/// Internal: the OTHER party paused / resumed the countdown — sourced
/// from the 'video_call_paused' / 'video_call_resumed' notification.
class _CallPauseStateChanged extends VideoCallEvent {
  final Map<String, dynamic> payload;
  _CallPauseStateChanged(this.payload);
}

/// Internal: socket-driven, someone is calling me.
class _IncomingCallReceived extends VideoCallEvent {
  final Map<String, dynamic> payload;
  _IncomingCallReceived(this.payload);
}

class _CallResolvedByOtherParty extends VideoCallEvent {
  final Map<String, dynamic> payload;
  _CallResolvedByOtherParty(this.payload);
}

/// Internal: socket-driven, the person I called just accepted.
class _CallAcceptedReceived extends VideoCallEvent {
  final Map<String, dynamic> payload;
  _CallAcceptedReceived(this.payload);
}

class CallDismissed extends VideoCallEvent {} // reset to idle after viewing summary

/// Fired when the app was cold-started (or backgrounded) by tapping an
/// incoming-call push notification — the bloc's live Pusher listener never
/// saw the original 'video_call_incoming' event in that case, so this
/// fetches the session directly instead of relying on the socket payload.
class CallResumeFromNotification extends VideoCallEvent {
  final String sessionUuid;
  CallResumeFromNotification(this.sessionUuid);
}

// ===== Bloc =====

class VideoCallBloc extends Bloc<VideoCallEvent, VideoCallState> {
  final VideoCallRepository repo;
  final VideoCallAgoraService agora;
  final RuntimeConfig runtimeConfig;

  StreamSubscription<Map<String, dynamic>>? _incomingSub;
  StreamSubscription<Map<String, dynamic>>? _acceptedSub;
  StreamSubscription<Map<String, dynamic>>? _resolvedSub;
  StreamSubscription<Map<String, dynamic>>? _pauseStateSub;
  Timer? _tickTimer;
  // Network-drop watcher (#3): flips the countdown to frozen when the
  // remote video/audio stops arriving, and unfreezes it when it returns.
  Timer? _mediaDropDebounce;
  bool _remoteMediaWatcherAttached = false;
  bool _networkPauseInFlight = false;
  // Fallback for a confirmed gap: broadcasts between the two parties on
  // a call can fail to arrive via Pusher at all — first confirmed for
  // reject events reaching the caller, but the same unreliability should
  // be assumed in either direction (a caller's end/cancel reaching the
  // callee is the same class of gap). Runs whenever either party is
  // ringing/connecting/active, independent of any live event ever
  // arriving — see _startResolutionPoll's doc comment.
  Timer? _resolutionPollTimer;
  bool _isDisposed = false;

  VideoCallBloc(this.repo, this.agora, this.runtimeConfig)
    : super(VideoCallState.initial()) {
    on<CallInitiateRequested>(_onInitiate);
    on<CallAcceptRequested>(_onAccept);
    on<CallRejectRequested>(_onReject);
    on<CallJoinRequested>(_onJoin);
    on<CallResumeAfterNotificationAccept>(_onResumeAfterNotificationAccept);
    on<CallExtendRequested>(_onExtend);
    on<CallEndRequested>(_onEnd);
    on<CallReportRequested>(_onReport);
    on<_CallTicked>(_onTick);
    on<_RemoteMediaChanged>(_onRemoteMediaChanged);
    on<_CallPauseStateChanged>(_onCallPauseStateChanged);
    on<_IncomingCallReceived>(_onIncomingReceived);
    on<_CallAcceptedReceived>(_onAcceptedReceived);
    on<_CallResolvedByOtherParty>(_onResolvedByOtherParty);
    on<CallDismissed>((e, emit) => emit(VideoCallState.initial()));
    on<CallResumeFromNotification>(_onResumeFromNotification);

    // These socket streams are app-wide (the repository is a long-lived
    // singleton) — bind once here so an incoming call is caught regardless
    // of which screen is currently open.
    _incomingSub = repo.incomingCallStream().listen(
      (payload) => add(_IncomingCallReceived(payload)),
    );
    _acceptedSub = repo.callAcceptedStream().listen(
      (payload) => add(_CallAcceptedReceived(payload)),
    );
    _resolvedSub = repo.callResolvedStream().listen(
      (payload) => add(_CallResolvedByOtherParty(payload)),
    );
    _pauseStateSub = repo.callPauseStateStream().listen(
      (payload) => add(_CallPauseStateChanged(payload)),
    );
  }

  /// The other party (caller or callee) ended/rejected the call the
  /// current device is on — reuses the exact same phase transitions the
  /// LOCAL end/reject flows already use, so every screen's existing
  /// listener logic (already correct, already tested) just naturally
  /// picks this up with no new UI code needed:
  ///   - Still ringing/connecting (not yet active) -> phase: idle, with
  ///     no error, which OutgoingCallScreen/IncomingCallScreen already
  ///     auto-pop cleanly on.
  ///   - Already active -> phase: ended, which ActiveCallScreen already
  ///     listens for and pushes CallSummaryScreen on.
  Future<void> _onResolvedByOtherParty(
    _CallResolvedByOtherParty e,
    Emitter<VideoCallState> emit,
  ) async {
    final meta = (e.payload['meta'] as Map?)?.cast<String, dynamic>() ?? {};
    final resolvedUuid = (meta['session_uuid'] ?? '').toString();
    if (resolvedUuid.isEmpty) return;

    _stopResolutionPoll();

    // Dismiss CallKit's NATIVE UI unconditionally, using the uuid from
    // the event itself — NOT gated on matching local bloc state. Calls
    // shown via the native FCM background path (app was backgrounded or
    // killed) never go through _onIncomingReceived at all, so
    // state.session may be null/stale even though the native ringing
    // screen is genuinely showing right now. Gating this dismiss on a
    // local-state match (the original bug) meant exactly that case
    // silently never got dismissed.
    try {
      debugPrint('📞 [CallKit] Attempting to dismiss native UI for: $resolvedUuid');
      await CallKitService().endCall(resolvedUuid);
      debugPrint('📞 [CallKit] endCall() completed without throwing');
    } catch (err, st) {
      debugPrint('❌ [CallKit] endCall() FAILED: $err');
      debugPrint('❌ [CallKit] Stack: $st');
    }

    // Same reasoning as CallKit above — unconditional, not gated on
    // matching local state, since a call ringing purely via the
    // background isolate path never populates local state at all.
    try {
      RingtonePlayer().stop();
      NotificationService().dismissIncomingCallNotification(resolvedUuid);
    } catch (_) {}

    final currentUuid = state.session?.uuid;

    // The actual Dart-side STATE transition below still needs the match
    // — we don't want an unrelated call's resolution to corrupt this
    // device's local bloc state for a genuinely different, still-active
    // call.
    if (currentUuid == null || resolvedUuid != currentUuid) return;

    _detachRemoteMediaWatcher();

    if (state.phase == VideoCallPhase.active) {
      // Leave AND dispose — matches _onEnd exactly. Leaving alone (the
      // original version here) never released the engine's camera/mic
      // hardware locks, which is what left the feed's own video/audio
      // playback broken after a call the OTHER party ended (_onEnd's
      // own local-hangup path already did this correctly; this path,
      // for the other party hanging up, was the one place it was
      // missed). Best-effort either way, since the other party is
      // already gone.
      try {
        await agora.leave();
        await agora.disposeEngine();
      } catch (_) {}
      emit(state.copyWith(phase: VideoCallPhase.ended, actionLoading: false));
    } else {
      emit(
        state.copyWith(
          phase: VideoCallPhase.idle,
          clearError: true,
          actionLoading: false,
        ),
      );
    }
  }
  Future<void> _onInitiate(
    CallInitiateRequested e,
    Emitter<VideoCallState> emit,
  ) async {
    emit(
      state.copyWith(
        actionLoading: true,
        clearError: true,
        phase: VideoCallPhase.ringingOutgoing,
      ),
    );
    try {
      debugPrint('CALLING NOW.............................');
      final session = await repo.initiate(
        calleeUserSlug: e.calleeUserSlug,
        minutes: e.minutes,
        initiatedFrom: e.initiatedFrom,
        livestreamId: e.livestreamId,
      );
      emit(
        state.copyWith(
          actionLoading: false,
          session: session,
          phase: VideoCallPhase.ringingOutgoing,
          isCaller: true,
        ),
      );
      // Belt-and-suspenders for the exact gap just confirmed by testing:
      // the caller can go the ENTIRE ring without ever receiving the
      // Pusher event for the callee's response (accept OR reject) — no
      // client-side fix can make a socket event arrive that the backend
      // never sent, so poll status() as a fallback the live event isn't
      // required for.
      _startResolutionPoll(session.uuid);
    } catch (err) {
      emit(
        state.copyWith(
          actionLoading: false,
          error: _msg(err),
          phase: VideoCallPhase.idle,
        ),
      );
    }
  }

  Future<void> _onAccept(
    CallAcceptRequested e,
    Emitter<VideoCallState> emit,
  ) async {
    _stopResolutionPoll();
    emit(
      state.copyWith(
        actionLoading: true,
        clearError: true,
        phase: VideoCallPhase.connecting,
      ),
    );
    try {
      final session = await repo.accept(e.sessionUuid);
      await _joinAgoraFromSession(session);
      emit(
        state.copyWith(
          actionLoading: false,
          session: session,
          phase: VideoCallPhase.active,
          localEndsAt: _anchorEndsAt(session),
        ),
      );
      _startTicking();
    } catch (err) {
      emit(
        state.copyWith(
          actionLoading: false,
          error: _msg(err),
          phase: VideoCallPhase.idle,
        ),
      );
    }
  }

  /// See CallResumeAfterNotificationAccept's doc comment — the receiver
  /// already accepted via the notification's own guaranteed HTTP call,
  /// this just needs to fetch the resulting session and actually connect
  /// to Agora, without calling accept() a second time.
  Future<void> _onResumeAfterNotificationAccept(
    CallResumeAfterNotificationAccept e,
    Emitter<VideoCallState> emit,
  ) async {
    _stopResolutionPoll();
    emit(
      state.copyWith(
        actionLoading: true,
        clearError: true,
        phase: VideoCallPhase.connecting,
      ),
    );
    try {
      final session = await repo.status(e.sessionUuid);
      await _joinAgoraFromSession(session);
      emit(
        state.copyWith(
          actionLoading: false,
          session: session,
          phase: VideoCallPhase.active,
          localEndsAt: _anchorEndsAt(session),
        ),
      );
      _startTicking();
    } catch (err) {
      emit(
        state.copyWith(
          actionLoading: false,
          error: _msg(err),
          phase: VideoCallPhase.idle,
        ),
      );
    }
  }

  Future<void> _onReject(
    CallRejectRequested e,
    Emitter<VideoCallState> emit,
  ) async {
    _stopResolutionPoll();
    emit(state.copyWith(actionLoading: true, clearError: true));
    try {
      await repo.reject(e.sessionUuid);
    } catch (err) {
      debugPrint('❌ [VideoCallBloc] reject failed: $err');
    }
    emit(VideoCallState.initial());
  }

  /// Caller-side: fetch own token once notified the callee accepted.
  Future<void> _onJoin(
    CallJoinRequested e,
    Emitter<VideoCallState> emit,
  ) async {
    _stopResolutionPoll();
    emit(
      state.copyWith(
        actionLoading: true,
        clearError: true,
        phase: VideoCallPhase.connecting,
      ),
    );
    try {
      final session = await repo.join(e.sessionUuid);
      await _joinAgoraFromSession(session);
      emit(
        state.copyWith(
          actionLoading: false,
          session: session,
          phase: VideoCallPhase.active,
          localEndsAt: _anchorEndsAt(session),
        ),
      );
      _startTicking();
    } catch (err) {
      // Unlike _onAccept/_onResumeAfterNotificationAccept, this used to
      // leave `phase` at `connecting` on failure instead of resetting it.
      // With no screen open to catch it (this fires from a cold-start
      // background dispatch, not a user tap), the bloc — a global
      // singleton — got permanently wedged "busy", silently dropping
      // every subsequent incoming call for the rest of the app session.
      emit(
        state.copyWith(
          actionLoading: false,
          error: _msg(err),
          phase: VideoCallPhase.idle,
        ),
      );
    }
  }

Future<void> _joinAgoraFromSession(VideoCallSessionModel session) async {
    final creds = session.agora;
    if (creds == null || creds.token.isEmpty) {
      throw StateError('No Agora credentials in session response');
    }

    // If this call came in while the callee was actively livestreaming,
    // her device already has a separate Agora engine (AgoraService, the
    // livestream host's) connected to her stream's channel. Agora's SDK
    // only allows ONE active channel join per app process regardless of
    // how many separate Dart-level "engine" objects exist — a second,
    // independent join here gets rejected with error -17
    // (ERR_JOIN_CHANNEL_REJECTED), confirmed via real device logs. This
    // is why accept/pause/resume all worked correctly server-side, but
    // her own call screen never actually connected. Release her
    // livestream engine's channel first so this join can succeed.
    if (session.initiatedFrom == 'livestream') {
      try {
        await sl<AgoraService>().leave();
      } catch (e) {
        debugPrint('⚠️ Failed to release livestream Agora engine before call join: $e');
      }
    }

    // appId is app-wide config, not per-session — read from wherever the
    // app already stores RuntimeConfig.agoraAppId (same value used by
    // AgoraService/AgoraViewerService).
    await agora.join(
      appId: runtimeConfig.agoraAppId,
      channel: creds.channelName,
      token: creds.token,
      uid: creds.uid,
    );
  }

  Future<void> _onExtend(
    CallExtendRequested e,
    Emitter<VideoCallState> emit,
  ) async {
    final sessionUuid = state.session?.uuid;
    if (sessionUuid == null) return;
    emit(state.copyWith(actionLoading: true, clearError: true));
    try {
      final session = await repo.extend(
        sessionUuid: sessionUuid,
        minutes: e.minutes,
      );
      emit(
        state.copyWith(
          actionLoading: false,
          session: session,
          showExtendPrompt: false,
          localEndsAt: _anchorEndsAt(session),
        ),
      );
    } catch (err) {
      emit(state.copyWith(actionLoading: false, error: _msg(err)));
    }
  }

  // Confirmed by testing: _CallTicked fires every second while active, and
  // once the countdown hits zero it dispatches CallEndRequested — but
  // _onEnd doesn't move `phase` away from `active` until its network
  // round trip completes, so on a slow connection EVERY tick in that
  // window queues yet another CallEndRequested. Bloc's default sequential
  // transformer processes all of them one after another regardless of
  // the first one having already succeeded — three redundant /end
  // requests, minutes of the screen never resolving. This guard makes
  // _onEnd a no-op while one is already in flight, independent of how
  // many times it gets dispatched or from where (tick flood, an
  // impatient repeated tap, PopScope firing again — doesn't matter).
  bool _endInFlight = false;

  Future<void> _onEnd(CallEndRequested e, Emitter<VideoCallState> emit) async {
    if (_endInFlight) return;
    _endInFlight = true;
    try {
      await _doEnd(e, emit);
    } finally {
      _endInFlight = false;
    }
  }

Future<void> _doEnd(CallEndRequested e, Emitter<VideoCallState> emit) async {
    final sessionUuid = state.session?.uuid;
    // Capture this BEFORE resetting anything below — determines which
    // phase to land on once the end() call completes.
    final wasActive = state.phase == VideoCallPhase.active;
    final endingSession = state.session;
    _tickTimer?.cancel();
    _detachRemoteMediaWatcher();
    _stopResolutionPoll();
    await agora.leave();
    await agora.disposeEngine();

    // If this call happened while the callee was livestreaming, her own
    // Agora engine (AgoraService) was released before the call's engine
    // joined (see _joinAgoraFromSession). Now that the call's over,
    // reconnect her to her own stream — fetch a fresh publisher token
    // (the original one may be long expired by now) and rejoin. Wrapped
    // in try/catch: a failure here shouldn't block the call itself from
    // finishing cleanly — worst case, she has to manually restart her
    // stream, same as before this fix existed.
    if (endingSession?.initiatedFrom == 'livestream' &&
        endingSession?.livestreamId != null) {
      try {
        final res = await sl<DioClient>().dio.get(
          '/api/v1/live/${endingSession!.livestreamId}/rtc',
          queryParameters: {'role': 'publisher'},
        );
        final data = (res.data is Map) ? res.data as Map : const {};
        await sl<AgoraService>().startPublishing(
          appId: (data['app_id'] ?? '').toString(),
          channel: (data['channel'] ?? '').toString(),
          token: (data['rtc_token'] ?? '').toString(),
          uidType: 'uid',
          uid: '${data['rtc_uid'] ?? ''}',
        );
        debugPrint('✅ Rejoined livestream after call ended');
      } catch (err) {
        debugPrint('⚠️ Failed to rejoin livestream after call: $err');
      }
    }

    if (sessionUuid == null) {
      emit(VideoCallState.initial());
      return;
    }

    emit(state.copyWith(actionLoading: true, clearError: true));
    try {
      final session = await repo.end(sessionUuid: sessionUuid, reason: e.reason);
      emit(
        state.copyWith(
          actionLoading: false,
          session: session,
          // Only a call that actually connected should go to `ended`
          // (which ActiveCallScreen listens for, pushing the summary
          // screen). A call cancelled while still ringing/connecting
          // needs `idle` instead — that's what OutgoingCallScreen's
          // existing listener knows how to auto-close on. Landing on
          // `ended` unconditionally (the previous behavior) meant
          // cancelling a not-yet-connected call transitioned to a phase
          // neither screen had any handling for at all, so nothing ever
          // happened and the screen just sat there indefinitely.
          phase: wasActive ? VideoCallPhase.ended : VideoCallPhase.idle,
        ),
      );
    } catch (err) {
      // Same bug class as _onJoin's fix — leaving phase wherever it was
      // (active/connecting) on a failed end() call wedges the bloc
      // permanently, silently dropping every future incoming call under
      // the "already busy" guard for the rest of the session. The Agora
      // engine is already torn down above regardless of this call's
      // outcome, so idle is always safe to land on here.
      emit(
        state.copyWith(
          actionLoading: false,
          error: _msg(err),
          phase: VideoCallPhase.idle,
        ),
      );
    }
  }

  Future<void> _onReport(
    CallReportRequested e,
    Emitter<VideoCallState> emit,
  ) async {
    final sessionUuid = state.session?.uuid;
    if (sessionUuid == null) return;
    try {
      await repo.report(
        sessionUuid: sessionUuid,
        reason: e.reason,
        note: e.note,
      );
    } catch (err) {
      emit(state.copyWith(error: _msg(err)));
    }
  }

  void _onIncomingReceived(
    _IncomingCallReceived e,
    Emitter<VideoCallState> emit,
  ) {
    // Ignore if already on a call — backend already blocks simultaneous
    // calls server-side; this is just the client-side mirror of that rule
    // so we don't clobber an in-progress call's UI.
    if (state.phase != VideoCallPhase.idle) {
      debugPrint('📞 [VideoCallBloc] Incoming call ignored — already busy');
      return;
    }

    final meta = (e.payload['meta'] as Map?)?.cast<String, dynamic>() ?? {};
    final sessionUuid = (meta['session_uuid'] ?? '').toString();
    if (sessionUuid.isEmpty) return;

    // Build a minimal session shell from the push payload — full details
    // are fetched via status() if the incoming-call screen needs more.
    final callerName = (meta['caller_name'] ?? 'Someone').toString();
    final callerAvatar = meta['caller_avatar']?.toString();

    emit(
      state.copyWith(
        phase: VideoCallPhase.ringingIncoming,
        isCaller: false,
        session: VideoCallSessionModel(
          uuid: sessionUuid,
          status: 'ringing',
          channelName: (meta['channel_name'] ?? '').toString(),
          initiatedFrom: '',
          rateCoinsPerMinute: 0,
          totalMinutesRequested: 0,
          totalCoinsHeld: 0,
          totalCoinsSettled: 0,
          totalCoinsRefunded: 0,
          caller: VideoCallUserSummary(
            userSlug: '',
            displayName: callerName,
            avatarUrl: callerAvatar,
          ),
        ),
      ),
    );
    // See _startResolutionPoll's doc comment — the same broadcast
    // unreliability confirmed for reject-reaching-the-caller applies
    // here too: without this, a caller cancelling before this device
    // answers has no guaranteed way to close the banner/ringtone if that
    // specific event also fails to arrive.
    _startResolutionPoll(sessionUuid);
  }

  void _onAcceptedReceived(
    _CallAcceptedReceived e,
    Emitter<VideoCallState> emit,
  ) {
    final meta = (e.payload['meta'] as Map?)?.cast<String, dynamic>() ?? {};
    final sessionUuid = (meta['session_uuid'] ?? '').toString();
    if (sessionUuid.isEmpty) return;
    if (state.session?.uuid != sessionUuid) return; // not our call

    // Trigger the join flow automatically — the caller doesn't need to
    // tap anything, this push IS the "she answered" signal.
    add(CallJoinRequested(sessionUuid));
  }

  Future<void> _onResumeFromNotification(
    CallResumeFromNotification e,
    Emitter<VideoCallState> emit,
  ) async {
    // If the live socket already caught this (foreground tap on a call
    // already ringing in-state), don't clobber it with a fetch.
    if (state.phase != VideoCallPhase.idle && state.session?.uuid == e.sessionUuid) {
      return;
    }

    emit(state.copyWith(actionLoading: true, clearError: true));
    try {
      final session = await repo.status(e.sessionUuid);
      // Only take over as an incoming-call prompt if it's genuinely still
      // ringing — the caller may have hung up or it may have expired by
      // the time the user actually opened the app.
      if (session.status != 'pending' && session.status != 'ringing') {
        emit(state.copyWith(actionLoading: false));
        return;
      }
      emit(
        state.copyWith(
          actionLoading: false,
          session: session,
          phase: VideoCallPhase.ringingIncoming,
          isCaller: false,
        ),
      );
      _startResolutionPoll(e.sessionUuid);
    } catch (err) {
      emit(state.copyWith(actionLoading: false, error: _msg(err)));
    }
  }

  void _startTicking() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isDisposed) add(_CallTicked());
    });
    _attachRemoteMediaWatcher();
  }

  /// Re-anchor the call's end time to THIS device's clock using the
  /// server's `remaining_seconds` (authoritative, already excludes any
  /// paused time). Falls back to the raw server `ends_at` only if the
  /// response lacked `remaining_seconds`. Using local elapsed time from
  /// here on means the countdown can't drift with device-clock skew, and
  /// both parties — anchoring off the same server value within a second
  /// of each other — stay in sync.
  DateTime? _anchorEndsAt(VideoCallSessionModel s) {
    final r = s.remainingSeconds;
    if (r != null) return DateTime.now().add(Duration(seconds: r));
    return s.endsAt;
  }

  // ── Network-drop timer freeze (#3) ──────────────────────────────────────

  /// Grace period before a media drop is treated as "connection lost".
  /// Agora briefly reports no-video on ordinary keyframe gaps / camera
  /// toggles; we only want to pause on a genuine stall.
  static const _mediaDropGrace = Duration(seconds: 4);

  void _attachRemoteMediaWatcher() {
    if (_remoteMediaWatcherAttached) return;
    _remoteMediaWatcherAttached = true;
    agora.remoteHasVideo.addListener(_onRemoteMediaMaybeChanged);
    agora.remoteHasAudio.addListener(_onRemoteMediaMaybeChanged);
  }

  void _detachRemoteMediaWatcher() {
    if (!_remoteMediaWatcherAttached) return;
    _remoteMediaWatcherAttached = false;
    _mediaDropDebounce?.cancel();
    _mediaDropDebounce = null;
    try {
      agora.remoteHasVideo.removeListener(_onRemoteMediaMaybeChanged);
      agora.remoteHasAudio.removeListener(_onRemoteMediaMaybeChanged);
    } catch (_) {}
  }

  void _onRemoteMediaMaybeChanged() {
    if (_isDisposed || state.phase != VideoCallPhase.active) return;

    final receiving =
        agora.remoteHasVideo.value || agora.remoteHasAudio.value;

    if (receiving) {
      // Connection restored — cancel any pending pause, and if we're
      // already paused, resume immediately.
      _mediaDropDebounce?.cancel();
      _mediaDropDebounce = null;
      if (state.isPaused) add(_RemoteMediaChanged(true));
      return;
    }

    // Media stopped — wait out the grace period before pausing.
    if (_mediaDropDebounce != null || state.isPaused) return;
    _mediaDropDebounce = Timer(_mediaDropGrace, () {
      _mediaDropDebounce = null;
      if (_isDisposed || state.phase != VideoCallPhase.active) return;
      final stillDown =
          !agora.remoteHasVideo.value && !agora.remoteHasAudio.value;
      if (stillDown && !state.isPaused) add(_RemoteMediaChanged(false));
    });
  }

  Future<void> _onRemoteMediaChanged(
    _RemoteMediaChanged e,
    Emitter<VideoCallState> emit,
  ) async {
    final sessionUuid = state.session?.uuid;
    if (sessionUuid == null || state.phase != VideoCallPhase.active) return;
    if (_networkPauseInFlight) return;

    // Optimistically reflect the freeze/unfreeze so the UI reacts
    // instantly; the server round-trip reconciles session.endsAt.
    if (e.visible && !state.isPaused) return;
    if (!e.visible && state.isPaused) return;

    _networkPauseInFlight = true;
    emit(state.copyWith(isPaused: !e.visible));
    try {
      final session = e.visible
          ? await repo.resume(sessionUuid)
          : await repo.pause(sessionUuid);
      emit(state.copyWith(
        session: session,
        isPaused: session.isPaused,
        localEndsAt: _anchorEndsAt(session),
      ));
    } catch (err) {
      // A failed pause/resume must never wedge the call — fall back to
      // the true media state.
      final receiving =
          agora.remoteHasVideo.value || agora.remoteHasAudio.value;
      emit(state.copyWith(isPaused: !receiving));
      debugPrint('⚠️ [VideoCall] pause/resume failed: ${_msg(err)}');
    } finally {
      _networkPauseInFlight = false;
    }

    // Media may have flipped again while the request was in flight (that
    // event would have been dropped by the _networkPauseInFlight guard) —
    // re-evaluate so we don't get stuck out of sync with reality.
    _onRemoteMediaMaybeChanged();
  }

  Future<void> _onCallPauseStateChanged(
    _CallPauseStateChanged e,
    Emitter<VideoCallState> emit,
  ) async {
    final meta = (e.payload['meta'] as Map?)?.cast<String, dynamic>() ?? {};
    final sessionUuid = (meta['session_uuid'] ?? '').toString();
    if (sessionUuid.isEmpty || state.session?.uuid != sessionUuid) return;
    if (state.phase != VideoCallPhase.active) return;

    final paused = meta['paused'] == true ||
        (e.payload['type'] ?? '') == 'video_call_paused';

    // Pull the authoritative session so our countdown matches the
    // server's freshly-adjusted ends_at.
    try {
      final session = await repo.status(sessionUuid);
      emit(state.copyWith(
        session: session,
        isPaused: session.isPaused,
        localEndsAt: _anchorEndsAt(session),
      ));
    } catch (_) {
      emit(state.copyWith(isPaused: paused));
    }
  }

  /// Fallback for a confirmed gap: a broadcast between the two parties
  /// on a call — confirmed for reject-reaching-the-caller, and assumed
  /// unreliable in either direction — can fail to arrive via Pusher for
  /// the ENTIRE duration of the ring, leaving whichever screen is
  /// waiting (OutgoingCallScreen, or IncomingCallBanner/IncomingCallScreen
  /// on the other side) sitting there indefinitely with no live event
  /// ever telling it otherwise. No client-side fix can make a socket
  /// event arrive that the backend never actually sent — so this polls
  /// status() instead, which doesn't depend on that broadcast at all.
  /// Started from every entry point into ringingOutgoing/ringingIncoming
  /// (_onInitiate, _onIncomingReceived, _onResumeFromNotification),
  /// stopped the moment that call leaves the ring by any path — a
  /// background poll for a call the UI has already moved on from would
  /// be pure waste.
  void _startResolutionPoll(String sessionUuid) {
    _stopResolutionPoll();
    _resolutionPollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_isDisposed) return;
      try {
        final session = await repo.status(sessionUuid);

        // Timer.cancel() only stops FUTURE ticks — it can't abort a tick
        // whose callback is already mid-await when _stopResolutionPoll()
        // runs (e.g. accept happens right as a poll's repo.status() call
        // is in flight). That stale response can still land afterward.
        // Confirmed by testing TWICE now: `connecting` used to be
        // included below on the theory that it's also "still waiting" —
        // but `connecting` is exactly the narrow instant _onAccept/_onJoin
        // call _stopResolutionPoll(), i.e. exactly the race window this
        // guard exists for. Trusting a stale poll response during it
        // meant a stale tick could fire _CallResolvedByOtherParty (tearing
        // down the Agora engine) the instant EITHER side taps Accept —
        // both screens disappearing right as the call connects. Only
        // ringingOutgoing/ringingIncoming are phases where the poll is
        // actually the intended safety net; by `connecting`,
        // _onResolvedByOtherParty's own live-event path (which has its
        // own session-match check) is the real safety net, not this poll.
        final stillWaiting = const {
          VideoCallPhase.ringingOutgoing,
          VideoCallPhase.ringingIncoming,
        }.contains(state.phase);
        final stillSameSession = state.session?.uuid == sessionUuid || state.session == null;
        if (!stillWaiting || !stillSameSession) return;

        if (session.status == 'active') {
          // The callee accepted, but 'video_call_accepted' never arrived
          // either — same gap, self-heal the same way that event would
          // have: join directly.
          if (state.phase == VideoCallPhase.ringingOutgoing) {
            add(CallJoinRequested(sessionUuid));
          }
        } else if (const {
          'rejected',
          'no_answer',
          'cancelled',
          'completed',
        }.contains(session.status)) {
          // Reuse the exact same cleanup _onResolvedByOtherParty already
          // does for a live event — CallKit dismiss, ringtone stop,
          // notification dismiss, phase transition — rather than
          // duplicating any of it here.
          add(
            _CallResolvedByOtherParty({
              'meta': {'session_uuid': sessionUuid},
            }),
          );
        }
      } catch (_) {
        // Transient network hiccup — next tick retries. Never tear
        // anything down over a single failed poll.
      }
    });
  }

  void _stopResolutionPoll() {
    _resolutionPollTimer?.cancel();
    _resolutionPollTimer = null;
  }

  void _onTick(_CallTicked e, Emitter<VideoCallState> emit) {
    final session = state.session;
    if (session == null || state.phase != VideoCallPhase.active) return;

    final endsAt = state.countdownEndsAt;
    if (endsAt == null) return;

    // Countdown is frozen while the connection is down (#3). The server
    // pushes ends_at forward on resume, so we simply skip every tick's
    // countdown/auto-end logic until then.
    if (state.isPaused) return;

    // The paid countdown — and the auto-end at zero — belong to the
    // CALLER only. The callee just talks; the server's per-minute sweep
    // is the authoritative backstop that ends the call for both.
    if (!state.isCaller) return;

    final remaining = endsAt.difference(DateTime.now()).inSeconds;

    // 30-second extend prompt (doc 1C). Only fire once per crossing, not
    // every tick, to avoid re-showing a dismissed prompt every second.
    final shouldShowPrompt = remaining <= 30 && remaining > 0;
    if (shouldShowPrompt != state.showExtendPrompt) {
      emit(state.copyWith(showExtendPrompt: shouldShowPrompt));
    }

    if (remaining <= 0) {
      // Timer hit zero client-side — tell the server. It independently
      // verifies elapsed time before honoring this, never trusts the
      // client's clock blindly (see VideoCallService::end()).
      add(CallEndRequested(reason: 'timer_elapsed'));
    }
  }

  String _msg(Object err) {
    if (err is DioException) {
      var d = err.response?.data;
      // Some error responses arrive as an unparsed JSON string.
      if (d is String && d.trim().startsWith('{')) {
        try {
          d = jsonDecode(d);
        } catch (_) {}
      }
      if (d is Map) {
        final message = d['message'];
        if (message is String && message.trim().isNotEmpty) return message;
        // Laravel validation shape: { errors: { field: [msg, ...] } }
        final errors = d['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) return '${first.first}';
          if (first is String && first.isNotEmpty) return first;
        }
      }
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Future<void> close() async {
    _isDisposed = true;
    _tickTimer?.cancel();
    _detachRemoteMediaWatcher();
    _stopResolutionPoll();
    await _incomingSub?.cancel();
    await _acceptedSub?.cancel();
    await _resolvedSub?.cancel();
    await _pauseStateSub?.cancel();
    // Deliberately NOT disposing `repo` here — it's an app-wide singleton,
    // shared across every screen, not owned by this bloc instance.
    try {
      await agora.leave();
      await agora.disposeEngine();
    } catch (_) {}
    agora.dispose();
    return super.close();
  }
}