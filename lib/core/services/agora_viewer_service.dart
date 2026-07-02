// lib/core/services/agora_viewer_service.dart

import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:moonlight/core/services/agoraPlaceholderWidgets.dart';
import 'package:moonlight/core/services/agora_engine_pool.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:moonlight/features/live_viewer/domain/entities.dart';

typedef TokenRefresher = Future<String> Function(String role);

class AgoraViewerService with ChangeNotifier {
  AgoraViewerService({
    required this.onTokenRefresh,
    required AgoraEnginePool pool,
  }) : _pool = pool;

  final TokenRefresher onTokenRefresh;
  final AgoraEnginePool _pool;

  RtcConnection? _coHostConnection;
  String? _standaloneChannel;
  RtcConnection? _standaloneConnection;

  final ValueNotifier<ConnectionState> _connectionState = ValueNotifier(
    ConnectionState.disconnected,
  );
  ValueListenable<ConnectionState> get connectionState => _connectionState;

  final StreamController<NetworkQuality> _hostQualityCtrl =
      StreamController.broadcast();
  final StreamController<NetworkQuality> _selfQualityCtrl =
      StreamController.broadcast();
  final StreamController<NetworkQuality> _guestQualityCtrl =
      StreamController.broadcast();
  final StreamController<RtcStats> _rtcStatsCtrl =
      StreamController<RtcStats>.broadcast();

  String? _appId;
  bool _joined = false;
  bool _isCoHost = false;
  bool _previewing = false;

  final ValueNotifier<int?> hostUid = ValueNotifier<int?>(null);
  final ValueNotifier<int?> guestUid = ValueNotifier<int?>(null);
  final ValueNotifier<bool> _hasVideo = ValueNotifier<bool>(false);
  ValueListenable<bool> get hostHasVideo => _hasVideo;
  final ValueNotifier<bool> _guestHasVideo = ValueNotifier<bool>(false);
  ValueListenable<bool> get guestHasVideo => _guestHasVideo;

  bool _isMicMuted = true;
  bool _isCamMuted = true;

  RtcStats? _lastRtcStats;
  LocalVideoStats? _lastLocalVideoStats;
  Map<int, RemoteVideoStats> _remoteVideoStats = {};

  Timer? _networkMonitorTimer;
  Timer? _statsUpdateTimer;
  Future<void>? _promoteInFlight;
  bool _handlerRegistered = false;

  bool get isJoined => _joined;
  void setJoined(bool v) => _joined = v;
  bool get isCoHost => _isCoHost;
  String? get channelId => _standaloneChannel;

  RtcEngineEx get engine => _pool.sharedEngine;

  /// When in co-host mode the audience slot was left and replaced by this
  /// broadcaster connection — which still subscribes to host video/audio.
  /// PoolVideoView uses this to render host video while the guest is active.
  RtcConnection? get coHostConnection => _coHostConnection;
  bool get isCoHostActive => _isCoHost && _coHostConnection != null;

  bool get isMicMuted => _isMicMuted;
  bool get isCamMuted => _isCamMuted;

  Stream<NetworkQuality> watchHostNetworkQuality() => _hostQualityCtrl.stream;
  Stream<NetworkQuality> watchSelfNetworkQuality() => _selfQualityCtrl.stream;
  Stream<NetworkQuality> watchGuestNetworkQuality() => _guestQualityCtrl.stream;
  Stream<RtcStats> watchRtcStats() => _rtcStatsCtrl.stream;

