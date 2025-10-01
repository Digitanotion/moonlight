// lib/core/services/agora_service.dart
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

// Add this state class at the top level, outside AgoraService
class RemoteUserState {
  final int uid;
  final bool hasVideo;
  final bool hasAudio;
  final bool joined;

  const RemoteUserState({
    required this.uid,
    required this.hasVideo,
    required this.hasAudio,
    required this.joined,
  });

  RemoteUserState copyWith({bool? hasVideo, bool? hasAudio, bool? joined}) {
    return RemoteUserState(
      uid: uid,
      hasVideo: hasVideo ?? this.hasVideo,
      hasAudio: hasAudio ?? this.hasAudio,
      joined: joined ?? this.joined,
    );
  }
}

/// AgoraService for hosting (Broadcaster).
class AgoraService with ChangeNotifier {
  RtcEngine? _engine;

  // Session state
  bool _joined = false;
  bool _previewing = false;

  String? _appId;
  String? _channelId;
  String? _token;

  String? _uidType; // "uid" | "userAccount"
  String? _userAccount; // set only when uidType == userAccount
  int? _localUid; // set only when uidType == uid

  String? _lastError;
  String? get lastError => _lastError;

  bool get joined => _joined;
  String? get channelId => _channelId;
  RtcEngine? get engine => _engine;

  // Primary remote publisher (your single guest). Null when none.
  final ValueNotifier<int?> primaryRemoteUid = ValueNotifier<int?>(null);
  final ValueNotifier<bool> _remoteHasVideo = ValueNotifier<bool>(false);

  bool get remoteHasVideo => _remoteHasVideo.value;

  // Enhanced remote user tracking
  final ValueNotifier<Map<int, RemoteUserState>> remoteUsers =
      ValueNotifier<Map<int, RemoteUserState>>({});

  // Legacy tracking maps (keep for compatibility if needed elsewhere)
  final Map<int, bool> _remoteVideoStates = {};
  final Map<int, bool> _remoteAudioStates = {};

