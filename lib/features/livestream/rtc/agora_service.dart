import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';

/// Events you can observe from UI/Cubits.
class AgoraJoinEvent {
  final String channel;
  AgoraJoinEvent(this.channel);
}

class AgoraRemoteUserEvent {
  final int uid;
  final String? userAccount; // we try to resolve this (may be null)
  final bool joined; // true=joined, false=left
  AgoraRemoteUserEvent({
    required this.uid,
    required this.joined,
    this.userAccount,
  });
}

class AgoraPauseEvent {
  final bool paused; // not native from Agora; you can fire your own if you want
  AgoraPauseEvent(this.paused);
}

class AgoraTokenEvent {
  final bool willExpireSoon;
  AgoraTokenEvent({required this.willExpireSoon});
}

class AgoraService {
  AgoraService();

  RtcEngine? _engine;

  // Streams (broadcast so multiple listeners can attach)
  final _onJoin = StreamController<AgoraJoinEvent>.broadcast();
  final _onRemoteUser = StreamController<AgoraRemoteUserEvent>.broadcast();
  final _onToken = StreamController<AgoraTokenEvent>.broadcast();
  final _onConnectionState = StreamController<ConnectionStateType>.broadcast();

  Stream<AgoraJoinEvent> get onJoined => _onJoin.stream;
  Stream<AgoraRemoteUserEvent> get onRemoteUser => _onRemoteUser.stream;
  Stream<AgoraTokenEvent> get onToken => _onToken.stream;
  Stream<ConnectionStateType> get onConnectionState =>
      _onConnectionState.stream;

  // Keep track of who is currently in the channel (for viewer counts, etc.)
  final Set<int> _remoteUids = <int>{};
  Set<int> get remoteUids => _remoteUids;

  bool get isReady => _engine != null;

  Future<void> init(String appId) async {
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(appId: appId));

    // video is on for live streaming experience
    await _engine!.enableVideo();

    // Register event handler once
    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onConnectionStateChanged:
            (
              RtcConnection _,
              ConnectionStateType state,
              ConnectionChangedReasonType __,
            ) {
              _onConnectionState.add(state);
            },
        onJoinChannelSuccess: (RtcConnection conn, int uid) {
          _onJoin.add(AgoraJoinEvent(conn.channelId ?? ''));
        },
        onUserJoined: (RtcConnection conn, int remoteUid, int elapsed) async {
          _remoteUids.add(remoteUid);

          String? account;
          try {
            // Try to resolve userAccount from uid (may fail if not cached yet)
            final info = await _engine?.getUserInfoByUid(remoteUid);
            account = info?.userAccount;
          } catch (_) {
            /* ignore */
          }

          _onRemoteUser.add(
            AgoraRemoteUserEvent(
              uid: remoteUid,
              joined: true,
              userAccount: account,
            ),
          );
        },
        onUserOffline:
            (RtcConnection conn, int remoteUid, UserOfflineReasonType reason) {
              _remoteUids.remove(remoteUid);
              _onRemoteUser.add(
                AgoraRemoteUserEvent(
                  uid: remoteUid,
                  joined: false,
                  userAccount: null,
                ),
              );
            },
        onLeaveChannel: (RtcConnection conn, RtcStats stats) {
          _remoteUids.clear();
        },
        onTokenPrivilegeWillExpire: (RtcConnection conn, String token) {
          _onToken.add(AgoraTokenEvent(willExpireSoon: true));
        },
        onError: (ErrorCodeType code, String msg) {
          // Optionally log/pipe errors to a logger/snackbar
          // debugPrint('Agora error: $code $msg');
        },
      ),
    );
  }

  /// Join by userAccount (UUID). Use role audience/publisher via [asHost].
  Future<void> joinChannel({
    required String token,
    required String channelName,
    required String userUuid, // UUID
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
        // Recommended for live streaming:
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );

    if (asHost) {
      // Enable local preview for broadcaster
      await _engine!.startPreview();
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

  Future<void> renewToken(String newToken) async {
    await _engine?.renewToken(newToken);
  }

  Future<void> muteLocalAudio(bool muted) async {
    await _engine?.muteLocalAudioStream(muted);
  }

  Future<void> muteLocalVideo(bool muted) async {
    await _engine?.muteLocalVideoStream(muted);
  }

  Future<void> switchCamera() async {
    await _engine?.switchCamera();
  }

  Future<void> leaveChannel() async {
    await _engine?.leaveChannel();
    _remoteUids.clear();
  }

  Future<void> destroy() async {
    await _engine?.release();
    _engine = null;

    // Close streams when your app shuts down (don’t close between screens)
    // _onJoin.close(); _onRemoteUser.close(); _onToken.close(); _onConnectionState.close();
  }

  RtcEngine? get engine => _engine;

  /// UI helpers for video views (plug into your widgets)
  /// Local preview (host)
  Widget localView() {
    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: _engine!,
        canvas: const VideoCanvas(uid: 0),
      ),
    );
  }

  /// Remote view by uid (publisher/guest). For multiple guests, create multiple.
  Widget remoteView(int uid) {
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: _engine!,
        canvas: VideoCanvas(uid: uid),
        connection: const RtcConnection(channelId: null), // current channel
      ),
    );
  }
}
