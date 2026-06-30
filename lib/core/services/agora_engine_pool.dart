// lib/core/services/agora_engine_pool.dart
//
// VERSION 3 — all bugs fixed.
//
// BUG 1 (fixed): onUserJoined never emitted an event, so PoolVideoView
//   called _buildController() on SlotEventKind.joined when hostUid was
//   still null, bailed silently, and had no signal to retry. Fixed by
//   adding SlotEventKind.hostUidReady, emitted from onUserJoined.
//
// BUG 2 (fixed): PoolVideoView mounted AFTER setInitialWindow() had
//   already fired all events into the broadcast stream — missed entirely
//   since broadcast streams don't replay. Fixed in pool_video_view.dart
//   by reading slot state synchronously on _attach(), not relying solely
//   on the stream.
//
// BUG 3 (fixed): _engineContextReady was keyed by SlotPosition enum,
//   which changes when slots rotate. So after one rotation the "previous"
//   slot's engine would be re-initialized with a new context on its next
//   join attempt — or worse, the set would claim it was already ready
//   when a different slot object now occupied that position key.
//   Fixed by keying _engineContextReady on the slot object itself
//   (Set<EngineSlot>) so readiness follows the engine, not the label.
//
// BUG 4 (fixed): EngineSlot.position was final and set at construction.
//   Event handlers emitted SlotEvent(position: slot.position) using the
//   original creation-time label. After rotation, the slot in the
//   "current" map key would emit events with position=previous (its
//   original label), which PoolVideoView filtered out.
//   Fixed by making currentPosition a mutable field updated on every
//   rotation so callbacks always emit the correct current label.

import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide ConnectionState;

enum SlotPosition { previous, current, next }

enum SlotJoinState { unavailable, idle, joining, joined, leaving }

enum SlotEventKind {
  joining,
  joined,
  hostUidReady, // fires after onUserJoined sets hostUid — PoolVideoView retries _buildController()
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
  final String rtcUid;
  final String rtcToken;
}

// ─────────────────────────────────────────────────────────────────────────────
// EngineSlot
// ─────────────────────────────────────────────────────────────────────────────

class EngineSlot {
  EngineSlot(this.engine, SlotPosition initialPosition)
      : currentPosition = initialPosition;

  final RtcEngine engine;

  /// MUTABLE — updated by the pool on every rotation so event handlers
  /// always emit the correct current position label, not the label the
  /// slot was created with.
  SlotPosition currentPosition;

  /// Incremented on every new join attempt. Callbacks capture myEpoch at
  /// call time and compare against this when they fire — stale events
  /// from superseded joins are silently dropped.
  int epoch = 0;

  SlotJoinState state = SlotJoinState.idle;
  String? channelId;
  String? livestreamParam;

  final ValueNotifier<int?> hostUid = ValueNotifier<int?>(null);
  final ValueNotifier<bool> hasVideo = ValueNotifier<bool>(false);

  /// Whether this slot's engine has been initialized with an appId.
  /// Keyed on the slot OBJECT (not position) so it survives rotation.
  bool engineReady = false;

  /// Whether registerEventHandler() has been called on this engine yet.
  /// Must only happen AFTER engine.initialize() succeeds — see fix note
  /// in AgoraEnginePool.initialize(). Survives rotation since it's on
  /// the slot OBJECT, same pattern as engineReady.
  bool handlersRegistered = false;

  void resetForNewJoin() {
    epoch++;
    state = SlotJoinState.idle;
    hostUid.value = null;
    hasVideo.value = false;
  }

  void markUnavailable() {
    epoch++;
    state = SlotJoinState.unavailable;
    channelId = null;
    livestreamParam = null;
    hostUid.value = null;
    hasVideo.value = false;
  }

  void softReset() {
    // Used after leaving — keeps engineReady=true so re-join skips init.
    channelId = null;
    livestreamParam = null;
    hostUid.value = null;
    hasVideo.value = false;
    if (state != SlotJoinState.unavailable) state = SlotJoinState.idle;
  }

