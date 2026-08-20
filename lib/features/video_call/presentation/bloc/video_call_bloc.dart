// lib/features/video_call/presentation/bloc/video_call_bloc.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:moonlight/core/config/runtime_config.dart';
import 'package:moonlight/core/services/call_kit_service.dart';
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

  const VideoCallState({
    required this.phase,
    this.session,
    this.actionLoading = false,
    this.error,
    this.showExtendPrompt = false,
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
  }) {
    return VideoCallState(
      phase: phase ?? this.phase,
      session: clearSession ? null : (session ?? this.session),
      actionLoading: actionLoading ?? this.actionLoading,
      error: clearError ? null : (error ?? this.error),
      showExtendPrompt: showExtendPrompt ?? this.showExtendPrompt,
    );
  }
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
  Timer? _tickTimer;
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

    final currentUuid = state.session?.uuid;

    // The actual Dart-side STATE transition below still needs the match
    // — we don't want an unrelated call's resolution to corrupt this
    // device's local bloc state for a genuinely different, still-active
    // call.
    if (currentUuid == null || resolvedUuid != currentUuid) return;

    if (state.phase == VideoCallPhase.active) {
      // Try to leave the Agora channel gracefully — best-effort, since
      // the other party is already gone either way.
      try {
        await agora.leave();
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
        ),
      );
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
        ),
      );
      _startTicking();
    } catch (err) {
      emit(state.copyWith(actionLoading: false, error: _msg(err)));
    }
  }

  Future<void> _joinAgoraFromSession(VideoCallSessionModel session) async {
    final creds = session.agora;
    if (creds == null || creds.token.isEmpty) {
      throw StateError('No Agora credentials in session response');
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
        ),
      );
    } catch (err) {
      emit(state.copyWith(actionLoading: false, error: _msg(err)));
    }
  }

  Future<void> _onEnd(CallEndRequested e, Emitter<VideoCallState> emit) async {
    final sessionUuid = state.session?.uuid;
    // Capture this BEFORE resetting anything below — determines which
    // phase to land on once the end() call completes.
    final wasActive = state.phase == VideoCallPhase.active;
    _tickTimer?.cancel();
    await agora.leave();
    await agora.disposeEngine();

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
      emit(state.copyWith(actionLoading: false, error: _msg(err)));
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
        ),
      );
    } catch (err) {
      emit(state.copyWith(actionLoading: false, error: _msg(err)));
    }
  }

  void _startTicking() {
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isDisposed) add(_CallTicked());
    });
  }

  void _onTick(_CallTicked e, Emitter<VideoCallState> emit) {
    final session = state.session;
    if (session == null || state.phase != VideoCallPhase.active) return;
    if (session.endsAt == null) return;

    final remaining = session.endsAt!.difference(DateTime.now()).inSeconds;

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
      final d = err.response?.data;
      if (d is Map && d['message'] is String) return d['message'] as String;
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Future<void> close() async {
    _isDisposed = true;
    _tickTimer?.cancel();
    await _incomingSub?.cancel();
    await _acceptedSub?.cancel();
    await _resolvedSub?.cancel();
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