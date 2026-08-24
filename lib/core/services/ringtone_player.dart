// lib/core/services/ringtone_player.dart
//
// Plays the incoming-call ringtone NATIVELY on Android (see MainActivity's
// "com.app.moonlightstream/ringtone" channel), NOT through Flutter's own
// audio engine. A first attempt used the audioplayers package here — that
// shares its audio session with the rest of the Flutter engine, including
// video_player, and reliably broke the feed's video/audio playback (even
// after calling stop()) once a ringtone was played. Routing this through a
// separate native MediaPlayer on AudioAttributes.USAGE_NOTIFICATION_RINGTONE
// puts it on Android's own ringtone stream, entirely outside that shared
// session — confirmed by testing not to touch the feed's playback at all.
//
// Deliberately NO Dart-side "am I playing" guard — confirmed by testing to
// be actively wrong, not just unnecessary. A Dart singleton (`factory ()
// => _instance`) only gives ONE instance PER ISOLATE, not one for the
// whole app process. play() is routinely called from the FCM background
// handler's isolate; stop() is routinely called from the main app
// isolate's CallKitService listener — two completely separate Dart
// memory spaces, each with its own independent copy of any instance
// field. A local `_isPlaying` flag set by play() in one isolate is
// invisible to stop() running in the other, so stop() would see "not
// playing" and return without ever reaching the native channel — leaving
// the ringtone silenced only by the native 60s safety timeout, never by
// the actual resolution event. The native side (packages/ringtone_native)
// already handles idempotency correctly and process-wide (a real shared
// singleton via Kotlin's companion object) — every call here just
// forwards to it unconditionally and lets it decide.
//
// iOS: not wired up yet — this is currently Android-only (no matching
// MethodChannel handler on the iOS side). play()/stop() are safe no-ops
// there (the channel call simply won't be handled), but the incoming call
// itself still works; it just rings silently on iOS for now.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RingtonePlayer {
  static final RingtonePlayer _instance = RingtonePlayer._internal();
  factory RingtonePlayer() => _instance;
  RingtonePlayer._internal();

  static const _channel = MethodChannel('com.app.moonlightstream/ringtone');

  /// Starts looping the ringtone natively. Safe to call repeatedly from
  /// any isolate — the native side is the single source of truth for
  /// whether it's already playing.
  Future<void> play() async {
    try {
      await _channel.invokeMethod('play');
      debugPrint('🔔 [Ringtone] play() sent');
    } catch (e) {
      debugPrint('⚠️ [Ringtone] Failed to start: $e');
    }
  }

  /// Stops playback immediately. Safe to call even if never started (on
  /// THIS isolate or any other), or called multiple times from different
  /// resolution paths (accept, decline, timeout, other-party-ended) —
  /// all of which should call this unconditionally rather than trying to
  /// track which one "owns" stopping it.
  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
      debugPrint('🔕 [Ringtone] stop() sent');
    } catch (e) {
      debugPrint('⚠️ [Ringtone] Failed to stop: $e');
    }
  }
}
