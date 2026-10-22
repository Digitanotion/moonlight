// lib/core/services/live_audio_meter.dart
//
// Who's talking and who's muted in a livestream — for the sound-wave and
// mute icons on the tiles in the box (same feel as club rooms). Attaches
// its own event handler to whichever Agora engine is live (the host's, or
// the shared viewer/guest engine), alongside their existing handlers.
//
// uid 0 = me (Agora reports the local mic as uid 0).

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';

class LiveAudioMeter extends ChangeNotifier {
  LiveAudioMeter._();
  static final LiveAudioMeter instance = LiveAudioMeter._();

  final Set<int> _attached = {};

  // Live loudness 0–1 per uid. Separate notifiers so the waves move several
  // times a second without rebuilding whole screens.
  final Map<int, ValueNotifier<double>> _levels = {};
  final Map<int, int> _lastLoudMs = {};
  final Map<int, int> _lastHeardMs = {};
  final Map<int, bool> _speaking = {};
  final Map<int, bool> _remoteMuted = {};

  /// Cameras switched off (uid 0 = my own, as the host). Tiles show a
  /// "camera off" cover instead of the frozen last frame.
  final Set<int> _camOff = {};

  /// People whose call connection dropped (left the box, app died). The
  /// box hides them at once instead of waiting for the server's list.
  final Set<int> _gone = {};

  /// Keep someone "speaking" through the short gaps between words.
  static const _holdMs = 700;

  /// Hook into [engine] (idempotent per engine). Turns on volume reports.
  Future<void> attach(RtcEngine engine) async {
    if (!_attached.add(identityHashCode(engine))) return;
    engine.registerEventHandler(
      RtcEngineEventHandler(
        // Separate reports arrive for my mic (uid 0) and for everyone
        // else — each only updates the people in it.
        onAudioVolumeIndication: (conn, speakers, _, _) =>
            _onVolumes(speakers, localUid: conn.localUid),
        onUserMuteAudio: (_, uid, muted) => _setMuted(uid, muted),
        onUserJoined: (_, uid, _) {
          if (_gone.remove(uid)) notifyListeners();
        },
        onUserMuteVideo: (_, uid, muted) => setCamOff(uid, muted),
        onRemoteVideoStateChanged: (_, uid, state, reason, _) {
          if (reason ==
                  RemoteVideoStateReason.remoteVideoStateReasonRemoteMuted ||
              reason ==
                  RemoteVideoStateReason.remoteVideoStateReasonRemoteOffline) {
            setCamOff(uid, true);
          } else if (state == RemoteVideoState.remoteVideoStateDecoding ||
              reason ==
                  RemoteVideoStateReason.remoteVideoStateReasonRemoteUnmuted) {
            setCamOff(uid, false);
          }
        },
        onRemoteAudioStateChanged: (_, uid, state, reason, _) {
          if (reason == RemoteAudioStateReason.remoteAudioReasonRemoteMuted ||
              reason == RemoteAudioStateReason.remoteAudioReasonRemoteOffline) {
            _setMuted(uid, true);
          } else if (reason ==
                  RemoteAudioStateReason.remoteAudioReasonRemoteUnmuted ||
              state == RemoteAudioState.remoteAudioStateDecoding) {
            _setMuted(uid, false);
          }
        },
        onUserOffline: (_, uid, _) {
          _speaking.remove(uid);
          _lastLoudMs.remove(uid);
          _levels[uid]?.value = 0;
          _gone.add(uid);
          notifyListeners();
        },
      ),
    );
    try {
      await engine.enableAudioVolumeIndication(
        interval: 250,
        smooth: 3,
        reportVad: true,
      );
    } catch (e) {
      debugPrint('[LiveAudioMeter] volume indication failed: $e');
    }
  }

