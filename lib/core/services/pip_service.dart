import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:moonlight/core/widgets/connection_toast.dart';

/// Single owner of the native Picture-in-Picture channel
/// (`com.app.moonlightstream/pip`, implemented in `MainActivity.kt`).
///
/// PiP auto-enter is **ref-counted**: it is armed only while at least one
/// screen that owns a full-bleed video (the live viewer, a video post) is
/// mounted and calls [acquire]. When the last of them calls [release] the
/// native flag is cleared, so the app never auto-minimises into PiP from an
/// unrelated screen.
class PipService {
  PipService._() {
    _channel.setMethodCallHandler(_onNativeCall);
  }
  static final PipService instance = PipService._();

  static const _channel = MethodChannel('com.app.moonlightstream/pip');

  int _refs = 0;

  /// True while the app is rendering in the OS PiP window.
  final ValueNotifier<bool> isInPipMode = ValueNotifier<bool>(false);

  Future<dynamic> _onNativeCall(MethodCall call) async {
    if (call.method == 'onPipModeChanged') {
      final active = (call.arguments is Map)
          ? (call.arguments['active'] as bool? ?? false)
          : false;
      isInPipMode.value = active;
      SimpleConnectionToast.pipActive.value = active;

      // Native clears its own auto-enter flag whenever PiP ends (belt &
      // braces against a stale flag). If a video screen is still on top —
      // e.g. the user tapped the PiP window to expand it back into the app
      // — re-assert so backgrounding again still works.
      if (!active && _refs > 0) {
        _setVideoPlaying(true);
      }
    }
    return null;
  }

  /// Register interest in PiP (call from a video screen's initState).
  void acquire() {
    _refs++;
    if (_refs == 1) _setVideoPlaying(true);
  }

  /// Give up interest (call from dispose). Clears auto-PiP when the count
  /// hits zero.
  void release() {
    if (_refs == 0) return;
    _refs--;
    if (_refs == 0) _setVideoPlaying(false);
  }

  Future<void> _setVideoPlaying(bool playing) async {
    try {
      await _channel.invokeMethod('setVideoPlaying', {'playing': playing});
    } catch (e) {
      debugPrint('PipService.setVideoPlaying: $e');
    }
  }

  /// Enter PiP right now (a "minimize" button).
  Future<void> enterPip() async {
    try {
      await _channel.invokeMethod('enterPip');
    } catch (e) {
      debugPrint('PipService.enterPip: $e');
    }
  }
}
