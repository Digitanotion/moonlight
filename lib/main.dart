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

// Background message handler — must be top-level
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📱 Background message: ${message.messageId}');
  if (message.notification != null) {
    debugPrint(
      '📱 Notification: ${message.notification!.title} - ${message.notification!.body}',
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🚀 App starting...');

  // ─── PHASE 1: Only what's needed to render the first frame ───
  // SharedPreferences (local disk, ~5ms) + blocs + cached config.
  // NO network calls here. NO Firebase. NO heavy interceptors.
  await SplashOptimizer.registerRenderEssentials();

  // ─── Show the UI immediately ───
  // The splash screen will appear right away while everything
  // else loads in the background below.
  runApp(const MyApp());

  // ─── PHASE 2 & 3: Everything else, after the UI is visible ───
  unawaited(_initializeInBackground());
}

/// All heavy initialization runs here, AFTER runApp().
/// The splash screen is already visible to the user at this point.
Future<void> _initializeInBackground() async {
  try {
    debugPrint('🔄 Background init starting...');

    // Firebase and config fetch can run in parallel
    await Future.wait([
      _initFirebase(),
      SplashOptimizer.loadConfigAndDependencies(),
    ]);

    // After config is ready, update the TokenRegistrationService base URL
    final tokenService = sl<TokenRegistrationService>();
    await tokenService.setDependencies(
      apiBaseUrl: sl<RuntimeConfig>().apiBaseUrl,
    );

    // Start connection monitoring
    await ConnectionMonitor().startMonitoring();

    // Load all remaining dependencies (DioClient, Pusher, all features)
    await SplashOptimizer.loadRemainingDependencies();

    // Start config refresh monitoring last
    await RuntimeConfigRefreshService().startMonitoring();

    debugPrint('🎉 Background init complete');
  } catch (e) {
    debugPrint('⚠️ Background init error: $e (app continues)');
  }
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp();
    debugPrint('✅ Firebase initialized');
    await _setupFirebaseMessaging();
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('⚠️ Firebase init error: $e');
  }
}

Future<void> _setupFirebaseMessaging() async {
  try {
    final messaging = FirebaseMessaging.instance;

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    final settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    debugPrint('📱 Notification permission: ${settings.authorizationStatus}');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📱 Foreground message: ${message.notification?.title}');
      if (message.notification != null) {
        NotificationService().showNotification(
          title: message.notification!.title!,
          body: message.notification!.body!,
          payload: message.data,
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📱 App opened from notification');
      _handleNotificationTap(message.data);
    });

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('📱 App opened from terminated state via notification');
      _handleNotificationTap(initialMessage.data);
    }

    final token = await messaging.getToken();
    debugPrint('📱 FCM Token: ${token != null ? "obtained" : "null"}');

    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString('fcm_token', token);

      // Auto-register token if user is already logged in
      try {
        final authToken = prefs.getString('auth_token');
        if (authToken != null && authToken.isNotEmpty) {
          await TokenRegistrationService(
            authLocalDataSource: sl<AuthLocalDataSource>(),
            runtimeConfig: sl<RuntimeConfig>(),
          ).registerTokenManually();
        }
      } catch (e) {
        debugPrint('⚠️ Auto token registration failed: $e');
      }
    }

    messaging.onTokenRefresh.listen((newToken) async {
      await prefs.setString('fcm_token', newToken);
      try {
        final authToken = prefs.getString('auth_token');
        if (authToken != null && authToken.isNotEmpty) {
          await TokenRegistrationService(
            authLocalDataSource: sl<AuthLocalDataSource>(),
            runtimeConfig: sl<RuntimeConfig>(),
          ).registerTokenManually();
        }
      } catch (e) {
        debugPrint('⚠️ Token refresh registration failed: $e');
      }
    });

    debugPrint('✅ Firebase Messaging setup complete');
  } catch (e) {
    debugPrint('❌ Firebase Messaging setup error: $e');
  }
}

void _handleNotificationTap(Map<String, dynamic> data) {
  debugPrint('📱 Notification tapped: $data');
  if (data.containsKey('type')) {
    NotificationHandlerService().handleNotificationClick(data);
  } else if (data.containsKey('data') && data['data'] is Map) {
    NotificationHandlerService().handleNotificationClick(
      data['data'] as Map<String, dynamic>,
    );
  }
}

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
                    debugPrint('Error unregistering services on logout: $e');
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
        builder: (context, child) {
          return SimpleConnectionToast(child: child!);
        },
      ),
    );
  }
}