  void registerStandaloneEventHandler() {
    if (_handlerRegistered) return;
    _handlerRegistered = true;
    engine.registerEventHandler(
      RtcEngineEventHandler(
        onRtcStats: (RtcConnection connection, RtcStats stats) {
          _lastRtcStats = stats;
          _rtcStatsCtrl.add(stats);
        },

        onLocalVideoStats: (RtcConnection connection, LocalVideoStats stats) {
          _lastLocalVideoStats = stats;
        },

        onRemoteVideoStats: (RtcConnection connection, RemoteVideoStats stats) {
          _remoteVideoStats[stats.uid!.toInt()] = stats;
        },

        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          if (!_isOurConnection(connection)) return;
          _connectionState.value = ConnectionState.connected;
          debugPrint('✅ [Viewer] joined: ch=${connection.channelId}');
          _joined = true;
          notifyListeners();
          _startNetworkMonitoring();
          _startStatsUpdateTimer();
        },

        onRemoteVideoStateChanged: (
          RtcConnection connection,
          int remoteUid,
          RemoteVideoState state,
          RemoteVideoStateReason reason,
          int elapsed,
        ) {
          if (!_isOurConnection(connection)) return;
          final hasVideo =
              state == RemoteVideoState.remoteVideoStateDecoding ||
              state == RemoteVideoState.remoteVideoStateStarting;
          if (hostUid.value == remoteUid) {
            _hasVideo.value = hasVideo;
          } else if (guestUid.value == remoteUid) {
            _guestHasVideo.value = hasVideo;
          } else if (hostUid.value == null && hasVideo) {
            hostUid.value = remoteUid;
            _hasVideo.value = true;
          }
          notifyListeners();
        },

        onNetworkQuality: (
          RtcConnection connection,
          int uid,
          QualityType txQuality,
          QualityType rxQuality,
        ) {
          if (!_isOurConnection(connection)) return;
          if (uid != 0) return;
          _selfQualityCtrl.add(_convertQuality(rxQuality));
        },

        onConnectionStateChanged: (
          RtcConnection connection,
          ConnectionStateType state,
          ConnectionChangedReasonType reason,
        ) {
          if (!_isOurConnection(connection)) return;
          _connectionState.value = _convertConnectionState(state);
          notifyListeners();
        },

        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          if (!_isOurConnection(connection)) return;
          _joined = false;
          _isCoHost = false;
          _previewing = false;
          hostUid.value = null;
          guestUid.value = null;
          _hasVideo.value = false;
          _guestHasVideo.value = false;
          _connectionState.value = ConnectionState.disconnected;
          notifyListeners();
        },

        onError: (ErrorCodeType code, String msg) {
          debugPrint('❌ [Viewer] Agora error: $code $msg');
          _connectionState.value = ConnectionState.failed;
          notifyListeners();
        },

        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          if (!_isOurConnection(connection)) return;
          if (hostUid.value == null) {
            hostUid.value = remoteUid;
          } else if (guestUid.value == null && remoteUid != hostUid.value) {
            guestUid.value = remoteUid;
          }
          notifyListeners();
        },

