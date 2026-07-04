// lib/core/services/agora_engine_pool.dart
//
// ═══════════════════════════════════════════════════════════════════════
// ARCHITECTURE — single RtcEngineEx, three fixed-uid RtcConnections
// ═══════════════════════════════════════════════════════════════════════
//
// ROOT CAUSE OF THE PREVIOUS DESIGN'S FAILURE:
//   Agora's native SDK enforces a hard limit of ONE RtcEngine instance
//   per running app process — confirmed from Agora's own API docs:
//   "The SDK only supports creating one RtcEngine instance per App."
//   The previous version of this pool created THREE separate RtcEngine
//   instances. It appeared to work in isolated tests but broke
//   decisively once a FOURTH engine (the co-host's publish engine in
//   AgoraViewerService) tried to join concurrently — rejected with -17
//   regardless of uid, because the rejection is a native one-engine
//   constraint, not a channel/uid collision.
//
// THE FIX — Agora's documented multi-channel pattern:
//   Exactly ONE RtcEngineEx. Multiple concurrent channel joins via
//   joinChannelEx(), each identified by a distinct, PERMANENT
//   RtcConnection(channelId, localUid). Events are routed by matching
//   the RtcConnection on each callback, not by engine instance.
//
// KEY DESIGN DECISION: the uid for each of the 3 connection "identities"
// is FIXED FOR THE IDENTITY'S LIFETIME, not derived from its current
// position label (previous/current/next). This is essential — Agora
// does not allow renaming an active connection's uid in place, so if
// uid were tied to position, "next becomes current" on rotation would
// force a full leave+rejoin every single swipe, destroying the whole
// point of pre-joining. Instead: 3 permanent connection identities
// (fixed uids), each carrying its own joined-or-not state and channel.
// Rotation simply RELABELS which identity currently plays the
// "previous/current/next" ROLE — mirroring how the original pool
// design rotated RtcEngine object references, applied here to
// RtcConnection identities instead.

import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';

enum SlotPosition { previous, current, next }

enum SlotJoinState { unavailable, idle, joining, joined, leaving }

enum SlotEventKind {
  joining,
  joined,
  hostUidReady,
  videoReady,
  leftChannel,
  joinFailed,
}

class SlotEvent {
  const SlotEvent({
    required this.position,
    required this.epoch,
    required this.kind,
  });

  final SlotPosition position;
  final int epoch;
  final SlotEventKind kind;

  @override
  String toString() => 'SlotEvent($position, epoch=$epoch, $kind)';
}

class StreamJoinRequest {
  const StreamJoinRequest({
    required this.livestreamParam,
    required this.appId,
    required this.channel,
    required this.rtcUid,
    required this.rtcToken,
  });

  final String livestreamParam;
  final String appId;
  final String channel;
  final String rtcUid; // backend-issued uid — informational only here
  final String rtcToken;
}

// ─────────────────────────────────────────────────────────────────────────────
// EngineSlot — a PERMANENT connection identity with a fixed uid. Its
// `currentPosition` (which role it's currently playing) rotates; its
// `fixedLocalUid` never changes for the lifetime of the pool.
// ─────────────────────────────────────────────────────────────────────────────

class EngineSlot {
  EngineSlot({
    required SlotPosition initialPosition,
    required this.fixedLocalUid,
  }) : currentPosition = initialPosition;

  /// MUTABLE — which logical role (previous/current/next) this
  /// connection identity is currently playing. Updated on every
  /// rotation. Determines video-quality preference and which slot
  /// PoolVideoView/listeners should treat as "the visible one."
  SlotPosition currentPosition;

  /// IMMUTABLE — this connection's uid for its entire lifetime. Never
  /// changes, regardless of which position it's currently labeled as.
  /// This is what makes rotation cheap: relabeling currentPosition does
  /// NOT require leaving/rejoining, because the uid (and therefore the
  /// RtcConnection identity) never changes.
  final int fixedLocalUid;

  /// Bumped on every new join attempt. Stale-callback guard.
  int epoch = 0;

  SlotJoinState state = SlotJoinState.idle;
  String? channelId;
  String? livestreamParam;
  int? activeLocalUid; // the actual uid used in the current joinChannelEx call

  final ValueNotifier<int?> hostUid = ValueNotifier<int?>(null);
  final ValueNotifier<bool> hasVideo = ValueNotifier<bool>(false);

  void resetForNewJoin() {
    epoch++;
    state = SlotJoinState.idle;
    activeLocalUid = null;
    hostUid.value = null;
    hasVideo.value = false;
  }

