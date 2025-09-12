// lib/core/services/agora_service.dart
import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';

/// Minimal service for live streaming (host + viewer)
class AgoraService {
  AgoraService();

  RtcEngine? _engine;
  String? _currentChannel;

  // Emits the *latest* remote uid that joined (good enough for 1:1 host<->viewer)
  final _remoteUserCtrl = StreamController<int>.broadcast();

  Stream<int> get onRemoteUser => _remoteUserCtrl.stream;
  bool get isReady => _engine != null;
  String? get channel => _currentChannel;

  Future<void> _ensurePermissions() async {
    // You already request in Manifest; this prompts at runtime
    final statuses = await [Permission.camera, Permission.microphone].request();

    if (statuses[Permission.camera]?.isGranted != true ||
        statuses[Permission.microphone]?.isGranted != true) {
      throw Exception('Camera/Microphone permission not granted');
    }
  }

  Future<void> init(String appId) async {
    if (_engine != null) return; // idempotent
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(appId: appId));

    await _engine!.enableVideo();
    await _engine!.setChannelProfile(
      ChannelProfileType.channelProfileLiveBroadcasting,
    );

    // Register event handlers — match your installed agora_rtc_engine version!
    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection conn, int uid) {
          _currentChannel = conn.channelId;
        },
        onUserJoined: (RtcConnection conn, int remoteUid, int elapsed) {
          _remoteUserCtrl.add(remoteUid);
        },
        onUserOffline:
            (RtcConnection conn, int remoteUid, UserOfflineReasonType reason) {
              // No-op; your UI can simply show placeholder when snapshot has no data
            },
      ),
    );
  }

  /// Join by userAccount. If [asHost] true, you publish local camera+mic.
  Future<void> joinAs({
    required String token,
    required String channelName,
    required String userUuid,
    required bool asHost,
  }) async {
    await _ensurePermissions();

    await _engine!.joinChannelWithUserAccount(
      token: token,
      channelId: channelName,
      userAccount: userUuid,
      options: ChannelMediaOptions(
        clientRoleType: asHost
            ? ClientRoleType.clientRoleBroadcaster
            : ClientRoleType.clientRoleAudience,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        publishMicrophoneTrack: asHost,
        publishCameraTrack: asHost,
      ),
    );

    if (asHost) {
      // Make sure preview is on so localView renders
      // await _engine!.startPreview();
      await _engine!.startPreview(
        sourceType: VideoSourceType.videoSourceCamera,
      );
    }
  }

  Future<void> switchToHost() async {
    await _engine?.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine?.startPreview();
  }

  Future<void> switchToAudience() async {
    await _engine?.stopPreview();
    await _engine?.setClientRole(role: ClientRoleType.clientRoleAudience);
  }

  Future<void> leave() async {
    await _engine?.leaveChannel();
    _currentChannel = null;
  }

  Future<void> destroy() async {
    await _engine?.release();
    _engine = null;
  }

  // ---- Views ----
  Widget localView() {
    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: _engine!,
        canvas: const VideoCanvas(uid: 0),
      ),
    );
  }

  Widget remoteView(int uid) {
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: _engine!,
        canvas: VideoCanvas(uid: uid),
        connection: RtcConnection(channelId: _currentChannel),
      ),
    );
  }
}
