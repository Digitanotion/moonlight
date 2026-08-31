import 'package:flutter/foundation.dart';
import 'package:screen_protector/screen_protector.dart';

/// Ref-counted wrapper around [ScreenProtector].
///
/// The underlying plugin toggles a single global flag (Android `FLAG_SECURE`
/// + iOS secure-field overlay), so overlapping screens that each call
/// on/off in their own lifecycle would fight each other — e.g. a disposed
/// [LiveViewerScreen] inside the pager turning protection OFF while the
/// visible page still needs it ON.
///
/// Callers do [acquire] in `initState` and [release] in `dispose`; the real
/// plugin calls fire only on the 0↔1 transition.
class ScreenGuard {
  ScreenGuard._();

  static int _count = 0;

  static Future<void> acquire() async {
    _count++;
    if (_count != 1) return;
    try {
      await ScreenProtector.protectDataLeakageOn(); // Android FLAG_SECURE
      await ScreenProtector.preventScreenshotOn(); // Android + iOS
    } catch (e) {
      debugPrint('ScreenGuard.acquire failed: $e');
    }
  }

  static Future<void> release() async {
    if (_count == 0) return;
    _count--;
    if (_count != 0) return;
    try {
      await ScreenProtector.protectDataLeakageOff();
      await ScreenProtector.preventScreenshotOff();
    } catch (e) {
      debugPrint('ScreenGuard.release failed: $e');
    }
  }
}