  void markUnavailable() {
    epoch++;
    state = SlotJoinState.unavailable;
    channelId = null;
    livestreamParam = null;
    activeLocalUid = null;
    hostUid.value = null;
    hasVideo.value = false;
  }

  void softReset() {
    channelId = null;
    livestreamParam = null;
    activeLocalUid = null;
    hostUid.value = null;
    hasVideo.value = false;
    if (state != SlotJoinState.unavailable) state = SlotJoinState.idle;
  }

  void dispose() {
    hostUid.dispose();
    hasVideo.dispose();
  }

  /// The RtcConnection this identity represents, if currently joined or
  /// joining to a channel. uid is always fixedLocalUid — never derived
  /// from position.
  RtcConnection? get connection {
    if (channelId == null || activeLocalUid == null) return null;
    return RtcConnection(channelId: channelId, localUid: activeLocalUid);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AgoraEnginePool
// ─────────────────────────────────────────────────────────────────────────────

class AgoraEnginePool {
  AgoraEnginePool();

  late final RtcEngineEx _engine;

  // Three PERMANENT connection identities. Each keeps the SAME uid for
  // the pool's entire lifetime. Rotation only ever changes which one is
  // labeled previous/current/next — never their uid, never which
  // RtcConnection object they represent once joined.
  late final EngineSlot _identityA;
  late final EngineSlot _identityB;
  late final EngineSlot _identityC;

  final Map<SlotPosition, EngineSlot> _map = {};

  final StreamController<SlotEvent> _eventsCtrl =
      StreamController<SlotEvent>.broadcast();
  Stream<SlotEvent> get events => _eventsCtrl.stream;

  bool _initialized = false;
  bool _engineContextReady = false;
  bool _disposed = false;
  bool _backgrounded = false;

  /// Called when a second remote uid joins the current slot's channel.
  /// Used to propagate guest/co-host uid to AgoraViewerService for rendering.
  void Function(int guestUid)? _onGuestUidChanged;

  void setGuestUidCallback(void Function(int) cb) {
    _onGuestUidChanged = cb;
  }

  Future<void>? _rotationInFlight;
  int? _latestRequestedIndex;
  int _currentIndex = 0;

  /// Reserved uid offset for AgoraViewerService's co-host publish
  /// connection — exposed so it can pick a uid guaranteed not to
  /// collide with any of this pool's 3 fixed identities.
  static const int coHostPublishUidOffset = 900000;

  EngineSlot? slotFor(SlotPosition position) => _map[position];

  /// Exposes the single shared engine so AgoraViewerService can publish
  /// through the SAME RtcEngineEx instance — required, since Agora only
  /// allows one engine per app.
  RtcEngineEx get sharedEngine {
    if (!_initialized) {
      throw StateError('AgoraEnginePool.initialize() must be called first');
    }
    return _engine;
  }

  bool get isInitialized => _initialized;

  // ── Initialization ────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _engine = createAgoraRtcEngineEx();

    // Fixed, permanent uids — never change for these identities' whole
    // lifetime. Arbitrary but disjoint from each other and from
    // coHostPublishUidOffset. If your backend already issues large
    // numeric uids that could plausibly collide with these, adjust the
    // offsets below to a range your backend never uses.
    _identityA = EngineSlot(
      initialPosition: SlotPosition.previous,
      fixedLocalUid: 100001,
    );
    _identityB = EngineSlot(
      initialPosition: SlotPosition.current,
      fixedLocalUid: 100002,
    );
    _identityC = EngineSlot(
      initialPosition: SlotPosition.next,
      fixedLocalUid: 100003,
    );

    _map[SlotPosition.previous] = _identityA;
    _map[SlotPosition.current] = _identityB;
    _map[SlotPosition.next] = _identityC;

    debugPrint('🏊 [Pool] Single RtcEngineEx created (3 fixed-uid identities)');
  }

  Future<void> _ensureEngineContext(String appId) async {
    if (_engineContextReady) return;

    await _engine.initialize(
      RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );
    await _engine.setDefaultAudioRouteToSpeakerphone(true);
    await _engine.enableAudio();
    await _engine.enableVideo();

    _engine.registerEventHandler(_buildEventHandler());

    _engineContextReady = true;
    debugPrint('🔧 [Pool] Engine context initialized, handler registered');
  }

  // ── Event handler — routes by RtcConnection (channelId+uid) ────────────────

  RtcEngineEventHandler _buildEventHandler() {
    return RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        if (_disposed) return;
        final slot = _identityForConnection(connection);
        if (slot == null) return;
        debugPrint(
          '✅ [Pool/${slot.currentPosition.name}] joined '
          'ch=${connection.channelId} uid=${connection.localUid}',
        );
        if (slot.state != SlotJoinState.unavailable) {
          slot.state = SlotJoinState.joined;
        }
        _emit(slot, SlotEventKind.joined);
      },

      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        if (_disposed) return;
        final slot = _identityForConnection(connection);
        if (slot == null) return;
        // Accept the first remote uid as the host regardless of whether
        // this is a fresh join or the host was already in the channel.
        // Agora fires onUserJoined for pre-existing participants too.
        if (slot.hostUid.value == null) {
          slot.hostUid.value = remoteUid;
          debugPrint(
            '👤 [Pool/${slot.currentPosition.name}] hostUid=$remoteUid',
          );
          _emit(slot, SlotEventKind.hostUidReady);
        } else if (slot.currentPosition == SlotPosition.current &&
            slot.hostUid.value != remoteUid) {
          // A second remote uid joined the current channel — this is the
          // co-host/guest. Notify AgoraViewerService so it can render
          // the guest video in DynamicSplitScreen.
          debugPrint(
            '👥 [Pool/current] guestUid=$remoteUid (second remote in channel)',
          );
          _onGuestUidChanged?.call(remoteUid);
        }
      },

