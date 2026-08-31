import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:moonlight/core/widgets/connection_toast.dart';

/// Single owner of the native Picture-in-Picture channel
/// (`com.app.moonlightstream/pip`, implemented in `MainActivity.kt`).
///
/// Only one `MethodCallHandler` may be attached to a channel at a time, so
/// every screen that cares about PiP (video posts, the live viewer) goes
/// through this singleton instead of creating its own channel.
class PipService {
  PipService._() {
    _channel.setMethodCallHandler(_onNativeCall);
  }
  static final PipService instance = PipService._();

  static const _channel = MethodChannel('com.app.moonlightstream/pip');

  /// True while the app is rendering in the OS PiP window.
  final ValueNotifier<bool> isInPipMode = ValueNotifier<bool>(false);

  Future<dynamic> _onNativeCall(MethodCall call) async {
    if (call.method == 'onPipModeChanged') {
      final active = (call.arguments is Map)
          ? (call.arguments['active'] as bool? ?? false)
          : false;
      isInPipMode.value = active;
      // Suppress the global connection toast while the PiP window is up.
      SimpleConnectionToast.pipActive.value = active;
    }
    return null;
  }

  /// Tell Android whether a video is playing. On API 31+ this enables
  /// auto-enter-PiP when the app is backgrounded; below that it just keeps
  /// the PiP params current for a manual [enterPip].
  Future<void> setVideoPlaying(bool playing) async {
    try {
      await _channel.invokeMethod('setVideoPlaying', {'playing': playing});
    } catch (e) {
      debugPrint('PipService.setVideoPlaying: $e');
    }
  }

  /// Enter PiP right now (e.g. a "minimize" button).
  Future<void> enterPip() async {
    try {
      await _channel.invokeMethod('enterPip');
    } catch (e) {
      debugPrint('PipService.enterPip: $e');
    }
  }
}
