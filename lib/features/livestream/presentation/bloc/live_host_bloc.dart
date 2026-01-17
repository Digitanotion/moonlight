// FILE: lib/features/livestream/presentation/bloc/live_host_bloc.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

/// Live host bloc with proper subscription lifecycle management
/// - Fixed stream controller state management
/// - Proper cleanup sequencing
/// - Robust error handling

const _kPrefFaceEnabled = 'beauty_face_enabled';
const _kPrefFaceLevel = 'beauty_face_level';
const _kPrefBrightEnabled = 'beauty_bright_enabled';
const _kPrefBrightLevel = 'beauty_bright_level';

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
  final String? activeGuestName;

  // NEW (gift toast)
  final GiftEvent? gift;
  final bool showGiftToast;

  // NEW premium fields
  final bool isPremium;
  final PremiumStatusModel? premiumStatus;
  final bool premiumActionLoading;
  final String? premiumError;

  // NEW beauty fields (persisted)
  final bool faceCleanEnabled;
  final int faceCleanLevel; // 0..100
  final bool brightenEnabled;
  final int brightenLevel; // 0..100

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
    this.activeGuestName,
    this.isPremium = false,
    this.premiumStatus,
    this.premiumActionLoading = false,
    this.premiumError,
    this.faceCleanEnabled = false,
    this.faceCleanLevel = 40,
    this.brightenEnabled = false,
    this.brightenLevel = 40,
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
    String? activeGuestName,
    bool? isPremium,
    PremiumStatusModel? premiumStatus,
    bool? premiumActionLoading,
    String? premiumError,
    // beauty fields
    bool? faceCleanEnabled,
    int? faceCleanLevel,
    bool? brightenEnabled,
    int? brightenLevel,
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
      activeGuestName: activeGuestName ?? this.activeGuestName,
      isPremium: isPremium ?? this.isPremium,
      premiumStatus: premiumStatus ?? this.premiumStatus,
      premiumActionLoading: premiumActionLoading ?? this.premiumActionLoading,
      premiumError: premiumError ?? this.premiumError,
      faceCleanEnabled: faceCleanEnabled ?? this.faceCleanEnabled,
      faceCleanLevel: faceCleanLevel ?? this.faceCleanLevel,
      brightenEnabled: brightenEnabled ?? this.brightenEnabled,
      brightenLevel: brightenLevel ?? this.brightenLevel,
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
    chatVisible: false,
    pendingRequest: null,
    gift: null,
    showGiftToast: false,
    endAnalytics: null,
    activeGuestUuid: null,
    activeGuestName: null,
    isPremium: false,
    premiumStatus: null,
    premiumActionLoading: false,
    premiumError: null,
    // beauty defaults (will be overwritten by prefs if present)
    faceCleanEnabled: false,
    faceCleanLevel: 40,
    brightenEnabled: false,
    brightenLevel: 40,
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
class HideGiftToast extends LiveHostEvent {}

class _ActiveGuestChanged extends LiveHostEvent {
  final String? uuid;
  final String? name;
  _ActiveGuestChanged(this.uuid, this.name);
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

// ===== Beauty persistence events =====
class LoadBeautyPreferences extends LiveHostEvent {}

class BeautyPreferencesUpdated extends LiveHostEvent {
  final bool faceCleanEnabled;
  final int faceCleanLevel;
  final bool brightenEnabled;
  final int brightenLevel;

  BeautyPreferencesUpdated({
    required this.faceCleanEnabled,
    required this.faceCleanLevel,
    required this.brightenEnabled,
    required this.brightenLevel,
  });
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

  // Internal: whether we've applied beauty prefs after join
  bool _beautyAppliedAfterJoin = false;
  bool _isDisposed = false;

  LiveHostBloc(this.repo, this.agoraService)
    : super(LiveHostState.initial('')) {
    on<LiveStarted>(_onStart);
    on<LiveTick>(_onTick);

    on<ViewerCountUpdated>((e, emit) {
      debugPrint('🎯 [BLOC] ViewerCountUpdated event received: ${e.viewers}');
      debugPrint('🎯 [BLOC] Previous viewers: ${state.viewers}');
      emit(state.copyWith(viewers: e.viewers));
      debugPrint('✅ [BLOC] Viewers updated in state');
    });
    on<IncomingMessage>((e, emit) {
      debugPrint(
        '🎯 [BLOC] IncomingMessage event received: ${e.message.handle}: ${e.message.text}',
      );
      debugPrint('🎯 [BLOC] Current messages count: ${state.messages.length}');
      emit(state.copyWith(messages: [...state.messages, e.message]));
      debugPrint('✅ [BLOC] Message added to state');
    });

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
      debugPrint('🎁 [BLOC] Processing GiftArrived event');
      debugPrint('🎁 [BLOC] Gift: ${e.gift.giftName} from ${e.gift.from}');
      emit(state.copyWith(gift: e.gift, showGiftToast: true));
      _autoHide(() => add(HideGiftToast()));
    });