      onRemoteVideoStateChanged:
          (
            RtcConnection connection,
            int uid,
            RemoteVideoState state,
            RemoteVideoStateReason reason,
            int elapsed,
          ) {
            if (_disposed) return;
            final slot = _identityForConnection(connection);
            if (slot == null) return;

            final videoOn =
                state == RemoteVideoState.remoteVideoStateDecoding ||
                state == RemoteVideoState.remoteVideoStateStarting;

            // If hostUid was never set (host was already in channel when
            // we joined — onUserJoined won't fire in that case), set it
            // now from the first remote video state change we receive.
            if (slot.hostUid.value == null && videoOn) {
              slot.hostUid.value = uid;
              debugPrint(
                '👤 [Pool/${slot.currentPosition.name}] hostUid=$uid (from videoState — joined after host)',
              );
              _emit(slot, SlotEventKind.hostUidReady);
            }

            if (slot.hostUid.value != uid) return;

            final wasOff = !slot.hasVideo.value;
            slot.hasVideo.value = videoOn;

            if (videoOn && wasOff) {
              debugPrint(
                '🎬 [Pool/${slot.currentPosition.name}] first frame uid=$uid',
              );
              _emit(slot, SlotEventKind.videoReady);
            }
          },

      onUserOffline:
          (RtcConnection connection, int uid, UserOfflineReasonType reason) {
            if (_disposed) return;
            final slot = _identityForConnection(connection);
            if (slot == null) return;
            if (slot.hostUid.value == uid) {
              slot.hostUid.value = null;
              slot.hasVideo.value = false;
            }
          },

      onLeaveChannel: (RtcConnection connection, RtcStats stats) {
        if (_disposed) return;
        final slot = _identityForConnection(connection);
        if (slot == null) return;
        debugPrint('🚪 [Pool/${slot.currentPosition.name}] left');
        _emit(slot, SlotEventKind.leftChannel);
      },

      onError: (ErrorCodeType code, String msg) {
        if (_disposed) return;
        debugPrint('❌ [Pool] engine-level error: $code $msg');
      },