  @override
  void dispose() {
    remoteUsers.dispose();
    primaryRemoteUid.dispose();
    _remoteHasVideo.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Pass the exact JSON you showed:
  /// {
  ///   "channel": "live_...",
  ///   "uid_type": "uid",
  ///   "uid": 5,
  ///   "rtc_role": "publisher",
  ///   "agora": { "app_id": "...", "rtc_token": "..." }
  /// }
  Future<void> startPublishingFromStartResponse(
    Map<String, dynamic> resp, {
    bool enablePreview = true,
  }) async {
    final appId = (resp['agora']?['app_id'] as String?) ?? '';
    final token = (resp['agora']?['rtc_token'] as String?) ?? '';
    final channel = (resp['channel'] as String?) ?? '';
    final uidType = ((resp['uid_type'] ?? 'uid').toString());
    final rtcRole = ((resp['rtc_role'] ?? 'publisher').toString());

    // uid can be int or string in the payload—normalize to string here,
    // we'll parse accordingly inside startPublishing().
    final uidVal = resp['uid'];
    final uidStr = uidVal == null ? '' : uidVal.toString();

    // Basic sanity logs (prefix token for safety)
    if (kDebugMode) {
      debugPrint(
        '[Agora] creds: appId=${_safe(appId)} channel=$channel uidType=$uidType uid=$uidStr role=$rtcRole token=${_safe(token)}',
      );
    }

    await startPublishing(
      appId: appId,
      channel: channel,
      token: token,
      uidType: uidType, // "uid" or "userAccount"
      uid: uidStr, // "5" for numeric, "abc-uuid" for userAccount
      role: rtcRole, // "publisher" or "subscriber" (host should be publisher)
      enablePreview: enablePreview,
    );
  }

  /// Core start: initializes engine, sets role to Broadcaster, and joins.
  Future<void> startPublishing({
    required String appId,
    required String channel,
    required String token,
    required String uidType, // "uid" | "userAccount"
    required String uid, // numeric-as-string or account string
    String role = 'publisher',
    bool enablePreview = true,
  }) async {
    _assertInputs(appId, channel, token, uidType, uid);

    // Ensure mic/cam permission
    await _ensurePermissions();

    // If we are already in the exact same session, skip
    final same =
        _engine != null &&
        _joined &&
        _appId == appId &&
        _channelId == channel &&
        _token == token &&
        _uidType == uidType &&
        ((uidType.toLowerCase() == 'useraccount' && _userAccount == uid) ||
            (uidType.toLowerCase() == 'uid' && _localUid == int.tryParse(uid)));

    if (same) {
      if (kDebugMode)
        debugPrint('[Agora] Same session detected, skipping rejoin.');
      return;
    }

    await _leaveIfAny();
    await _disposeIfAny();

    // Create/init engine
    final e = createAgoraRtcEngine();
    _engine = e;
    _appId = appId;
    _channelId = channel;
    _token = token;
    _uidType = uidType;
    _lastError = null;

    await e.initialize(
      RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );

    // Defaults for live
    await e.enableAudio();
    await e.enableVideo();
    // 🔧 Lock front camera & set encoder BEFORE preview
    await e.setCameraCapturerConfiguration(
      const CameraCapturerConfiguration(
        cameraDirection: CameraDirection.cameraFront,
      ),
    );

    // 🔧 720x1280 portrait @ 30fps (good live default)
    await e.setVideoEncoderConfiguration(
      const VideoEncoderConfiguration(
        dimensions: VideoDimensions(width: 720, height: 1280),
        frameRate: 30,
        bitrate: null, // kbps; let Agora auto if you prefer (set null)
        orientationMode: OrientationMode.orientationModeFixedPortrait,
      ),
    );

    await e.setDefaultAudioRouteToSpeakerphone(true);

    // Only enable string UID mode if using userAccount
    if (uidType.toLowerCase() == 'useraccount') {
      await e.setParameters(r'{"rtc.string_uid":true}');
    }

    // Events - FIXED: Correct parameter types for Agora SDK
    e.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection conn, int elapsed) {
          _joined = true;
          if (kDebugMode) {
            debugPrint(
              '✅ [Agora] onJoinChannelSuccess ch=${conn.channelId} localUid=${conn.localUid}',
            );
          }
          notifyListeners();
        },

        onUserJoined: (RtcConnection conn, int remoteUid, int elapsed) {
          if (kDebugMode) {
            debugPrint('[Agora] Remote user joined: $remoteUid');
          }

          // Initialize user state
          remoteUsers.value = {
            ...remoteUsers.value,
            remoteUid: RemoteUserState(
              uid: remoteUid,
              hasVideo: false,
              hasAudio: false,
              joined: true,
            ),
          };

          // Set as primary remote if we don't have one yet
          if (primaryRemoteUid.value == null) {
            primaryRemoteUid.value = remoteUid;
            if (kDebugMode) {
              debugPrint('[Agora] Setting primary remote UID: $remoteUid');
            }
          }

          notifyListeners();
        },

        onUserOffline:
            (RtcConnection conn, int remoteUid, UserOfflineReasonType reason) {
              if (kDebugMode) {
                debugPrint(
                  '[Agora] Remote user offline: $remoteUid, reason: $reason',
                );
              }

              // Remove from tracking
              remoteUsers.value = Map.from(remoteUsers.value)
                ..remove(remoteUid);

              // Clear primary if this was the primary
              if (primaryRemoteUid.value == remoteUid) {
                primaryRemoteUid.value = null;
                _remoteHasVideo.value = false;
              }

              notifyListeners();
            },

        onRemoteVideoStateChanged:
            (
              RtcConnection conn,
              int remoteUid,
              RemoteVideoState state,
              RemoteVideoStateReason reason,
              int elapsed,
            ) {
              if (kDebugMode) {
                debugPrint(
                  '[Agora] Remote video state changed - UID: $remoteUid, State: $state, Reason: $reason',
                );
              }

              final hasVideo =
                  state == RemoteVideoState.remoteVideoStateDecoding ||
                  state == RemoteVideoState.remoteVideoStateStarting;

              // Update user state
              if (remoteUsers.value.containsKey(remoteUid)) {
                remoteUsers.value = {
                  ...remoteUsers.value,
                  remoteUid: remoteUsers.value[remoteUid]!.copyWith(
                    hasVideo: hasVideo,
                  ),
                };
              }

              // Update primary remote video state
              if (remoteUid == primaryRemoteUid.value) {
                _remoteHasVideo.value = hasVideo;
                if (kDebugMode) {
                  debugPrint('[Agora] Primary remote video state: $hasVideo');
                }
              }

              notifyListeners();
            },

        onRemoteAudioStateChanged:
            (
              RtcConnection conn,
              int remoteUid,
              RemoteAudioState state,
              RemoteAudioStateReason reason,
              int elapsed,
            ) {
              final hasAudio =
                  state == RemoteAudioState.remoteAudioStateDecoding;

              // Update user state
              if (remoteUsers.value.containsKey(remoteUid)) {
                remoteUsers.value = {
                  ...remoteUsers.value,
                  remoteUid: remoteUsers.value[remoteUid]!.copyWith(
                    hasAudio: hasAudio,
                  ),
                };
              }

              notifyListeners();
            },

        // FIXED: Correct parameter types for local audio state
        onLocalAudioStateChanged:
            (
              RtcConnection conn,
              LocalAudioStreamState state,
              LocalAudioStreamReason error,
            ) {
              debugPrint('[Agora] localAudio state=$state error=$error');
            },

        // FIXED: Correct parameter types for camera exposure (int, int, int, int)
        onCameraExposureAreaChanged: (int x, int y, int width, int height) {
          debugPrint(
            '[Agora] camera exposure area changed: x=$x, y=$y, w=$width, h=$height',
          );
        },

        onLeaveChannel: (RtcConnection conn, RtcStats stats) {
          _joined = false;
          primaryRemoteUid.value = null;
          _remoteHasVideo.value = false;
          remoteUsers.value = {};
          if (kDebugMode) {
            debugPrint('[Agora] onLeaveChannel ch=${conn.channelId}');
          }
          notifyListeners();
        },

        onError: (ErrorCodeType code, String? msg) {
          _lastError = 'Agora error $code ${msg ?? ""}';
          debugPrint('❌ $_lastError');
          debugPrint(
            '[Agora] DIAG appId=${_safe(_appId)} ch=$_channelId uidType=$_uidType userAccount=$_userAccount localUid=$_localUid token=${_safe(_token)}',
          );
          notifyListeners();
        },

        onTokenPrivilegeWillExpire: (RtcConnection conn, String t) {
          if (kDebugMode)
            debugPrint(
              '[Agora] Token will expire soon — call renewToken(newToken).',
            );
        },

        onConnectionStateChanged:
            (
              RtcConnection conn,
              ConnectionStateType s,
              ConnectionChangedReasonType r,
            ) {
              if (kDebugMode)
                debugPrint('[Agora] connection state=$s reason=$r');
            },
      ),
    );

    // Role: host is Broadcaster (must match your token role=publisher)
    await e.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

    // Optional local preview before join
    if (enablePreview) {
      await e.startPreview();
      _previewing = true;
    }

    // Channel options: Broadcaster publishing both tracks
    const options = ChannelMediaOptions(
      publishCameraTrack: true,
      publishMicrophoneTrack: true,
      clientRoleType: ClientRoleType.clientRoleBroadcaster,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    );

    // UID handling
    if (uidType.toLowerCase() == 'useraccount') {
      _userAccount = uid;
      _localUid = null;
      await e.registerLocalUserAccount(appId: appId, userAccount: uid);
      await e.joinChannel(
        token: token,
        channelId: channel,
        uid: 0,
        options: options,
      );
    } else {
      // numeric "uid"
      final n = int.tryParse(uid);
      if (n == null) {
        throw ArgumentError(
          'uid_type was "uid" but uid="$uid" is not an integer.',
        );
      }
      _localUid = n;
      _userAccount = null;
      await e.joinChannel(
        token: token,
        channelId: channel,
        uid: n,
        options: options,
      );
    }
  }

  /// Renew token when backend refreshes it.
  Future<void> renewToken(String newToken) async {
    _token = newToken;
    await _engine?.renewToken(newToken);
    if (kDebugMode)
      debugPrint('[Agora] renewToken ok token=${_safe(newToken)}');
  }

  /// Toggle mic (true = ON/publishing)
  Future<void> setMicEnabled(bool enabled) async {
    final e = _engine;
    if (e == null) return;
    await e.muteLocalAudioStream(!enabled);
  }

  /// Toggle camera (true = ON/publishing)
  Future<void> setCameraEnabled(bool enabled) async {
    final e = _engine;
    if (e == null) return;
    await e.muteLocalVideoStream(!enabled);
    if (enabled && !_previewing) {
      await e.startPreview();
      _previewing = true;
    } else if (!enabled && _previewing) {
      await e.stopPreview();
      _previewing = false;
    }
  }

  Future<void> switchCamera() async {
    await _engine?.switchCamera();
  }

  // Make sure we reset on leave
  Future<void> leave() async {
    try {
      await _engine?.leaveChannel();
    } finally {
      _joined = false;
      primaryRemoteUid.value = null;
      _remoteHasVideo.value = false;
      notifyListeners();
    }
  }

  Future<void> disposeEngine() async {
    try {
      if (_previewing) {
        await _engine?.stopPreview();
        _previewing = false;
      }
      await _engine?.release();
    } finally {
      _engine = null;
      _appId = null;
      _channelId = null;
      _token = null;
      _uidType = null;
      _userAccount = null;
      _localUid = null;
      _lastError = null;
      _joined = false;
      primaryRemoteUid.value = null;
      _remoteHasVideo.value = false;
      notifyListeners();
    }
  }

  /// Clear remote guest explicitly (e.g., when host returns them to viewer)
  void clearGuest() {
    primaryRemoteUid.value = null;
    _remoteHasVideo.value = false;
  }

  // Render local preview (uid:0 canvas is standard for local view)
  Widget localPreview({double? width, double? height}) {
    final e = _engine;
    if (e == null)
      return const SizedBox.expand(child: ColoredBox(color: Colors.black));
    return SizedBox(
      width: width,
      height: height,
      child: AgoraVideoView(
        controller: VideoViewController(
          useFlutterTexture: true,
          rtcEngine: e,
          canvas: const VideoCanvas(uid: 0),
        ),
      ),
    );
  }

  // Render a remote user (for co-host later)
  Widget remoteView(int remoteUid) {
    final e = _engine;
    final ch = _channelId;
    if (e == null || ch == null) return const SizedBox.shrink();
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: e,
        useFlutterTexture: true,
        canvas: VideoCanvas(uid: remoteUid),
        connection: RtcConnection(channelId: ch),
      ),
    );
  }

  /// Render the primary remote (guest). Black if none.
  Widget primaryRemoteView() {
    final e = _engine;
    final ch = _channelId;

    if (e == null || ch == null || primaryRemoteUid.value == null) {
      return _buildBlackPlaceholder('No guest');
    }

    return ValueListenableBuilder<int?>(
      valueListenable: primaryRemoteUid,
      builder: (_, remoteUid, __) {
        if (remoteUid == null) {
          return _buildBlackPlaceholder('No guest');
        }

        return ValueListenableBuilder<bool>(
          valueListenable: _remoteHasVideo,
          builder: (_, hasVideo, __) {
            if (!hasVideo) {
              return _buildBlackPlaceholder('Guest video\nconnecting...');
            }

            return AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: e,
                useFlutterTexture: true,
                canvas: VideoCanvas(uid: remoteUid),
                connection: RtcConnection(channelId: ch),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBlackPlaceholder(String text) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
      ),
    );
  }

  // Method to explicitly set a guest (useful for manual guest management)
  void setPrimaryGuest(int remoteUid) {
    if (remoteUsers.value.containsKey(remoteUid)) {
      primaryRemoteUid.value = remoteUid;
      _remoteHasVideo.value = remoteUsers.value[remoteUid]!.hasVideo;
      if (kDebugMode) {
        debugPrint('[Agora] Manually set primary guest: $remoteUid');
      }
      notifyListeners();
    }
  }

  // Get all remote users for debugging
  List<int> get remoteUserIds => remoteUsers.value.keys.toList();

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<void> _ensurePermissions() async {
    final statuses = await [Permission.microphone, Permission.camera].request();
    final denied = statuses.values.any(
      (s) => s.isDenied || s.isPermanentlyDenied || s.isRestricted,
    );
    if (denied) throw StateError('Camera/Microphone permission denied');
  }

  void _assertInputs(
    String appId,
    String channel,
    String token,
    String uidType,
    String uid,
  ) {
    if (appId.isEmpty) throw ArgumentError('appId is empty');
    if (channel.isEmpty) throw ArgumentError('channel is empty');
    if (token.isEmpty) throw ArgumentError('token is empty');

    final t = uidType.toLowerCase();
    if (t != 'uid' && t != 'useraccount') {
      throw ArgumentError('uidType must be "uid" or "userAccount"');
    }
    if (t == 'uid' && int.tryParse(uid) == null) {
      throw ArgumentError(
        'uidType "uid" requires integer uid string, got "$uid"',
      );
    }
    if (t == 'useraccount' && uid.trim().isEmpty) {
      throw ArgumentError(
        'uidType "userAccount" requires non-empty uid string',
      );
    }
  }

  String _safe(String? v) {
    if (v == null) return '';
    if (v.length <= 12) return v;
    return '${v.substring(0, 6)}…${v.substring(v.length - 6)}';
  }

  Future<void> _leaveIfAny() async {
    if (_engine != null && _joined) {
      await leave();
    }
  }

  Future<void> _disposeIfAny() async {
    if (_engine != null) {
      await disposeEngine();
    }
  }
}