    on<LiveEndedReceived>((e, emit) async {
      if (_isDisposed) return;
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
    on<HideGiftToast>((e, emit) => emit(state.copyWith(showGiftToast: false)));

    // Only one handler for _ActiveGuestChanged
    on<_ActiveGuestChanged>((e, emit) {
      emit(state.copyWith(activeGuestUuid: e.uuid, activeGuestName: e.name));
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

    // Beauty prefs events
    on<LoadBeautyPreferences>(_onLoadBeautyPreferences);
    on<BeautyPreferencesUpdated>(_onBeautyPreferencesUpdated);
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
      // Restart streams before starting the session
      await repo.restartStreams();

      // Then start the session
      await repo.startSession(topic: e.topic);
      debugPrint('✅ Live session started successfully');
    } catch (error) {
      debugPrint('❌ Failed to start live session: $error');
      emit(state.copyWith(isLive: false));
      return;
    }

    // Load persisted beauty preferences and setup subscriptions
    add(LoadBeautyPreferences());
    // IMPORTANT: Clean up old subscriptions first
    // await _cleanupSubscriptions();
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
            coins: pkg.coins as int,
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
        packageName: pkg.title,
        coins: pkg.coins.toString(),
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

  Future<void> _onLoadBeautyPreferences(
    LoadBeautyPreferences e,
    Emitter<LiveHostState> emit,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final faceEnabled = prefs.getBool(_kPrefFaceEnabled) ?? false;
      final faceLevel = prefs.getInt(_kPrefFaceLevel) ?? 40;
      final brightEnabled = prefs.getBool(_kPrefBrightEnabled) ?? false;
      final brightLevel = prefs.getInt(_kPrefBrightLevel) ?? 40;

      emit(
        state.copyWith(
          faceCleanEnabled: faceEnabled,
          faceCleanLevel: faceLevel,
          brightenEnabled: brightEnabled,
          brightenLevel: brightLevel,
        ),
      );

      // Try to apply immediately if Agora is joined; otherwise _onAgoraChanged will apply when joined.
      await _applyBeautyFromStateIfReady();
    } catch (err) {
      debugPrint('⚠️ failed to load beauty prefs: $err');
      // keep defaults
    }
  }

  Future<void> _onBeautyPreferencesUpdated(
    BeautyPreferencesUpdated e,
    Emitter<LiveHostState> emit,
  ) async {
    final faceEnabled = e.faceCleanEnabled;
    final faceLevel = e.faceCleanLevel.clamp(0, 100);
    final brightEnabled = e.brightenEnabled;
    final brightLevel = e.brightenLevel.clamp(0, 100);

    emit(
      state.copyWith(
        faceCleanEnabled: faceEnabled,
        faceCleanLevel: faceLevel,
        brightenEnabled: brightEnabled,
        brightenLevel: brightLevel,
      ),
    );

    // persist
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefFaceEnabled, faceEnabled);
      await prefs.setInt(_kPrefFaceLevel, faceLevel);
      await prefs.setBool(_kPrefBrightEnabled, brightEnabled);
      await prefs.setInt(_kPrefBrightLevel, brightLevel);
    } catch (err) {
      debugPrint('⚠️ failed to persist beauty prefs: $err');
    }

    // apply immediately if possible
    await _applyBeautyFromStateIfReady();
  }

  Future<void> _applyBeautyFromStateIfReady() async {
    if (_isDisposed) return;

    // If Agora is joined, apply immediately. Otherwise wait for join.
    try {
      if (agoraService.joined) {
        // call AgoraService to apply
        await agoraService.applyBeauty(
          faceCleanEnabled: state.faceCleanEnabled,
          faceCleanLevel: state.faceCleanLevel,
          brightenEnabled: state.brightenEnabled,
          brightenLevel: state.brightenLevel,
        );
        _beautyAppliedAfterJoin = true;
      } else {
        _beautyAppliedAfterJoin = false;
        if (kDebugMode)
          debugPrint('[Beauty] Agora not joined yet; will apply on join');
      }
    } catch (err) {
      debugPrint('⚠️ failed to apply beauty options to Agora: $err');
    }
  }

