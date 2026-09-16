// Local fork of the `in_app_update` pub.dev package (see
// packages/in_app_update_patched/README-FORK.md), wired in via a
// `dependency_overrides` entry in the app's pubspec.yaml so every
// `import 'package:in_app_update/in_app_update.dart'` elsewhere in the app
// keeps working unchanged. The only deliberate change from upstream:
// `installUpdateListener` now carries real byte progress
// (bytesDownloaded/totalBytesToDownload), not just the bare status — see
// [InstallProgress] below and the matching Android-side change in
// InAppUpdatePlugin.kt's `addState`.

import 'dart:async';

import 'package:flutter/services.dart';

/// Status of a download/install.
///
/// For more information, see its corresponding page on
/// [Android Developers](https://developer.android.com/reference/com/google/android/play/core/install/model/InstallStatus.html).
enum InstallStatus {
  unknown(0),
  pending(1),
  downloading(2),
  installing(3),
  installed(4),
  failed(5),
  canceled(6),
  downloaded(11);

  const InstallStatus(this.value);
  final int value;
}

/// Availability of an update for the requested package.
///
/// For more information, see its corresponding page on
/// [Android Developers](https://developer.android.com/reference/com/google/android/play/core/install/model/UpdateAvailability.html).
enum UpdateAvailability {
  unknown(0),
  updateNotAvailable(1),
  updateAvailable(2),
  developerTriggeredUpdateInProgress(3);

  const UpdateAvailability(this.value);
  final int value;
}

/// One install-state event, with real byte progress — `bytesDownloaded`/
/// `totalBytesToDownload` are 0 whenever Play hasn't reported them for the
/// current [status] (e.g. before a download starts), not just while
/// actively downloading.
class InstallProgress {
  final InstallStatus status;
  final int bytesDownloaded;
  final int totalBytesToDownload;

  const InstallProgress({
    required this.status,
    required this.bytesDownloaded,
    required this.totalBytesToDownload,
  });

  /// 0.0–1.0, or null if there's nothing to divide (no total reported yet).
  double? get fraction =>
      totalBytesToDownload > 0 ? bytesDownloaded / totalBytesToDownload : null;
}

enum AppUpdateResult {
  /// The user has accepted the update. For immediate updates, you might not
  /// receive this callback because the update should already be completed by
  /// Google Play by the time the control is given back to your app.
  success,

  /// The user has denied or cancelled the update.
  userDeniedUpdate,

  /// Some other error prevented either the user from providing consent or the
  /// update to proceed.
  inAppUpdateFailed,
}

class InAppUpdate {
  static const MethodChannel _channel =
      const MethodChannel('de.ffuf.in_app_update/methods');
  static const EventChannel _installListener =
      const EventChannel('de.ffuf.in_app_update/stateEvents');

  /// Has to be called before being able to start any update.
  ///
  /// Returns [AppUpdateInfo], which can be used to decide if
  /// [startFlexibleUpdate] or [performImmediateUpdate] should be called.
  static Future<AppUpdateInfo> checkForUpdate() async {
    final result = await _channel.invokeMethod('checkForUpdate');

    return AppUpdateInfo(
      updateAvailability: UpdateAvailability.values.firstWhere(
          (element) => element.value == result['updateAvailability']),
      immediateUpdateAllowed: result['immediateAllowed'],
      immediateAllowedPreconditions: result['immediateAllowedPreconditions']
          ?.map<int>((e) => e as int)
          .toList(),
      flexibleUpdateAllowed: result['flexibleAllowed'],
      flexibleAllowedPreconditions: result['flexibleAllowedPreconditions']
          ?.map<int>((e) => e as int)
          .toList(),
      availableVersionCode: result['availableVersionCode'],
      installStatus: InstallStatus.values
          .firstWhere((element) => element.value == result['installStatus']),
      packageName: result['packageName'],
      clientVersionStalenessDays: result['clientVersionStalenessDays'],
      updatePriority: result['updatePriority'],
    );
  }

  /// Fired on every install-state change. Carries real byte progress
  /// (Play Core's `InstallState.bytesDownloaded()`/`totalBytesToDownload()`)
  /// alongside the status — this local fork's one deliberate change from
  /// upstream, which only reports the bare status.
  static Stream<InstallProgress> get installUpdateListener {
    return _installListener.receiveBroadcastStream().map((dynamic event) {
      final map = (event as Map).cast<String, dynamic>();
      final statusValue = map['status'] as int? ?? 0;
      return InstallProgress(
        status: InstallStatus.values.firstWhere(
          (s) => s.value == statusValue,
          orElse: () => InstallStatus.unknown,
        ),
        bytesDownloaded: (map['bytesDownloaded'] as num?)?.toInt() ?? 0,
        totalBytesToDownload:
            (map['totalBytesToDownload'] as num?)?.toInt() ?? 0,
      );
    });
  }

  /// Performs an immediate update that is entirely handled by the Play API.
  ///
  /// [checkForUpdate] has to be called first to be able to run this.
  static Future<AppUpdateResult> performImmediateUpdate() async {
    try {
      await _channel.invokeMethod('performImmediateUpdate');
      return AppUpdateResult.success;
    } on PlatformException catch (e) {
      if (e.code == 'USER_DENIED_UPDATE') {
        return AppUpdateResult.userDeniedUpdate;
      } else if (e.code == 'IN_APP_UPDATE_FAILED') {
        return AppUpdateResult.inAppUpdateFailed;
      }

      throw e;
    }
  }

