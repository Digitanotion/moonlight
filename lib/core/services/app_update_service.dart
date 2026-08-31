import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final String storeUrl;
  final String notes;

  const AppUpdateInfo({
    required this.available,
    required this.forced,
    required this.latestVersion,
    required this.latestBuild,
    required this.storeUrl,
    required this.notes,
  });
}

/// Checks `GET /api/v1/app-version` against the running build and decides
/// whether to prompt (soft) or block (forced). Fails open — any error just
/// means "no update to show", never blocks the app.
class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static const _snoozedBuildKey = 'app_update_snoozed_build';

  bool _checkedThisSession = false;

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
      final storeUrl = (p['store_url'] ?? '').toString();
      if (latestBuild == 0 || storeUrl.isEmpty) return null;

      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;

      final forced = globalForce || (minBuild > 0 && currentBuild < minBuild);
      final available = forced || currentBuild < latestBuild;

      if (!available) return null;

      return AppUpdateInfo(
        available: true,
        forced: forced,
        latestVersion: (p['latest_version'] ?? '').toString(),
        latestBuild: latestBuild,
        storeUrl: storeUrl,
        notes: (p['notes'] ?? '').toString(),
      );
    } catch (e) {
      debugPrint('AppUpdateService.check: $e');
      return null;
    }
  }

  /// True if the user has already dismissed the *soft* prompt for this exact
  /// build — don't nag again until there's a newer one.
  Future<bool> isSnoozed(int latestBuild) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getInt(_snoozedBuildKey) ?? 0) >= latestBuild;
    } catch (_) {
      return false;
    }
  }

  Future<void> snooze(int latestBuild) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_snoozedBuildKey, latestBuild);
    } catch (_) {}
  }

  static int _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('${v ?? ''}') ?? 0;
  }
}
