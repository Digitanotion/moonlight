import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One thing the phone must allow for calls (and the rest of the app) to
/// work. The "Set up calls" guide walks through the missing ones in order.
enum SetupItem {
  notifications,
  callRingtone,
  fullScreen,
  lockScreen,
  microphone,
  camera,
  battery,
  autostart,
}

/// Checks what's still missing and opens the right settings page for each.
class CallSetupService {
  CallSetupService._();
  static final instance = CallSetupService._();

  static const _native = MethodChannel('com.app.moonlightstream/call_setup');

  /// Must match NotificationService's incoming-call channel.
  static const callChannelId = 'incoming_call_ring_v2';

  static const _autostartDoneKey = 'call_setup_autostart_done';
  static const _lockScreenDoneKey = 'call_setup_lockscreen_done';

  Map<String, dynamic>? _info;

  Future<Map<String, dynamic>> _deviceInfo() async {
    if (_info != null) return _info!;
    try {
      final raw = await _native.invokeMethod<Map>('info');
      _info = Map<String, dynamic>.from(raw ?? const {});
    } catch (_) {
      _info = const {};
    }
    return _info!;
  }

  /// Phone maker name for instructions, e.g. "Xiaomi".
  Future<String> makerName() async {
    final m = ((await _deviceInfo())['manufacturer'] ?? '').toString();
    if (m.isEmpty) return 'your phone';
    return m[0].toUpperCase() + m.substring(1);
  }

  /// Every item that applies to this phone, in the order the guide asks.
  Future<List<SetupItem>> applicable() async {
    final out = <SetupItem>[];
    for (final item in SetupItem.values) {
      if (await _applies(item)) out.add(item);
    }
    return out;
  }

  /// Done / not done for every item that applies to this phone.
  Future<Map<SetupItem, bool>> statuses() async {
    final out = <SetupItem, bool>{};
    for (final item in await applicable()) {
      out[item] = await isDone(item);
    }
    return out;
  }

  /// Items still missing, in the order the guide asks for them.
  Future<List<SetupItem>> missing() async => [
    for (final e in (await statuses()).entries)
      if (!e.value) e.key,
  ];

  Future<bool> _applies(SetupItem item) async {
    if (!Platform.isAndroid) {
      // iOS handles ringing itself; only the basic permissions apply.
      return item == SetupItem.notifications ||
          item == SetupItem.microphone ||
          item == SetupItem.camera;
    }
    if (item == SetupItem.lockScreen) {
      // Makers that block the call screen over the lock screen unless their
      // own switches are on (Xiaomi, vivo, Huawei, Tecno…).
      return (await _deviceInfo())['hasLockScreenSwitches'] == true;
    }
    if (item == SetupItem.autostart) {
      // Phones whose maker adds an auto-start switch (Xiaomi, OPPO, vivo,
      // Tecno, Huawei…).
      return (await _deviceInfo())['hasAutostartPage'] == true;
    }
    return true;
  }

  /// Items the app can't read on this phone — the user confirms them
  /// ("I've turned it on").
  Future<bool> needsConfirm(SetupItem item) async {
    if (item == SetupItem.autostart) return true;
    if (item == SetupItem.lockScreen) {
      return !(await _lockScreenReadable());
    }
    return false;
  }

  bool? _lockReadable;
  Future<bool> _lockScreenReadable() async {
    if (_lockReadable != null) return _lockReadable!;
    try {
      _lockReadable =
          await _native.invokeMethod<bool>('lockScreenReadable') ?? false;
    } catch (_) {
      _lockReadable = false;
    }
    return _lockReadable!;
  }

  Future<bool> isDone(SetupItem item) async {
    try {
      switch (item) {
        case SetupItem.notifications:
          return await Permission.notification.isGranted;
        case SetupItem.callRingtone:
          // Can't ring while all notifications are off; the notifications
          // step comes first and this is re-checked right after it.
          if (!await Permission.notification.isGranted) return false;
          final blocked = await _native.invokeMethod<bool>(
            'callChannelBlocked',
            {'channelId': callChannelId},
          );
          return blocked != true;
        case SetupItem.fullScreen:
          return await _native.invokeMethod<bool>('canUseFullScreenIntent') ??
              true;
        case SetupItem.lockScreen:
          if (await _lockScreenReadable()) {
            return await _native.invokeMethod<bool>('lockScreenAllowed') ??
                true;
          }
          final prefs = await SharedPreferences.getInstance();
          return prefs.getBool(_lockScreenDoneKey) ?? false;
        case SetupItem.microphone:
          return await Permission.microphone.isGranted;
        case SetupItem.camera:
          return await Permission.camera.isGranted;
        case SetupItem.battery:
          return await Permission.ignoreBatteryOptimizations.isGranted;
        case SetupItem.autostart:
          final prefs = await SharedPreferences.getInstance();
          return prefs.getBool(_autostartDoneKey) ?? false;
      }
    } catch (e) {
      debugPrint('⚠️ CallSetup check $item failed: $e');
      return true; // never nag about something we can't check
    }
  }

  /// Ask for [item]: a system pop-up where Android has one, otherwise the
  /// exact settings page. Returns when the pop-up closes or the settings
  /// page has been opened (the guide re-checks when the app resumes).
  Future<void> fix(SetupItem item) async {
    try {
      switch (item) {
        case SetupItem.notifications:
          await _requestOrSettings(Permission.notification);
        case SetupItem.callRingtone:
          await _native.invokeMethod('openChannelSettings', {
            'channelId': callChannelId,
          });
        case SetupItem.fullScreen:
          await _native.invokeMethod('openFullScreenSettings');
        case SetupItem.lockScreen:
          await _native.invokeMethod('openLockScreenPermissions');
        case SetupItem.microphone:
          await _requestOrSettings(Permission.microphone);
        case SetupItem.camera:
          await _requestOrSettings(Permission.camera);
        case SetupItem.battery:
          final s = await Permission.ignoreBatteryOptimizations.request();
          if (!s.isGranted) await openAppSettings();
        case SetupItem.autostart:
          await _native.invokeMethod('openAutostart');
      }
    } catch (e) {
      debugPrint('⚠️ CallSetup fix $item failed: $e');
      await openAppSettings();
    }
  }

  /// For items the app can't read: the user says it's on.
  Future<void> markConfirmed(SetupItem item) async {
    final prefs = await SharedPreferences.getInstance();
    if (item == SetupItem.autostart) await prefs.setBool(_autostartDoneKey, true);
    if (item == SetupItem.lockScreen) await prefs.setBool(_lockScreenDoneKey, true);
  }

  /// Asks once; if Android won't show the pop-up again ("don't ask again"
  /// or denied twice), opens the app's settings page instead.
  Future<void> _requestOrSettings(Permission p) async {
    if (await p.isPermanentlyDenied) {
      await openAppSettings();
      return;
    }
    final s = await p.request();
    if (s.isPermanentlyDenied) await openAppSettings();
  }
}
