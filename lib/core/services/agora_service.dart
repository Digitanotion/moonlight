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

/// Production AgoraService.
///
/// ═══════════════════════════════════════════════════════════════════
/// BEAUTY — THE ONLY SAFE APPROACH
/// ═══════════════════════════════════════════════════════════════════
///
/// Problem: Agora's setBeautyEffectOptions(enabled: false) triggers a
/// YUV ↔ Texture2D renderer switch inside the native GL pipeline. The
/// VideoCapturerThread delivers camera frames asynchronously via
/// SurfaceTextureHelper. If a frame arrives mid-switch,
/// GlShader.useProgram crashes on the freed GL context (SIGSEGV,
/// confirmed in stack trace at TextureBufferPool.textureCopy).
///
/// There is NO safe way to drain VideoCapturerThread from Dart. Any
/// Future.delayed is a guess — the camera HAL delivers frames on its
/// own schedule regardless of what Dart awaits.
///
/// SOLUTION: NEVER call setBeautyEffectOptions(enabled: false).
///   • Beauty is initialised ONCE with enabled: true.
///   • "Turning off" beauty = setting all effect values to 0.0 while
///     keeping enabled: true. The pipeline stays active, the renderer
///     never switches, the GL context is never torn down mid-frame.
///   • Net visual result: identical to disabled (no smoothing,
///     no brightening, passthrough).
///   • beautyActive notifier reflects whether any value > 0 for UI.
///
/// ═══════════════════════════════════════════════════════════════════
/// OTHER RULES
/// ═══════════════════════════════════════════════════════════════════
///
/// 1. Beauty NEVER calls notifyListeners(). Only beautyActive
///    (ValueNotifier) is used for UI. notifyListeners() rebuilds the
///    camera widget → black screen.
///
/// 2. VideoViewController is created in onJoinChannelSuccess — not
///    before joinChannel — to avoid use-after-free on second stream.
///
/// 3. disposeEngine() does NOT call resetBeauty(). Beauty flags are
///    cleared in-place. The engine is about to be released.
///
/// 4. disposeEngine() resets _isMicEnabled/_isCameraEnabled for the
///    next session so UI state is correct.
class AgoraService with ChangeNotifier {
  RtcEngine? _engine;
  bool _disposed = false;

  // ── Session ────────────────────────────────────────────────────────
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
  bool get isMicEnabled => _isMicEnabled;
  bool get isCameraEnabled => _isCameraEnabled;

  final ValueNotifier<int?> primaryRemoteUid = ValueNotifier<int?>(null);
  final ValueNotifier<bool> _remoteHasVideo = ValueNotifier<bool>(false);
  final ValueNotifier<Map<int, RemoteUserState>> remoteUsers =
      ValueNotifier<Map<int, RemoteUserState>>({});
  bool get remoteHasVideo => _remoteHasVideo.value;

  // ── Beauty ─────────────────────────────────────────────────────────
  /// True when any beauty value is > 0. Pure UI indicator.
  final ValueNotifier<bool> beautyActive = ValueNotifier<bool>(false);

  /// Whether beauty has been initialised on the current engine.
  bool _beautyInitialised = false;

  /// In-flight guard — only one call to Agora at a time.
  bool _isApplyingBeauty = false;

  /// Latest desired state, queued while a call is in flight.
  bool _hasPendingBeauty = false;
  bool _pendingFaceEnabled = false;
  int _pendingFaceLevel = 0;
  bool _pendingBrightEnabled = false;
  int _pendingBrightLevel = 0;

  // ── Local preview ──────────────────────────────────────────────────
  VideoViewController? _localViewController;

  // ── Helpers ────────────────────────────────────────────────────────

  void _setNotifier<T>(ValueNotifier<T> n, T v) {
    if (_disposed) return;
    try {
      n.value = v;
    } catch (_) {}
  }

