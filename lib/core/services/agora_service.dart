// lib/core/services/agora_service.dart
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

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
///
/// KEY DESIGN RULE — why beauty never calls notifyListeners():
///
///   The camera preview is rendered inside an AnimatedBuilder(animation: agora).
///   Every notifyListeners() call causes that builder to run, which recreates
///   the AgoraVideoView and its VideoViewController.  Recreating the controller
///   while the SDK is still finishing a setBeautyEffectOptions() call tears down
///   the render surface → black screen.
///
///   Beauty state is therefore exposed ONLY through [beautyActive] (a separate
///   ValueNotifier).  The AnimatedBuilder in live_host_page must NOT listen to
///   this notifier — only localPreview-unrelated widgets should observe it.
///   notifyListeners() is called only for session state changes (join, leave,
///   mic/camera mute, remote user events) — never for beauty operations.
class AgoraService with ChangeNotifier {
  RtcEngine? _engine;

  // Disposed guard — checked before every notifier write.
  bool _disposed = false;

  // ── Session state ──────────────────────────────────────────────────────────
  bool _joined = false;
  bool _previewing = false;

  String? _appId;
  String? _channelId;
  String? _token;
  String? _uidType;
  String? _userAccount;
  int? _localUid;

  String? _lastError;
  String? get lastError => _lastError;

  bool get joined => _joined;
  String? get channelId => _channelId;
  RtcEngine? get engine => _engine;

  bool _isMicEnabled = true;
  bool _isCameraEnabled = true;

  final ValueNotifier<int?> primaryRemoteUid = ValueNotifier<int?>(null);
  final ValueNotifier<bool> _remoteHasVideo = ValueNotifier<bool>(false);

  bool get remoteHasVideo => _remoteHasVideo.value;
  bool get isMicEnabled => _isMicEnabled;
  bool get isCameraEnabled => _isCameraEnabled;

  final ValueNotifier<Map<int, RemoteUserState>> remoteUsers =
      ValueNotifier<Map<int, RemoteUserState>>({});

  // ── Beauty state ───────────────────────────────────────────────────────────
  //
  // [beautyActive] is a SEPARATE ValueNotifier — widgets that only need to show
  // an "FX on" badge observe this directly and do NOT cause the video view to
  // rebuild.
  //
  // Pending-state pattern: latest requested values are stored immediately.
  // _isApplyingBeauty guards one SDK call at a time.  When the in-flight call
  // finishes, its finally{} block re-runs if _hasPendingBeauty is set — so a
  // rapid toggle-off is never silently dropped.
  final ValueNotifier<bool> beautyActive = ValueNotifier<bool>(false);

  bool _isApplyingBeauty = false;
  bool _hasPendingBeauty = false;
  bool _pendingFaceEnabled = false;
  int _pendingFaceLevel = 0;
  bool _pendingBrightenEnabled = false;
  int _pendingBrightenLevel = 0;

  // ── Stable local preview controller ───────────────────────────────────────
  //
  // Created once when the engine is ready and reused for the lifetime of the
  // session.  Never recreated by a beauty change.
  VideoViewController? _localViewController;

  // ── Safe helpers ───────────────────────────────────────────────────────────

  void _setNotifier<T>(ValueNotifier<T> notifier, T value) {
    if (_disposed) return;
    try {
      notifier.value = value;
    } catch (e) {
      debugPrint('[AgoraService] notifier write skipped (disposed): $e');
    }
  }

