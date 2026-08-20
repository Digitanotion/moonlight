// lib/core/services/ringtone_player.dart
//
// Plays our own looping ringtone audio, entirely independent of CallKit's
// native sound handling and the fallback notification's sound — both of
// which proved unreliable across today's testing on this device/plugin
// combination, despite exhausting every documented fix. This gives us
// full programmatic control: genuine continuous ringing until the call
// is resolved (accept/decline/timeout/cancelled), then an explicit stop.
//
// RELIABILITY NOTE: this is confirmed reliable while the app process is
// genuinely alive (foreground or backgrounded). For a FULLY KILLED app,
// background isolates have real, documented restrictions on plugin
// access — the same class of uncertainty we hit with GetIt access
// earlier. This has NOT been verified to work reliably from that fully
// killed context; if it doesn't fire there, the fallback notification's
// own single-chime sound is still what plays in that specific case.
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class RingtonePlayer {
  static final RingtonePlayer _instance = RingtonePlayer._internal();
  factory RingtonePlayer() => _instance;
  RingtonePlayer._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  /// Starts looping the ringtone. Safe to call repeatedly — a no-op if
  /// already playing, so multiple event sources (foreground listener,
  /// notification handler) can all call this without needing to
  /// coordinate who's "responsible" for starting it.
  Future<void> play() async {
    if (_isPlaying) return;
    _isPlaying = true;
    try {
      // TEMPORARILY REMOVED — setAudioContext() call below is suspected
      // of hanging indefinitely (neither succeeding nor throwing) on
      // this device. Reverting to the simpler version that at least
      // reliably completed before, to isolate whether this specific
      // addition is the actual cause before trying anything else.
      //
      // await _player.setAudioContext(
      //   AudioContext(
      //     android: AudioContextAndroid(
      //       isSpeakerphoneOn: true,
      //       stayAwake: true,
      //       contentType: AndroidContentType.sonification,
      //       usageType: AndroidUsageType.notificationRingtone,
      //       audioFocus: AndroidAudioFocus.gainTransient,
      //     ),
      //   ),
      // );
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('audio/ringtone_default.mp3'));
      debugPrint('🔔 [Ringtone] Started looping playback');
    } catch (e) {
      debugPrint('⚠️ [Ringtone] Failed to start: $e');
      _isPlaying = false;
    }
  }

  /// Stops playback immediately. Safe to call even if never started, or
  /// called multiple times from different resolution paths (accept,
  /// decline, timeout, other-party-ended) — all of which should call
  /// this unconditionally rather than trying to track which one "owns"
  /// stopping it.
  Future<void> stop() async {
    if (!_isPlaying) return;
    _isPlaying = false;
    try {
      await _player.stop();
      debugPrint('🔕 [Ringtone] Stopped');
    } catch (e) {
      debugPrint('⚠️ [Ringtone] Failed to stop: $e');
    }
  }

  void dispose() {
    _player.dispose();
  }
}