// lib/core/services/video_call_agora_service.dart
//
// Dedicated Agora service for private 1:1 video calls.
//
// Deliberately separate from AgoraService (livestream host) and
// AgoraViewerService/AgoraEnginePool (livestream viewer). A private call
// is peer-to-peer — both sides equal, no audience — which is Agora's
// channelProfileCommunication profile, not channelProfileLiveBroadcasting.
// Mixing this into either existing service would mean running a call on
// the wrong profile (worse latency characteristics, wrong semantics) or
// fighting the pool's audience/co-host state machine for a case it was
// never designed for.
//
// Registered as a factory (fresh instance per call), not a singleton —
// AgoraService may already be active on a streamer's device (she's live)
// when a call comes in; the backend already handles pausing her stream,
// this service just needs to not collide with that engine.
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class VideoCallAgoraService with ChangeNotifier {
  RtcEngine? _engine;
  bool _disposed = false;

  bool _joined = false;
  String? _channelId;
  int? _localUid;

  bool _isMicEnabled = true;
  bool _isCameraEnabled = true;
  String? _lastError;

  final ValueNotifier<int?> remoteUid = ValueNotifier<int?>(null);
  final ValueNotifier<bool> remoteHasVideo = ValueNotifier<bool>(false);
  final ValueNotifier<bool> remoteHasAudio = ValueNotifier<bool>(false);

  /// True only while THIS device's Agora connection is fully connected.
  /// Goes false the moment we drop to reconnecting/failed — this is how a
  /// call detects the *local* network dying (the remote-state callbacks
  /// never fire in that case, because our socket is down).
  final ValueNotifier<bool> connectionHealthy = ValueNotifier<bool>(true);

  /// True while we are genuinely receiving the peer's video, OR the peer
  /// deliberately turned their camera off (their network is fine — the
  /// call continues). False when their video froze/stopped for a network
  /// reason, or they went offline. Drives the network-drop timer freeze.
  final ValueNotifier<bool> remoteStreamHealthy = ValueNotifier<bool>(false);

  bool get joined => _joined;
  String? get channelId => _channelId;
  bool get isMicEnabled => _isMicEnabled;
  bool get isCameraEnabled => _isCameraEnabled;
  String? get lastError => _lastError;

  void _notify() {
    if (_disposed) return;
    try {
      notifyListeners();
    } catch (_) {}
  }

  void _setNotifier<T>(ValueNotifier<T> n, T v) {
    if (_disposed) return;
    try {
      n.value = v;
    } catch (_) {}
  }

  Future<void> _ensurePermissions() async {
    final statuses = await [
      Permission.microphone,
      Permission.camera,
    ].request();
    final denied = statuses.values.any(
      (s) => s.isDenied || s.isPermanentlyDenied || s.isRestricted,
    );
    if (denied) throw StateError('Camera/Microphone permission denied');
  }

  /// Joins the call channel. [uid] must match the numeric uid the backend
  /// generated the token for (see AgoraTokenService's uid convention on
  /// the server — clamped user id, never 0).
  Future<void> join({
    required String appId,
    required String channel,
    required String token,
    required int uid,
  }) async {
    if (appId.isEmpty) throw ArgumentError('appId is empty');
    if (channel.isEmpty) throw ArgumentError('channel is empty');
    if (token.isEmpty) throw ArgumentError('token is empty');

    await _ensurePermissions();

    if (_engine != null && _joined && _channelId == channel) {
      if (kDebugMode) debugPrint('[VideoCallAgora] Already in this channel');
      return;
    }

    await leave();
    await disposeEngine();

    final e = createAgoraRtcEngine();
    _engine = e;
    _channelId = channel;
    _localUid = uid;
    _lastError = null;
    _setNotifier(connectionHealthy, true);
    _setNotifier(remoteStreamHealthy, false);

    await e.initialize(
      RtcEngineContext(
        appId: appId,
        // Communication profile: both parties are equal peers, no
        // audience/broadcaster distinction. This is the correct profile
        // for a 1:1 call — not channelProfileLiveBroadcasting.
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );

    await e.enableAudio();
    await e.enableVideo();
    await e.setCameraCapturerConfiguration(
      const CameraCapturerConfiguration(
        cameraDirection: CameraDirection.cameraFront,
      ),
    );
    await e.setVideoEncoderConfiguration(
      const VideoEncoderConfiguration(
        dimensions: VideoDimensions(width: 720, height: 1280),
        frameRate: 24,
        bitrate: 0,
        orientationMode: OrientationMode.orientationModeFixedPortrait,
        degradationPreference: DegradationPreference.maintainFramerate,
      ),
    );
    await e.setDefaultAudioRouteToSpeakerphone(true);

    e.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection conn, int elapsed) {
          _joined = true;
          if (kDebugMode) {
            debugPrint(
              '✅ [VideoCallAgora] joined ch=${conn.channelId} uid=${conn.localUid}',
            );
          }
          _notify();
        },
        onUserJoined: (RtcConnection conn, int uid, int elapsed) {
          if (kDebugMode) debugPrint('[VideoCallAgora] Remote joined: $uid');
          _setNotifier(remoteUid, uid);
          _notify();
        },
        onUserOffline: (
          RtcConnection conn,
          int uid,
          UserOfflineReasonType reason,
        ) {
          if (kDebugMode) debugPrint('[VideoCallAgora] Remote offline: $uid');
          if (remoteUid.value == uid) {
            _setNotifier(remoteUid, null);
            _setNotifier(remoteHasVideo, false);
            _setNotifier(remoteHasAudio, false);
            _setNotifier(remoteStreamHealthy, false);
          }
          _notify();
        },
        onConnectionStateChanged: (
          RtcConnection conn,
          ConnectionStateType state,
          ConnectionChangedReasonType reason,
        ) {
          final ok = state == ConnectionStateType.connectionStateConnected;
          if (kDebugMode) {
            debugPrint('[VideoCallAgora] connection=$state ok=$ok');
          }
          _setNotifier(connectionHealthy, ok);
          _notify();
        },
        onRemoteVideoStateChanged: (
          RtcConnection conn,
          int uid,
          RemoteVideoState state,
          RemoteVideoStateReason reason,
          int elapsed,
        ) {
          if (uid != remoteUid.value) return;
          final decoding =
              state == RemoteVideoState.remoteVideoStateDecoding;
          final starting =
              state == RemoteVideoState.remoteVideoStateStarting;
          _setNotifier(remoteHasVideo, decoding || starting);

          // "Healthy" = we're seeing them, OR they deliberately turned
          // their camera off (network fine — don't freeze the timer).
          // A frozen/stopped stream for ANY other reason is a network
          // problem → freeze.
          final byPeerChoice = reason ==
                  RemoteVideoStateReason.remoteVideoStateReasonRemoteMuted ||
              reason ==
                  RemoteVideoStateReason.remoteVideoStateReasonRemoteUnmuted;
          _setNotifier(
            remoteStreamHealthy,
            decoding || starting || byPeerChoice,
          );
          _notify();
        },
        onRemoteAudioStateChanged: (
          RtcConnection conn,
          int uid,
          RemoteAudioState state,
          RemoteAudioStateReason reason,
          int elapsed,
        ) {
          final hasAudio = state == RemoteAudioState.remoteAudioStateDecoding;
          if (uid == remoteUid.value) {
            _setNotifier(remoteHasAudio, hasAudio);
          }
          _notify();
        },
        onLeaveChannel: (RtcConnection conn, RtcStats stats) {
          _joined = false;
          _setNotifier(remoteUid, null);
          _setNotifier(remoteHasVideo, false);
          _setNotifier(remoteHasAudio, false);
          _setNotifier(remoteStreamHealthy, false);
          if (kDebugMode) debugPrint('[VideoCallAgora] left');
          _notify();
        },
        onError: (ErrorCodeType code, String? msg) {
          _lastError = 'Agora error $code ${msg ?? ""}';
          debugPrint('❌ [VideoCallAgora] $_lastError');
          _notify();
        },
        onTokenPrivilegeWillExpire: (RtcConnection conn, String t) {
          if (kDebugMode) {
            debugPrint('[VideoCallAgora] Token expiring soon');
          }
        },
      ),
    );

    // Communication profile has no client-role concept — every joiner
    // publishes and subscribes by default, unlike broadcasting's
    // publisher/audience split.
    await e.joinChannel(
      token: token,
      channelId: channel,
      uid: uid,
      options: const ChannelMediaOptions(
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );
  }

  Future<void> renewToken(String newToken) async {
    try {
      await _engine?.renewToken(newToken);
    } catch (e) {
      debugPrint('❌ [VideoCallAgora] renewToken failed: $e');
    }
  }

  Future<void> setMicEnabled(bool enabled) async {
    if (_disposed || _engine == null) return;
    try {
      _isMicEnabled = enabled;
      await _engine!.muteLocalAudioStream(!enabled);
      _notify();
    } catch (e) {
      debugPrint('❌ [VideoCallAgora] setMicEnabled failed: $e');
    }
  }

  Future<void> setCameraEnabled(bool enabled) async {
    if (_disposed || _engine == null) return;
    try {
      _isCameraEnabled = enabled;
      await _engine!.muteLocalVideoStream(!enabled);
      _notify();
    } catch (e) {
      debugPrint('❌ [VideoCallAgora] setCameraEnabled failed: $e');
    }
  }

  Future<void> switchCamera() async {
    try {
      await _engine?.switchCamera();
    } catch (e) {
      debugPrint('❌ [VideoCallAgora] switchCamera failed: $e');
    }
  }

  Future<void> leave() async {
    try {
      await _engine?.leaveChannel();
    } catch (e) {
      debugPrint('❌ [VideoCallAgora] leaveChannel failed: $e');
    } finally {
      _joined = false;
      _setNotifier(remoteUid, null);
      _setNotifier(remoteHasVideo, false);
      _setNotifier(remoteHasAudio, false);
      _notify();
    }
  }

  Future<void> disposeEngine() async {
    try {
      await _engine?.release();
    } catch (e) {
      debugPrint('❌ [VideoCallAgora] disposeEngine failed: $e');
    } finally {
      _engine = null;
      _channelId = null;
      _localUid = null;
      _lastError = null;
      _joined = false;
      _isMicEnabled = true;
      _isCameraEnabled = true;
      _setNotifier(remoteUid, null);
      _setNotifier(remoteHasVideo, false);
      _setNotifier(remoteHasAudio, false);
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    try {
      remoteUid.dispose();
    } catch (_) {}
    try {
      remoteHasVideo.dispose();
    } catch (_) {}
    try {
      remoteHasAudio.dispose();
    } catch (_) {}
    try {
      connectionHealthy.dispose();
    } catch (_) {}
    try {
      remoteStreamHealthy.dispose();
    } catch (_) {}
    super.dispose();
  }

  // ── Widget helpers ─────────────────────────────────────────────────

  Widget localPreview() {
    final e = _engine;
    if (e == null) {
      return const ColoredBox(color: Colors.black);
    }
    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: e,
        canvas: const VideoCanvas(uid: 0),
      ),
    );
  }

  Widget remoteView() {
    final e = _engine;
    final ch = _channelId;
    final uid = remoteUid.value;
    if (e == null || ch == null || uid == null) {
      return const ColoredBox(color: Colors.black);
    }
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: e,
        canvas: VideoCanvas(uid: uid),
        connection: RtcConnection(channelId: ch),
      ),
    );
  }
}