  Future<void> _setupStreamSubscriptions() async {
    if (_isDisposed) return;

    // Cancel existing subscriptions first
    await _cleanupSubscriptions();

    // Setup new subscriptions with error handling
    try {
      _vSub = repo.viewersStream().listen(
        (v) {
          if (!_isDisposed) {
            debugPrint('👥 Viewer count update: $v');
            add(ViewerCountUpdated(v));
          }
        },
        onError: (e) {
          debugPrint('❌ Viewer stream error: $e');
        },
      );

      _cSub = repo.chatStream().listen(
        (m) {
          if (!_isDisposed) {
            debugPrint('💬 Chat message received');
            add(IncomingMessage(m));
          }
        },
        onError: (e) {
          debugPrint('❌ Chat stream error: $e');
        },
      );

      _rSub = repo.joinRequestStream().listen(
        (r) {
          if (!_isDisposed) {
            debugPrint('🙋 Join request received');
            add(IncomingJoinRequest(r));
          }
        },
        onError: (e) {
          debugPrint('❌ Join request stream error: $e');
        },
      );

      _pSub = repo.pauseStream().listen(
        (p) {
          if (!_isDisposed) {
            debugPrint('⏸️ Pause status: $p');
            add(PauseStatusChanged(p));
          }
        },
        onError: (e) {
          debugPrint('❌ Pause stream error: $e');
        },
      );

      _gSub = repo.giftsStream().listen(
        (g) {
          if (!_isDisposed) {
            debugPrint('🎁 [BLOC] Gift received: ${g.giftName} from ${g.from}');
            debugPrint('🎁 [BLOC] Gift details: id=${g.id}, coins=${g.coins}');
            add(GiftArrived(g));
          }
        },
        onError: (e) {
          debugPrint('❌ [BLOC] Gift stream error: $e');
        },
        onDone: () {
          debugPrint('✅ [BLOC] Gift stream completed');
        },
        cancelOnError: false,
      );

      _eSub = repo.endedStream().listen(
        (_) {
          debugPrint('🔴 Live ended event received');
          // add(LiveEndedReceived());
        },
        onError: (e) {
          debugPrint('❌ Ended stream error: $e');
        },
      );

      _jhSub = repo.joinHandledStream().listen(
        (j) {
          if (!_isDisposed) {
            debugPrint('✅ Join handled: ${j.accepted}');
            add(JoinHandledReceived(j));
          }
        },
        onError: (e) {
          debugPrint('❌ Join handled stream error: $e');
        },
      );

      _guestSub = repo.activeGuestUuidStream().listen(
        (uuid) {
          if (!_isDisposed) {
            debugPrint('🎥 Active guest UUID (host view): $uuid');
            add(_ActiveGuestChanged(uuid, 'Guest'));
          }
        },
        onError: (e) {
          debugPrint('❌ Active guest stream error: $e');
        },
      );

      // Premium subscription
      _premiumSub = repo.premiumStatusStream().listen(
        (p) {
          if (!_isDisposed) {
            debugPrint(
              '🔔 premium event in bloc (stream): isPremium=${p.isPremium} livestreamId=${p.livestreamId ?? "?"}',
            );
            add(PremiumStatusUpdated(p));
          }
        },
        onError: (e) {
          debugPrint('⚠️ premium stream error: $e');
        },
      );

      debugPrint('✅ All stream subscriptions setup');
    } catch (e) {
      debugPrint('❌ Failed to setup stream subscriptions: $e');
    }

    // Add Agora listener for join changes
    _setupAgoraListener();
  }

  Future<void> _cleanupSubscriptions() async {
    await _vSub?.cancel();
    await _cSub?.cancel();
    await _rSub?.cancel();
    await _pSub?.cancel();
    await _gSub?.cancel();
    await _eSub?.cancel();
    await _jhSub?.cancel();
    await _guestSub?.cancel();
    await _premiumSub?.cancel();

    _vSub = null;
    _cSub = null;
    _rSub = null;
    _pSub = null;
    _gSub = null;
    _eSub = null;
    _jhSub = null;
    _guestSub = null;
    _premiumSub = null;

    _removeAgoraListener();
  }

