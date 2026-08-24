// lib/main.dart

import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/config/runtime_config.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/routing/app_router.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/services/ad_service.dart';
import 'package:moonlight/core/services/call_kit_service.dart'; // ← NEW
import 'package:moonlight/core/services/connection_monitor.dart';
import 'package:moonlight/core/services/current_user_service.dart';
import 'package:moonlight/core/services/notification_handler_service.dart';
import 'package:moonlight/core/services/notification_service.dart';
import 'package:moonlight/core/services/ringtone_player.dart';
import 'package:moonlight/core/services/runtime_config_refresh_service.dart';
import 'package:moonlight/core/services/service_registration_manager.dart';
import 'package:moonlight/core/services/tenjin_service.dart';
import 'package:moonlight/core/services/token_registration_service.dart';
import 'package:moonlight/core/theme/app_theme.dart';
import 'package:moonlight/core/widgets/connection_toast.dart';
import 'package:moonlight/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moonlight/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:moonlight/features/video_call/domain/repositories/video_call_repository.dart';
import 'package:moonlight/features/video_call/presentation/bloc/video_call_bloc.dart';
import 'package:moonlight/features/video_call/presentation/pages/active_call_screen.dart'; // ← NEW
import 'package:moonlight/features/video_call/presentation/widgets/incoming_call_banner.dart'; // ← NEW
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📱 Background message: ${message.messageId}');

  // This isolate is the ACTUAL entry point for a killed-app incoming
  // call — nothing else in the app is running yet. Trigger CallKit's
  // native ringing UI directly from here, rather than relying on the
  // app fully launching first.
  final data = message.data;
  if (data['type'] == 'video_call_incoming') {
    // An earlier attempt used audioplayers here — that package shares
    // Flutter's own audio engine (video_player included), which reliably
    // broke the feed's video/audio playback even after calling stop().
    // RingtonePlayer now goes through packages/ringtone_native instead:
    // a real FlutterPlugin (not a MainActivity-only channel), so it's
    // reachable from this exact background isolate, and plays on
    // Android's own ringtone audio stream — confirmed by testing not to
    // touch the feed's playback at all.
    try {
      await RingtonePlayer().play();
    } catch (e) {
      debugPrint('⚠️ Ringtone background start failed: $e');
    }

    try {
      await CallKitService().showIncomingCall(
        sessionUuid: data['session_uuid'] ?? '',
        callerName: data['caller_name'] ?? 'Someone',
        callerAvatarUrl: (data['caller_avatar'] as String?)?.isNotEmpty == true
            ? data['caller_avatar']
            : null,
      );
    } catch (e) {
      debugPrint('⚠️ CallKit background show failed: $e');
    }

    // Fallback, alongside CallKit — see NotificationService's own doc
    // comment for why this exists. On devices where CallKit's Telecom
    // registration is rejected (onCreateIncomingConnectionFailed — an
    // OEM/device-level restriction, not something app code controls),
    // this full-screen-intent notification is the one actually reaching
    // the user: it wakes the lock screen independently of Telecom, and
    // opens straight into IncomingCallScreen.
    try {
      await NotificationService().showIncomingCallNotification(
        sessionUuid: data['session_uuid'] ?? '',
        callerName: data['caller_name'] ?? 'Someone',
        apiBaseUrl: data['api_base_url'] ?? 'https://svc.moonlightstream.app',
      );
    } catch (e) {
      debugPrint('⚠️ Fallback notification (background) failed: $e');
    }
  } else if (data['type'] == 'video_call_ended' ||
      data['type'] == 'video_call_rejected') {
    // Matching cleanup for the call this same background isolate started
    // ringing above — this was missing entirely. Without it, a call
    // ended/rejected while the app is genuinely backgrounded (not just
    // minimized-but-alive) never reaches anything that stops the
    // ringtone: _onResolvedByOtherParty in VideoCallBloc only fires once
    // the MAIN app engine gets the event via Pusher/foreground-FCM,
    // which isn't guaranteed while truly backgrounded — this background
    // isolate is the one place guaranteed to see it.
    final sessionUuid = (data['session_uuid'] ?? '').toString();
    try {
      await RingtonePlayer().stop();
    } catch (e) {
      debugPrint('⚠️ Ringtone background stop failed: $e');
    }
    if (sessionUuid.isNotEmpty) {
      try {
        await CallKitService().endCall(sessionUuid);
      } catch (e) {
        debugPrint('⚠️ CallKit background dismiss failed: $e');
      }
      try {
        await NotificationService().dismissIncomingCallNotification(sessionUuid);
      } catch (e) {
        debugPrint('⚠️ Notification background dismiss failed: $e');
      }
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('🚀 App starting...');

  // Step 1: Render the bare splash on frame 1 — nothing else runs yet.
  runApp(const _BareSplash());

  // Step 2: addPostFrameCallback fires only AFTER the splash has been
  // rasterised and sent to the screen. Any work here starts after the user
  // already sees the splash, so there is zero perceived delay.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    // Register auth/onboarding blocs — fast, disk-only (~5–15 ms).
    await SplashOptimizer.registerRenderEssentials();

    // Step 3: Swap in the full app. The real splash route inside MyApp
    // immediately takes over; it waits for DependencyManager.markReady()
    // before navigating onward, so nothing visible changes for the user.
    runApp(const MyApp());

    // Step 4: Run the rest of initialisation in the background.
    // The real splash screen waits for this to complete before it navigates.
    unawaited(_initEverything());
  });
}

