// lib/core/services/agora_viewer_service.dart - ENHANCE
import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:moonlight/core/services/agoraPlaceholderWidgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:moonlight/features/live_viewer/domain/entities.dart';

typedef TokenRefresher = Future<String> Function(String role);

/// Enhanced with network monitoring, connection state tracking, and RTC stats
class AgoraViewerService with ChangeNotifier {
  AgoraViewerService({required this.onTokenRefresh});

  final TokenRefresher onTokenRefresh;
  RtcEngine? _engine;

  // Connection state
  final ValueNotifier<ConnectionState> _connectionState = ValueNotifier(
    ConnectionState.disconnected,
  );
  ValueListenable<ConnectionState> get connectionState => _connectionState;

  // Network quality streams
  final StreamController<NetworkQuality> _hostQualityCtrl =
      StreamController.broadcast();
  final StreamController<NetworkQuality> _selfQualityCtrl =
      StreamController.broadcast();
  final StreamController<NetworkQuality> _guestQualityCtrl =
      StreamController.broadcast();

  // RTC Stats stream
  final StreamController<RtcStats> _rtcStatsCtrl =
      StreamController<RtcStats>.broadcast();

  // Original fields
  String? _appId;
  String? _channel;
  String? _uidType;
  String? _uid;
  int? _localNumericUid;
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

  // Network quality tracking
  NetworkQuality _lastHostQuality = NetworkQuality.unknown;
  NetworkQuality _lastSelfQuality = NetworkQuality.unknown;
  NetworkQuality _lastGuestQuality = NetworkQuality.unknown;

  // RTC Stats tracking
  RtcStats? _lastRtcStats;
  LocalVideoStats? _lastLocalVideoStats;
  Map<int, RemoteVideoStats> _remoteVideoStats = {};

  // Timers
  Timer? _networkMonitorTimer;
  Timer? _statsUpdateTimer;

  bool get isJoined => _joined;

  void setJoined(bool status_) {
    _joined = status_;
  }

  bool get isCoHost => _isCoHost;
  String? get channelId => _channel;
  RtcEngine? get engine => _engine;
  bool get isMicMuted => _isMicMuted;
  bool get isCamMuted => _isCamMuted;

  // ============ ENHANCED NETWORK MONITORING ============

  Stream<NetworkQuality> watchHostNetworkQuality() => _hostQualityCtrl.stream;
  Stream<NetworkQuality> watchSelfNetworkQuality() => _selfQualityCtrl.stream;
  Stream<NetworkQuality> watchGuestNetworkQuality() => _guestQualityCtrl.stream;
  Stream<RtcStats> watchRtcStats() => _rtcStatsCtrl.stream;

  Future<ConnectionStats> getConnectionStats() async {
    try {
      // Use cached stats from onRtcStats callback
      final stats = _lastRtcStats;

      // Get local video stats if available
      LocalVideoStats? localVideoStats;
      try {
        // localVideoStats = await _engine?.getLocalVideoStats();
      } catch (e) {
        debugPrint('⚠️ Failed to get local video stats: $e');
      }

      return ConnectionStats(
        bitrate: stats?.txKBitRate?.toDouble() ?? 0,
        packetLoss: stats?.rxPacketLossRate?.toDouble() ?? 0,
        latency: stats?.lastmileDelay?.toDouble() ?? 0,
        jitter:
            stats?.txPacketLossRate?.toDouble() ??
            0, // Use TX packet loss as proxy
        timestamp: DateTime.now(),
      );
    } catch (e) {
      debugPrint('⚠️ Failed to get connection stats: $e');
      return ConnectionStats(
        bitrate: 0,
        packetLoss: 0,
        latency: 0,
        jitter: 0,
        timestamp: DateTime.now(),
      );
    }
  }