  /// Starts the download of the app update.
  ///
  /// Throws a [PlatformException] if the download fails.
  /// When the returned [Future] is completed without any errors,
  /// [completeFlexibleUpdate] can be called to install the update.
  ///
  /// [checkForUpdate] has to be called first to be able to run this.
  static Future<AppUpdateResult> startFlexibleUpdate() async {
    try {
      await _channel.invokeMethod('startFlexibleUpdate');
      return AppUpdateResult.success;
    } on PlatformException catch (e) {
      if (e.code == 'USER_DENIED_UPDATE') {
        return AppUpdateResult.userDeniedUpdate;
      } else if (e.code == 'IN_APP_UPDATE_FAILED') {
        return AppUpdateResult.inAppUpdateFailed;
      }

      throw e;
    }
  }

  /// Installs the update downloaded via [startFlexibleUpdate].
  ///
  /// [startFlexibleUpdate] has to be completed successfully.
  static Future<void> completeFlexibleUpdate() async {
    return await _channel.invokeMethod('completeFlexibleUpdate');
  }
}

/// Contains information about the availability and progress of an app
/// update.
///
/// For more information, see its corresponding page on
/// [Android Developers](https://developer.android.com/reference/com/google/android/play/core/appupdate/AppUpdateInfo).
class AppUpdateInfo {
  /// Whether an update is available for the app.
  ///
  /// This is a value from [UpdateAvailability].
  final UpdateAvailability updateAvailability;

  /// Whether an immediate update is allowed.
  final bool immediateUpdateAllowed;

  /// determine the reason why an update cannot be started
  final List<int>? immediateAllowedPreconditions;

  /// Whether a flexible update is allowed.
  final bool flexibleUpdateAllowed;

  /// determine the reason why an update cannot be started
  final List<int>? flexibleAllowedPreconditions;

  /// The version code of the update.
  ///
  /// If no updates are available, this is an arbitrary value.
  final int? availableVersionCode;

  /// The progress status of the update.
  ///
  /// This value is defined only if [updateAvailability] is
  /// [UpdateAvailability.developerTriggeredUpdateInProgress].
  ///
  /// This is a value from [InstallStatus].
  final InstallStatus installStatus;

  /// The package name for the app to be updated.
  final String packageName;

  /// The in-app update priority for this update, as defined by the developer
  /// in the Google Play Developer API.
  ///
  /// This value is defined only if [updateAvailability] is
  /// [UpdateAvailability.updateAvailable].
  final int updatePriority;

  /// The number of days since the Google Play Store app on the user's device
  /// has learnt about an available update.
  ///
  /// If update is not available, or if staleness information is unavailable,
  /// this is null.
  final int? clientVersionStalenessDays;

  AppUpdateInfo({
    required this.updateAvailability,
    required this.immediateUpdateAllowed,
    required this.immediateAllowedPreconditions,
    required this.flexibleUpdateAllowed,
    required this.flexibleAllowedPreconditions,
    required this.availableVersionCode,
    required this.installStatus,
    required this.packageName,
    required this.clientVersionStalenessDays,
    required this.updatePriority,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUpdateInfo &&
          runtimeType == other.runtimeType &&
          updateAvailability == other.updateAvailability &&
          immediateUpdateAllowed == other.immediateUpdateAllowed &&
          immediateAllowedPreconditions ==
              other.immediateAllowedPreconditions &&
          flexibleUpdateAllowed == other.flexibleUpdateAllowed &&
          flexibleAllowedPreconditions == other.flexibleAllowedPreconditions &&
          availableVersionCode == other.availableVersionCode &&
          installStatus == other.installStatus &&
          packageName == other.packageName &&
          clientVersionStalenessDays == other.clientVersionStalenessDays &&
          updatePriority == other.updatePriority;

  @override
  int get hashCode =>
      updateAvailability.hashCode ^
      immediateUpdateAllowed.hashCode ^
      immediateAllowedPreconditions.hashCode ^
      flexibleUpdateAllowed.hashCode ^
      flexibleAllowedPreconditions.hashCode ^
      availableVersionCode.hashCode ^
      installStatus.hashCode ^
      packageName.hashCode ^
      clientVersionStalenessDays.hashCode ^
      updatePriority.hashCode;

  @override
  String toString() =>
      'InAppUpdateState{updateAvailability: $updateAvailability, '
      'immediateUpdateAllowed: $immediateUpdateAllowed, '
      'immediateAllowedPreconditions: $immediateAllowedPreconditions, '
      'flexibleUpdateAllowed: $flexibleUpdateAllowed, '
      'flexibleAllowedPreconditions: $flexibleAllowedPreconditions, '
      'availableVersionCode: $availableVersionCode, '
      'installStatus: $installStatus, '
      'packageName: $packageName, '
      'clientVersionStalenessDays: $clientVersionStalenessDays, '
      'updatePriority: $updatePriority}';
}
