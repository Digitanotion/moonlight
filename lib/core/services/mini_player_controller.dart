import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/services/agora_engine_pool.dart';
import 'package:moonlight/core/services/pip_service.dart';
import 'package:moonlight/core/services/screen_guard.dart';
import 'package:moonlight/features/home/domain/entities/live_item.dart';

/// State for the in-app minimized livestream ("mini player").
///
/// Distinct from OS Picture-in-Picture (`PipService`): this keeps the stream
/// in a small draggable window *inside the app* so the user can browse the
/// feed, open chats, etc. while it keeps playing. OS PiP still takes over on
/// top of this if the user then backgrounds the whole app.
///
/// Lifecycle of the shared resources (Agora pool, PipService, ScreenGuard):
///   full viewer open   -> pager acquires PipService + ScreenGuard
///   minimize           -> pager pops but does NOT release them; the mini
///                         player is now on screen and they carry over
///   expand             -> pager is re-pushed with `resumingFromMini: true`
///                         and skips re-acquiring (the refs never dropped)
///   mini closed (X)    -> release both + pool.leaveAll()
///   full viewer closed -> pager releases both + pool.leaveAll()
class MiniStreamRef {
  final List<LiveItem> items;
  final int index;
  const MiniStreamRef({required this.items, required this.index});
}

class MiniPlayerController extends ChangeNotifier {
  MiniPlayerController._();
  static final MiniPlayerController instance = MiniPlayerController._();

  MiniStreamRef? _ref;
  MiniStreamRef? get ref => _ref;
  bool get isActive => _ref != null;

  /// Fires when the user taps the mini player to go back to full screen — the
  /// app-root host listens and re-pushes the viewer.
  final _expandCtrl = StreamController<MiniStreamRef>.broadcast();
  Stream<MiniStreamRef> get onExpand => _expandCtrl.stream;

  /// The active pager registers a "minimize me" callback here so the deeply
  /// nested top-bar button can trigger it without plumbing.
  VoidCallback? _minimizeRequest;

  void bindActivePager(VoidCallback onMinimizeRequested) =>
      _minimizeRequest = onMinimizeRequested;

  void unbindActivePager(VoidCallback onMinimizeRequested) {
    if (identical(_minimizeRequest, onMinimizeRequested)) {
      _minimizeRequest = null;
    }
  }

  /// True when a pager is on screen that can be minimized in-app.
  bool get canMinimize => _minimizeRequest != null;

  /// Called from the viewer's "minimize" button.
  void requestMinimize() => _minimizeRequest?.call();

  /// The pager calls this right after it pops itself.
  void enterMini(MiniStreamRef ref) {
    _ref = ref;
    notifyListeners();
  }

  /// User tapped the mini player — the root listener re-opens the full viewer.
  void requestExpand() {
    final ref = _ref;
    if (ref == null) return;
    _ref = null;
    notifyListeners();
    _expandCtrl.add(ref);
  }

  /// User dismissed the mini player. This owns the teardown now.
  void close() {
    _ref = null;
    try {
      sl<AgoraEnginePool>().leaveAll();
    } catch (_) {}
    PipService.instance.release();
    ScreenGuard.release();
    notifyListeners();
  }
}