  /// Volume reports for one joinChannelEx connection — the engine-wide
  /// switch above doesn't cover those, so without this a guest never sees
  /// their own wave.
  Future<void> watchConnection(RtcEngineEx engine, RtcConnection c) async {
    try {
      await engine.enableAudioVolumeIndicationEx(
        interval: 250,
        smooth: 3,
        reportVad: true,
        connection: c,
      );
    } catch (e) {
      debugPrint('[LiveAudioMeter] volume indication (ex) failed: $e');
    }
  }

  /// Their camera is off right now.
  bool isCamOff(int uid) => _camOff.contains(uid);

  /// Record a camera turning off/on (also used for my own camera as host).
  void setCamOff(int uid, bool off) {
    final changed = off ? _camOff.add(uid) : _camOff.remove(uid);
    if (changed) notifyListeners();
  }

  /// Their call connection dropped (and hasn't come back).
  bool isGone(int uid) => _gone.contains(uid);

  @visibleForTesting
  void setGoneForTest(int uid, bool gone) {
    gone ? _gone.add(uid) : _gone.remove(uid);
    notifyListeners();
  }

  /// How loud [uid] is right now, 0–1.
  ValueListenable<double> levelOf(int uid) =>
      _levels.putIfAbsent(uid, () => ValueNotifier(0));

  bool isSpeaking(int uid) => _speaking[uid] ?? false;

  /// Remote mic muted (null = unknown yet).
  bool? isMuted(int uid) => _remoteMuted[uid];

  void _setMuted(int uid, bool muted) {
    if (_remoteMuted[uid] == muted) return;
    _remoteMuted[uid] = muted;
    if (muted) {
      _speaking[uid] = false;
      _lastLoudMs.remove(uid);
      _levels[uid]?.value = 0;
    }
    notifyListeners();
  }

  // My mic is reported once per call connection. As a guest the shared
  // engine also holds silent watch-only connections (the streams above and
  // below in the feed), whose "me = 0" reports would wipe out the real one.
  int _localLoudVol = 0;
  int _localLoudMs = 0;

  void _onVolumes(List<AudioVolumeInfo> speakers, {int? localUid}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final sp in speakers) {
      var uid = sp.uid ?? 0;
      // Some connections label my own report with my uid instead of 0.
      if (localUid != null && localUid != 0 && uid == localUid) uid = 0;
      final vol = sp.volume ?? 0; // 0–255
      if (uid == 0) {
        if (vol < _localLoudVol && now - _localLoudMs < 400) continue;
        _localLoudVol = vol;
        _localLoudMs = now;
      }
      _lastHeardMs[uid] = now;
      final loud = vol > 12 || (uid == 0 && (sp.vad ?? 0) == 1 && vol > 4);
      if (loud) _lastLoudMs[uid] = now;
      final target = (vol / 120).clamp(0.0, 1.0);
      final n = _levels.putIfAbsent(uid, () => ValueNotifier(0));
      n.value = n.value * 0.35 + target * 0.65;
    }
    for (final e in _levels.entries) {
      if (now - (_lastHeardMs[e.key] ?? 0) > 500 && e.value.value > 0) {
        e.value.value = e.value.value < 0.05 ? 0 : e.value.value * 0.5;
      }
    }
    var changed = false;
    for (final uid in {..._speaking.keys, ..._lastLoudMs.keys}) {
      final v = now - (_lastLoudMs[uid] ?? 0) < _holdMs;
      if ((_speaking[uid] ?? false) != v) {
        _speaking[uid] = v;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  @visibleForTesting
  void feedVolumesForTest(List<AudioVolumeInfo> speakers, {int? localUid}) =>
      _onVolumes(speakers, localUid: localUid);

  @visibleForTesting
  void setMutedForTest(int uid, bool muted) => _setMuted(uid, muted);

  /// Forget everyone (e.g. when a live closes).
  void reset() {
    _speaking.clear();
    _lastLoudMs.clear();
    _lastHeardMs.clear();
    _remoteMuted.clear();
    _gone.clear();
    _camOff.clear();
    _localLoudVol = 0;
    _localLoudMs = 0;
    for (final n in _levels.values) {
      n.value = 0;
    }
    notifyListeners();
  }
}