// =============================================================================
// Bare splash — shown on frame 1, before GetIt or blocs are available.
// Intentionally has zero dependencies so it renders in < 1 ms.
// =============================================================================
class _BareSplash extends StatelessWidget {
  const _BareSplash();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF6C35DE), // AppColors.primary fallback
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo.png',
                width: 150,
                height: 150,
                filterQuality: FilterQuality.high,
              ),
              const SizedBox(height: 32),
              const Text(
                'Moonlight',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Full app — mounted once Track 1 (blocs) are registered in GetIt.
// =============================================================================
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Safety net mirroring the official flutter_callkit_incoming example's
  // checkAndNavigationCallingPage() pattern: every time the app resumes
  // from background, ask CallKit itself whether there's already an
  // accepted call our own Dart-side flow might have missed (e.g. Accept
  // tapped on the native lock-screen UI while the app was fully killed,
  // before our event listener had a chance to attach).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkForMissedAcceptedCall();
    }
  }

  Future<void> _checkForMissedAcceptedCall() => _reconcileVideoCallState();

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<OnboardingBloc>(create: (_) => sl<OnboardingBloc>()),
        BlocProvider<AuthBloc>(
          create: (_) => sl<AuthBloc>()
            ..stream.listen((state) {
              if (state is AuthUnauthenticated) {
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  try {
                    await ServiceRegistrationManager().unregisterServices();
                  } catch (e) {
                    debugPrint('Error unregistering services: $e');
                  }
                });
              } else if (state is AuthAuthenticated) {
                // VideoCallRepository is constructed at app launch (see
                // _initEverything()'s eager sl<VideoCallBloc>() call
                // below), before login — its initial uuid may be
                // empty/stale. Re-point it at the real logged-in user's
                // uuid now, or an incoming call would silently never
                // arrive (subscribed to the wrong Pusher channel).
                try {
                  final uuid = sl<CurrentUserService>().getCurrentUserId();
                  if (uuid != null && uuid.isNotEmpty) {
                    sl<VideoCallRepository>().resubscribeForUser(uuid);
                  }
                } catch (e) {
                  debugPrint('⚠️ VideoCall resubscribe failed: $e');
                }
              }
            }),
        ),
      ],
      child: MaterialApp(
        title: 'Moonlight',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        onGenerateRoute: AppRouter.generateRoute,
        initialRoute: RouteNames.splash,
        navigatorKey: MyApp.navigatorKey,
        builder: (context, child) => IncomingCallBanner(
          child: SimpleConnectionToast(child: child!),
        ),
      ),
    );
  }
}