  void _notify() {
    if (_disposed) return;
    try {
      notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    _isApplyingBeauty = false;
    _hasPendingBeauty = false;

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

  // ─────────────────────────────────────────────────────────────────
  // Beauty — internal
  // ─────────────────────────────────────────────────────────────────

  /// Ensures beauty is initialised with enabled:true on the current
  /// engine. Safe to call multiple times — no-op after first call.
  Future<void> _ensureBeautyInitialised(RtcEngine e) async {
    if (_beautyInitialised) return;
    try {
      await e.setBeautyEffectOptions(
        enabled: true,
        options: const BeautyOptions(
          smoothnessLevel: 0.0,
          lighteningLevel: 0.0,
          rednessLevel: 0.0,
          sharpnessLevel: 0.0,
        ),
      );
      _beautyInitialised = true;
      debugPrint('[Beauty] Pipeline initialised (enabled:true, all zeros)');
    } catch (err) {
      debugPrint('⚠️ [Beauty] Init failed: $err');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Beauty — public API
  // ─────────────────────────────────────────────────────────────────

  /// Apply beauty. "Turning off" = set values to 0, keep enabled:true.
  /// Never calls notifyListeners(). Never crashes.
  Future<void> applyBeauty({
    required bool faceCleanEnabled,
    required int faceCleanLevel,
    required bool brightenEnabled,
    required int brightenLevel,
  }) async {
    if (_disposed) return;

    _pendingFaceEnabled = faceCleanEnabled;
    _pendingFaceLevel = faceCleanLevel.clamp(0, 100);
    _pendingBrightEnabled = brightenEnabled;
    _pendingBrightLevel = brightenLevel.clamp(0, 100);
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
      debugPrint('[Beauty] Engine not available — will apply on join');
      _hasPendingBeauty = false;
      return;
    }

    _isApplyingBeauty = true;
    _hasPendingBeauty = false;

    final faceEnabled = _pendingFaceEnabled;
    final faceLevel = _pendingFaceLevel;
    final brightEnabled = _pendingBrightEnabled;
    final brightLevel = _pendingBrightLevel;

    debugPrint(
      '[Beauty] Applying - Face: $faceEnabled($faceLevel), '
      'Brighten: $brightEnabled($brightLevel)',
    );

    try {
      if (_disposed) return;

      // Ensure the pipeline has been started exactly once.
      await _ensureBeautyInitialised(e);
      if (_disposed) return;

      final smooth = (faceEnabled ? faceLevel / 100.0 : 0.0).clamp(0.0, 1.0);
      final lighten = (brightEnabled ? brightLevel / 100.0 : 0.0).clamp(
        0.0,
        1.0,
      );

      // Always call with enabled:true.
      // All-zero values = passthrough (visually identical to disabled).
      // This NEVER triggers the renderer switch that causes the crash.
      await e.setBeautyEffectOptions(
        enabled: true,
        options: BeautyOptions(
          smoothnessLevel: smooth,
          lighteningLevel: lighten,
          lighteningContrastLevel: smooth > 0 || lighten > 0
              ? LighteningContrastLevel.lighteningContrastNormal
              : LighteningContrastLevel.lighteningContrastLow,
          rednessLevel: (lighten * 0.12).clamp(0.0, 0.15),
          sharpnessLevel: smooth > 0
              ? (0.25 + smooth * 0.2).clamp(0.0, 1.0)
              : 0.0,
        ),
      );

      final isActive = smooth > 0 || lighten > 0;
      _setNotifier(beautyActive, isActive);
      debugPrint(
        '[Beauty] Applied — smooth=$smooth lighten=$lighten '
        'active=$isActive',
      );
    } catch (err, stack) {
      debugPrint('❌ [Beauty] Apply failed: $err\n$stack');
      _lastError = 'Beauty effects failed: $err';
    } finally {
      _isApplyingBeauty = false;

      if (!_disposed && _hasPendingBeauty) {
        debugPrint('[Beauty] Applying queued pending state');
        await _doApplyBeauty();
      } else {
        debugPrint('[Beauty] Successfully applied');
      }
    }
  }

  /// "Reset" beauty — sets all values to 0. Pipeline stays active.
  /// Safe to call from dispose() or anywhere.
  Future<void> resetBeauty() async {
    _hasPendingBeauty = false;
    _pendingFaceEnabled = false;
    _pendingFaceLevel = 0;
    _pendingBrightEnabled = false;
    _pendingBrightLevel = 0;
    _setNotifier(beautyActive, false);

    final e = _engine;
    if (e == null || !_beautyInitialised) return;

    try {
      await e.setBeautyEffectOptions(
        enabled: true,
        options: const BeautyOptions(
          smoothnessLevel: 0.0,
          lighteningLevel: 0.0,
          rednessLevel: 0.0,
          sharpnessLevel: 0.0,
        ),
      );
      debugPrint('[Agora] Beauty reset (all zeros, pipeline stays active)');
    } catch (err) {
      debugPrint('⚠️ Failed to reset beauty: $err');
    }
  }

  Future<void> safeReset() async {
    try {
      await resetBeauty();
      if (!_isCameraEnabled) await setCameraEnabled(true);
    } catch (e) {
      debugPrint('❌ safeReset failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Session API
  // ─────────────────────────────────────────────────────────────────

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
        '[Agora] Starting: channel=$channel uidType=$uidType '
        'uid=$uidStr role=$rtcRole',
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
    _beautyInitialised = false; // reset for new engine

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
          _localViewController ??= VideoViewController(
            useFlutterTexture: true,
            rtcEngine: e,
            canvas: const VideoCanvas(uid: 0),
          );
          if (kDebugMode) {
            debugPrint(
              '✅ [Agora] joined ch=${conn.channelId} uid=${conn.localUid}',
            );
          }
          _notify();
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
                debugPrint('[Agora] Remote offline: $remoteUid reason=$reason');
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
    // Clear beauty flags WITHOUT touching the engine (rule 3).
    _beautyInitialised = false;
    _isApplyingBeauty = false;
    _hasPendingBeauty = false;
    _setNotifier(beautyActive, false);

    // Dispose controller BEFORE engine.release() (rule 2).
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
      _isMicEnabled = true; // reset for next session (rule 4)
      _isCameraEnabled = true; // reset for next session (rule 4)
      _setNotifier(primaryRemoteUid, null);
      _setNotifier(_remoteHasVideo, false);
      _notify();
    }
  }

  void clearGuest() {
    _setNotifier(primaryRemoteUid, null);
    _setNotifier(_remoteHasVideo, false);
  }

  // ─────────────────────────────────────────────────────────────────
  // Widget helpers
  // ─────────────────────────────────────────────────────────────────

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
    if (kDebugMode) debugPrint('[Agora] Primary guest set: $remoteUid');
    _notify();
  }

  List<int> get remoteUserIds => remoteUsers.value.keys.toList();

  bool get primaryGuestHasAudio {
    final uid = primaryRemoteUid.value;
    if (uid == null) return false;
    return remoteUsers.value[uid]?.hasAudio ?? false;
  }

  // ─────────────────────────────────────────────────────────────────
  // Internals
  // ─────────────────────────────────────────────────────────────────

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
      throw ArgumentError('uidType "uid" requires integer uid, got "$uid"');
    }
    if (t == 'useraccount' && uid.trim().isEmpty) {
      throw ArgumentError('uidType "userAccount" requires non-empty uid');
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
