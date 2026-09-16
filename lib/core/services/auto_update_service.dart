// lib/core/services/auto_update_service.dart
//
// Owns the whole "flexible" Google Play in-app update lifecycle: kicks off
// the background download, tracks real byte progress (via the local
// in_app_update fork — see packages/in_app_update_patched/README-FORK.md),
// and — once downloaded — restarts the app itself after a short heads-up
// banner, with no tap required from the user. This is the piece that makes
// updates genuinely automatic instead of the old "tap Restart" snackbar.
//
// Deliberately does NOT touch:
//  - the server-driven forced gate (ForceUpdateScreen) — that stays exactly
//    as it was, a hard non-dismissible block;
//  - Play's own "immediate" update flow (high-priority releases) — that's
//    entirely Play's full-screen UI, nothing of ours to show progress for.
//
// Android-only: iOS has no equivalent API (Apple doesn't allow apps to
// silently self-update), so every method here is a no-op off Android.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart' as play;

enum AutoUpdateStage {
  /// Nothing happening — no update, or not yet checked.
  idle,

  /// Downloading in the background. [AutoUpdateService.progress] is
  /// 0.0–1.0 once Play has reported a total size, else null (indeterminate).
  downloading,

  /// Fully downloaded, counting down to an automatic restart.
  downloaded,

  /// `completeFlexibleUpdate()` has been called — the process is about to
  /// be killed and relaunched by the OS.
  restarting,

  /// The download or install failed — surfaced briefly, then back to idle.
  failed,
}

class AutoUpdateService {
  AutoUpdateService._();
  static final AutoUpdateService instance = AutoUpdateService._();

  /// How long the "update ready — restarting shortly" banner stays up
  /// before the app actually restarts. Long enough to read, short enough
  /// that "automatic" doesn't feel like a lie.
  static const Duration _restartCountdown = Duration(seconds: 5);

  final ValueNotifier<AutoUpdateStage> stage = ValueNotifier(
    AutoUpdateStage.idle,
  );

  /// 0.0–1.0 while downloading; null when there's no meaningful fraction
  /// yet (Play hasn't reported a total size) or when [stage] is idle.
  final ValueNotifier<double?> progress = ValueNotifier<double?>(null);

  StreamSubscription<play.InstallProgress>? _sub;
  bool _starting = false;
  bool _restartScheduled = false;
  Timer? _restartTimer;

  /// Tries to take ownership of a flexible update described by [result]
  /// (from `InAppUpdate.checkForUpdate()`). Returns true if it did — the
  /// caller should treat the flexible case as fully handled and not show
  /// its own UI for it. Returns false if there's nothing for this service
  /// to do (not Android, no flexible update, or already tracking one),
  /// so the caller can fall through to its existing logic unchanged.
  Future<bool> tryStart(play.AppUpdateInfo result) async {
    if (!Platform.isAndroid) return false;

    // Already tracking one (e.g. resume re-check while still downloading
    // from launch) — nothing new to do, but this IS a flexible update we
    // own, so tell the caller to leave it alone.
    if (stage.value != AutoUpdateStage.idle) return true;

    // A previous flexible download already finished (this session or a
    // prior one) — Play reports this regardless of whether a NEW flexible
    // update is still "allowed" to start, so check it before that gate.
    if (result.installStatus == play.InstallStatus.downloaded) {
      _listen();
      _onDownloaded();
      return true;
    }

    if (!result.flexibleUpdateAllowed) return false;
    _listen();

    if (_starting) return true;
    _starting = true;
    stage.value = AutoUpdateStage.downloading;
    progress.value = null;

    try {
      await play.InAppUpdate.startFlexibleUpdate();
    } catch (e) {
      debugPrint('AutoUpdateService.tryStart: $e');
      _starting = false;
      stage.value = AutoUpdateStage.failed;
      // Brief flash of "failed" on the ring, then quietly back to idle —
      // next launch/resume check will just try again.
      Future.delayed(const Duration(seconds: 3), _reset);
      return true; // we did own this attempt, even though it failed
    }
    _starting = false;
    return true;
  }

  void _listen() {
    if (_sub != null) return;
    _sub = play.InAppUpdate.installUpdateListener.listen((p) {
      switch (p.status) {
        case play.InstallStatus.downloading:
        case play.InstallStatus.pending:
          stage.value = AutoUpdateStage.downloading;
          progress.value = p.fraction;
          break;
        case play.InstallStatus.downloaded:
          _onDownloaded();
          break;
        case play.InstallStatus.failed:
        case play.InstallStatus.canceled:
          stage.value = AutoUpdateStage.failed;
          Future.delayed(const Duration(seconds: 3), _reset);
          break;
        default:
          break;
      }
    }, onError: (e) => debugPrint('AutoUpdateService listener: $e'));
  }

  void _onDownloaded() {
    if (_restartScheduled) return;
    _restartScheduled = true;
    progress.value = 1.0;
    stage.value = AutoUpdateStage.downloaded;

    _restartTimer?.cancel();
    _restartTimer = Timer(_restartCountdown, () async {
      stage.value = AutoUpdateStage.restarting;
      try {
        // The process is killed and relaunched by Play once this resolves
        // successfully — nothing after this line is expected to run.
        await play.InAppUpdate.completeFlexibleUpdate();
      } catch (e) {
        debugPrint('AutoUpdateService.completeFlexibleUpdate: $e');
        _reset();
      }
    });
  }

  void _reset() {
    _starting = false;
    _restartScheduled = false;
    _restartTimer?.cancel();
    _restartTimer = null;
    progress.value = null;
    stage.value = AutoUpdateStage.idle;
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _restartTimer?.cancel();
  }
}