  /// Only used for SESSION state changes (join/leave/mic/camera/remote users).
  /// NEVER called from beauty methods.
  void _notify() {
    if (_disposed) return;
    try {
      notifyListeners();
    } catch (e) {
      debugPrint('[AgoraService] notifyListeners skipped (disposed): $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _isApplyingBeauty = false;
    _hasPendingBeauty = false;

    // Dispose the stable controller before the engine is released.
    try {
      _localViewController?.dispose();
    } catch (_) {}
    _localViewController = null;

    try {
      remoteUsers.dispose();
    } catch (_) {}
    try {
      primaryRemoteUid.dispose();
    } catch (_) {}
    try {
      _remoteHasVideo.dispose();
    } catch (_) {}
    try {
      beautyActive.dispose();
    } catch (_) {}

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Beauty API
  // ---------------------------------------------------------------------------

  /// Apply beauty options (face clean = smoothing, brighten = lightening).
  ///
  /// NEVER calls notifyListeners() — beauty changes must not rebuild the video
  /// view.  State is surfaced only through [beautyActive].
  Future<void> applyBeauty({
    required bool faceCleanEnabled,
    required int faceCleanLevel,
    required bool brightenEnabled,
    required int brightenLevel,
  }) async {
    if (_disposed) return;

    _pendingFaceEnabled = faceCleanEnabled;
    _pendingFaceLevel = faceCleanLevel.clamp(0, 100);
    _pendingBrightenEnabled = brightenEnabled;
    _pendingBrightenLevel = brightenLevel.clamp(0, 100);
    _hasPendingBeauty = true;

    if (_isApplyingBeauty) {
      debugPrint('[Beauty] Apply in-flight — newest state queued');
      return;
    }

    await _doApplyBeauty();
  }

  Future<void> _doApplyBeauty() async {
    if (_disposed || !_hasPendingBeauty) return;

    final e = _engine;
    if (e == null) {
      debugPrint('[Beauty] Engine not available — skipping');
      _hasPendingBeauty = false;
      return;
    }

    _isApplyingBeauty = true;
    _hasPendingBeauty = false;

    // Snapshot before any await so later writes don't race.
    final faceEnabled = _pendingFaceEnabled;
    final faceLevel = _pendingFaceLevel;
    final brightenEnabled = _pendingBrightenEnabled;
    final brightenLevel = _pendingBrightenLevel;

    try {
      if (_disposed) return;

      final smooth = (faceEnabled ? faceLevel / 100.0 : 0.0).clamp(0.0, 1.0);
      final lighten = (brightenEnabled ? brightenLevel / 100.0 : 0.0).clamp(
        0.0,
        1.0,
      );

      if (smooth == 0.0 && lighten == 0.0) {
        await e.setBeautyEffectOptions(
          enabled: false,
          options: const BeautyOptions(),
        );
        // Update badge notifier only — NO notifyListeners().
        _setNotifier(beautyActive, false);
        debugPrint('[Beauty] Disabled successfully');
      } else {
        final options = BeautyOptions(
          smoothnessLevel: smooth,
          lighteningLevel: lighten,
          lighteningContrastLevel:
              LighteningContrastLevel.lighteningContrastNormal,
          rednessLevel: (lighten * 0.12).clamp(0.0, 0.15),
          sharpnessLevel: (0.25 + smooth * 0.2).clamp(0.0, 1.0),
        );
        await e.setBeautyEffectOptions(enabled: true, options: options);
        // Update badge notifier only — NO notifyListeners().
        _setNotifier(beautyActive, true);
        debugPrint('[Beauty] Applied — smooth=$smooth lighten=$lighten');
      }
      // ← intentionally NO _notify() here
    } catch (err, stack) {
      debugPrint('❌ [Beauty] Apply failed: $err\n$stack');
      _lastError = 'Beauty effects failed: $err';

      // Best-effort recovery: disable so pipeline is clean.
      try {
        if (!_disposed && _engine != null) {
          await _engine!.setBeautyEffectOptions(
            enabled: false,
            options: const BeautyOptions(),
          );
          _setNotifier(beautyActive, false);
          debugPrint('[Beauty] Recovery — effects disabled after error');
        }
      } catch (recoveryErr) {
        debugPrint('❌ [Beauty] Recovery also failed: $recoveryErr');
      }
      // ← intentionally NO _notify() here either
    } finally {
      _isApplyingBeauty = false;

      if (!_disposed && _hasPendingBeauty) {
        debugPrint('[Beauty] Applying queued pending state');
        await Future.delayed(const Duration(milliseconds: 30));
        await _doApplyBeauty();
      }
    }
  }

  /// Reset all beauty — disables effects and clears pending state.
  /// Never throws. NEVER calls notifyListeners().
  Future<void> resetBeauty() async {
    _hasPendingBeauty = false;
    _pendingFaceEnabled = false;
    _pendingFaceLevel = 0;
    _pendingBrightenEnabled = false;
    _pendingBrightenLevel = 0;

    _setNotifier(beautyActive, false);

    final e = _engine;
    if (e == null) return;

    try {
      await e.setBeautyEffectOptions(
        enabled: false,
        options: const BeautyOptions(),
      );
      // ← intentionally NO _notify()
      if (kDebugMode) debugPrint('[Agora] Beauty reset');
    } catch (err) {
      debugPrint('⚠️ Failed to reset beauty: $err');
    }
  }

  /// Safe full reset: disables beauty + ensures camera is running.
  Future<void> safeReset() async {
    try {
      await resetBeauty();
      if (!_isCameraEnabled) await setCameraEnabled(true);
      await Future.delayed(const Duration(milliseconds: 200));
    } catch (e) {
      debugPrint('❌ safeReset failed: $e');
      try {
        await _engine?.muteLocalVideoStream(false);
        await _engine?.startPreview();
        _previewing = true;
      } catch (_) {}
    }
  }

  // ---------------------------------------------------------------------------
  // Session API
  // ---------------------------------------------------------------------------

  Future<void> startPublishingFromStartResponse(
    Map<String, dynamic> resp, {
    bool enablePreview = true,
  }) async {
    final appId = (resp['agora']?['app_id'] as String?) ?? '';
    final token = (resp['agora']?['rtc_token'] as String?) ?? '';
    final channel = (resp['channel'] as String?) ?? '';
    final uidType = (resp['uid_type'] ?? 'uid').toString();
    final rtcRole = (resp['rtc_role'] ?? 'publisher').toString();
    final uidStr = (resp['uid'] ?? '').toString();

    if (kDebugMode) {
      debugPrint(
        '[Agora] creds: appId=${_safe(appId)} channel=$channel '
        'uidType=$uidType uid=$uidStr role=$rtcRole token=${_safe(token)}',
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
      if (kDebugMode) debugPrint('[Agora] Same session — skipping rejoin.');
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
              '✅ [Agora] joined ch=${conn.channelId} uid=${conn.localUid}',
            );
          }
          _notify(); // session change — OK to notify
        },

        onUserJoined: (RtcConnection conn, int remoteUid, int elapsed) {
          if (kDebugMode) debugPrint('[Agora] Remote joined: $remoteUid');
          if (!_disposed) {
            remoteUsers.value = {
              ...remoteUsers.value,
              remoteUid: RemoteUserState(
                uid: remoteUid,
                hasVideo: false,
                hasAudio: false,
                joined: true,
              ),
            };
          }
          if (primaryRemoteUid.value == null) {
            _setNotifier(primaryRemoteUid, remoteUid);
          }
          _notify();
        },

        onUserOffline:
            (RtcConnection conn, int remoteUid, UserOfflineReasonType reason) {
              if (kDebugMode) {
                debugPrint(
                  '[Agora] Remote offline: $remoteUid reason: $reason',
                );
              }
              if (!_disposed) {
                remoteUsers.value = Map.from(remoteUsers.value)
                  ..remove(remoteUid);
              }
              if (primaryRemoteUid.value == remoteUid) {
                _setNotifier(primaryRemoteUid, null);
                _setNotifier(_remoteHasVideo, false);
              }
              _notify();
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
                  state == RemoteVideoState.remoteVideoStateDecoding ||
                  state == RemoteVideoState.remoteVideoStateStarting;

              if (!_disposed && remoteUsers.value.containsKey(remoteUid)) {
                remoteUsers.value = {
                  ...remoteUsers.value,
                  remoteUid: remoteUsers.value[remoteUid]!.copyWith(
                    hasVideo: hasVideo,
                  ),
                };
              }
              if (remoteUid == primaryRemoteUid.value) {
                _setNotifier(_remoteHasVideo, hasVideo);
              }
              _notify();
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
              if (!_disposed && remoteUsers.value.containsKey(remoteUid)) {
                remoteUsers.value = {
                  ...remoteUsers.value,
                  remoteUid: remoteUsers.value[remoteUid]!.copyWith(
                    hasAudio: hasAudio,
                  ),
                };
              }
              _notify();
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
          debugPrint('[Agora] camera exposure: x=$x y=$y w=$width h=$height');
        },

        onLeaveChannel: (RtcConnection conn, RtcStats stats) {
          _joined = false;
          _setNotifier(primaryRemoteUid, null);
          _setNotifier(_remoteHasVideo, false);
          if (!_disposed) remoteUsers.value = {};
          if (kDebugMode) debugPrint('[Agora] left ch=${conn.channelId}');
          _notify();
        },

        onError: (ErrorCodeType code, String? msg) {
          _lastError = 'Agora error $code ${msg ?? ""}';
          debugPrint('❌ $_lastError');
          _notify();
        },

        onTokenPrivilegeWillExpire: (RtcConnection conn, String t) {
          if (kDebugMode)
            debugPrint('[Agora] Token expiring — call renewToken().');
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

    // Build the stable local view controller once.
    _localViewController = VideoViewController(
      useFlutterTexture: true,
      rtcEngine: e,
      canvas: const VideoCanvas(uid: 0),
    );

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
        throw ArgumentError('uid_type="uid" but uid="$uid" is not an integer.');
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
    try {
      await _engine?.renewToken(newToken);
      if (kDebugMode) debugPrint('[Agora] renewToken ok');
    } catch (e) {
      debugPrint('❌ [Agora] renewToken failed: $e');
    }
  }

  Future<void> setMicEnabled(bool enabled) async {
    if (_disposed || _engine == null) return;
    try {
      _isMicEnabled = enabled;
      await _engine!.muteLocalAudioStream(!enabled);
      _notify();
    } catch (e) {
      debugPrint('❌ [Agora] setMicEnabled failed: $e');
    }
  }

  Future<void> setCameraEnabled(bool enabled) async {
    if (_disposed || _engine == null) return;
    try {
      _isCameraEnabled = enabled;
      await _engine!.muteLocalVideoStream(!enabled);
      if (enabled && !_previewing) {
        await _engine!.startPreview();
        _previewing = true;
      } else if (!enabled && _previewing) {
        await _engine!.stopPreview();
        _previewing = false;
      }
      _notify();
    } catch (e) {
      debugPrint('❌ [Agora] setCameraEnabled failed: $e');
    }
  }

  Future<void> switchCamera() async {
    try {
      await _engine?.switchCamera();
    } catch (e) {
      debugPrint('❌ [Agora] switchCamera failed: $e');
    }
  }

  Future<void> leave() async {
    try {
      await _engine?.leaveChannel();
    } catch (e) {
      debugPrint('❌ [Agora] leaveChannel failed: $e');
    } finally {
      _joined = false;
      _setNotifier(primaryRemoteUid, null);
      _setNotifier(_remoteHasVideo, false);
      _notify();
    }
  }

  Future<void> disposeEngine() async {
    try {
      _localViewController?.dispose();
      _localViewController = null;
    } catch (_) {}

    try {
      if (_previewing) {
        await _engine?.stopPreview();
        _previewing = false;
      }
      await _engine?.release();
    } catch (e) {
      debugPrint('❌ [Agora] disposeEngine failed: $e');
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
      _setNotifier(primaryRemoteUid, null);
      _setNotifier(_remoteHasVideo, false);
      _notify();
    }
  }

  void clearGuest() {
    _setNotifier(primaryRemoteUid, null);
    _setNotifier(_remoteHasVideo, false);
  }

  // ---------------------------------------------------------------------------
  // Widget helpers
  // ---------------------------------------------------------------------------

  /// Returns a stable [AgoraVideoView] whose controller is created once per
  /// session.  It is intentionally NOT rebuilt on beauty changes.
  Widget localPreview({double? width, double? height}) {
    final ctrl = _localViewController;
    if (ctrl == null) {
      return const SizedBox.expand(child: ColoredBox(color: Colors.black));
    }
    return SizedBox(
      width: width,
      height: height,
      child: AgoraVideoView(controller: ctrl),
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
      return _blackPlaceholder('No guest');
    }
    return ValueListenableBuilder<int?>(
      valueListenable: primaryRemoteUid,
      builder: (_, remoteUid, __) {
        if (remoteUid == null) return _blackPlaceholder('No guest');
        return ValueListenableBuilder<bool>(
          valueListenable: _remoteHasVideo,
          builder: (_, hasVideo, __) {
            if (!hasVideo)
              return _blackPlaceholder('Guest video\nconnecting...');
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

  Widget _blackPlaceholder(String text) {
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
    if (!remoteUsers.value.containsKey(remoteUid)) return;
    _setNotifier(primaryRemoteUid, remoteUid);
    _setNotifier(_remoteHasVideo, remoteUsers.value[remoteUid]!.hasVideo);
    if (kDebugMode)
      debugPrint('[Agora] Manually set primary guest: $remoteUid');
    _notify();
  }

  List<int> get remoteUserIds => remoteUsers.value.keys.toList();

  bool get primaryGuestHasAudio {
    final uid = primaryRemoteUid.value;
    if (uid == null) return false;
    return remoteUsers.value[uid]?.hasAudio ?? false;
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
    if (v == null || v.isEmpty) return '';
    if (v.length <= 12) return v;
    return '${v.substring(0, 6)}…${v.substring(v.length - 6)}';
  }

  Future<void> _leaveIfAny() async {
    if (_engine != null && _joined) await leave();
  }

  Future<void> _disposeIfAny() async {
    if (_engine != null) await disposeEngine();
  }
}