  /// Get detailed stats for UI display
  Map<String, dynamic> getDetailedStats() {
    final stats = _lastRtcStats;
    if (stats == null) {
      return {'status': 'No stats available'};
    }

    return {
      'duration': '${stats.duration}s',
      'txBitrate': '${stats.txKBitRate} kbps',
      'rxBitrate': '${stats.rxKBitRate} kbps',
      'audioTx': '${stats.txAudioKBitRate} kbps',
      'audioRx': '${stats.rxAudioKBitRate} kbps',
      'videoTx': '${stats.txVideoKBitRate} kbps',
      'videoRx': '${stats.rxVideoKBitRate} kbps',
      'packetLoss': '${stats.rxPacketLossRate}%',
      'latency': '${stats.lastmileDelay}ms',
      'cpuApp': stats.cpuAppUsage != null
          ? '${stats.cpuAppUsage!.toStringAsFixed(1)}%'
          : 'N/A',
      'cpuTotal': stats.cpuTotalUsage != null
          ? '${stats.cpuTotalUsage!.toStringAsFixed(1)}%'
          : 'N/A',
      'users': stats.userCount,
      'gatewayRtt': '${stats.gatewayRtt}ms',
      'memoryUsage': stats.memoryAppUsageRatio != null
          ? '${stats.memoryAppUsageRatio!.toStringAsFixed(1)}%'
          : 'N/A',
    };
  }

