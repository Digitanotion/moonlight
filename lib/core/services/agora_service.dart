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

  // Add mute state tracking
  bool _isMicEnabled = true;
  bool _isCameraEnabled = true;

  // Primary remote publisher (your single guest). Null when none.
  final ValueNotifier<int?> primaryRemoteUid = ValueNotifier<int?>(null);
  final ValueNotifier<bool> _remoteHasVideo = ValueNotifier<bool>(false);

  bool get remoteHasVideo => _remoteHasVideo.value;
  bool get isMicEnabled => _isMicEnabled;
  bool get isCameraEnabled => _isCameraEnabled;
  // Enhanced remote user tracking
  final ValueNotifier<Map<int, RemoteUserState>> remoteUsers =
      ValueNotifier<Map<int, RemoteUserState>>({});

  // Legacy tracking maps (keep for compatibility if needed elsewhere)
  final Map<int, bool> _remoteVideoStates = {};
  final Map<int, bool> _remoteAudioStates = {};

  // ─── Beauty state ───────────────────────────────────────────────────────────
  // Pending-state pattern: latest requested values are always stored here.
  // _isApplyingBeauty guards the Agora SDK call; when it finishes it checks
  // whether a newer request came in and, if so, re-applies immediately.
  // This guarantees the LAST requested state is always ultimately applied,
  // so a quick toggle-off can never be silently dropped.
  bool _isApplyingBeauty = false;
  bool _hasPendingBeauty = false;

  bool _pendingFaceEnabled = false;
  int _pendingFaceLevel = 0;
  bool _pendingBrightenEnabled = false;
  int _pendingBrightenLevel = 0;

  // Expose a notifier so UI can optionally react
  final ValueNotifier<bool> beautyActive = ValueNotifier<bool>(false);

  @override
  void dispose() {
    remoteUsers.dispose();
    primaryRemoteUid.dispose();
    _remoteHasVideo.dispose();
    beautyActive.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Apply beauty options (face clean = smoothing, brighten = lightening).
  /// Uses a pending-state queue so rapid toggles (on→off, slider drags) always
  /// resolve to the latest requested state — preventing the black-screen bug
  /// that occurred when a disable call was dropped by the old cooldown guard.
  ///
  /// IMPORTANT: This method intentionally does NOT touch the camera enabled
  /// state. Toggling the camera inside an effect call was the primary cause of
  /// the black-screen regression.
  Future<void> applyBeauty({
    required bool faceCleanEnabled,
    required int faceCleanLevel,
    required bool brightenEnabled,
    required int brightenLevel,
  }) async {
    // Always store the newest desired state.
    _pendingFaceEnabled = faceCleanEnabled;
    _pendingFaceLevel = faceCleanLevel.clamp(0, 100);
    _pendingBrightenEnabled = brightenEnabled;
    _pendingBrightenLevel = brightenLevel.clamp(0, 100);
    _hasPendingBeauty = true;

    // If a call is already in flight the pending values will be picked up when
    // it completes (see _doApplyBeauty's finally block).
    if (_isApplyingBeauty) {
      debugPrint('[Beauty] Apply in progress – latest state queued');
      return;
    }

    await _doApplyBeauty();
  }

  /// Internal worker that always operates on _pending* values.
  Future<void> _doApplyBeauty() async {
    if (!_hasPendingBeauty) return;
    final e = _engine;
    if (e == null) {
      debugPrint('[Beauty] Engine not available, skipping apply');
      _hasPendingBeauty = false;
      return;
    }

    _isApplyingBeauty = true;
    _hasPendingBeauty = false;

    // Snapshot the values we're about to apply so later pending writes don't
    // mutate under us mid-call.
    final faceEnabled = _pendingFaceEnabled;
    final faceLevel = _pendingFaceLevel;
    final brightenEnabled = _pendingBrightenEnabled;
    final brightenLevel = _pendingBrightenLevel;

    try {
      final smooth = (faceEnabled ? (faceLevel / 100.0) : 0.0).clamp(0.0, 1.0);
      final lighten = (brightenEnabled ? (brightenLevel / 100.0) : 0.0).clamp(
        0.0,
        1.0,
      );

      if (smooth == 0.0 && lighten == 0.0) {
        // Disable beauty completely – this is the path most likely to cause
        // the black screen if interrupted, so we do it in one clean call.
        await e.setBeautyEffectOptions(
          enabled: false,
          options: const BeautyOptions(),
        );
        beautyActive.value = false;
        debugPrint('[Beauty] Disabled successfully');
      } else {
        final options = BeautyOptions(
          smoothnessLevel: smooth,
          lighteningLevel: lighten,
          lighteningContrastLevel:
              LighteningContrastLevel.lighteningContrastNormal,
          rednessLevel: (lighten * 0.12).clamp(0.0, 0.15),
          sharpnessLevel: 0.25 + (smooth * 0.2),
        );
        await e.setBeautyEffectOptions(enabled: true, options: options);
        beautyActive.value = true;
        debugPrint('[Beauty] Applied – smooth=$smooth lighten=$lighten');
      }

      notifyListeners();
    } catch (err, stack) {
      debugPrint('❌ [Beauty] Apply failed: $err');
      debugPrint('$stack');
      _lastError = 'Beauty effects failed: $err';

      // Attempt a clean reset so the camera pipeline isn't left in a bad state.
      try {
        await e.setBeautyEffectOptions(
          enabled: false,
          options: const BeautyOptions(),
        );
        beautyActive.value = false;
        debugPrint('[Beauty] Recovery reset applied');
      } catch (recoveryErr) {
        debugPrint('❌ [Beauty] Recovery also failed: $recoveryErr');
      }

      notifyListeners();
    } finally {
      _isApplyingBeauty = false;

      // If a newer state arrived while we were applying, honour it now.
      if (_hasPendingBeauty) {
        debugPrint('[Beauty] Applying queued pending state');
        // Tiny yield so we don't starve the event loop.
        await Future.delayed(const Duration(milliseconds: 30));
        await _doApplyBeauty();
      }
    }
  }

  // Add a new method to safely reset everything
  Future<void> safeReset() async {
    try {
      // Reset beauty first
      await _engine?.setBeautyEffectOptions(
        enabled: false,
        options: const BeautyOptions(),
      );

      // Ensure camera is enabled
      if (!_isCameraEnabled) {
        await setCameraEnabled(true);
      }

      // Small stabilization delay
      await Future.delayed(const Duration(milliseconds: 300));

      beautyActive.value = false;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Safe reset failed: $e');
      // Try emergency recovery
      try {
        await _engine?.muteLocalVideoStream(false);
        await _engine?.startPreview();
        _previewing = true;
      } catch (_) {}
    }
  }

  /// Reset/disable any beauty options previously applied. Safe no-op if engine absent.
  Future<void> resetBeauty() async {
    // Clear any pending state first so _doApplyBeauty won't re-enable after we reset.
    _hasPendingBeauty = false;
    _pendingFaceEnabled = false;
    _pendingFaceLevel = 0;
    _pendingBrightenEnabled = false;
    _pendingBrightenLevel = 0;

    beautyActive.value = false;

    final e = _engine;
    if (e == null) return;
    try {
      await e.setBeautyEffectOptions(
        enabled: false,
        options: const BeautyOptions(),
      );
      notifyListeners();
      if (kDebugMode) debugPrint('[Agora] Beauty reset');
    } catch (err) {
      debugPrint('⚠️ Failed to reset beauty: $err');
    }
  }

  Future<void> startPublishingFromStartResponse(
    Map<String, dynamic> resp, {
    bool enablePreview = true,
  }) async {
    final appId = (resp['agora']?['app_id'] as String?) ?? '';
    final token = (resp['agora']?['rtc_token'] as String?) ?? '';
    final channel = (resp['channel'] as String?) ?? '';
    final uidType = ((resp['uid_type'] ?? 'uid').toString());
    final rtcRole = ((resp['rtc_role'] ?? 'publisher').toString());

    final uidVal = resp['uid'];
    final uidStr = uidVal == null ? '' : uidVal.toString();

    if (kDebugMode) {
      debugPrint(
        '[Agora] creds: appId=${_safe(appId)} channel=$channel uidType=$uidType uid=$uidStr role=$rtcRole token=${_safe(token)}',
      );
    }

    await startPublishing(
      appId: appId,
      channel: channel,
      token: token,
      uidType: uidType,
      uid: uidStr,
      role: rtcRole,
      enablePreview: enablePreview,
    );
  }

  /// Core start: initializes engine, sets role to Broadcaster, and joins.
  Future<void> startPublishing({
    required String appId,
    required String channel,
    required String token,
    required String uidType,
    required String uid,
    String role = 'publisher',
    bool enablePreview = true,
  }) async {
    _assertInputs(appId, channel, token, uidType, uid);

    await _ensurePermissions();

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
        frameRate: 30,
        bitrate: null,
        orientationMode: OrientationMode.orientationModeFixedPortrait,
      ),
    );

    await e.setDefaultAudioRouteToSpeakerphone(true);

    if (uidType.toLowerCase() == 'useraccount') {
      await e.setParameters(r'{"rtc.string_uid":true}');
    }

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

          remoteUsers.value = {
            ...remoteUsers.value,
            remoteUid: RemoteUserState(
              uid: remoteUid,
              hasVideo: false,
              hasAudio: false,
              joined: true,
            ),
          };

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

              remoteUsers.value = Map.from(remoteUsers.value)
                ..remove(remoteUid);

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

              if (remoteUsers.value.containsKey(remoteUid)) {
                remoteUsers.value = {
                  ...remoteUsers.value,
                  remoteUid: remoteUsers.value[remoteUid]!.copyWith(
                    hasVideo: hasVideo,
                  ),
                };
              }

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

        onLocalAudioStateChanged:
            (
              RtcConnection conn,
              LocalAudioStreamState state,
              LocalAudioStreamReason error,
            ) {
              debugPrint('[Agora] localAudio state=$state error=$error');
            },

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

    await e.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

    if (enablePreview) {
      await e.startPreview();
      _previewing = true;
    }

    const options = ChannelMediaOptions(
      publishCameraTrack: true,
      publishMicrophoneTrack: true,
      clientRoleType: ClientRoleType.clientRoleBroadcaster,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    );

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

  Future<void> renewToken(String newToken) async {
    _token = newToken;
    await _engine?.renewToken(newToken);
    if (kDebugMode)
      debugPrint('[Agora] renewToken ok token=${_safe(newToken)}');
  }

  Future<void> setMicEnabled(bool enabled) async {
    final e = _engine;
    if (e == null) return;
    _isMicEnabled = enabled;
    await e.muteLocalAudioStream(!enabled);
    notifyListeners();
  }

  Future<void> setCameraEnabled(bool enabled) async {
    final e = _engine;
    if (e == null) return;
    _isCameraEnabled = enabled;
    await e.muteLocalVideoStream(!enabled);

    if (enabled && !_previewing) {
      await e.startPreview();
      _previewing = true;
    } else if (!enabled && _previewing) {
      await e.stopPreview();
      _previewing = false;
    }
    notifyListeners();
  }

  Future<void> switchCamera() async {
    await _engine?.switchCamera();
  }

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

  void clearGuest() {
    primaryRemoteUid.value = null;
    _remoteHasVideo.value = false;
  }

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

  List<int> get remoteUserIds => remoteUsers.value.keys.toList();

  bool get primaryGuestHasAudio {
    final uid = primaryRemoteUid.value;
    if (uid == null) return false;

    final state = remoteUsers.value[uid];
    return state?.hasAudio ?? false;
  }

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