        onUserOffline: (
          RtcConnection connection,
          int remoteUid,
          UserOfflineReasonType reason,
        ) {
          if (!_isOurConnection(connection)) return;
          if (hostUid.value == remoteUid) {
            hostUid.value = null;
            _hasVideo.value = false;
          } else if (guestUid.value == remoteUid) {
            guestUid.value = null;
            _guestHasVideo.value = false;
          }
          _remoteVideoStats.remove(remoteUid);
          notifyListeners();
        },

        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) async {
          if (!_isOurConnection(connection)) return;
          try {
            final role = _isCoHost ? 'publisher' : 'audience';
            final newToken = await onTokenRefresh(role);
            await engine.updateChannelMediaOptionsEx(
              connection: connection,
              options: ChannelMediaOptions(token: newToken),
            );
          } catch (e) {
            debugPrint('⚠️ [Viewer] token refresh failed: $e');
          }
        },

        onConnectionLost: (RtcConnection connection) {
          if (!_isOurConnection(connection)) return;
          _connectionState.value = ConnectionState.disconnected;
          notifyListeners();
        },

        onRejoinChannelSuccess: (RtcConnection connection, int elapsed) {
          if (!_isOurConnection(connection)) return;
          _connectionState.value = ConnectionState.connected;
          notifyListeners();
        },

        onLocalAudioStats: (RtcConnection connection, LocalAudioStats stats) {},
        onRemoteAudioStats: (RtcConnection connection, RemoteAudioStats stats) {},
      ),
    );
  }

  bool _isOurConnection(RtcConnection conn) {
    if (_standaloneConnection != null &&
        conn.channelId == _standaloneConnection!.channelId &&
        conn.localUid == _standaloneConnection!.localUid) {
      return true;
    }
    if (_coHostConnection != null &&
        conn.channelId == _coHostConnection!.channelId &&
        conn.localUid == _coHostConnection!.localUid) {
      return true;
    }
    return false;
  }

  void _startNetworkMonitoring() {
    _networkMonitorTimer?.cancel();
    _networkMonitorTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => notifyListeners(),
    );
  }

  void _startStatsUpdateTimer() {
    _statsUpdateTimer?.cancel();
    _statsUpdateTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_lastRtcStats != null) notifyListeners();
    });
  }

  // ── Public API ────────────────────────────────────────────────────────────

  Future<void> joinAudience({
    required String appId,
    required String channel,
    required String uidType,
    required String uid,
    required String rtcToken,
  }) async {
    _appId = appId;
    _standaloneChannel = channel;
    _isCoHost = false;
    _connectionState.value = ConnectionState.connecting;

    final localUid = int.tryParse(uid) ?? 0;
    _standaloneConnection = RtcConnection(channelId: channel, localUid: localUid);

    await engine.setVideoEncoderConfiguration(
      const VideoEncoderConfiguration(
        dimensions: VideoDimensions(width: 360, height: 640),
        frameRate: 20,
        bitrate: 300,
        orientationMode: OrientationMode.orientationModeAdaptive,
      ),
    );

    await engine.joinChannelEx(
      token: rtcToken,
      connection: _standaloneConnection!,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleAudience,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
        publishCameraTrack: false,
        publishMicrophoneTrack: false,
      ),
    );

    debugPrint('✅ [Viewer] Joined as audience (standalone): ch=$channel');
  }

  Future<void> promoteToCoHost({
    required String rtcToken,
    String? appId,
    String? channel,
    String? uid,
  }) async {
    if (_promoteInFlight != null) {
      debugPrint('⏳ [Viewer] promoteToCoHost already in flight');
      return _promoteInFlight;
    }
    _promoteInFlight = _promoteInternal(
      rtcToken: rtcToken,
      appId: appId,
      channel: channel,
      uid: uid,
    );
    try {
      await _promoteInFlight;
    } finally {
      _promoteInFlight = null;
    }
  }

  Future<void> _promoteInternal({
    required String rtcToken,
    String? appId,
    String? channel,
    String? uid,
  }) async {
    final targetChannel =
        channel ??
        _pool.slotFor(SlotPosition.current)?.channelId ??
        _standaloneChannel;

    if (targetChannel == null) {
      debugPrint('❌ [Viewer] promoteToCoHost: no target channel');
      return;
    }

    // Use the backend-issued uid directly — the token is uid-bound to
    // baseUid. Using an offset (baseUid + 900000) causes errInvalidToken.
    // To avoid -17 collision with the pool's audience connection (which
    // also holds uid=baseUid on this channel), we leave that connection
    // first, then rejoin as broadcaster. Previous/next slot connections
    // on other channels are completely unaffected.
    final baseUid = int.tryParse(uid ?? '') ?? 0;
    final publishUid = baseUid == 0 ? 1 : baseUid;

    _coHostConnection = RtcConnection(channelId: targetChannel, localUid: publishUid);

    try {
      debugPrint('🔄 [Viewer] Starting promotion to co-host...');
      _connectionState.value = ConnectionState.connecting;

      if (_previewing) {
        await engine.stopPreview();
        _previewing = false;
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Leave the pool's current audience connection so we can rejoin
      // the same channel with the same uid as broadcaster.
      final currentSlotConn = _pool.slotFor(SlotPosition.current)?.connection;
      if (currentSlotConn != null) {
        try {
          await engine.leaveChannelEx(connection: currentSlotConn);
          debugPrint('🔌 [Viewer] Left audience slot before co-host join');
        } catch (e) {
          debugPrint('⚠️ [Viewer] Leave audience slot failed (non-fatal): \$e');
        }
      }

      final statuses = await [Permission.microphone, Permission.camera].request();
      if (statuses.values.any(
        (s) => s.isDenied || s.isPermanentlyDenied || s.isRestricted,
      )) {
        throw StateError('Camera/Microphone permission denied');
      }

      _isMicMuted = true;
      _isCamMuted = true;

      await engine.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 360, height: 640),
          frameRate: 20,
          bitrate: 300,
          orientationMode: OrientationMode.orientationModeFixedPortrait,
        ),
      );

      await engine.enableVideo();
      await engine.setCameraCapturerConfiguration(
        const CameraCapturerConfiguration(cameraDirection: CameraDirection.cameraFront),
      );

      await Future.delayed(const Duration(milliseconds: 150));

      await engine.joinChannelEx(
        token: rtcToken,
        connection: _coHostConnection!,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          // Subscribe to host audio/video so co-host can see/hear the host.
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          // Start with camera AND mic OFF — guest must explicitly unmute.
          // This is enforced both here in ChannelMediaOptions AND via
          // updateChannelMediaOptionsEx after join, so there is no window
          // where the guest is accidentally publishing.
          publishCameraTrack: false,
          publishMicrophoneTrack: false,
        ),
      );

      debugPrint('✅ [Viewer] Co-host joined as broadcaster: ch=$targetChannel uid=$publishUid');

      // Explicitly confirm mute state via updateChannelMediaOptionsEx on
      // the co-host connection — this is the correct Ex-API way to mute
      // a specific connection, NOT the global muteLocalAudioStream which
      // affects all connections and doesn't work reliably with joinChannelEx.
      await engine.updateChannelMediaOptionsEx(
        connection: _coHostConnection!,
        options: const ChannelMediaOptions(
          publishCameraTrack: false,
          publishMicrophoneTrack: false,
        ),
      );

      // Don't start preview until the guest explicitly enables camera.
      // startPreview without publishing is fine for local viewfinder only,
      // but we skip it here since cam is muted — avoids black frame flash.
      _previewing = false;
      _isMicMuted = true;
      _isCamMuted = true;

      debugPrint('✅ [Viewer] Co-host joined — mic/cam OFF until guest enables them');

      // Start local preview so the guest can see themselves in the split
      // screen bottom half. This is viewfinder-only — the camera is NOT
      // publishing yet (publishCameraTrack: false above). The guest must
      // explicitly tap the camera button to start publishing.
      await engine.startPreview();
      _previewing = true;
      debugPrint('✅ [Viewer] Local preview started (viewfinder only, not publishing)');

      _isCoHost = true;
      _connectionState.value = ConnectionState.connected;
      debugPrint('🎤 [Viewer] Successfully promoted to co-host');
      notifyListeners();
    } catch (e, stack) {
      debugPrint('❌ [Viewer] Promotion failed: $e');
      debugPrint('Stack: $stack');
      _connectionState.value = ConnectionState.failed;
      _coHostConnection = null;
      try {
        await demoteToAudience();
      } catch (recoveryError) {
        debugPrint('❌ [Viewer] Recovery also failed: $recoveryError');
      }
      rethrow;
    }
  }

  Future<void> demoteToAudience() async {
    try {
      debugPrint('🔄 [Viewer] Starting demotion to audience...');
      _connectionState.value = ConnectionState.connecting;

      if (_previewing) {
        await engine.stopPreview();
        _previewing = false;
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (_coHostConnection != null) {
        await engine.leaveChannelEx(connection: _coHostConnection!);
        _coHostConnection = null;
      }

      _isCoHost = false;
      _isMicMuted = true;
      _isCamMuted = true;

      // After leaving co-host, mark the current pool slot as needing
      // a rejoin so the viewer can watch the host again. The pager's
      // next setInitialWindow / rotate call will re-join automatically.
      // For immediate rejoin, reset the slot so PoolVideoView triggers
      // a fresh joinChannelEx on the next token fetch.
      _pool.slotFor(SlotPosition.current)?.resetForNewJoin();

      debugPrint('✅ [Viewer] Successfully demoted to audience');
      _connectionState.value = ConnectionState.connected;
      notifyListeners();
    } catch (e, stack) {
      debugPrint('❌ [Viewer] Demotion failed: $e');
      debugPrint('Stack: $stack');
      _connectionState.value = ConnectionState.failed;
      rethrow;
    }
  }

  Future<void> _enforceMuteState() async {
    if (!_isCoHost || _coHostConnection == null) return;
    try {
      // In the joinChannelEx (Ex API) architecture, per-connection publish
      // state must be set via updateChannelMediaOptionsEx — NOT via the
      // global muteLocalAudioStream/muteLocalVideoStream which affects all
      // connections and doesn't reliably control a specific Ex connection.
      await engine.updateChannelMediaOptionsEx(
        connection: _coHostConnection!,
        options: ChannelMediaOptions(
          publishCameraTrack: !_isCamMuted,
          publishMicrophoneTrack: !_isMicMuted,
        ),
      );

      // Camera preview (local viewfinder) — keep it running regardless of
      // mute state so the guest always sees themselves in the split screen.
      // We only stop the preview on full demotion (demoteToAudience).
      if (!_previewing) {
        await engine.enableVideo();
        await engine.startPreview();
        _previewing = true;
      }

      await Future.delayed(const Duration(milliseconds: 100));
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to enforce mute state: $e');
    }
  }

  Future<void> setMicEnabled(bool on) async {
    try {
      _isMicMuted = !on;
      await _enforceMuteState();
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to set mic enabled: $e');
      rethrow;
    }
  }

  Future<void> setCamEnabled(bool on) async {
    try {
      _isCamMuted = !on;
      await _enforceMuteState();
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to set camera enabled: $e');
      rethrow;
    }
  }

  Future<void> leave() async {
    try {
      if (_previewing) {
        await engine.stopPreview();
        _previewing = false;
      }
      if (_coHostConnection != null) {
        await engine.leaveChannelEx(connection: _coHostConnection!);
        _coHostConnection = null;
      }
      if (_standaloneConnection != null) {
        await engine.leaveChannelEx(connection: _standaloneConnection!);
        _standaloneConnection = null;
      }
    } finally {
      _joined = false;
      _isCoHost = false;
      hostUid.value = null;
      guestUid.value = null;
      _hasVideo.value = false;
      _guestHasVideo.value = false;
      _connectionState.value = ConnectionState.disconnected;
      _lastRtcStats = null;
      _remoteVideoStats.clear();
      notifyListeners();
    }
  }

  Future<void> renewToken(String newToken) async {
    final conn = _standaloneConnection ?? _coHostConnection;
    if (conn == null) return;
    await engine.updateChannelMediaOptionsEx(
      connection: conn,
      options: ChannelMediaOptions(token: newToken),
    );
  }

  Future<void> muteAllRemoteAudio(bool mute) async {
    try {
      await engine.muteAllRemoteAudioStreams(mute);
    } catch (e) {
      debugPrint('⚠️ muteAllRemoteAudio error: $e');
    }
  }

  // ── Video rendering ───────────────────────────────────────────────────────

  Widget buildHostVideo() {
    final ch = _standaloneChannel;
    final conn = _standaloneConnection;
    if (ch == null || conn == null) {
      return buildBlackPlaceholder('No engine or channel');
    }

    return ValueListenableBuilder<int?>(
      valueListenable: hostUid,
      builder: (_, remote, __) {
        if (remote == null) return buildBlackPlaceholder('Waiting for host...');
        return ValueListenableBuilder<bool>(
          valueListenable: _hasVideo,
          builder: (_, hasVideo, __) {
            if (!hasVideo) return buildConnectingPlaceholder('Host');
            return Container(
              color: Colors.black,
              child: AgoraVideoView(
                key: ValueKey('host_${remote}_${_isCoHost}_$_joined'),
                controller: VideoViewController.remote(
                  rtcEngine: engine,
                  useFlutterTexture: true,
                  canvas: VideoCanvas(uid: remote),
                  connection: conn,
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Called by the pool when a second remote uid joins the current channel
  /// (the co-host/guest). Propagated so DynamicSplitScreen can render it.
  void setGuestUid(int uid) {
    if (guestUid.value != uid) {
      guestUid.value = uid;
      notifyListeners();
    }
  }

  /// Pool-mode variant of buildGuestVideo. Uses an explicit engine +
  /// connection (the pool's current slot) since _standaloneConnection
  /// is null in pool mode and buildGuestVideo() would return null.
  Widget? buildGuestVideoWithConnection(
    RtcConnection? connection,
    RtcEngineEx rtcEngine,
  ) {
    final gid = guestUid.value;
    if (connection == null || gid == null) return null;

    return ValueListenableBuilder<bool>(
      valueListenable: _guestHasVideo,
      builder: (_, hasVideo, __) {
        if (!hasVideo) return buildConnectingPlaceholder('Guest');
        return Container(
          color: Colors.black,
          child: AgoraVideoView(
            key: ValueKey('guest_pool_${gid}_$_isCoHost'),
            controller: VideoViewController.remote(
              rtcEngine: rtcEngine,
              useFlutterTexture: true,
              canvas: VideoCanvas(uid: gid),
              connection: connection,
            ),
          ),
        );
      },
    );
  }

  Widget buildGuestVideo() {
    final ch = _standaloneChannel;
    final conn = _standaloneConnection;
    final gid = guestUid.value;
    if (ch == null || conn == null || gid == null) {
      return buildVideoPlaceholder('Waiting for guest...');
    }

    return ValueListenableBuilder<bool>(
      valueListenable: _guestHasVideo,
      builder: (_, hasVideo, __) {
        if (!hasVideo) return buildConnectingPlaceholder('Guest');
        return Container(
          color: Colors.black,
          child: AgoraVideoView(
            key: ValueKey('guest_${gid}_$_isCoHost'),
            controller: VideoViewController.remote(
              rtcEngine: engine,
              useFlutterTexture: true,
              canvas: VideoCanvas(uid: gid),
              connection: conn,
            ),
          ),
        );
      },
    );
  }

  Widget? buildLocalPreview() {
    if (!_isCoHost) return null;
    // Always render the local view widget when co-host. Agora renders
    // blank frames when the camera is muted/stopped — that's correct
    // behaviour (shows a black box). We never return null here so the
    // split screen always has a surface to paint onto.
    return Container(
      color: Colors.black,
      child: AgoraVideoView(
        key: const ValueKey('local_preview'),
        controller: VideoViewController(
          rtcEngine: engine,
          useFlutterTexture: true,
          canvas: const VideoCanvas(uid: 0),
        ),
      ),
    );
  }

  Widget? localPreviewBubble({double w = 110, double h = 160}) {
    if (!_isCoHost) return null;
    return SizedBox(
      width: w,
      height: h,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AgoraVideoView(
          controller: VideoViewController(
            rtcEngine: engine,
            useFlutterTexture: true,
            canvas: const VideoCanvas(uid: 0),
          ),
        ),
      ),
    );
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  Future<void> disposeEngine() async {
    _networkMonitorTimer?.cancel();
    _statsUpdateTimer?.cancel();
    _hostQualityCtrl.close();
    _selfQualityCtrl.close();
    _guestQualityCtrl.close();
    _rtcStatsCtrl.close();
    await leave();
  }

  void debugState() {
    debugPrint('''
=== AgoraViewerService State ===
Joined: $_joined
IsCoHost: $_isCoHost
StandaloneChannel: $_standaloneChannel
CoHostConnection: ${_coHostConnection?.channelId} uid=${_coHostConnection?.localUid}
Engine exists: ${_pool.isInitialized}
===============================''');
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  NetworkQuality _convertQuality(QualityType q) => switch (q) {
    QualityType.qualityExcellent => NetworkQuality.excellent,
    QualityType.qualityGood => NetworkQuality.good,
    QualityType.qualityPoor ||
    QualityType.qualityBad ||
    QualityType.qualityVbad => NetworkQuality.poor,
    QualityType.qualityDown => NetworkQuality.disconnected,
    _ => NetworkQuality.unknown,
  };

  ConnectionState _convertConnectionState(ConnectionStateType state) =>
      switch (state) {
        ConnectionStateType.connectionStateConnected => ConnectionState.connected,
        ConnectionStateType.connectionStateConnecting => ConnectionState.connecting,
        ConnectionStateType.connectionStateReconnecting => ConnectionState.reconnecting,
        ConnectionStateType.connectionStateDisconnected => ConnectionState.disconnected,
        ConnectionStateType.connectionStateFailed => ConnectionState.failed,
        _ => ConnectionState.disconnected,
      };

  Future<ConnectionStats> getConnectionStats() async => ConnectionStats(
    bitrate: _lastRtcStats?.txKBitRate?.toDouble() ?? 0,
    packetLoss: _lastRtcStats?.rxPacketLossRate?.toDouble() ?? 0,
    latency: _lastRtcStats?.lastmileDelay?.toDouble() ?? 0,
    jitter: _lastRtcStats?.txPacketLossRate?.toDouble() ?? 0,
    timestamp: DateTime.now(),
  );
}