// =============================================================================
// BACKGROUND INITIALIZATION
// Runs after runApp(MyApp()). The real splash route waits for
// DependencyManager.waitForAllDependencies() before navigating away.
// =============================================================================
Future<void> _initEverything() async {
  try {
    debugPrint('🔄 Background init starting...');

    // Firebase, remaining GetIt registrations, ad SDK init, and Tenjin
    // attribution SDK init all run in parallel — none of these block the
    // splash, which is already on screen by this point.
    await Future.wait([
      _initFirebase(),
      SplashOptimizer.loadRemainingDependencies(),
      _initAds(),
      _initTenjin(),
    ]);

    // Update FCM token registration base URL.
    try {
      await sl<TokenRegistrationService>().setDependencies(
        apiBaseUrl: sl<RuntimeConfig>().apiBaseUrl,
      );
    } catch (_) {}

    // Force VideoCallBloc's lazy singleton to construct RIGHT NOW, the
    // moment all dependencies are ready — not whenever some route's
    // Provider happens to first call sl<VideoCallBloc>(). This guarantees
    // its Pusher listeners (incoming-call / call-accepted) are wired up
    // from near app-launch, regardless of which screen the user is on
    // when a call actually comes in.
    try {
      sl<VideoCallBloc>();
      debugPrint('✅ VideoCallBloc eagerly initialized');
    } catch (e) {
      debugPrint('⚠️ VideoCallBloc eager init failed: $e');
    }

    // Start listening for CallKit's native Accept/Decline/Timeout events.
    // Must happen before any incoming call can arrive.
    CallKitService().startListening();
    debugPrint('✅ CallKitService listening');

    // Required Android 13+/14+ permissions (notification + full-screen
    // intent) — separate from Firebase Messaging's own notification
    // permission request. Must happen before the first showIncomingCall().
    unawaited(CallKitService().requestRequiredPermissions());

    // Global call-state listeners — see _startGlobalVideoCallListeners()
    // below for why these are needed (foreground ringing trigger +
    // post-accept navigation for the cold-start case).
    _startGlobalVideoCallListeners();

    // Cold-start counterpart to MyApp's didChangeAppLifecycleState resume
    // check — covers the case where the app was fully killed, the user
    // accepted directly on CallKit's native lock-screen UI (or the
    // fallback notification), and THIS is the very first app launch
    // since (so there's no "resume" event to catch it, only this
    // initial cold boot).
    unawaited(_reconcileVideoCallState());

    // Also run it continuously, not just on resume/cold-start. Confirmed
    // gap: a call delivered purely through the FCM background handler
    // (app was already backgrounded when it arrived) never touches
    // VideoCallBloc at all — its phase stays idle the entire time, so
    // VideoCallBloc's own resolution-poll fallback (which only starts
    // once phase reaches ringingIncoming/ringingOutgoing) never engages
    // either. If the user never manually resumes the app — just sits on
    // CallKit's screen — nothing was ever reconciling that call against
    // reality. This closes that: the moment reconciliation notices a
    // CallKit-known call the bloc doesn't, it dispatches
    // CallResumeFromNotification, which itself starts that same
    // resolution poll — so from here on, either mechanism catches the
    // call ending even if the user never touches anything.
    Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_reconcileVideoCallState());
    });

    // Connection monitoring.
    unawaited(
      ConnectionMonitor().startMonitoring().catchError(
        (e) => debugPrint('⚠️ ConnectionMonitor: $e'),
      ),
    );

    debugPrint('🎉 Background init complete');
  } catch (e) {
    debugPrint('⚠️ Background init error: $e');
    // Release the gate so the splash never hangs indefinitely.
    DependencyManager.markReady();
  }
}

// Tracks the session_uuid we've already reacted to, per phase, so a
// duplicate state emission (e.g. a bloc rebuild) doesn't trigger CallKit
// or navigation twice for the same call.
String? _lastRingingSessionUuid;
String? _lastActiveNavigatedSessionUuid;

// Debounce for _reconcileVideoCallState's continuous polling — confirmed
// by testing to otherwise race its own cleanup: CallKit's native
// activeCalls() state doesn't always update instantly after we call
// endCall()/hideCallkitIncoming() (this device's Telecom integration is
// already confirmed flaky), so the NEXT reconciliation tick can
// re-discover a call we just locally declined as "still ringing" from
// CallKit's stale point of view, and restart the entire ringing flow —
// ringtone included — moments after it was correctly stopped. Recording
// what we just resolved locally, and skipping reconciliation from
// reviving that exact session for a short grace window, closes it.
String? _lastLocallyResolvedSessionUuid;
DateTime? _lastLocallyResolvedAt;

