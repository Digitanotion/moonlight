// lib/main.dart
//
// CHANGES vs your version:
//   1. Added import for AdService.
//   2. AdService.instance.init() added to the Future.wait(...) inside
//      _initEverything() — runs in PARALLEL with Firebase init and the
//      remaining dependency loading. This preserves your splash-first
//      boot order exactly: the bare splash still renders on frame 1,
//      nothing here blocks that, and ad init is just one more background
//      task alongside the ones you already have.
//
// Nothing else changed — same two-phase boot, same DependencyManager gate,
// same Firebase/FCM setup.

import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/config/runtime_config.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/routing/app_router.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/services/ad_service.dart'; // ← NEW
import 'package:moonlight/core/services/connection_monitor.dart';
import 'package:moonlight/core/services/notification_handler_service.dart';
import 'package:moonlight/core/services/notification_service.dart';
import 'package:moonlight/core/services/runtime_config_refresh_service.dart';
import 'package:moonlight/core/services/service_registration_manager.dart';
import 'package:moonlight/core/services/token_registration_service.dart';
import 'package:moonlight/core/theme/app_theme.dart';
import 'package:moonlight/core/widgets/connection_toast.dart';
import 'package:moonlight/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moonlight/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📱 Background message: ${message.messageId}');
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
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

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
        navigatorKey: navigatorKey,
        builder: (context, child) => SimpleConnectionToast(child: child!),
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

    // Firebase, remaining GetIt registrations, and ad SDK init all run
    // in parallel — none of these block the splash, which is already
    // on screen by this point.
    await Future.wait([
      _initFirebase(),
      SplashOptimizer.loadRemainingDependencies(),
      _initAds(), // ← NEW
    ]);

    // Update FCM token registration base URL.
    try {
      await sl<TokenRegistrationService>().setDependencies(
        apiBaseUrl: sl<RuntimeConfig>().apiBaseUrl,
      );
    } catch (_) {}

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

// ── NEW ──────────────────────────────────────────────────────────────────
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