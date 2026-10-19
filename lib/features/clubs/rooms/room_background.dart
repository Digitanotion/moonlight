// lib/features/clubs/rooms/room_background.dart
//
// Keeps a club room running while the user is in other apps: an Android
// foreground service (RoomForegroundService.kt) with an ongoing "You're in
// a live room" notification. Without it Android cuts the mic as soon as the
// app leaves the screen and may close the app.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class RoomBackground {
  RoomBackground._();

  static const _channel = MethodChannel('com.app.moonlightstream/room');

  static String? _last;

  /// Start (or update) the service. [mic] = the user may be talking.
  static Future<void> start({
    required String title,
    required bool video,
    required bool mic,
  }) async {
    if (!Platform.isAndroid) return;
    final text = mic
        ? 'You\'re live in this ${video ? 'video' : 'audio'} room · tap to return'
        : 'Listening to this ${video ? 'video' : 'audio'} room · tap to return';
    final key = '$title|$text|$mic';
    if (key == _last) return;
    _last = key;
    try {
      await _channel.invokeMethod('start', {
        'title': title,
        'text': text,
        'mic': mic,
      });
    } catch (e) {
      debugPrint('[RoomBackground] start failed: $e');
    }
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid || _last == null) return;
    _last = null;
    try {
      await _channel.invokeMethod('stop');
    } catch (e) {
      debugPrint('[RoomBackground] stop failed: $e');
    }
  }
}
