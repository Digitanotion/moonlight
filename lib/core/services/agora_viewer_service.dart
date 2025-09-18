// lib/core/services/agora_viewer_service.dart
import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

typedef TokenRefresher =
    Future<String> Function(String role); // 'audience' | 'publisher'

/// Viewer RTC: join as audience, and promote to co-host (publisher) when accepted.
/// - No permissions required for audience
/// - Requests mic/cam only when promoted
/// - Handles token refresh via [onTokenRefresh]
class AgoraViewerService with ChangeNotifier {
  AgoraViewerService({required this.onTokenRefresh});

  final TokenRefresher onTokenRefresh;

  RtcEngine? _engine;

  String? _appId;
  String? _channel;
  String? _uidType; // 'userAccount' | 'uid'
  String? _uid; // userAccount value or numeric (as string)
  int? _localNumericUid;

  bool _joined = false;
  bool _isCoHost = false;
  bool _previewing = false;

  // First remote uid treated as the “host” stream for the background
  final ValueNotifier<int?> hostUid = ValueNotifier<int?>(null);

  // ---------------- Getters ----------------
  bool get isJoined => _joined;
  bool get isCoHost => _isCoHost;
  String? get channelId => _channel;
  RtcEngine? get engine => _engine;

  // ---------------- Engine lifecycle ----------------
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

    // Route audio through speaker for better UX on phones
    await e.setDefaultAudioRouteToSpeakerphone(true);

    e.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (conn, elapsed) {
          _joined = true;
          if (kDebugMode) {
            debugPrint(
              '✅ [Viewer] joined: ch=${conn.channelId} localUid=${conn.localUid}',
            );
          }
          notifyListeners();
        },
        onLeaveChannel: (conn, stats) {
          _joined = false;
          _isCoHost = false;
          _previewing = false;
          hostUid.value = null;
          if (kDebugMode) {
            debugPrint('🚪 [Viewer] left: ch=${conn.channelId}');
          }
          notifyListeners();
        },
        onError: (code, msg) {
          debugPrint('❌ [Viewer] Agora error: $code ${msg ?? ""}');
        },
        onUserJoined: (conn, remoteUid, elapsed) {
          // Consider the first remote as host camera feed
          hostUid.value ??= remoteUid;
          if (kDebugMode) {
            debugPrint('👤 [Viewer] remote joined: $remoteUid');
          }
        },
        onUserOffline: (conn, remoteUid, reason) {
          if (hostUid.value == remoteUid) {
            hostUid.value = null;
          }
          if (kDebugMode) {
            debugPrint('👤 [Viewer] remote left: $remoteUid reason=$reason');
          }
        },
        onTokenPrivilegeWillExpire: (conn, token) async {
          try {
            final role = _isCoHost ? 'publisher' : 'audience';
            final newToken = await onTokenRefresh(role);
            await _engine?.renewToken(newToken);
            if (kDebugMode) debugPrint('🔄 [Viewer] token renewed ($role)');
          } catch (e) {
            debugPrint('⚠️ [Viewer] token refresh failed: $e');
          }
        },
        onConnectionStateChanged: (conn, state, reason) {
          if (kDebugMode) {
            debugPrint('🔌 [Viewer] connState=$state reason=$reason');
          }
        },
      ),
    );
  }

  // ---------------- Public API ----------------

  /// Join the livestream as **Audience** (watch-only).
  /// - [uidType]: 'userAccount' | 'uid'
  /// - [uid]: when uidType == 'uid', pass numeric as string (e.g. "12"); when 'userAccount', pass account string.
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

    await _init(appId);

    final e = _engine!;
    await e.setClientRole(role: ClientRoleType.clientRoleAudience);
    await e.enableVideo();

    // Enable string UID mode only when needed
    if (uidType.toLowerCase() == 'useraccount') {
      await e.setParameters(r'{"rtc.string_uid":true}');
    }

    const audienceOptions = ChannelMediaOptions(
      clientRoleType: ClientRoleType.clientRoleAudience,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      autoSubscribeAudio: true,
      autoSubscribeVideo: true,
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
  }

  /// Promote to co-host (publisher) after the host accepts your request.
  /// Requires mic & camera permissions.
  Future<void> promoteToCoHost({required String rtcToken}) async {
    final e = _engine;
    if (e == null || !_joined) return;

    // Ask for permissions only when publishing
    final statuses = await [Permission.microphone, Permission.camera].request();
    if (statuses.values.any(
      (s) => s.isDenied || s.isPermanentlyDenied || s.isRestricted,
    )) {
      throw StateError('Camera/Microphone permission denied');
    }

    // Role → Broadcaster
    await e.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await e.enableVideo();

    // Encoder config suitable for portrait live
    await e.setVideoEncoderConfiguration(
      const VideoEncoderConfiguration(
        dimensions: VideoDimensions(width: 720, height: 1280),
        frameRate: 30,
        bitrate: 1800,
        orientationMode: OrientationMode.orientationModeFixedPortrait,
      ),
    );

    // Start local preview (so user sees themselves)
    await e.startPreview();
    _previewing = true;

    // Begin publishing
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

    // Switch to publisher token
    await e.renewToken(rtcToken);

    _isCoHost = true;
    if (kDebugMode) debugPrint('🎤 [Viewer] promoted to co-host');
    notifyListeners();
  }

  /// Render the host's remote video as the background.
  /// Falls back to a black fill until a remote host is detected.
  Widget hostVideoView() {
    final e = _engine;
    final ch = _channel;
    if (e == null || ch == null) {
      return const SizedBox.expand(child: ColoredBox(color: Colors.black));
    }
    return ValueListenableBuilder<int?>(
      valueListenable: hostUid,
      builder: (_, remote, __) {
        if (remote == null) {
          return const SizedBox.expand(child: ColoredBox(color: Colors.black));
        }
        return AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: e,
            connection: RtcConnection(channelId: ch),
            canvas: VideoCanvas(uid: remote),
          ),
        );
      },
    );
  }

  /// Small local preview bubble when co-hosting.
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
            // Local preview uses uid:0 canvas
            canvas: const VideoCanvas(uid: 0),
          ),
        ),
      ),
    );
  }

  /// Leave the channel (keeps engine for potential re-join).
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
      notifyListeners();
    }
  }

  /// Dispose the engine completely (call when screen is closed).
  Future<void> disposeEngine() async {
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
      notifyListeners();
    }
  }
}