  void dispose() {
    hostUid.dispose();
    hasVideo.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AgoraEnginePool
// ─────────────────────────────────────────────────────────────────────────────

class AgoraEnginePool {
  AgoraEnginePool();

  // All three slot objects. Never recreated — only their currentPosition
  // label and their channel assignment change on rotation.
  late final EngineSlot _slotA;
  late final EngineSlot _slotB;
  late final EngineSlot _slotC;

  // Position-to-slot map. Rotated on every swipe.
  final Map<SlotPosition, EngineSlot> _map = {};

  final StreamController<SlotEvent> _eventsCtrl =
      StreamController<SlotEvent>.broadcast();
  Stream<SlotEvent> get events => _eventsCtrl.stream;

  bool _initialized = false;
  bool _disposed = false;
  bool _backgrounded = false;

  // Rotation serialization
  Future<void>? _rotationInFlight;
  int? _latestRequestedIndex;
  int _currentIndex = 0;

  // ── Accessors ─────────────────────────────────────────────────────────────

  EngineSlot? slotFor(SlotPosition position) => _map[position];

  // ── Initialization ────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _slotA = EngineSlot(createAgoraRtcEngine(), SlotPosition.previous);
    _slotB = EngineSlot(createAgoraRtcEngine(), SlotPosition.current);
    _slotC = EngineSlot(createAgoraRtcEngine(), SlotPosition.next);

    _map[SlotPosition.previous] = _slotA;
    _map[SlotPosition.current] = _slotB;
    _map[SlotPosition.next] = _slotC;

    // FIX: do NOT call _registerHandlers() here. At this point each
    // engine is a raw RtcEngine returned by createAgoraRtcEngine() —
    // engine.initialize(RtcEngineContext(...)) has NOT been called yet
    // (that only happens later, inside _joinSlot(), where we first know
    // the appId). Agora's native SDK requires registerEventHandler() to
    // be called AFTER initialize() for the handler to reliably attach to
    // the native callback dispatch; calling it on an uninitialized
    // engine silently no-ops. This was the root cause of video never
    // rendering: onJoinChannelSuccess/onUserJoined/onRemoteVideoState
    // Changed were never reaching our Dart-side handler at all, despite
    // the native engine genuinely joining and decoding frames — the
    // handler registration itself never took effect.
    //
    // Registration now happens in _joinSlot(), immediately after
    // engine.initialize() succeeds, guarded by slot.handlersRegistered
    // so it only runs once per engine's lifetime (not on every join).

    debugPrint('🏊 [Pool] 3 engines created');
  }

  List<EngineSlot> get _allSlots => [_slotA, _slotB, _slotC];

  // ── Event handler registration ────────────────────────────────────────────

  void _registerHandlers(EngineSlot slot) {
    slot.engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (conn, elapsed) {
          if (_disposed) return;
          debugPrint(
            '✅ [Pool/${slot.currentPosition.name}] '
            'joined ch=${conn.channelId} epoch=${slot.epoch}',
          );
          if (slot.state != SlotJoinState.unavailable) {
            slot.state = SlotJoinState.joined;
          }
          _emit(slot, SlotEventKind.joined);
        },

        onUserJoined: (conn, remoteUid, elapsed) {
          if (_disposed) return;
          if (slot.hostUid.value == null) {
            slot.hostUid.value = remoteUid;
            debugPrint(
              '👤 [Pool/${slot.currentPosition.name}] '
              'hostUid=$remoteUid — emitting hostUidReady',
            );
            // KEY FIX (Bug 1): emit hostUidReady so PoolVideoView can
            // now call _buildController() with a valid hostUid.
            _emit(slot, SlotEventKind.hostUidReady);
          }
        },

        onRemoteVideoStateChanged: (conn, uid, state, reason, elapsed) {
          if (_disposed) return;

          // FIX: previously this hard-gated on `slot.hostUid.value != uid`
          // and silently dropped the event on any mismatch. That's fragile
          // — onUserJoined can report a different uid than the one that
          // actually publishes video (e.g. internal SDK stream ids, or
          // ordering races between onUserJoined and the first video state
          // change for the SAME logical host). If hostUid was set to the
          // "wrong" uid first, every subsequent real video event for the
          // actual publishing uid was being discarded here — which is
          // very likely why frames decoded successfully at the codec
          // level but the pool/Flutter side never learned about it.
          //
          // New behavior: treat onRemoteVideoStateChanged as authoritative
          // for whichever uid it reports. If hostUid is unset, or differs
          // from this uid, self-correct hostUid to match — this uid IS
          // the one actually delivering video, which is the ground truth
          // we actually care about for rendering purposes.
          if (slot.hostUid.value != uid) {
            debugPrint(
              '🔧 [Pool/${slot.currentPosition.name}] '
              'hostUid correcting ${slot.hostUid.value} → $uid '
              '(video state event is authoritative)',
            );
            slot.hostUid.value = uid;
            // hostUid changed — PoolVideoView needs to rebuild its
            // controller against the corrected uid.
            _emit(slot, SlotEventKind.hostUidReady);
          }

          final videoOn =
              state == RemoteVideoState.remoteVideoStateDecoding ||
              state == RemoteVideoState.remoteVideoStateStarting;

          final wasOff = !slot.hasVideo.value;
          slot.hasVideo.value = videoOn;

          if (videoOn && wasOff) {
            debugPrint(
              '🎬 [Pool/${slot.currentPosition.name}] first frame uid=$uid',
            );
            _emit(slot, SlotEventKind.videoReady);
          }
        },

        onUserOffline: (conn, uid, reason) {
          if (_disposed) return;
          if (slot.hostUid.value == uid) {
            slot.hostUid.value = null;
            slot.hasVideo.value = false;
          }
        },

        onLeaveChannel: (conn, stats) {
          if (_disposed) return;
          debugPrint('🚪 [Pool/${slot.currentPosition.name}] left');
          _emit(slot, SlotEventKind.leftChannel);
        },

        onError: (code, msg) {
          if (_disposed) return;
          debugPrint(
            '❌ [Pool/${slot.currentPosition.name}] error $code: ${msg ?? ""}',
          );
          if (slot.state == SlotJoinState.joining) {
            slot.state = SlotJoinState.idle;
          }
          _emit(slot, SlotEventKind.joinFailed);
        },

        onNetworkQuality: (conn, uid, txQ, rxQ) {
          if (_disposed) return;
          if (uid != 0) return; // only handle self quality
          final hostUid = slot.hostUid.value;
          if (hostUid == null) return;
          final isPoor = rxQ == QualityType.qualityPoor ||
              rxQ == QualityType.qualityBad ||
              rxQ == QualityType.qualityVbad ||
              rxQ == QualityType.qualityDown;
          slot.engine
              .setRemoteVideoStreamType(
                uid: hostUid,
                streamType: isPoor
                    ? VideoStreamType.videoStreamLow
                    : (slot.currentPosition == SlotPosition.current
                        ? VideoStreamType.videoStreamHigh
                        : VideoStreamType.videoStreamLow),
              )
              .catchError((_) {});
        },
      ),
    );
  }

  void _emit(EngineSlot slot, SlotEventKind kind) {
    if (_eventsCtrl.isClosed) return;
    _eventsCtrl.add(SlotEvent(
      position: slot.currentPosition,
      epoch: slot.epoch,
      kind: kind,
    ));
  }

  // ── Join / leave ──────────────────────────────────────────────────────────

  Future<void> _joinSlot(EngineSlot slot, StreamJoinRequest req) async {
    if (_disposed) return;

    slot.resetForNewJoin();
    final myEpoch = slot.epoch;
    slot.state = SlotJoinState.joining;
    slot.channelId = req.channel;
    slot.livestreamParam = req.livestreamParam;

    _emit(slot, SlotEventKind.joining);

    try {
      // One-time engine + video pipeline setup per slot OBJECT (not per
      // position, not per join). engineReady survives rotation AND
      // survives repeated leave/rejoin cycles — we never re-issue these
      // setup calls on an engine that's already had them applied.
      //
      // ROOT CAUSE FIX: enableAudio()/enableVideo()/setClientRole()/
      // setVideoEncoderConfiguration() were previously called on EVERY
      // _joinSlot() invocation — i.e. every single channel switch on a
      // pooled engine. Since pooled engines are reused across many joins
      // (that's the entire point of pooling), re-issuing enableVideo()
      // and especially setVideoEncoderConfiguration() on an engine that
      // already has an active video pipeline resets that pipeline at the
      // native SDK level. This invalidated whatever surface/texture the
      // previous AgoraVideoView had attached, even though neither the
      // RtcEngine instance nor the Flutter-side VideoViewController
      // object changed identity. Decoding kept succeeding (a new
      // MediaCodec instance — mId incrementing each join — was silently
      // created underneath) but nothing was ever rendered, because the
      // surface binding these calls reset was never the one frames were
      // actually being decoded into. The OLD single-engine path never
      // hit this because AgoraViewerService only ever joined once per
      // screen instance — these calls were never repeated on a live
      // engine there.
      if (!slot.engineReady) {
        await slot.engine.initialize(
          RtcEngineContext(
            appId: req.appId,
            channelProfile:
                ChannelProfileType.channelProfileLiveBroadcasting,
          ),
        );

        // FIX: register the event handler HERE, immediately after
        // initialize() succeeds — not in pool-level initialize() where
        // the engine was still raw/uninitialized. This is the actual
        // fix for video never rendering: the handler registered on an
        // uninitialized engine never attached to the native callback
        // dispatch, so onJoinChannelSuccess/onUserJoined/
        // onRemoteVideoStateChanged were silently never reaching Dart,
        // even though the native engine genuinely joined and decoded
        // frames the whole time.
        if (!slot.handlersRegistered) {
          _registerHandlers(slot);
          slot.handlersRegistered = true;
          debugPrint(
            '🔗 [Pool/${slot.currentPosition.name}] event handler '
            'registered (post-initialize)',
          );
        }

        await slot.engine.setDefaultAudioRouteToSpeakerphone(true);
        await slot.engine.enableAudio();
        await slot.engine.enableVideo();
        await slot.engine.setClientRole(
          role: ClientRoleType.clientRoleAudience,
        );
        await slot.engine.setVideoEncoderConfiguration(
          const VideoEncoderConfiguration(
            dimensions: VideoDimensions(width: 360, height: 640),
            frameRate: 20,
            bitrate: 300,
            orientationMode: OrientationMode.orientationModeAdaptive,
          ),
        );
        slot.engineReady = true;
        debugPrint(
          '🔧 [Pool/${slot.currentPosition.name}] engine initialized '
          '(one-time pipeline setup complete)',
        );
      }

      final uid = int.tryParse(req.rtcUid) ?? 0;
      await slot.engine.joinChannel(
        token: req.rtcToken,
        channelId: req.channel,
        uid: uid,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleAudience,
          channelProfile:
              ChannelProfileType.channelProfileLiveBroadcasting,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          publishCameraTrack: false,
          publishMicrophoneTrack: false,
        ),
      );

      // Current slot gets high-quality video; others get low to save CPU.
      // setRemoteDefaultVideoStreamType is safe to call per-join — it
      // doesn't touch the local pipeline/surface, only the requested
      // remote stream quality.
      await slot.engine.setRemoteDefaultVideoStreamType(
        slot.currentPosition == SlotPosition.current
            ? VideoStreamType.videoStreamHigh
            : VideoStreamType.videoStreamLow,
      );

      debugPrint(
        '🔌 [Pool/${slot.currentPosition.name}] join issued '
        'ch=${req.channel} uid=$uid epoch=$myEpoch',
      );
    } catch (e) {
      debugPrint('❌ [Pool/${slot.currentPosition.name}] join error: $e');
      if (slot.epoch == myEpoch &&
          slot.state != SlotJoinState.unavailable) {
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
    slot.state = SlotJoinState.leaving;
    try {
      await slot.engine.leaveChannel();
    } catch (e) {
      debugPrint(
        '⚠️ [Pool/${slot.currentPosition.name}] leave error: $e',
      );
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

    // Join all 3 slots concurrently.
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

  Future<void> rotate({
    required int newIndex,
    required int itemCount,
    required Future<StreamJoinRequest?> Function(int index) resolve,
  }) async {
    _latestRequestedIndex = newIndex;
    if (_rotationInFlight != null) return _rotationInFlight;
    _rotationInFlight =
        _runRotation(itemCount: itemCount, resolve: resolve);
    try {
      await _rotationInFlight;
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

    // ── Relabel slots ─────────────────────────────────────────────────
    // Rotating forward (direction=1):
    //   old current → new previous
    //   old next    → new current   (already joined — zero latency!)
    //   old previous → new next     (needs to leave old and join new)
    //
    // Rotating backward (direction=-1):
    //   old current  → new next
    //   old previous → new current  (already joined — zero latency!)
    //   old next     → new previous (needs to leave old and join new)

    final oldCurrent = _map[SlotPosition.current]!;
    final oldNext = _map[SlotPosition.next]!;
    final oldPrevious = _map[SlotPosition.previous]!;

    EngineSlot newCurrentSlot;
    EngineSlot newPreviousSlot;
    EngineSlot newNextSlot;
    EngineSlot recycledSlot; // the one that gets repurposed

    if (direction > 0) {
      // Scrolled forward
      newCurrentSlot = oldNext;
      newPreviousSlot = oldCurrent;
      recycledSlot = oldPrevious; // will leave its old channel, join new next
      newNextSlot = recycledSlot;
    } else {
      // Scrolled backward
      newCurrentSlot = oldPrevious;
      newNextSlot = oldCurrent;
      recycledSlot = oldNext; // will leave its old channel, join new previous
      newPreviousSlot = recycledSlot;
    }

    // Update position labels on the slot objects (fixes Bug 4).
    newCurrentSlot.currentPosition = SlotPosition.current;
    newPreviousSlot.currentPosition = SlotPosition.previous;
    newNextSlot.currentPosition = SlotPosition.next;

    // Commit the new map.
    _map[SlotPosition.current] = newCurrentSlot;
    _map[SlotPosition.previous] = newPreviousSlot;
    _map[SlotPosition.next] = newNextSlot;

    // Upgrade the new current to high-quality video immediately.
    if (newCurrentSlot.state == SlotJoinState.joined &&
        newCurrentSlot.hostUid.value != null) {
      newCurrentSlot.engine
          .setRemoteVideoStreamType(
            uid: newCurrentSlot.hostUid.value!,
            streamType: VideoStreamType.videoStreamHigh,
          )
          .catchError((_) {});
    }

    // Downgrade non-current slots to low-quality.
    for (final slot in [newPreviousSlot, newNextSlot]) {
      if (slot.state == SlotJoinState.joined &&
          slot.hostUid.value != null) {
        slot.engine
            .setRemoteVideoStreamType(
              uid: slot.hostUid.value!,
              streamType: VideoStreamType.videoStreamLow,
            )
            .catchError((_) {});
      }
    }

    // Background work: leave the recycled slot's old channel and join
    // the newly-exposed adjacent stream. The user doesn't wait for this.
    final newExposedIndex = direction > 0
        ? newIndex + 1  // new next after scrolling forward
        : newIndex - 1; // new previous after scrolling backward

    unawaited(_backgroundRejoin(
      slot: recycledSlot,
      index: newExposedIndex,
      itemCount: itemCount,
      resolve: resolve,
    ));

    debugPrint(
      '🔄 [Pool] Rotated ${direction > 0 ? "→" : "←"} '
      'to index=$newIndex',
    );
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

    // Skip if already on the right channel (e.g. fast back-and-forth).
    if (slot.channelId == req.channel &&
        slot.state == SlotJoinState.joined) {
      debugPrint(
        '⚡ [Pool/${slot.currentPosition.name}] '
        'already on ch=${req.channel} — skip rejoin',
      );
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
    for (final slot in _allSlots) {
      if (slot.currentPosition == SlotPosition.current) continue;
      await _leaveSlot(slot);
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

  // ── Teardown ──────────────────────────────────────────────────────────────

  Future<void> disposeAll() async {
    if (_disposed) return;
    _disposed = true;
    for (final slot in _allSlots) {
      try { await slot.engine.leaveChannel(); } catch (_) {}
      try { await slot.engine.release(); } catch (_) {}
      slot.dispose();
    }
    _map.clear();
    if (!_eventsCtrl.isClosed) await _eventsCtrl.close();
    debugPrint('🏊 [Pool] All 3 engines disposed');
  }
}

void unawaited(Future<void> future) =>
    future.catchError((e) => debugPrint('⚠️ [Pool] unawaited error: $e'));