  void _setupAgoraListener() {
    try {
      agoraService.primaryRemoteUid.addListener(_onAgoraRemoteUidChanged);
      agoraService.addListener(_onAgoraChanged);
      debugPrint('✅ Agora listeners added');
    } catch (e) {
      debugPrint('⚠️ Failed to add Agora listeners: $e');
    }
  }

  void _removeAgoraListener() {
    try {
      agoraService.primaryRemoteUid.removeListener(_onAgoraRemoteUidChanged);
      agoraService.removeListener(_onAgoraChanged);
      debugPrint('✅ Agora listeners removed');
    } catch (e) {
      debugPrint('⚠️ Failed to remove Agora listeners: $e');
    }
  }

  void _onAgoraRemoteUidChanged() {
    if (_isDisposed) return;
    final remoteUid = agoraService.primaryRemoteUid.value;
    debugPrint('🎥 Agora primary remote UID changed: $remoteUid');
  }

  void _onAgoraChanged() {
    if (_isDisposed) return;
    try {
      if (agoraService.joined && !_beautyAppliedAfterJoin) {
        _applyBeautyFromStateIfReady();
      }
    } catch (e) {
      debugPrint('⚠️ error in agora change handler: $e');
    }
  }

  void _onTick(LiveTick e, Emitter<LiveHostState> emit) {
    if (!state.isPaused && !_isDisposed) {
      emit(state.copyWith(elapsedSeconds: state.elapsedSeconds + 1));
    }
  }

  Future<void> _onTogglePause(
    TogglePause e,
    Emitter<LiveHostState> emit,
  ) async {
    if (_isDisposed) return;

    final next = !state.isPaused;
    emit(state.copyWith(isPaused: next)); // optimistic
    repo.setLocalPause(next); // instant local mute
    await repo.togglePause(); // server will broadcast too
  }

  Future<void> _onEnd(EndPressed e, Emitter<LiveHostState> emit) async {
    if (_isDisposed) return;

    try {
      debugPrint('🔄 Ending live session...');

      // 1) Call server to end + get analytics
      final analytics = await repo.endAndFetchAnalytics();

      debugPrint('✅ Analytics received: ${analytics.status}');

      // 2) Clean up bloc subscriptions but DON'T dispose the repo
      await _cleanupSubscriptions();

      // Cancel timer
      _timer?.cancel();
      _timer = null;

      // 3) Update state
      emit(state.copyWith(isLive: false, endAnalytics: analytics));

      debugPrint('✅ Live session ended successfully');
    } catch (error, stack) {
      debugPrint('❌ Error ending live stream: $error');
      debugPrint('Stack trace: $stack');

      // Still attempt to cleanup
      await _cleanupSubscriptions();
      _timer?.cancel();
      _timer = null;

      // Update state to show ended even on error
      emit(
        state.copyWith(
          isLive: false,
          endAnalytics: LiveEndAnalytics(
            status: 'error',
            endedAtIso: DateTime.now().toUtc().toIso8601String(),
            durationFormatted: '00:00:00',
            durationSeconds: 0.0,
            totalViewers: 0,
            totalChats: 0,
            coinsAmount: 0,
            coinsCurrency: 'coins',
          ),
        ),
      );
    }
  }

  Future<void> _onAccept(
    AcceptJoinRequest e,
    Emitter<LiveHostState> emit,
  ) async {
    if (_isDisposed) return;
    await repo.acceptJoinRequest(e.id);
    // Do not clear immediately; wait for server echo (join.handled)
  }

  Future<void> _onDecline(
    DeclineJoinRequest e,
    Emitter<LiveHostState> emit,
  ) async {
    if (_isDisposed) return;
    await repo.declineJoinRequest(e.id);
    // Also wait for echo to clear
  }

  void _autoHide(void Function() cb) {
    if (_isDisposed) return;
    Future.delayed(const Duration(seconds: 4), cb);
  }

  Future<void> _cleanDown() async {
    _timer?.cancel();
    _timer = null;

    await _cleanupSubscriptions();
    await repo.endSession(); // idempotent
  }

  @override
  Future<void> close() async {
    _isDisposed = true;

    _timer?.cancel();
    _timer = null;

    await _cleanupSubscriptions();

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
