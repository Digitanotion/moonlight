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
  bool speakerOn = true;
  String? lastError;

  /// Remote uids currently in the channel.
  final Set<int> remoteUids = {};

  /// uid → speaking right now (0 = me).
  final Map<int, bool> speaking = {};

  // Live loudness per uid (0–1) for the sound-wave animation. Separate
  // notifiers so the waves move several times a second without rebuilding
  // the whole room.
  final Map<int, ValueNotifier<double>> _levels = {};
  final Map<int, int> _lastLoudMs = {};
  final Map<int, int> _lastHeardMs = {};

  /// How loud [uid] is right now, 0–1 (0 = me).
  ValueListenable<double> levelOf(int uid) =>
      _levels.putIfAbsent(uid, () => ValueNotifier(0));

  /// Keep someone "speaking" through the short gaps between words.
  static const _holdMs = 700;

  /// uid → mic muted, straight from the call itself. Fresher than the
  /// server's participant list, which only updates when a realtime
  /// message gets through.
  final Map<int, bool> remoteMuted = {};

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
      interval: 200, // fast enough for the wave to follow the voice
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
          remoteMuted.remove(uid);
          _lastLoudMs.remove(uid);
          _levels[uid]?.value = 0;
          _notify();
        },
        onUserMuteAudio: (_, uid, muted) {
          remoteMuted[uid] = muted;
          if (muted) {
            speaking[uid] = false;
            _lastLoudMs.remove(uid);
            _levels[uid]?.value = 0;
          }
          _notify();
        },
        onRemoteAudioStateChanged: (_, uid, state, reason, _) {
          bool? muted;
          if (reason == RemoteAudioStateReason.remoteAudioReasonRemoteMuted ||
              reason == RemoteAudioStateReason.remoteAudioReasonRemoteOffline) {
            muted = true;
          } else if (reason ==
                  RemoteAudioStateReason.remoteAudioReasonRemoteUnmuted ||
              state == RemoteAudioState.remoteAudioStateDecoding) {
            muted = false;
          }
          if (muted != null && remoteMuted[uid] != muted) {
            remoteMuted[uid] = muted;
            if (muted) speaking[uid] = false;
            _notify();
          }
        },
        // Agora sends TWO separate reports — one for my own mic (uid 0) and
        // one for everyone else. Each report only updates the people in it;
        // the old code reset everyone not in the current report, so the
        // two reports kept wiping each other and waves barely showed.
        onAudioVolumeIndication: (_, speakers, _, _) => _onVolumes(speakers),
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

  void _onVolumes(List<AudioVolumeInfo> speakers) {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final sp in speakers) {
      final uid = sp.uid ?? 0;
      final vol = sp.volume ?? 0; // 0–255
      _lastHeardMs[uid] = now;
      final loud = vol > 12 || (uid == 0 && (sp.vad ?? 0) == 1 && vol > 4);
      if (loud) _lastLoudMs[uid] = now;
      // Normal speech sits around 30–150; map it onto 0–1 and ease a bit
      // so the bars follow the voice without jitter.
      final target = (vol / 120).clamp(0.0, 1.0);
      final n = _levels.putIfAbsent(uid, () => ValueNotifier(0));
      n.value = n.value * 0.35 + target * 0.65;
    }
    // Quiet or no longer reported → let the level fall to rest.
    for (final e in _levels.entries) {
      if (now - (_lastHeardMs[e.key] ?? 0) > 500 && e.value.value > 0) {
        e.value.value = e.value.value < 0.05 ? 0 : e.value.value * 0.5;
      }
    }
    var changed = false;
    for (final uid in {...speaking.keys, ..._lastLoudMs.keys}) {
      final v = now - (_lastLoudMs[uid] ?? 0) < _holdMs;
      if ((speaking[uid] ?? false) != v) {
        speaking[uid] = v;
        changed = true;
      }
    }
    if (changed) _notify();
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

  /// Loudspeaker vs earpiece.
  Future<void> setSpeakerOn(bool on) async {
    speakerOn = on;
    await _engine?.setEnableSpeakerphone(on);
    _notify();
  }

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
    remoteMuted.clear();
    _lastLoudMs.clear();
    _lastHeardMs.clear();
    for (final n in _levels.values) {
      n.value = 0;
    }
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
    for (final n in _levels.values) {
      n.dispose();
    }
    super.dispose();
  }
}
