// lib/features/clubs/rooms/club_room_rtc.dart
//
// Agora engine for one club room. Its own engine instance (like
// VideoCallAgoraService), released when the room closes, so it never
// collides with the livestream engines.
//
// Live-broadcasting profile: people on stage (audio speakers, video host /
// guests) are broadcasters; video-room viewers are audience. Premium:
// remote cameras the viewer hasn't unlocked are muted locally
// (muteRemoteVideoStream) while their audio keeps playing.

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'club_room_models.dart';

class ClubRoomRtc with ChangeNotifier {
  RtcEngine? _engine;
  RtcEngine? get engine => _engine;

  String? _channel;
  String? get channel => _channel;

  bool _video = false;
  bool _publisher = false;
  bool get isPublisher => _publisher;

  bool joined = false;
  bool micMuted = false;
  bool cameraOff = false;
  String? lastError;

  /// Remote uids currently in the channel.
  final Set<int> remoteUids = {};

  /// uid → speaking right now (0 = me).
  final Map<int, bool> speaking = {};

  final Set<int> _hiddenVideo = {};
  bool _disposed = false;

  Future<void> join(
    RtcCredentials creds, {
    required bool video,
    bool startMuted = false,
  }) async {
    await _leaveEngine();
    _video = video;
    _publisher = creds.isPublisher;
    _channel = creds.channel;
    micMuted = startMuted;
    lastError = null;

    if (_publisher) {
      final perms = <Permission>[
        Permission.microphone,
        if (video) Permission.camera,
      ];
      await perms.request();
    }

    final e = createAgoraRtcEngine();
    _engine = e;
    await e.initialize(
      RtcEngineContext(
        appId: creds.appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );
    await e.enableAudio();
    if (video) {
      await e.enableVideo();
      await e.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          // Small tiles in a grid of up to 10 — no need for 720p each.
          dimensions: VideoDimensions(width: 480, height: 640),
          frameRate: 15,
          bitrate: 0,
          orientationMode: OrientationMode.orientationModeFixedPortrait,
          degradationPreference: DegradationPreference.maintainFramerate,
        ),
      );
    } else {
      await e.disableVideo();
    }
    await e.setDefaultAudioRouteToSpeakerphone(true);
    await e.enableAudioVolumeIndication(
      interval: 400,
      smooth: 3,
      reportVad: true,
    );

    e.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (_, _) {
          joined = true;
          _notify();
        },
        onUserJoined: (_, uid, _) {
          remoteUids.add(uid);
          if (_hiddenVideo.contains(uid)) {
            e.muteRemoteVideoStream(uid: uid, mute: true);
          }
          _notify();
        },
        onUserOffline: (_, uid, _) {
          remoteUids.remove(uid);
          speaking.remove(uid);
          _notify();
        },
        onAudioVolumeIndication: (_, speakers, _, _) {
          var changed = false;
          final now = <int>{};
          for (final s in speakers) {
            final uid = s.uid ?? 0;
            final talking = (s.volume ?? 0) > 18 || (s.vad ?? 0) == 1;
            if (talking) now.add(uid);
          }
          for (final uid in {...speaking.keys, ...now}) {
            final v = now.contains(uid);
            if (speaking[uid] != v) {
              speaking[uid] = v;
              changed = true;
            }
          }
          if (changed) _notify();
        },
        onError: (err, msg) {
          lastError = '$err $msg';
          if (kDebugMode) debugPrint('[ClubRoomRtc] error $err $msg');
        },
      ),
    );

    await e.setClientRole(
      role: _publisher
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleAudience,
    );
    if (_publisher && video) await e.startPreview();

    await e.joinChannel(
      token: creds.token,
      channelId: creds.channel,
      uid: creds.uid,
      options: ChannelMediaOptions(
        clientRoleType: _publisher
            ? ClientRoleType.clientRoleBroadcaster
            : ClientRoleType.clientRoleAudience,
        publishMicrophoneTrack: _publisher,
        publishCameraTrack: _publisher && video,
        autoSubscribeAudio: true,
        autoSubscribeVideo: video,
      ),
    );
    if (_publisher && startMuted) {
      await e.muteLocalAudioStream(true);
    }
    _notify();
  }

  Future<void> setMicMuted(bool muted) async {
    micMuted = muted;
    await _engine?.muteLocalAudioStream(muted);
    _notify();
  }

  Future<void> setCameraOff(bool off) async {
    cameraOff = off;
    await _engine?.muteLocalVideoStream(off);
    await _engine?.enableLocalVideo(!off);
    _notify();
  }

  Future<void> switchCamera() async => _engine?.switchCamera();

  /// Premium gating: hide these remote cameras (audio still plays).
  Future<void> setHiddenVideo(Set<int> uids) async {
    if (!_video) return;
    final e = _engine;
    final toShow = _hiddenVideo.difference(uids);
    final toHide = uids.difference(_hiddenVideo);
    _hiddenVideo
      ..clear()
      ..addAll(uids);
    if (e == null) return;
    for (final uid in toHide) {
      await e.muteRemoteVideoStream(uid: uid, mute: true);
    }
    for (final uid in toShow) {
      await e.muteRemoteVideoStream(uid: uid, mute: false);
    }
    _notify();
  }

  Future<void> leave() async {
    await _leaveEngine();
    _notify();
  }

  Future<void> _leaveEngine() async {
    final e = _engine;
    _engine = null;
    joined = false;
    remoteUids.clear();
    speaking.clear();
    if (e == null) return;
    try {
      await e.leaveChannel();
      if (_video) await e.stopPreview();
      await e.release();
    } catch (err) {
      if (kDebugMode) debugPrint('[ClubRoomRtc] release failed: $err');
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _leaveEngine();
    super.dispose();
  }
}
