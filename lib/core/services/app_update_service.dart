import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:moonlight/core/network/dio_client.dart';
import 'package:moonlight/core/injection_container.dart';

/// Result of an update check.
class AppUpdateInfo {
  /// A newer build than the one running exists.
  final bool available;

  /// The running build is older than the minimum supported build (or the
  /// server set a global force flag) — the user must update to continue.
  final bool forced;

  final String latestVersion; // e.g. "1.5.0"
  final int latestBuild;

  /// An https Play/App Store URL the user can always open in a browser.
  final String storeUrl;

  /// A `market://details?id=<pkg>` deep link for the primary button — opens
  /// the Play Store app directly. Empty on iOS / when the package id is
  /// unavailable. Callers should try this first, then fall back to [storeUrl].
  final String marketUrl;

  final String notes;

  const AppUpdateInfo({
    required this.available,
    required this.forced,
    required this.latestVersion,
    required this.latestBuild,
    required this.storeUrl,
    required this.marketUrl,
    required this.notes,
  });
}

/// Checks `GET /api/v1/app-version` against the running build and decides
/// whether to prompt (soft) or block (forced). Fails open — any error just
/// means "no update to show", never blocks the app.
class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  bool _checkedThisSession = false;

  /// The user tapped "Later" on the soft prompt during THIS app session.
  /// Deliberately not persisted: the client's requirement is that the soft
  /// prompt reappears on every fresh launch until the user actually updates.
  /// Forced updates are never affected by this.
  bool _softDismissedThisSession = false;
  bool get softDismissedThisSession => _softDismissedThisSession;
  void dismissSoftPromptForSession() => _softDismissedThisSession = true;

  /// [force] re-checks even if already checked this session (used on resume).
  Future<AppUpdateInfo?> check({bool force = false}) async {
    if (_checkedThisSession && !force) return null;
    _checkedThisSession = true;

    try {
      final res = await sl<DioClient>().dio.get('/v1/app-version');
      final data = (res.data is Map)
          ? (res.data as Map).cast<String, dynamic>()
          : <String, dynamic>{};

      final globalForce = data['force'] == true;
      final platform = Platform.isIOS ? 'ios' : 'android';
      final p = (data[platform] is Map)
          ? (data[platform] as Map).cast<String, dynamic>()
          : <String, dynamic>{};

      final latestBuild = _asInt(p['latest_build']);
      final minBuild = _asInt(p['min_build']);
      if (latestBuild == 0) return null;

      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;
      final pkg = info.packageName;

      // Never trust the server URL blindly — synthesize a correct one from the
      // real package id when it's missing or not a recognisable store URL.
      // (A blank/wrong store_url used to make the whole prompt vanish.)
      final storeUrl = _resolveStoreUrl((p['store_url'] ?? '').toString(), pkg);
      final marketUrl =
          (Platform.isAndroid && pkg.isNotEmpty) ? 'market://details?id=$pkg' : '';

      final forced = globalForce || (minBuild > 0 && currentBuild < minBuild);
      final available = forced || currentBuild < latestBuild;

      if (!available) return null;

      return AppUpdateInfo(
        available: true,
        forced: forced,
        latestVersion: (p['latest_version'] ?? '').toString(),
        latestBuild: latestBuild,
        storeUrl: storeUrl,
        marketUrl: marketUrl,
        notes: (p['notes'] ?? '').toString(),
      );
    } catch (e) {
      debugPrint('AppUpdateService.check: $e');
      return null;
    }
  }

  String _resolveStoreUrl(String serverUrl, String pkg) {
    final s = serverUrl.trim();
    if (s.startsWith('https://play.google.com/') ||
        s.startsWith('market://') ||
        s.startsWith('https://apps.apple.com/')) {
      return s;
    }
    if (Platform.isAndroid && pkg.isNotEmpty) {
      return 'https://play.google.com/store/apps/details?id=$pkg';
    }
    return s; // iOS with no server URL — nothing sensible to synthesize
  }

  static int _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('${v ?? ''}') ?? 0;
  }
}