/// Shared by both the cold-start path (_initEverything, below) and every
/// app-resume (_MyAppState.didChangeAppLifecycleState) — used to matter
/// only on resume, but a stuck bloc doesn't wait for a resume event to
/// happen: it silently drops every incoming call from the moment it gets
/// wedged, cold-start included, so this now runs at both.
///
/// 1. If CallKit has an already-accepted call our own flow might have
///    missed (native lock-screen Accept while Dart wasn't listening
///    yet), join it.
/// 2. Else, if the fallback notification's Accept succeeded server-side
///    but couldn't reach the bloc directly (that isolate's GetIt access
///    isn't reliable), pick up the pending join it persisted.
/// 3. Else, safety net: if the bloc is stuck in `active`/`connecting`
///    with no real CallKit call behind it — e.g. _onJoin/_onAccept threw
///    and (before this was fixed) never reset the phase back to idle —
///    reset it. Deliberately NOT `ringingIncoming`/`ringingOutgoing`:
///    those can be genuinely legitimate at the exact moment this runs.
Future<void> _reconcileVideoCallState() async {
  final sessionUuid = await CallKitService().checkForActiveAcceptedCall();

  if (sessionUuid != null) {
    if (sessionUuid == _lastActiveNavigatedSessionUuid) return; // already handled
    // Same debounce as the ringing-call branch below — CallKit's native
    // state can lag behind a call we JUST ended/resolved locally.
    final recentlyResolved = sessionUuid == _lastLocallyResolvedSessionUuid &&
        _lastLocallyResolvedAt != null &&
        DateTime.now().difference(_lastLocallyResolvedAt!) < const Duration(seconds: 15);
    if (recentlyResolved) {
      debugPrint('📞 [main] Skipping reconcile (accepted) — $sessionUuid was just resolved locally');
      return;
    }
    try {
      sl<VideoCallBloc>().add(CallJoinRequested(sessionUuid));
    } catch (e) {
      debugPrint('⚠️ Failed to join missed accepted call: $e');
    }
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  final pendingUuid = prefs.getString('pending_join_session_uuid');
  if (pendingUuid != null && pendingUuid.isNotEmpty) {
    await prefs.remove('pending_join_session_uuid');
    if (pendingUuid != _lastActiveNavigatedSessionUuid) {
      try {
        debugPrint('📞 [main] Joining pending call from notification accept: $pendingUuid');
        sl<VideoCallBloc>().add(CallResumeAfterNotificationAccept(pendingUuid));
      } catch (e) {
        debugPrint('⚠️ Failed to join pending call: $e');
      }
    }
    return;
  }

  try {
    final bloc = sl<VideoCallBloc>();
    // REMOVED: this used to force-reset phase to idle whenever it was
    // active/connecting with nothing in CallKit's activeCalls(). That
    // premise only holds for the CALLEE — CallKit is never invoked at
    // all for a call THIS device initiated, so on the caller's side
    // "CallKit shows nothing" is the permanent, expected state for every
    // genuinely active outgoing call, not a sign of anything stuck.
    // Confirmed by testing: this fired within 5s of every successful
    // outgoing call connecting and force-dismissed it — call connects,
    // shows video, disappears a second later. The actual bug this was
    // meant to catch (phase never resetting after a failed
    // accept/join/end) is now fixed at its real source — the missing
    // phase resets in _onJoin/_onAccept/_onEnd's own error handlers —
    // so this blunt, wrongly-targeted safety net is no longer needed.

    // A call that started ringing while the app was fully backgrounded —
    // CallKit is showing it, but the bloc has no idea (see
    // checkForActiveRingingCall's doc comment). Fetch the real session
    // and populate ringingIncoming so IncomingCallBanner has something
    // to show once the user is back in the app, instead of leaving only
    // CallKit's own screen or the fallback notification as a way in.
    if (bloc.state.phase == VideoCallPhase.idle) {
      final ringingUuid = await CallKitService().checkForActiveRingingCall();
      if (ringingUuid != null) {
        // Debounce — see _lastLocallyResolvedSessionUuid's doc comment.
        // CallKit's native state can lag behind a resolve we JUST did
        // locally; without this, this exact tick can restart the whole
        // ringing flow (ringtone included) for a call already handled.
        final recentlyResolved = ringingUuid == _lastLocallyResolvedSessionUuid &&
            _lastLocallyResolvedAt != null &&
            DateTime.now().difference(_lastLocallyResolvedAt!) < const Duration(seconds: 15);
        if (recentlyResolved) {
          debugPrint('📞 [main] Skipping reconcile — $ringingUuid was just resolved locally');
        } else {
          debugPrint('📞 [main] Reconciling still-ringing call CallKit knows about: $ringingUuid');
          bloc.add(CallResumeFromNotification(ringingUuid));
        }
      }
    }
  } catch (e) {
    debugPrint('⚠️ Stale-state reset check failed: $e');
  }
}

/// Two things this covers, both because VideoCallBloc is a global
/// singleton with no guaranteed screen listening to it at all times:
///
/// 1. BACKGROUNDED/LOCKED ringing — CallKit's native full-screen UI,
///    triggered here for the case where the Pusher-delivered event (or
///    an FCM message injected via injectExternalEvent) reaches the bloc
///    while the app isn't actually being looked at. The FOREGROUND case
///    is deliberately NOT handled here: Android only auto-launches a
///    full-screen-intent notification (what CallKit's isFullScreen
///    relies on) when the device is locked or the screen is off — with
///    the app already active/unlocked, Android silently downgrades it to
///    a plain heads-up notification, and this app's CallKit params
///    suppress even that fallback (isCustomSmallExNotification: false),
///    so nothing would show at all. Confirmed Android platform behavior,
///    not a plugin bug. IncomingCallBanner (wrapping MaterialApp — see
///    its own doc comment) listens to this exact same bloc stream
///    directly and renders itself for that case instead — nothing to
///    push here.
///
/// 2. POST-ACCEPT navigation for the cold-start case — if the app was
///    killed and the user tapped Accept directly on CallKit's native UI
///    (without ever opening a Flutter screen first), nothing would
///    otherwise navigate to ActiveCallScreen once the bloc's phase
///    becomes `active`. This listener catches that and pushes it.
void _startGlobalVideoCallListeners() {
  sl<VideoCallBloc>().stream.listen((state) {
    // ── 1. Backgrounded/locked ringing ───────────────────────────────────
    if (state.phase == VideoCallPhase.ringingIncoming) {
      final uuid = state.session?.uuid;
      if (uuid != null && uuid != _lastRingingSessionUuid) {
        _lastRingingSessionUuid = uuid;
        final caller = state.session?.caller;
        final isForeground =
            WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

        if (!isForeground) {
          CallKitService().showIncomingCall(
            sessionUuid: uuid,
            callerName: caller?.displayName ?? 'Someone',
            callerAvatarUrl: caller?.avatarUrl,
          );
          // Fallback, alongside CallKit — see NotificationService's own
          // doc comment for why this exists. Skipped while foreground:
          // IncomingCallBanner is already the single source of truth
          // there, and a second actionable notification stacked on top
          // of it risks a double-accept/-decline race.
          NotificationService().showIncomingCallNotification(
            sessionUuid: uuid,
            callerName: caller?.displayName ?? 'Someone',
            apiBaseUrl: sl<RuntimeConfig>().apiBaseUrl,
          );
        }
      }
    } else if (state.phase == VideoCallPhase.idle) {
      // Single authoritative rule, not another scattered call site: the
      // instant the bloc says idle, by ANY path whatsoever (successful
      // reject, a reject that failed 4xx/429 but still resets local
      // state, resolved-by-other-party, dismissed, a poll catching what
      // a broadcast missed...), ringtone/CallKit/notification must all
      // be off. Confirmed by testing that individual call sites scattered
      // across every handler are too easy to miss one of — this can't be
      // missed, since every single path to idle flows through this one
      // listener. Fully idempotent either way (safe no-op if already
      // stopped/dismissed), so unconditional here is never wasted.
      try {
        RingtonePlayer().stop();
      } catch (_) {}
      final uuidToDismiss = _lastRingingSessionUuid ?? state.session?.uuid;
      if (uuidToDismiss != null) {
        _lastLocallyResolvedSessionUuid = uuidToDismiss;
        _lastLocallyResolvedAt = DateTime.now();
        try {
          CallKitService().endCall(uuidToDismiss);
        } catch (_) {}
        NotificationService().dismissIncomingCallNotification(uuidToDismiss);
      }
      _lastRingingSessionUuid = null;
      _lastActiveNavigatedSessionUuid = null;
    }

    // ── 2. Post-accept navigation (cold-start-via-CallKit case) ─────────
    if (state.phase == VideoCallPhase.active) {
      final uuid = state.session?.uuid;
      if (uuid != null && uuid != _lastActiveNavigatedSessionUuid) {
        final navState = MyApp.navigatorKey.currentState;
        if (navState != null) {
          // If a screen is already showing this same active call (e.g.
          // OutgoingCallScreen/IncomingCallScreen's own BlocConsumer
          // already navigated), this becomes a harmless extra push.
          // Acceptable trade-off for guaranteeing the cold-start case
          // always works; a stricter de-dupe would need each screen to
          // also update _lastActiveNavigatedSessionUuid, which is more
          // coupling than this is worth right now.
          _lastActiveNavigatedSessionUuid = uuid;
          navState.push(
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: sl<VideoCallBloc>(),
                child: const ActiveCallScreen(),
              ),
              fullscreenDialog: true,
            ),
          );
        }
      }
    }
  });
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp();
    await _setupFirebaseMessaging();
    await NotificationService().initialize();
    debugPrint('✅ Firebase initialized');
  } catch (e) {
    debugPrint('⚠️ Firebase init error: $e');
  }
}

