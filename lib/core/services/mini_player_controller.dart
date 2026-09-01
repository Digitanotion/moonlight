import 'package:flutter/foundation.dart';

/// Drives the viewer's in-app "minimise" state.
///
/// The live viewer route is pushed as a *transparent* route, so when
/// [minimized] is true the pager shrinks itself into a small draggable
/// window and the screen underneath (feed, home, chat) shows through and is
/// interactive. The route — and therefore all of its state, its Agora
/// connection and its Pusher subscriptions — stays fully mounted, so
/// restoring is instant with no re-join.
///
/// Distinct from OS Picture-in-Picture (`PipService`), which shrinks the
/// whole app into a system window when it's backgrounded.
class MiniPlayerController extends ChangeNotifier {
  MiniPlayerController._();
  static final MiniPlayerController instance = MiniPlayerController._();

  bool _minimized = false;
  bool get minimized => _minimized;

  /// The active pager registers a "minimise me" hook so the deeply nested
  /// top-bar button can trigger it, and so we know a minimisable viewer is on
  /// screen at all (vs the standalone deep-link route, which uses OS PiP).
  VoidCallback? _minimizeHook;

  void bindActivePager(VoidCallback onMinimize) => _minimizeHook = onMinimize;

  void unbindActivePager(VoidCallback onMinimize) {
    if (identical(_minimizeHook, onMinimize)) _minimizeHook = null;
    _minimized = false;
  }

  /// True when an in-app minimisable viewer is on screen.
  bool get canMinimize => _minimizeHook != null;

  /// Called from the viewer's minimise button.
  void requestMinimize() => _minimizeHook?.call();

  void minimize() {
    if (_minimized) return;
    _minimized = true;
    notifyListeners();
  }

  void expand() {
    if (!_minimized) return;
    _minimized = false;
    notifyListeners();
  }
}
