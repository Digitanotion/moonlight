// lib/core/services/call_kit_service.dart
//
// Wraps flutter_callkit_incoming (v3.1.5). This gives us a genuine
// WhatsApp-style incoming call experience: full-screen ringing UI with
// ringtone/vibration, visible even when the app is backgrounded or fully
// killed, with native Accept/Decline actions right on the lock screen.
//
// CallKit's UI now IS the ringing screen for both foreground and
// background/killed calls — IncomingCallScreen (the custom Flutter widget
// built earlier) is no longer shown for the ringing phase. Once the user
// taps Accept here, we go straight into ActiveCallScreen.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/services/notification_service.dart';
import 'package:moonlight/core/services/ringtone_player.dart';
import 'package:moonlight/features/video_call/presentation/bloc/video_call_bloc.dart';

class CallKitService {
  static final CallKitService _instance = CallKitService._internal();
  factory CallKitService() => _instance;
  CallKitService._internal();

  StreamSubscription<CallEvent?>? _eventSub;
  bool _listening = false;

  /// Checks whether CallKit already has an active/accepted call that our
  /// own Dart-side flow might have missed — e.g. if the user tapped
  /// Accept directly on the native lock-screen UI while the app was
  /// fully killed, and our CallKitService.startListening() event
  /// listener (which only exists once Dart/GetIt has actually finished
  /// booting) didn't get a chance to react in time. Mirrors the official
  /// package example's checkAndNavigationCallingPage() pattern — call
  /// this at app startup AND every time the app resumes from background,
  /// not just once.
  ///
  /// Returns the session_uuid of an already-accepted call if one exists,
  /// or null if there's nothing to resume into.
  Future<String?> checkForActiveAcceptedCall() async {
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      if (calls is! List || calls.isEmpty) return null;

      // activeCalls() returns actual CallKitParams objects directly (my
      // earlier assumption that it returned raw Maps needing .cast() was
      // wrong — confirmed by the compiler, not guessed twice).
      final first = calls.first;
      if (first is! CallKitParams) return null;

      if (first.isAccepted && first.id.isNotEmpty) {
        debugPrint('📞 [CallKit] Found already-accepted call on resume: ${first.id}');
        return first.id;
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ CallKit activeCalls() check failed: $e');
      return null;
    }
  }

  /// Same idea as checkForActiveAcceptedCall, but for a call that's still
  /// ringing (not yet accepted). A call that arrives while the app is
  /// genuinely backgrounded/killed only ever reaches CallKit directly —
  /// the FCM background isolate that shows it can't safely touch
  /// VideoCallBloc at all (separate isolate, no reliable GetIt access —
  /// see _firebaseMessagingBackgroundHandler's doc comment in main.dart).
  /// So the bloc can be completely unaware a call is ringing even while
  /// CallKit's native UI is showing it. Without this, backgrounding
  /// CallKit's screen and reopening the app left no in-app way back to
  /// Accept/Decline — only CallKit's own screen or the fallback
  /// notification. Called on resume/cold-start to reconcile the two.
  Future<String?> checkForActiveRingingCall() async {
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      if (calls is! List || calls.isEmpty) return null;

      final first = calls.first;
      if (first is! CallKitParams) return null;

      if (!first.isAccepted && first.id.isNotEmpty) {
        debugPrint('📞 [CallKit] Found still-ringing call on resume: ${first.id}');
        return first.id;
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ CallKit activeCalls() ringing check failed: $e');
      return null;
    }
  }

  /// Requests the permissions CallKit needs on Android 13+ (notifications)
  /// and Android 14+ (full-screen intent) — required per the package's
  /// own setup docs, separate from the notification permission Firebase
  /// Messaging already requests elsewhere. Call once, early at startup,
  /// before the first showIncomingCall().
  Future<void> requestRequiredPermissions() async {
    try {
      await FlutterCallkitIncoming.requestNotificationPermission({
        "title": "Notification permission",
        "rationaleMessagePermission":
            "Notification permission is required to show incoming call alerts.",
        "postNotificationMessageRequired":
            "Notification permission is required — please allow it from settings.",
      });

      final canUseFullScreen =
          await FlutterCallkitIncoming.canUseFullScreenIntent();
      if (canUseFullScreen != true) {
        await FlutterCallkitIncoming.requestFullIntentPermission();
      }
    } catch (e) {
      debugPrint('⚠️ CallKit permission request failed: $e');
    }
  }

