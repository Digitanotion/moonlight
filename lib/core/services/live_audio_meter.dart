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

  /// Keep someone "speaking" through the short gaps between words.
  static const _holdMs = 700;

  /// Hook into [engine] (idempotent per engine). Turns on volume reports.
  Future<void> attach(RtcEngine engine) async {
    if (!_attached.add(identityHashCode(engine))) return;
    engine.registerEventHandler(
      RtcEngineEventHandler(
        // Separate reports arrive for my mic (uid 0) and for everyone
        // else — each only updates the people in it.
        onAudioVolumeIndication: (_, speakers, _, _) => _onVolumes(speakers),
        onUserMuteAudio: (_, uid, muted) => _setMuted(uid, muted),
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

  void _onVolumes(List<AudioVolumeInfo> speakers) {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final sp in speakers) {
      final uid = sp.uid ?? 0;
      final vol = sp.volume ?? 0; // 0–255
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
  void feedVolumesForTest(List<AudioVolumeInfo> speakers) =>
      _onVolumes(speakers);

  @visibleForTesting
  void setMutedForTest(int uid, bool muted) => _setMuted(uid, muted);

  /// Forget everyone (e.g. when a live closes).
  void reset() {
    _speaking.clear();
    _lastLoudMs.clear();
    _lastHeardMs.clear();
    _remoteMuted.clear();
    for (final n in _levels.values) {
      n.value = 0;
    }
    notifyListeners();
  }
}
