import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Single owner of the screen-stay-awake flag while the user is watching
/// video or a livestream — the live viewer, the video-watching feed, and
/// any video post detail view.
///
/// **Ref-counted** for the same reason PipService is: video_preload_service
/// .dart keeps a small number of `VideoPlayerController`s alive
/// at once (a feed item scrolled past but not yet evicted, a preloaded
/// upcoming item), so more than one video-owning widget can be mounted
/// simultaneously. If each one called `WakelockPlus.disable()` on its own
/// dispose, the first one to go away would turn the screen-sleep timer
/// back on while a different video is still actively playing. Only the
/// transition from 0 → 1 acquires, and 1 → 0 releases.
///
/// Also re-asserts the flag on app resume: some OEM Android builds clear
/// `FLAG_KEEP_SCREEN_ON` when the app is backgrounded and restored rather
/// than preserving it (the same reason live_host_page.dart re-enables on
/// resume for the host's own broadcast).
class WakelockCoordinator with WidgetsBindingObserver {
  WakelockCoordinator._() {
    WidgetsBinding.instance.addObserver(this);
  }
  static final WakelockCoordinator instance = WakelockCoordinator._();

  int _refs = 0;

  /// Register interest in keeping the screen awake (call from a video/
  /// livestream screen's initState, or when a post transitions into being
  /// a video).
  void acquire() {
    _refs++;
    if (_refs == 1) WakelockPlus.enable();
  }

  /// Give up interest (call from dispose, or when a post stops being a
  /// video). Only actually releases the OS flag once nothing else holds it.
  void release() {
    if (_refs == 0) return;
    _refs--;
    if (_refs == 0) WakelockPlus.disable();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _refs > 0) {
      WakelockPlus.enable();
    }
  }
}