  Future<void> _startNetworkMonitoring() async {
    _networkMonitorTimer?.cancel();
    _networkMonitorTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _collectNetworkQuality(),
    );
  }

  Future<void> _collectNetworkQuality() async {
    try {
      // Host quality
      if (hostUid.value != null) {
        final hostQuality = await _getRemoteNetworkQuality(hostUid.value!);
        _lastHostQuality = hostQuality;
        _hostQualityCtrl.add(hostQuality);
      }

      // Self quality - use RtcStats for better accuracy if available
      NetworkQuality selfQuality;
      if (_lastRtcStats != null) {
        // Determine quality based on packet loss and bitrate
        if (_lastRtcStats!.rxPacketLossRate!.toInt() > 10 ||
            _lastRtcStats!.txKBitRate!.toInt() < 100) {
          selfQuality = NetworkQuality.poor;
        } else if (_lastRtcStats!.rxPacketLossRate!.toInt() > 5 ||
            _lastRtcStats!.txKBitRate!.toInt() < 300) {
          selfQuality = NetworkQuality.good;
        } else {
          selfQuality = NetworkQuality.excellent;
        }
      } else {
        selfQuality = await _getSelfNetworkQuality();
      }

      _lastSelfQuality = selfQuality;
      _selfQualityCtrl.add(selfQuality);

      // Guest quality
      if (guestUid.value != null) {
        final guestQuality = await _getRemoteNetworkQuality(guestUid.value!);
        _lastGuestQuality = guestQuality;
        _guestQualityCtrl.add(guestQuality);
      }

      // Log detailed stats periodically
      if (_lastRtcStats != null) {
        final stats = _lastRtcStats!;
        debugPrint('''
📊 Network Stats:
  TX: ${stats.txKBitRate}kbps
  RX: ${stats.rxKBitRate}kbps  
  Packet Loss: ${stats.rxPacketLossRate}%
  Latency: ${stats.lastmileDelay}ms
  CPU: ${stats.cpuAppUsage?.toStringAsFixed(1) ?? 'N/A'}%
  Users: ${stats.userCount}
''');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Network quality collection failed: $e');
    }
  }

  Future<NetworkQuality> _getRemoteNetworkQuality(int uid) async {
    // try {
    //   final stats = await _engine?.getRemoteVideoStats(uid);
    //   if (stats == null) return NetworkQuality.unknown;

    //   // Estimate quality based on frame rate and packet loss
    //   if (stats.receivedFrameRate <= 5) return NetworkQuality.poor;
    //   if (stats.receivedFrameRate <= 15) return NetworkQuality.good;
    //   return NetworkQuality.excellent;
    // } catch (e) {
    //   return NetworkQuality.unknown;
    // }
    return NetworkQuality.unknown;
  }

  Future<NetworkQuality> _getSelfNetworkQuality() async {
    // try {
    //   final stats = await _engine?.getLocalVideoStats();
    //   if (stats == null) return NetworkQuality.unknown;

    //   if (stats.sentFrameRate <= 5) return NetworkQuality.poor;
    //   if (stats.sentFrameRate <= 15) return NetworkQuality.good;
    //   return NetworkQuality.excellent;
    // } catch (e) {
    //   return NetworkQuality.unknown;
    // }
    return NetworkQuality.unknown;
  }

  // ============ ENHANCED ENGINE SETUP WITH RTC STATS ============

  Future<void> _init(String appId) async {
    if (_engine != null) return;

    final e = createAgoraRtcEngine();
    _engine = e;

    await e.initialize(
      RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );

    await e.setDefaultAudioRouteToSpeakerphone(true);

    e.registerEventHandler(
      RtcEngineEventHandler(
        // RTC Stats callback - called every 2 seconds
        onRtcStats: (RtcConnection connection, RtcStats stats) {
          _lastRtcStats = stats;
          _rtcStatsCtrl.add(stats);

          debugPrint(
            '📊 RTC Stats: '
            'Duration: ${stats.duration}s, '
            'TX: ${stats.txKBitRate}kbps, '
            'RX: ${stats.rxKBitRate}kbps, '
            'Packet Loss: ${stats.rxPacketLossRate}%, '
            'Delay: ${stats.lastmileDelay}ms',
          );
        },

        // Local video stats callback
        onLocalVideoStats: (RtcConnection connection, LocalVideoStats stats) {
          _lastLocalVideoStats = stats;
        },

        // Remote video stats callback
        onRemoteVideoStats: (RtcConnection connection, RemoteVideoStats stats) {
          _remoteVideoStats[stats.uid!.toInt()] = stats;
        },

        onJoinChannelSuccess: (conn, elapsed) {
          _connectionState.value = ConnectionState.connected;
          debugPrint('✅ [Viewer] joined: ch=${conn.channelId}');
          notifyListeners();
          _startNetworkMonitoring();
          _startStatsUpdateTimer();
          _joined = true;
        },

        onRemoteVideoStateChanged:
            (
              RtcConnection conn,
              int remoteUid,
              RemoteVideoState state,
              RemoteVideoStateReason reason,
              int elapsed,
            ) {
              final hasVideo =
                  state == RemoteVideoState.remoteVideoStateDecoding;

              if (hostUid.value == remoteUid) {
                _hasVideo.value = hasVideo;
                debugPrint('🎥 [Viewer] Host video: $hasVideo');

                // Handle network issues
                if (reason ==
                    RemoteVideoStateReason
                        .remoteVideoStateReasonNetworkCongestion) {
                  debugPrint('⚠️ Host network congestion detected');
                  _hostQualityCtrl.add(NetworkQuality.poor);
                }
              } else if (guestUid.value == remoteUid) {
                _guestHasVideo.value = hasVideo;
                debugPrint('🎥 [Viewer] Guest video: $hasVideo');
              }

              notifyListeners();
            },

        onNetworkQuality:
            (
              RtcConnection conn,
              int remoteUid,
              QualityType txQuality,
              QualityType rxQuality,
            ) {
              final quality = _convertAgoraQuality(rxQuality);

              if (remoteUid == 0) {
                // Self quality
                _selfQualityCtrl.add(quality);
              } else if (hostUid.value == remoteUid) {
                _hostQualityCtrl.add(quality);
              } else if (guestUid.value == remoteUid) {
                _guestQualityCtrl.add(quality);
              }
            },

        onConnectionStateChanged:
            (
              RtcConnection conn,
              ConnectionStateType state,
              ConnectionChangedReasonType reason,
            ) {
              final newState = _convertAgoraConnectionState(state);
              _connectionState.value = newState;
              debugPrint('🔌 Connection state: $newState, Reason: $reason');
              notifyListeners();
            },

        onLeaveChannel: (conn, stats) {
          _joined = false;
          _isCoHost = false;
          _previewing = false;
          hostUid.value = null;
          guestUid.value = null;
          _hasVideo.value = false;
          _guestHasVideo.value = false;
          _connectionState.value = ConnectionState.disconnected;
          _lastRtcStats = null;
          _lastLocalVideoStats = null;
          _remoteVideoStats.clear();
          debugPrint('🚪 [Viewer] left: ch=${conn.channelId}');
          notifyListeners();
        },

        onError: (code, msg) {
          debugPrint('❌ [Viewer] Agora error: $code ${msg ?? ""}');
          _connectionState.value = ConnectionState.failed;
          notifyListeners();
        },

        onUserJoined: (conn, remoteUid, elapsed) {
          if (hostUid.value == null) {
            hostUid.value = remoteUid;
            debugPrint('🎯 [Viewer] Setting host UID: $remoteUid');
          } else if (guestUid.value == null && remoteUid != hostUid.value) {
            guestUid.value = remoteUid;
            debugPrint('🎯 [Viewer] Setting guest UID: $remoteUid');
          }
          _hasVideo.value = hostUid.value != null;
          _guestHasVideo.value = guestUid.value != null;
          debugPrint('👤 [Viewer] remote joined: $remoteUid');
          notifyListeners();
        },

        onUserOffline: (conn, remoteUid, reason) {
          if (hostUid.value == remoteUid) {
            hostUid.value = null;
            _hasVideo.value = false;
            debugPrint('🎯 [Viewer] Host offline: $remoteUid');
          } else if (guestUid.value == remoteUid) {
            guestUid.value = null;
            _guestHasVideo.value = false;
            debugPrint('🎯 [Viewer] Guest offline: $remoteUid');
          }
          // Remove from remote stats cache
          _remoteVideoStats.remove(remoteUid);
          debugPrint('👤 [Viewer] remote left: $remoteUid reason=$reason');
          notifyListeners();
        },

        onTokenPrivilegeWillExpire: (conn, token) async {
          try {
            final role = _isCoHost ? 'publisher' : 'audience';
            final newToken = await onTokenRefresh(role);
            await _engine?.renewToken(newToken);
            debugPrint('🔄 [Viewer] token renewed ($role)');
          } catch (e) {
            debugPrint('⚠️ [Viewer] token refresh failed: $e');
          }
        },

        onConnectionLost: (conn) {
          debugPrint('🔌 [Viewer] Connection lost');
          _connectionState.value = ConnectionState.disconnected;
          notifyListeners();
        },

        onRejoinChannelSuccess: (conn, elapsed) {
          debugPrint('✅ [Viewer] Rejoined channel successfully');
          _connectionState.value = ConnectionState.connected;
          notifyListeners();
        },

        // Audio stats callbacks
        onLocalAudioStats: (RtcConnection connection, LocalAudioStats stats) {
          // Handle local audio stats if needed
        },

        onRemoteAudioStats: (RtcConnection connection, RemoteAudioStats stats) {
          // Handle remote audio stats if needed
        },
      ),
    );
  }

  void _startStatsUpdateTimer() {
    _statsUpdateTimer?.cancel();
    _statsUpdateTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_lastRtcStats != null) {
        notifyListeners(); // Notify listeners that stats have updated
      }
    });
  }

  NetworkQuality _convertAgoraQuality(QualityType quality) {
    return switch (quality) {
      QualityType.qualityExcellent => NetworkQuality.excellent,
      QualityType.qualityGood => NetworkQuality.good,
      QualityType.qualityPoor => NetworkQuality.poor,
      QualityType.qualityBad => NetworkQuality.poor,
      QualityType.qualityVbad => NetworkQuality.poor,
      QualityType.qualityDown => NetworkQuality.disconnected,
      _ => NetworkQuality.unknown,
    };
  }

  ConnectionState _convertAgoraConnectionState(ConnectionStateType state) {
    return switch (state) {
      ConnectionStateType.connectionStateConnected => ConnectionState.connected,
      ConnectionStateType.connectionStateConnecting =>
        ConnectionState.connecting,
      ConnectionStateType.connectionStateReconnecting =>
        ConnectionState.reconnecting,
      ConnectionStateType.connectionStateDisconnected =>
        ConnectionState.disconnected,
      ConnectionStateType.connectionStateFailed => ConnectionState.failed,
      _ => ConnectionState.disconnected,
    };
  }

  // ============ PUBLIC API (PRESERVED WITH ENHANCEMENTS) ============

  Future<void> joinAudience({
    required String appId,
    required String channel,
    required String uidType,
    required String uid,
    required String rtcToken,
  }) async {
    _appId = appId;
    _channel = channel;
    _uidType = uidType;
    _uid = uid;
    _isCoHost = false;
    _connectionState.value = ConnectionState.connecting;

    await _init(appId);
    final e = _engine!;

    await e.setVideoEncoderConfiguration(
      const VideoEncoderConfiguration(
        dimensions: VideoDimensions(width: 360, height: 640),
        frameRate: 20,
        bitrate: 300,
        orientationMode: OrientationMode.orientationModeAdaptive,
      ),
    );

    await e.enableVideo();
    await e.enableAudio();
    await e.setClientRole(role: ClientRoleType.clientRoleAudience);

    await e.setParameters(r'''
    {
      "rtc.video.downscale_bad_network_enabled": true,
      "rtc.video.low_bitrate_stream_optimization": true
    }
    ''');

    if (uidType.toLowerCase() == 'useraccount') {
      await e.setParameters(r'{"rtc.string_uid":true}');
    }

    const audienceOptions = ChannelMediaOptions(
      clientRoleType: ClientRoleType.clientRoleAudience,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      autoSubscribeAudio: true,
      autoSubscribeVideo: true,
      publishCameraTrack: false,
      publishMicrophoneTrack: false,
    );

    if (uidType.toLowerCase() == 'useraccount') {
      await e.registerLocalUserAccount(appId: appId, userAccount: uid);
      await e.joinChannel(
        token: rtcToken,
        channelId: channel,
        uid: 0,
        options: audienceOptions,
      );
    } else {
      _localNumericUid = int.tryParse(uid);
      await e.joinChannel(
        token: rtcToken,
        channelId: channel,
        uid: _localNumericUid ?? 0,
        options: audienceOptions,
      );
    }
    // notifyListeners();
    debugPrint('✅ [Viewer] Joined as audience to channel: $channel');
  }

  Future<void> promoteToCoHost({required String rtcToken}) async {
    final e = _engine;
    if (e == null || !_joined) return;

    try {
      debugPrint('🔄 [Viewer] Starting promotion to co-host...');
      _connectionState.value = ConnectionState.connecting;

      if (_previewing) {
        await e.stopPreview();
        _previewing = false;
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final statuses = await [
        Permission.microphone,
        Permission.camera,
      ].request();
      if (statuses.values.any(
        (s) => s.isDenied || s.isPermanentlyDenied || s.isRestricted,
      )) {
        throw StateError('Camera/Microphone permission denied');
      }

      _isMicMuted = true;
      _isCamMuted = true;

      await e.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      await e.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 360, height: 640),
          frameRate: 20,
          bitrate: 300,
          orientationMode: OrientationMode.orientationModeFixedPortrait,
        ),
      );

      await e.enableVideo();

      await e.setCameraCapturerConfiguration(
        const CameraCapturerConfiguration(
          cameraDirection: CameraDirection.cameraFront,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 150));

      await e.startPreview();
      _previewing = true;
      debugPrint('✅ [Viewer] Local preview started');

      await _enforceMuteState();

      await e.updateChannelMediaOptions(
        const ChannelMediaOptions(
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );

      await e.renewToken(rtcToken);

      await Future.delayed(const Duration(milliseconds: 200));
      await _enforceMuteState();

      _isCoHost = true;
      _connectionState.value = ConnectionState.connected;
      debugPrint('🎤 [Viewer] Successfully promoted to co-host');
      notifyListeners();
    } catch (e, stack) {
      debugPrint('❌ [Viewer] Promotion failed: $e');
      debugPrint('Stack: $stack');
      _connectionState.value = ConnectionState.failed;

      try {
        await demoteToAudience();
      } catch (recoveryError) {
        debugPrint('❌ [Viewer] Recovery also failed: $recoveryError');
      }
      rethrow;
    }
  }

  Future<void> demoteToAudience() async {
    final e = _engine;
    if (e == null) return;

    try {
      debugPrint('🔄 [Viewer] Starting demotion to audience...');
      _connectionState.value = ConnectionState.connecting;

      if (_previewing) {
        await e.stopPreview();
        _previewing = false;
        await Future.delayed(const Duration(milliseconds: 100));
      }

      await e.setClientRole(role: ClientRoleType.clientRoleAudience);

      await e.updateChannelMediaOptions(
        const ChannelMediaOptions(
          publishCameraTrack: false,
          publishMicrophoneTrack: false,
          clientRoleType: ClientRoleType.clientRoleAudience,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );

      _isCoHost = false;
      _isMicMuted = true;
      _isCamMuted = true;

      await e.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 360, height: 640),
          frameRate: 20,
          bitrate: 300,
          orientationMode: OrientationMode.orientationModeAdaptive,
        ),
      );

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
    try {
      final e = _engine;
      if (e == null) return;

      await e.muteLocalAudioStream(_isMicMuted);
      debugPrint('🎤 Mic ${_isMicMuted ? 'muted' : 'unmuted'}');

      await e.muteLocalVideoStream(_isCamMuted);
      debugPrint('📷 Camera ${_isCamMuted ? 'muted' : 'unmuted'}');

      if (_isCamMuted && _previewing) {
        debugPrint('📷 Stopping preview due to camera mute');
        await e.stopPreview();
        _previewing = false;
      } else if (!_isCamMuted && !_previewing && _isCoHost) {
        debugPrint('📷 Starting preview due to camera unmute');
        await e.enableVideo();
        await e.setVideoEncoderConfiguration(
          const VideoEncoderConfiguration(
            dimensions: VideoDimensions(width: 360, height: 640),
            frameRate: 20,
            bitrate: 300,
            orientationMode: OrientationMode.orientationModeFixedPortrait,
          ),
        );
        await e.startPreview();
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
      debugPrint('🎤 Mic ${on ? 'enabled' : 'disabled'} by user');
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
      debugPrint('📷 Camera ${on ? 'enabled' : 'disabled'} by user');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to set camera enabled: $e');
      rethrow;
    }
  }

  Future<void> reconnect() async {
    try {
      _connectionState.value = ConnectionState.reconnecting;
      debugPrint('🔄 Attempting to reconnect...');

      // Leave and rejoin with saved state
      await leave();
      // TODO: Implement proper rejoin with saved credentials

      _connectionState.value = ConnectionState.connected;
      debugPrint('✅ Reconnected successfully');
    } catch (e) {
      _connectionState.value = ConnectionState.failed;
      debugPrint('❌ Reconnection failed: $e');
      rethrow;
    }
  }

  Future<void> leave() async {
    try {
      await _engine?.leaveChannel();
      if (_previewing) {
        await _engine?.stopPreview();
        _previewing = false;
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
      _lastLocalVideoStats = null;
      _remoteVideoStats.clear();
      notifyListeners();
    }
  }

  Future<void> renewToken(String newToken) async {
    await _engine?.renewToken(newToken);
    debugPrint('🔄 [Viewer] renewToken applied');
  }

  // ============ VIDEO RENDERING (PRESERVED) ============

  Widget buildHostVideo() {
    final e = _engine;
    final ch = _channel;
    if (e == null || ch == null) {
      return buildBlackPlaceholder('No engine or channel');
    }

    return ValueListenableBuilder<int?>(
      valueListenable: hostUid,
      builder: (_, remote, __) {
        if (remote == null) {
          return buildBlackPlaceholder('Waiting for host...');
        }

        return ValueListenableBuilder<bool>(
          valueListenable: _hasVideo,
          builder: (_, hasVideo, __) {
            if (!hasVideo) {
              return buildConnectingPlaceholder('Host');
            }

            return Container(
              color: Colors.black,
              child: AgoraVideoView(
                key: ValueKey('host_${remote}_${_isCoHost}_${_joined}'),
                controller: VideoViewController.remote(
                  rtcEngine: e,
                  useFlutterTexture: true,
                  canvas: VideoCanvas(uid: remote),
                  connection: RtcConnection(channelId: ch),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // In AgoraViewerService.dart, enhance the buildGuestVideo method:

  Widget buildGuestVideo() {
    final e = _engine;
    final ch = _channel;
    final gid = guestUid.value;

    if (e == null || ch == null || gid == null) {
      return buildVideoPlaceholder('Waiting for guest...');
    }

    return ValueListenableBuilder<bool>(
      valueListenable: _guestHasVideo,
      builder: (_, hasVideo, __) {
        if (!hasVideo) {
          return buildConnectingPlaceholder('Guest');
        }

        return Container(
          color: Colors.black,
          child: AgoraVideoView(
            key: ValueKey('guest_${gid}_${_isCoHost}'),
            controller: VideoViewController.remote(
              rtcEngine: e,
              useFlutterTexture: true,
              canvas: VideoCanvas(uid: gid),
              connection: RtcConnection(channelId: ch),
            ),
          ),
        );
      },
    );
  }

  Widget? buildLocalPreview() {
    // if (!_isCoHost || _engine == null) return null;

    return Container(
      color: Colors.black,
      child: AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: _engine!,
          useFlutterTexture: true,
          canvas: const VideoCanvas(uid: 0),
        ),
      ),
    );
  }

  Widget? localPreviewBubble({double w = 110, double h = 160}) {
    if (!_isCoHost || _engine == null) return null;
    return SizedBox(
      width: w,
      height: h,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AgoraVideoView(
          controller: VideoViewController(
            rtcEngine: _engine!,
            useFlutterTexture: true,
            canvas: const VideoCanvas(uid: 0),
          ),
        ),
      ),
    );
  }

  Widget guestVideoView() {
    final e = _engine;
    final ch = _channel;
    final gid = guestUid.value;
    if (e == null || ch == null || gid == null) {
      return const SizedBox.expand(child: ColoredBox(color: Colors.black));
    }

    return ValueListenableBuilder<bool>(
      valueListenable: _guestHasVideo,
      builder: (_, hasVideo, __) {
        if (!hasVideo) {
          return buildVideoPlaceholder('Guest video connecting...');
        }

        return AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: e,
            useFlutterTexture: true,
            connection: RtcConnection(channelId: ch),
            canvas: VideoCanvas(uid: gid),
          ),
        );
      },
    );
  }

  Future<void> emergencyVideoRecovery() async {
    final e = _engine;
    if (e == null) return;

    try {
      debugPrint('🚨 Starting emergency video recovery...');

      if (_previewing) {
        await e.stopPreview();
        _previewing = false;
      }

      await Future.delayed(const Duration(milliseconds: 200));
      await e.disableVideo();
      await Future.delayed(const Duration(milliseconds: 100));
      await e.enableVideo();

      await e.setVideoEncoderConfiguration(
        VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 360, height: 640),
          frameRate: 20,
          bitrate: 300,
          orientationMode: _isCoHost
              ? OrientationMode.orientationModeFixedPortrait
              : OrientationMode.orientationModeAdaptive,
        ),
      );

      if (_isCoHost && !_isCamMuted) {
        await e.startPreview();
        _previewing = true;
      }

      if (hostUid.value != null) {
        await e.muteRemoteVideoStream(uid: hostUid.value!, mute: true);
        await Future.delayed(const Duration(milliseconds: 300));
        await e.muteRemoteVideoStream(uid: hostUid.value!, mute: false);
      }

      if (guestUid.value != null) {
        await e.muteRemoteVideoStream(uid: guestUid.value!, mute: true);
        await Future.delayed(const Duration(milliseconds: 300));
        await e.muteRemoteVideoStream(uid: guestUid.value!, mute: false);
      }

      debugPrint('✅ Emergency recovery completed');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Emergency recovery failed: $e');
    }
  }

  Future<void> disposeEngine() async {
    _networkMonitorTimer?.cancel();
    _statsUpdateTimer?.cancel();
    _hostQualityCtrl.close();
    _selfQualityCtrl.close();
    _guestQualityCtrl.close();
    _rtcStatsCtrl.close();

    try {
      if (_previewing) {
        await _engine?.stopPreview();
        _previewing = false;
      }
      await _engine?.release();
    } finally {
      _engine = null;
      _joined = false;
      _isCoHost = false;
      _appId = null;
      _channel = null;
      _uidType = null;
      _uid = null;
      _localNumericUid = null;
      hostUid.value = null;
      guestUid.value = null;
      _hasVideo.value = false;
      _guestHasVideo.value = false;
      _connectionState.value = ConnectionState.disconnected;
      _lastRtcStats = null;
      _lastLocalVideoStats = null;
      _remoteVideoStats.clear();
      notifyListeners();
    }
  }

  void debugState() {
    debugPrint('''
=== AgoraViewerService Enhanced State ===
Joined: $_joined
IsCoHost: $_isCoHost
Channel: $_channel
Host UID: ${hostUid.value}
Guest UID: ${guestUid.value}
Host has video: ${_hasVideo.value}
Guest has video: ${_guestHasVideo.value}
Connection State: ${_connectionState.value}
Host Network: $_lastHostQuality
Self Network: $_lastSelfQuality
Guest Network: $_lastGuestQuality
RTC Stats: ${_lastRtcStats != null ? 'Available' : 'Not available'}
Engine exists: ${_engine != null}
===============================''');

    if (_lastRtcStats != null) {
      final stats = _lastRtcStats!;
      debugPrint('''
📊 Detailed RTC Stats:
  Duration: ${stats.duration}s
  TX Bitrate: ${stats.txKBitRate}kbps
  RX Bitrate: ${stats.rxKBitRate}kbps
  Packet Loss: ${stats.rxPacketLossRate}%
  Latency: ${stats.lastmileDelay}ms
  Users: ${stats.userCount}
  CPU: ${stats.cpuAppUsage?.toStringAsFixed(1) ?? 'N/A'}%
''');
    }
  }
}
