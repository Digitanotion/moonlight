import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/widgets.dart';

class AgoraService {
  AgoraService();

  RtcEngine? _engine;
  String? _currentChannel; // keep for remote view
  final _onRemoteUser = StreamController<int>.broadcast();

  Stream<int> get onRemoteUser => _onRemoteUser.stream;
  bool get isReady => _engine != null;
  String? get channel => _currentChannel;

  Future<void> init(String appId) async {
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(appId: appId));
    await _engine!.enableVideo();

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        // Agora ^6.2.x uses: onJoinChannelSuccess(RtcConnection, int elapsed)
        onJoinChannelSuccess: (RtcConnection conn, int elapsed) {
          _currentChannel = conn.channelId;
        },
        // onUserJoined has 3 params: (conn, remoteUid, elapsed)
        onUserJoined: (RtcConnection conn, int remoteUid, int elapsed) {
          _onRemoteUser.add(remoteUid);
        },
        onUserOffline:
            (RtcConnection conn, int remoteUid, UserOfflineReasonType reason) {
              // You can also emit a “left” event if you want
            },
      ),
    );
  }

  Future<void> joinAs({
    required String token,
    required String channelName,
    required String userUuid,
    bool asHost = false,
  }) async {
    await _engine!.joinChannelWithUserAccount(
      token: token,
      channelId: channelName,
      userAccount: userUuid,
      options: ChannelMediaOptions(
        clientRoleType: asHost
            ? ClientRoleType.clientRoleBroadcaster
            : ClientRoleType.clientRoleAudience,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );
    if (asHost) {
      await _engine!.startPreview();
    }
  }

  Future<void> leaveChannel() async {
    await _engine?.leaveChannel();
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

  // Views
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
