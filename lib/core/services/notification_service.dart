import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/services/call_kit_service.dart';
import 'package:moonlight/core/services/notification_handler_service.dart';
import 'package:moonlight/core/services/ringtone_player.dart';
import 'package:moonlight/features/video_call/presentation/bloc/video_call_bloc.dart';
import 'package:moonlight/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Runs action-button taps (Accept/Decline) even if the app process was
// killed and this fires in a constrained background isolate — must be a
// top-level function, same pattern as the FCM background handler.
// Deliberately makes a raw, direct HTTP call rather than going through
// GetIt/VideoCallBloc, since we can't be certain the full app's DI graph
// is available in this isolate context. This is the fallback path's
// whole purpose: work even when the "normal" app-context flow can't be
// trusted to be ready.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  _handleActionTap(response);
}

void _handleActionTap(NotificationResponse response) {
  if (response.actionId != 'ACCEPT_CALL' && response.actionId != 'DECLINE_CALL') {
    return; // plain tap, not an action button — handled elsewhere
  }
  if (response.payload == null) return;

  Map<String, dynamic>? data;
  try {
    data = jsonDecode(response.payload!) as Map<String, dynamic>;
  } catch (_) {
    return;
  }

  final sessionUuid = data['session_uuid'] as String?;
  final apiBaseUrl = data['api_base_url'] as String?;
  if (sessionUuid == null || apiBaseUrl == null) return;

  final action = response.actionId == 'ACCEPT_CALL' ? 'accept' : 'reject';

  // Keep CallKit's native UI in sync too — the user resolved this call
  // via the notification specifically, so the separate native full-screen
  // layer needs to be told explicitly to stop, or it just sits there
  // ringing/showing even though the call was already handled here.
  try {
    CallKitService().endCall(sessionUuid);
  } catch (_) {}

  // Same reasoning as CallKit above, but for the native ringtone —
  // RingtonePlayer routes through a real plugin (packages/ringtone_native),
  // reachable from this isolate same as everything else here.
  try {
    RingtonePlayer().stop();
  } catch (_) {}

  // GUARANTEED path — always runs, regardless of whether the bloc/GetIt
  // happens to be reachable from whatever isolate this callback executes
  // in. Confirmed by testing that notification-action-tap callbacks
  // don't reliably run in the same isolate as the main app, even when
  // the app is technically "open" — so this can never be skipped in
  // favor of only the bloc path, or the server-side call succeeds while
  // our local bloc state silently never finds out, leaving it stuck
  // "busy" forever (exactly what caused every later incoming call to be
  // ignored in this same session).
  SharedPreferences.getInstance().then((prefs) {
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) return;
    http.post(
      Uri.parse('$apiBaseUrl/api/v1/video-call/$sessionUuid/$action'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );
  });

  // Prefer dispatching through the actual VideoCallBloc when it's
  // available — best-effort, since this callback's isolate context has
  // proven unreliable for reaching GetIt (confirmed via testing: CallKit's
  // own native event stream reaches the bloc fine from the same "app is
  // open" state; this notification-action-tap callback specifically does
  // not, reliably).
  try {
    final bloc = sl<VideoCallBloc>();
    if (response.actionId == 'ACCEPT_CALL') {
      // NOT CallAcceptRequested — the guaranteed HTTP call above already
      // accepted this session server-side. Dispatching CallAcceptRequested
      // here made the bloc call repo.accept() a SECOND time for an
      // already-accepted session, which the backend correctly rejects —
      // silently leaving the receiver stuck (never joining Agora) while
      // the caller, who only ever saw the first successful accept, moves
      // on waiting for someone who never shows up. This is the same
      // "already accepted, just fetch status and join" event the
      // SharedPreferences fallback below eventually triggers via the
      // app-resume handler — dispatching it directly here does the same
      // thing immediately, without waiting for a resume cycle.
      bloc.add(CallResumeAfterNotificationAccept(sessionUuid));
    } else {
      bloc.add(CallRejectRequested(sessionUuid));
    }
  } catch (_) {
    // GUARANTEED fallback for the accept case specifically: persist a
    // marker that the app's resume handler (already proven reliable —
    // same mechanism used for CallKit's own "missed accepted call"
    // check) will pick up and act on the next time the app is actually
    // in the main isolate. Reject doesn't need this — the guaranteed
    // HTTP call above already fully resolves it server-side, and there's
    // no local screen state to sync afterward (the receiver isn't
    // entering anything).
    if (response.actionId == 'ACCEPT_CALL') {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('pending_join_session_uuid', sessionUuid);
      });
    }
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // In NotificationService class, update the initialize method:
  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) async {
        print('🎯 NOTIFICATION CLICKED!');

        if (details.actionId == 'ACCEPT_CALL' || details.actionId == 'DECLINE_CALL') {
          _handleActionTap(details);
          return;
        }

        // Plain tap on the notification BODY (not an action button). For
        // the incoming-call notification specifically, this now doubles
        // as the fullScreenIntent target (see showIncomingCallNotification)
        // — the primary way locked/backgrounded calls actually reach the
        // user on devices where CallKit's Telecom registration is
        // rejected. Open IncomingCallScreen so there's something to land
        // on either way; Accept/Decline still work from there same as
        // always.
        final payload = _parseNotificationPayload(details.payload);
        if (payload != null &&
            payload.containsKey('session_uuid') &&
            !payload.containsKey('type')) {
          final sessionUuid = payload['session_uuid']?.toString();
          if (sessionUuid != null && sessionUuid.isNotEmpty) {
            print('📞 Incoming-call notification opened: $sessionUuid');
            NotificationHandlerService().handleNotificationClick({
              'type': 'video_call_incoming',
              'session_uuid': sessionUuid,
            });
          }
          return;
        }

        if (payload != null) {
          print('✅ Parsed payload: $payload');
          _handleNotificationNavigation(payload);
        } else {
          print('❌ Could not parse payload: ${details.payload}');
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Create notification channel for Android 8.0+
    await _createNotificationChannel();
    await _createIncomingCallChannel();

    // Cold-start counterpart to the live tap handler above — the app was
    // fully killed and this notification (tapped, or auto-launched via
    // fullScreenIntent while locked) is what's starting it. Nothing else
    // picks this up: it's a plain local notification, not an FCM one, so
    // FCM's own getInitialMessage() never sees it.
    try {
      final launchDetails = await _notificationsPlugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true) {
        final payload = _parseNotificationPayload(launchDetails!.notificationResponse?.payload);
        final sessionUuid = payload?['session_uuid']?.toString();
        if (sessionUuid != null && sessionUuid.isNotEmpty) {
          print('📞 Cold-started via incoming-call notification: $sessionUuid');
          NotificationHandlerService().handleNotificationClick({
            'type': 'video_call_incoming',
            'session_uuid': sessionUuid,
          });
        }
      }
    } catch (e) {
      print('⚠️ getNotificationAppLaunchDetails failed: $e');
    }

    print('✅ NotificationService initialized');
  }

  // ✅ Handle properly when user clicks on the push notification
  void _handleNotificationNavigation(Map<String, dynamic> payload) {
    print('🎯 Notification tapped in foreground: $payload');
    NotificationHandlerService().handleNotificationClick(payload);
  }

  // Add this helper function to NotificationService
  Map<String, dynamic>? _parseNotificationPayload(String? payloadString) {
    if (payloadString == null || payloadString.isEmpty) {
      return null;
    }

    try {
      // Try to parse as JSON first
      return jsonDecode(payloadString) as Map<String, dynamic>;
    } catch (e) {
      print('⚠️ JSON parse failed, trying alternative parsing...');

      // If it's already a Map string representation like "{key: value}"
      if (payloadString.startsWith('{') && payloadString.endsWith('}')) {
        try {
          // Convert Dart Map string to JSON format
          // This is a simple conversion - may need adjustment for complex cases
          var jsonStr = payloadString
              .replaceAllMapped(
                RegExp(r'([a-zA-Z0-9_]+):'),
                (match) => '"${match.group(1)}":',
              )
              .replaceAllMapped(
                RegExp(r': ([a-zA-Z0-9_@./#&+-]+)(?=[,}])'),
                (match) => ': "${match.group(1)}"',
              );

          return jsonDecode(jsonStr) as Map<String, dynamic>;
        } catch (e2) {
          print('❌ Alternative parsing failed: $e2');
        }
      }
    }

  return null;
  }

  Future<void> _createNotificationChannel() async {
    AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id - MUST match manifest
      'High Importance Notifications', // title
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 1000, 500]),
      // playSound: true,
      // sound: const RawResourceAndroidNotificationSound('notification'),
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    print('✅ Notification channel created');
  }

  // Dedicated channel for the fallback incoming-call notification —
  // deliberately separate from 'high_importance_channel', so if that
  // channel ever ends up stuck with wrong sound/importance settings (as
  // happened with CallKit's own channel — channel settings are
  // permanently sticky once created), this one still works independently.
  Future<void> _createIncomingCallChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'incoming_call_fallback_v1',
      'Incoming Calls (Notification)',
      description:
          'Fallback actionable notification for incoming video calls, shown alongside the full-screen ringing UI.',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  /// Shows an actionable Accept/Decline notification for an incoming
  /// video call, as a fallback running ALONGSIDE CallKit's full-screen
  /// UI — not a replacement. If CallKit's native UI fails to render for
  /// any device-specific reason (which we've seen happen intermittently
  /// across different manufacturer restrictions), this guarantees the
  /// user still gets something actionable rather than a silent missed
  /// call.
  Future<void> showIncomingCallNotification({
    required String sessionUuid,
    required String callerName,
    required String apiBaseUrl,
  }) async {
    final payload = jsonEncode({
      'session_uuid': sessionUuid,
      'api_base_url': apiBaseUrl,
    });

    final androidDetails = AndroidNotificationDetails(
      'incoming_call_fallback_v1',
      'Incoming Calls (Notification)',
      channelDescription:
          'Fallback actionable notification for incoming video calls.',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      // true: this is now the PRIMARY mechanism for locked/backgrounded
      // calls, not just a plain-notification fallback alongside CallKit.
      // Android only auto-launches a full-screen-intent notification's
      // target when the device is locked/screen-off — entirely
      // independent of CallKit's Telecom/ConnectionService integration,
      // which some devices/OEMs reject outright
      // (onCreateIncomingConnectionFailed) with no app-code workaround.
      // CallKit still runs alongside where Telecom cooperates; this
      // covers the rest.
      fullScreenIntent: true,
      playSound: true,
      enableVibration: true,
      ongoing: true,
      autoCancel: false,
      actions: const [
        AndroidNotificationAction(
          'ACCEPT_CALL',
          'Accept',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'DECLINE_CALL',
          'Decline',
          // Changed from false to true — Accept (which already uses
          // true) is confirmed working reliably; Decline (which was
          // false) doesn't respond at all. showsUserInterface:false
          // routes the action through a different, apparently less
          // reliable background-only callback path. Declining doesn't
          // functionally need the app in foreground, but our code
          // already treats it as a pure no-op for navigation (nothing
          // gets pushed), so this trades a negligible UX difference for
          // actual functional reliability.
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );

    await _notificationsPlugin.show(
      // Use a stable, deterministic ID derived from the session so a
      // later dismiss()/cancel() call (once the call is answered
      // elsewhere or times out) can target this exact notification.
      sessionUuid.hashCode,
      '$callerName is calling',
      'Incoming video call',
      NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }

  /// Dismisses the fallback notification — call this once the call is
  /// resolved through any path (CallKit accept/decline, timeout, etc.)
  /// so it doesn't linger after the call is no longer relevant.
  Future<void> dismissIncomingCallNotification(String sessionUuid) async {
    await _notificationsPlugin.cancel(sessionUuid.hashCode);
  }

  Future<void> showNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
    String? channelId = 'high_importance_channel',
  }) async {
    print('🎯 Attempting to show notification: $title');
    print('🎯 Payload type: ${payload?.runtimeType}');
    print('🎯 Payraw: $payload');

    AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription:
              'This channel is used for important notifications.',
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'ticker',
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 1000, 500]),
        );

    const DarwinNotificationDetails iosNotificationDetails =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosNotificationDetails,
    );

    // FIX: Convert payload to JSON string
    String? payloadJson;
    if (payload != null) {
      try {
        payloadJson = jsonEncode(payload);
        print('🎯 Payload JSON encoded: $payloadJson');
      } catch (e) {
        print('❌ Error encoding payload to JSON: $e');
        payloadJson = null;
      }
    }

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: payloadJson, // Use JSON string
    );

    print('📱 Local notification shown: $title - $body');
  }
}