// Initializes the Google Mobile Ads SDK and pre-loads the first
// interstitial. Wrapped in try/catch so an ad-network hiccup (e.g. no
// network yet, SDK init failure on a weird device) never blocks app
// startup — ads are a revenue feature, not a critical path. If this
// fails, AdService's methods will simply no-op until it succeeds.
Future<void> _initAds() async {
  try {
    await AdService.instance.init();
    debugPrint('✅ Ads initialized');
  } catch (e) {
    debugPrint('⚠️ Ads init error (non-fatal): $e');
  }
}

// Initializes the Tenjin attribution SDK. Wrapped in try/catch for the
// same reason as _initAds() — attribution tracking must never block or
// crash app startup.
Future<void> _initTenjin() async {
  try {
    await TenjinService.initialize();
    debugPrint('✅ Tenjin initialized');
  } catch (e) {
    debugPrint('⚠️ Tenjin init error (non-fatal): $e');
  }
}

Future<void> _setupFirebaseMessaging() async {
  try {
    final messaging = FirebaseMessaging.instance;
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );

    FirebaseMessaging.onMessage.listen((msg) {
      // Video-call events are data-only messages (no msg.notification),
      // so they'd never reach the branch below regardless — they need
      // their own path. This used to be skipped entirely on the (wrong)
      // assumption that the live Pusher socket would independently
      // deliver the same event in the foreground; it doesn't reliably
      // (nothing else in the app ever calls subscribeToCallEvents()), so
      // FCM here was the only channel that was ever supposed to carry
      // this — same message type the background handler above already
      // trusts, just delivered to the foreground isolate instead. Route
      // it through the repository's stream controllers so
      // VideoCallBloc/every screen reacts exactly as it would for a
      // Pusher-delivered event.
      const videoCallTypes = {
        'video_call_incoming',
        'video_call_accepted',
        'video_call_ended',
        'video_call_rejected',
      };
      if (videoCallTypes.contains(msg.data['type'])) {
        try {
          sl<VideoCallRepository>().injectExternalEvent(msg.data);
        } catch (e) {
          debugPrint('⚠️ Failed to route foreground video-call FCM message: $e');
        }
        return;
      }

      if (msg.notification != null) {
        NotificationService().showNotification(
          title: msg.notification!.title!,
          body: msg.notification!.body!,
          payload: msg.data,
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen(
      (msg) => _handleNotificationTap(msg.data),
    );

    final initial = await messaging.getInitialMessage();
    if (initial != null) _handleNotificationTap(initial.data);

    final prefs = await SharedPreferences.getInstance();
    final token = await messaging.getToken();
    if (token != null) {
      await prefs.setString('fcm_token', token);
      _tryRegisterFcmToken(prefs);
    }
    messaging.onTokenRefresh.listen((t) async {
      await prefs.setString('fcm_token', t);
      _tryRegisterFcmToken(prefs);
    });
  } catch (e) {
    debugPrint('❌ Firebase Messaging: $e');
  }
}

void _tryRegisterFcmToken(SharedPreferences prefs) {
  final auth = prefs.getString('auth_token');
  if (auth == null || auth.isEmpty) return;
  TokenRegistrationService(
    authLocalDataSource: sl<AuthLocalDataSource>(),
    runtimeConfig: sl<RuntimeConfig>(),
  ).registerTokenManually().catchError(
    (e) => debugPrint('⚠️ FCM token registration: $e'),
  );
}

void _handleNotificationTap(Map<String, dynamic> data) {
  if (data.containsKey('type')) {
    NotificationHandlerService().handleNotificationClick(data);
  } else if (data['data'] is Map) {
    NotificationHandlerService().handleNotificationClick(
      data['data'] as Map<String, dynamic>,
    );
  }
}