      onNetworkQuality:
          (
            RtcConnection connection,
            int uid,
            QualityType txQuality,
            QualityType rxQuality,
          ) {
            if (_disposed) return;
            if (uid != 0) return;
            final slot = _identityForConnection(connection);
            if (slot == null) return;
            final hostUid = slot.hostUid.value;
            if (hostUid == null) return;
            final isPoor = rxQuality == QualityType.qualityPoor ||
                rxQuality == QualityType.qualityBad ||
                rxQuality == QualityType.qualityVbad ||
                rxQuality == QualityType.qualityDown;
            _engine
                .setRemoteVideoStreamTypeEx(
                  uid: hostUid,
                  streamType: isPoor
                      ? VideoStreamType.videoStreamLow
                      : (slot.currentPosition == SlotPosition.current
                          ? VideoStreamType.videoStreamHigh
                          : VideoStreamType.videoStreamLow),
                  connection: connection,
                )
                .catchError((_) {});
          },
    );
  }

  /// Matches an incoming callback's RtcConnection to the identity that
  /// owns it. Matches on fixedLocalUid (permanently unique per
  /// identity) plus channelId, for safety.
  EngineSlot? _identityForConnection(RtcConnection connection) {
    for (final slot in [_identityA, _identityB, _identityC]) {
      if (slot.channelId == connection.channelId &&
          slot.activeLocalUid == connection.localUid) {
        return slot;
      }
    }
    return null;
  }

  void _emit(EngineSlot slot, SlotEventKind kind) {
    if (_eventsCtrl.isClosed) return;
    _eventsCtrl.add(SlotEvent(
      position: slot.currentPosition,
      epoch: slot.epoch,
      kind: kind,
    ));
  }

  // ── Join / leave ─────────────────────────────────────────────────────────

  Future<void> _joinSlot(EngineSlot slot, StreamJoinRequest req) async {
    if (_disposed) return;

    await _ensureEngineContext(req.appId);

    slot.resetForNewJoin();
    final myEpoch = slot.epoch;
    slot.state = SlotJoinState.joining;
    slot.channelId = req.channel;
    slot.livestreamParam = req.livestreamParam;

    _emit(slot, SlotEventKind.joining);

    final localUid = int.tryParse(req.rtcUid) ?? 0;
    slot.activeLocalUid = localUid;

    final connection = RtcConnection(
      channelId: req.channel,
      localUid: localUid,
    );

    try {
      await _engine.joinChannelEx(
        token: req.rtcToken,
        connection: connection,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleAudience,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          publishCameraTrack: false,
          publishMicrophoneTrack: false,
        ),
      );

      // await _engine.setRemoteDefaultVideoStreamTypeEx(
      //   streamType: slot.currentPosition == SlotPosition.current
      //       ? VideoStreamType.videoStreamHigh
      //       : VideoStreamType.videoStreamLow,
      //   connection: connection,
      // );

      debugPrint(
        '🔌 [Pool/${slot.currentPosition.name}] joinChannelEx issued '
        'ch=${req.channel} uid=$localUid epoch=$myEpoch',
      );
    } catch (e) {
      debugPrint('❌ [Pool/${slot.currentPosition.name}] join error: $e');
      if (slot.epoch == myEpoch && slot.state != SlotJoinState.unavailable) {
        slot.state = SlotJoinState.idle;
      }
      if (_eventsCtrl.isClosed) return;
      _eventsCtrl.add(SlotEvent(
        position: slot.currentPosition,
        epoch: myEpoch,
        kind: SlotEventKind.joinFailed,
      ));
    }
  }

  Future<void> _leaveSlot(EngineSlot slot) async {
    if (slot.state == SlotJoinState.idle ||
        slot.state == SlotJoinState.unavailable) return;
    final connection = slot.connection;
    if (connection == null) {
      slot.softReset();
      return;
    }
    slot.state = SlotJoinState.leaving;
    try {
      await _engine.leaveChannelEx(connection: connection);
    } catch (e) {
      debugPrint('⚠️ [Pool/${slot.currentPosition.name}] leave error: $e');
    } finally {
      slot.softReset();
    }
  }

  // ── Window management ─────────────────────────────────────────────────────

  Future<void> setInitialWindow({
    required int currentIndex,
    required int itemCount,
    required Future<StreamJoinRequest?> Function(int index) resolve,
  }) async {
    if (!_initialized) throw StateError('Call initialize() first.');
    _currentIndex = currentIndex;

    await Future.wait([
      for (final position in SlotPosition.values)
        _joinPositionAt(position, currentIndex, itemCount, resolve),
    ]);

    debugPrint('🏊 [Pool] Initial window set (index=$currentIndex)');
  }

  Future<void> _joinPositionAt(
    SlotPosition position,
    int currentIndex,
    int itemCount,
    Future<StreamJoinRequest?> Function(int) resolve,
  ) async {
    final index = _indexFor(position, currentIndex);
    final slot = _map[position]!;

    if (index < 0 || index >= itemCount) {
      slot.markUnavailable();
      return;
    }
    final req = await resolve(index);
    if (req == null) {
      slot.markUnavailable();
      return;
    }
    await _joinSlot(slot, req);
  }

  // ── Rotation ──────────────────────────────────────────────────────────────
  //
  // Rotation relabels which PERMANENT identity (_identityA/B/C) plays
  // which ROLE (previous/current/next) in the _map. The identities
  // themselves — and their already-joined connections — are untouched
  // by relabeling. Only the identity that falls OUTSIDE the new window
  // needs an actual leave+rejoin, mirroring the original pool's
  // single-step-swipe efficiency.

  Future<void> rotate({
    required int newIndex,
    required int itemCount,
    required Future<StreamJoinRequest?> Function(int index) resolve,
  }) async {
    _latestRequestedIndex = newIndex;
    // If a rotation is already running, just update the target index —
    // _runRotation's while loop will pick it up and rotate to the latest.
    if (_rotationInFlight != null) return;
    _rotationInFlight = _runRotation(itemCount: itemCount, resolve: resolve);
    try {
      await _rotationInFlight;
    } catch (e) {
      debugPrint('❌ [Pool] rotation error: \$e');
    } finally {
      _rotationInFlight = null;
    }
  }

  Future<void> _runRotation({
    required int itemCount,
    required Future<StreamJoinRequest?> Function(int) resolve,
  }) async {
    int? settled;
    while (settled != _latestRequestedIndex) {
      final target = _latestRequestedIndex!;
      settled = target;
      await _rotateTo(target, itemCount: itemCount, resolve: resolve);
    }
  }

  Future<void> _rotateTo(
    int newIndex, {
    required int itemCount,
    required Future<StreamJoinRequest?> Function(int) resolve,
  }) async {
    if (_disposed) return;

    final direction = newIndex > _currentIndex ? 1 : -1;
    _currentIndex = newIndex;

    final oldCurrent = _map[SlotPosition.current]!;
    final oldNext = _map[SlotPosition.next]!;
    final oldPrevious = _map[SlotPosition.previous]!;

    EngineSlot newCurrentSlot;
    EngineSlot newPreviousSlot;
    EngineSlot newNextSlot;
    EngineSlot recycledSlot; // the identity that falls outside the window

    if (direction > 0) {
      // Forward: old-next becomes current (already joined — instant).
      newCurrentSlot = oldNext;
      newPreviousSlot = oldCurrent;
      recycledSlot = oldPrevious; // needs to leave old, join new "next"
      newNextSlot = recycledSlot;
    } else {
      // Backward: old-previous becomes current (already joined — instant).
      newCurrentSlot = oldPrevious;
      newNextSlot = oldCurrent;
      recycledSlot = oldNext; // needs to leave old, join new "previous"
      newPreviousSlot = recycledSlot;
    }

    // Relabel — this is the ENTIRE cost for the two identities that
    // didn't change channel. Their RtcConnection (channelId + fixed
    // uid) is untouched; only the `currentPosition` metadata changes,
    // which affects video-quality preference and which position
    // listeners treat as "visible."
    newCurrentSlot.currentPosition = SlotPosition.current;
    newPreviousSlot.currentPosition = SlotPosition.previous;
    newNextSlot.currentPosition = SlotPosition.next;

    _map[SlotPosition.current] = newCurrentSlot;
    _map[SlotPosition.previous] = newPreviousSlot;
    _map[SlotPosition.next] = newNextSlot;

    // Upgrade newly-current to high quality; downgrade the others.
    final currentConn = newCurrentSlot.connection;
    if (newCurrentSlot.state == SlotJoinState.joined &&
        newCurrentSlot.hostUid.value != null &&
        currentConn != null) {
      _engine
          .setRemoteVideoStreamTypeEx(
            uid: newCurrentSlot.hostUid.value!,
            streamType: VideoStreamType.videoStreamHigh,
            connection: currentConn,
          )
          .catchError((_) {});
    }
    for (final slot in [newPreviousSlot, newNextSlot]) {
      final conn = slot.connection;
      if (slot.state == SlotJoinState.joined &&
          slot.hostUid.value != null &&
          conn != null) {
        _engine
            .setRemoteVideoStreamTypeEx(
              uid: slot.hostUid.value!,
              streamType: VideoStreamType.videoStreamLow,
              connection: conn,
            )
            .catchError((_) {});
      }
    }

    // Background: the recycled identity needs to leave its old stream
    // (if any) and join the newly-exposed adjacent one. User doesn't
    // wait for this — it's exactly the pre-join work that makes the
    // NEXT swipe instant.
    final newExposedIndex = direction > 0 ? newIndex + 1 : newIndex - 1;

    unawaited(_backgroundRejoin(
      slot: recycledSlot,
      index: newExposedIndex,
      itemCount: itemCount,
      resolve: resolve,
    ));

    debugPrint(
      '🔄 [Pool] Rotated ${direction > 0 ? "→" : "←"} to index=$newIndex',
    );

    // CRITICAL: emit a synthetic event for the newly-current slot so
    // PoolVideoView knows to re-seed its controller from the new slot.
    // Without this, PoolVideoView keeps waiting for events that fired
    // BEFORE this slot became current (on its old position label) and
    // never renders the new stream.
    if (newCurrentSlot.state == SlotJoinState.joined) {
      if (newCurrentSlot.hasVideo.value) {
        _emit(newCurrentSlot, SlotEventKind.videoReady);
      } else if (newCurrentSlot.hostUid.value != null) {
        _emit(newCurrentSlot, SlotEventKind.hostUidReady);
      } else {
        _emit(newCurrentSlot, SlotEventKind.joined);
      }
    }
  }

  Future<void> _backgroundRejoin({
    required EngineSlot slot,
    required int index,
    required int itemCount,
    required Future<StreamJoinRequest?> Function(int) resolve,
  }) async {
    if (_disposed) return;

    if (index < 0 || index >= itemCount) {
      await _leaveSlot(slot);
      slot.markUnavailable();
      return;
    }

    final req = await resolve(index);
    if (req == null || _disposed) {
      slot.markUnavailable();
      return;
    }

    if (slot.channelId == req.channel && slot.state == SlotJoinState.joined) {
      // Fast back-and-forth landed back on the same stream this
      // identity was already on — no work needed.
      return;
    }

    await _leaveSlot(slot);
    if (_disposed) return;
    await _joinSlot(slot, req);
  }

  int _indexFor(SlotPosition position, int currentIndex) => switch (position) {
    SlotPosition.previous => currentIndex - 1,
    SlotPosition.current => currentIndex,
    SlotPosition.next => currentIndex + 1,
  };

  // ── App lifecycle ─────────────────────────────────────────────────────────

  Future<void> onAppBackgrounded() async {
    if (_backgrounded) return;
    _backgrounded = true;
    for (final position in [SlotPosition.previous, SlotPosition.next]) {
      await _leaveSlot(_map[position]!);
    }
    debugPrint('📴 [Pool] Backgrounded');
  }

  Future<void> onAppForegrounded({
    required int currentIndex,
    required int itemCount,
    required Future<StreamJoinRequest?> Function(int) resolve,
  }) async {
    if (!_backgrounded) return;
    _backgrounded = false;
    await setInitialWindow(
      currentIndex: currentIndex,
      itemCount: itemCount,
      resolve: resolve,
    );
    debugPrint('📲 [Pool] Foregrounded');
  }

  /// Fully releases the shared engine so another engine (e.g. AgoraService
  /// for the host go-live screen) can be created. The pool resets to an
  /// uninitialized state — the next call to initialize() will create a
  /// fresh engine. Call this BEFORE opening the host/go-live screen.
  Future<void> release() async {
    if (_disposed || !_initialized) return;
    await leaveAll();
    if (_engineContextReady) {
      try { await _engine.release(); } catch (_) {}
      _engineContextReady = false;
    }
    _initialized = false;
    _onGuestUidChanged = null;
    _map.clear();
    debugPrint('🏊 [Pool] Engine released (host mode)');
  }

  /// Leaves all active slot connections without releasing the engine.
  /// Call this when the viewer pager closes so audio/video stops, but
  /// the engine stays alive for the next pager session.
  Future<void> leaveAll() async {
    if (_disposed) return;
    for (final slot in [_identityA, _identityB, _identityC]) {
      await _leaveSlot(slot);
    }
    debugPrint('🏊 [Pool] All connections left (engine retained)');
  }

  // ── Teardown ──────────────────────────────────────────────────────────────

  Future<void> disposeAll() async {
    if (_disposed) return;
    _disposed = true;
    for (final slot in [_identityA, _identityB, _identityC]) {
      final conn = slot.connection;
      if (conn != null) {
        try { await _engine.leaveChannelEx(connection: conn); } catch (_) {}
      }
      slot.dispose();
    }
    if (_engineContextReady) {
      try { await _engine.release(); } catch (_) {}
    }
    _map.clear();
    if (!_eventsCtrl.isClosed) await _eventsCtrl.close();
    debugPrint('🏊 [Pool] Disposed shared engine and all connections');
  }
}

void unawaited(Future<void> future) =>
    future.catchError((e) => debugPrint('⚠️ [Pool] unawaited error: $e'));