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
import 'package:moonlight/features/video_call/presentation/pages/incoming_call_screen.dart'; // ← NEW
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
    // RingtonePlayer/audioplayers usage removed — confirmed via testing
    // that it leaves the app's shared audio session broken even after
    // calling stop(), breaking the existing posts-feed video player.
    // Reverting to relying on the fallback notification's own sound as
    // the stable, working solution — a worse ringtone experience is a
    // much better trade-off than breaking core existing functionality.
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
    // comment for why this exists.
    try {
      await NotificationService().showIncomingCallNotification(
        sessionUuid: data['session_uuid'] ?? '',
        callerName: data['caller_name'] ?? 'Someone',
        apiBaseUrl: data['api_base_url'] ?? 'https://svc.moonlightstream.app',
      );
    } catch (e) {
      debugPrint('⚠️ Fallback notification (background) failed: $e');
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

  Future<void> _checkForMissedAcceptedCall() async {
    final sessionUuid = await CallKitService().checkForActiveAcceptedCall();

    if (sessionUuid != null) {
      if (sessionUuid == _lastActiveNavigatedSessionUuid) return; // already handled
      try {
        sl<VideoCallBloc>().add(CallJoinRequested(sessionUuid));
      } catch (e) {
        debugPrint('⚠️ Failed to join missed accepted call: $e');
      }
      return;
    }

    // Check for a pending accept from the fallback notification — set by
    // NotificationService when its own Accept button's direct bloc
    // dispatch failed (the notification-action-tap isolate has proven
    // unreliable for reaching GetIt). This is the guaranteed path: by
    // the time the app actually resumes here, we're reliably back in the
    // main isolate.
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

    // Safety net for the exact bug we hit: an action-button tap
    // (Accept/Decline from the fallback notification) can succeed
    // server-side via the guaranteed HTTP path while the bloc's local
    // state never finds out, because that isolate context doesn't
    // reliably have GetIt access. Left unresolved, the bloc stays
    // stuck "busy" and silently ignores every future incoming call for
    // the rest of the app session.
    //
    // IMPORTANT: only reset `active`/`connecting` — NOT `ringingIncoming`
    // or `ringingOutgoing`. This method runs on EVERY app resume, which
    // can happen for all sorts of incidental reasons (notification shade,
    // screen lock/unlock, split-screen) — including the exact moment a
    // real call is legitimately ringing. The original version reset ANY
    // non-idle phase unconditionally, which meant a real incoming call
    // could get silently wiped out mid-ring by a coincidental resume
    // event, causing exactly the "call not showing" + "state becomes
    // unreliable afterward" regression this caused. `active`/`connecting`
    // are the only phases that should ALWAYS correspond to a real
    // CallKit-tracked call — if CallKit shows nothing active while we're
    // in one of those specifically, that's genuinely suspicious/stale.
    try {
      final bloc = sl<VideoCallBloc>();
      final suspiciousPhase = bloc.state.phase == VideoCallPhase.active ||
          bloc.state.phase == VideoCallPhase.connecting;
      if (suspiciousPhase) {
        debugPrint('📞 [main] Resetting stale non-idle bloc state on resume (no real active call found)');
        bloc.add(CallDismissed());
      }
    } catch (e) {
      debugPrint('⚠️ Stale-state reset check failed: $e');
    }
  }

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
    unawaited(() async {
      final sessionUuid = await CallKitService().checkForActiveAcceptedCall();
      if (sessionUuid != null) {
        try {
          sl<VideoCallBloc>().add(CallJoinRequested(sessionUuid));
        } catch (e) {
          debugPrint('⚠️ Failed to join missed accepted call (cold start): $e');
        }
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final pendingUuid = prefs.getString('pending_join_session_uuid');
      if (pendingUuid != null && pendingUuid.isNotEmpty) {
        await prefs.remove('pending_join_session_uuid');
        try {
          debugPrint('📞 [main] Joining pending call from notification accept (cold start): $pendingUuid');
          sl<VideoCallBloc>().add(CallResumeAfterNotificationAccept(pendingUuid));
        } catch (e) {
          debugPrint('⚠️ Failed to join pending call (cold start): $e');
        }
      }
    }());

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
      if (_lastRingingSessionUuid != null) {
        NotificationService().dismissIncomingCallNotification(_lastRingingSessionUuid!);
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