  /// Shows the native incoming-call UI. Safe to call from both a
  /// foreground Pusher event and the FCM background message handler —
  /// same code path either way, so there's only one ringing experience
  /// to maintain.
  Future<void> showIncomingCall({
    required String sessionUuid,
    required String callerName,
    String? callerAvatarUrl,
  }) async {
    final params = CallKitParams(
      id: sessionUuid,
      nameCaller: callerName,
      appName: 'Moonlight',
      avatar: callerAvatarUrl,
      handle: callerName,
      type: 1, // video
      duration: 45000, // doc 1M — ring timeout ~45s, matches backend's VIDEO_CALL_RING_TIMEOUT_SECONDS
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: false,
        subtitle: 'Missed video call',
      ),
      extra: <String, dynamic>{'session_uuid': sessionUuid},
      android: const AndroidParams(
        isCustomNotification: true,
        // FIX: Changed from true to false. Suppressing this stops CallKit from 
        // painting its own overlay when backgrounded or completely killed, 
        // which leaves nothing to draw if the main Dart/Flutter thread is paused.
        isCustomSmallExNotification: false, 
        isShowLogo: false,
        isShowCallID: false,
        // Plain filename, no URI prefix — this is the only format
        // actually confirmed in the package's real README examples and
        // source code. The 'resource://raw/' prefix isn't a documented
        // pattern for this package; reverting to stay on verified ground
        // rather than an unconfirmed format that might silently fail.
        ringtonePath: 'ringtone_default',
        backgroundColor: '#0F1020', // AppColors.dark
        actionColor: '#4CD964', // AppColors.accentGreen
        textColor: '#FFFFFF',
        // FIX: Incremented versioning keys to v3 to break past cached, sticky system channel configurations.
        incomingCallNotificationChannelName: 'Incoming Video Calls v3',
        missedCallNotificationChannelName: 'Missed Video Calls v3',
        isFullScreen: true,
        textAccept: 'Accept',
        textDecline: 'Decline',
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  /// Programmatically ends the native call UI — used when the caller
  /// cancels before the callee answers, or the call times out server-side.
  ///
  /// FlutterCallkitIncoming.endCall() is NOT what actually dismisses the
  /// Android UI — the package's own doc comment on that method says so
  /// outright: "On Android, Nothing (only callback event listener)". It
  /// was being relied on as if it did, which is exactly why the incoming
  /// screen kept sitting there after the other party ended the call.
  /// hideCallkitIncoming() is the one explicitly documented as doing this
  /// ("Hide notification call for Android. Only Android"). Also fire
  /// endCall() (harmless, and correct on iOS) and endAllCalls() as a
  /// last-resort safety net given this device's separately-confirmed
  /// unreliable Telecom/ConnectionService integration.
  Future<void> endCall(String sessionUuid) async {
    try {
      await FlutterCallkitIncoming.hideCallkitIncoming(
        CallKitParams(id: sessionUuid),
      );
    } catch (e) {
      debugPrint('⚠️ CallKit hideCallkitIncoming failed: $e');
    }
    try {
      await FlutterCallkitIncoming.endCall(sessionUuid);
    } catch (e) {
      debugPrint('⚠️ CallKit endCall failed: $e');
    }
    try {
      await FlutterCallkitIncoming.endAllCalls();
    } catch (e) {
      debugPrint('⚠️ CallKit endAllCalls failed: $e');
    }
  }

  /// Starts listening for Accept/Decline/Timeout events from the native
  /// UI. Call once, near app startup — safe to call multiple times, only
  /// attaches the listener once.
  void startListening() {
    if (_listening) return;
    _listening = true;

    _eventSub = FlutterCallkitIncoming.onEvent.listen((event) {
      if (event == null) return;
      final bloc = sl<VideoCallBloc>();

      switch (event) {
        case CallEventActionCallAccept(:final callKitParams):
          if (callKitParams != null) {
            debugPrint('📞 [CallKit] Accepted: ${callKitParams.id}');
            bloc.add(CallAcceptRequested(callKitParams.id));
            // Dismiss the fallback notification too — the user answered
            // via CallKit's native UI specifically, so the separate
            // notification layer needs to be told explicitly, or it
            // just lingers (and keeps making sound) even though the
            // call was already answered elsewhere.
            NotificationService().dismissIncomingCallNotification(callKitParams.id);
            RingtonePlayer().stop();
          }

        case CallEventActionCallDecline(:final callKitParams):
          if (callKitParams != null) {
            debugPrint('📞 [CallKit] Declined: ${callKitParams.id}');
            bloc.add(CallRejectRequested(callKitParams.id));
            NotificationService().dismissIncomingCallNotification(callKitParams.id);
            RingtonePlayer().stop();
          }

        case CallEventActionCallTimeout(:final id):
          debugPrint('📞 [CallKit] Timed out: $id');
          NotificationService().dismissIncomingCallNotification(id);
          RingtonePlayer().stop();
          // No explicit bloc event required if backend handles timeout tracking

        default:
          break;
      }
    });
  }

  /// Disposes of the active stream subscription explicitly to clear memory 
  /// allocations if the service lifecycle ever shifts.
  void dispose() {
    _eventSub?.cancel();
    _listening = false;
  }
}