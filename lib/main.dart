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

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("📱 Handling a background message: ${message.messageId}");
  print("📱 Notification data: ${message.data}");

  if (message.notification != null) {
    print(
      "📱 Notification: ${message.notification!.title} - ${message.notification!.body}",
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🚀 App starting with fast splash...');

  // Initialize Firebase
  final firebaseFuture = Firebase.initializeApp();

  // Load absolute minimum essentials (cached)
  await SplashOptimizer.loadEssentialsOnly();

  // Wait for Firebase
  await firebaseFuture;
  debugPrint('✅ Firebase initialized');

  // ✅ CRITICAL: Set up Firebase messaging handlers BEFORE anything else
  await _setupFirebaseMessaging();

  // Initialize Notification Services (local notifications only)
  await NotificationService().initialize();

  // Get the TokenRegistrationService from GetIt
  final tokenService = sl<TokenRegistrationService>();

  // Set dependencies with proper API base URL
  await tokenService.setDependencies(
    apiBaseUrl: sl<RuntimeConfig>().apiBaseUrl,
  );

  // Start connection monitoring
  await ConnectionMonitor().startMonitoring();

  // Run app IMMEDIATELY
  runApp(const MyApp());

  // Start background service loading AFTER app is running
  Future(() async {
    try {
      debugPrint('🔄 Starting background service initialization...');
      await SplashOptimizer.loadRemainingDependencies();
      debugPrint('🎉 All background services loaded');

      await RuntimeConfigRefreshService().startMonitoring();
    } catch (e) {
      debugPrint('⚠️ Background service loading error: $e (app continues)');
    }
  });
}

// ✅ CRITICAL: UPDATED Firebase Messaging Setup
Future<void> _setupFirebaseMessaging() async {
  try {
    final messaging = FirebaseMessaging.instance;

    // ✅ CRITICAL: Set background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permissions
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print('📱 Notification permission status: ${settings.authorizationStatus}');

    // ✅ CRITICAL: Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📱 FOREGROUND MESSAGE RECEIVED!');
      print('Title: ${message.notification?.title}');
      print('Body: ${message.notification?.body}');
      print('Data: ${message.data}');

      // Show local notification when app is in foreground
      if (message.notification != null) {
        NotificationService().showNotification(
          title: message.notification!.title!,
          body: message.notification!.body!,
          payload: message.data,
        );
      }
    });

    // ✅ CRITICAL: Handle when app is opened from terminated/background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📱 APP OPENED FROM NOTIFICATION (background/terminated)');
      print('Data: ${message.data}');

      // Handle navigation based on notification type
      _handleNotificationTap(message.data);
    });

    // ✅ CRITICAL: Check if app was opened from terminated state
    RemoteMessage? initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      print('📱 APP OPENED FROM TERMINATED STATE WITH NOTIFICATION');
      _handleNotificationTap(initialMessage.data);
    }

    // Get token
    final token = await messaging.getToken();
    print('📱 FCM Token: $token');

    // Store token in local storage
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString('fcm_token', token);
      print('✅ FCM token stored locally');

      // Check if user is already logged in
      try {
        final authToken = await prefs.getString('auth_token');
        if (authToken != null && authToken.isNotEmpty) {
          print('📱 User logged in, attempting token registration...');
          await TokenRegistrationService(
            authLocalDataSource: sl<AuthLocalDataSource>(),
            runtimeConfig: sl<RuntimeConfig>(),
          ).registerTokenManually();
        }
      } catch (e) {
        print('⚠️ Auto-token registration check failed: $e');
      }
    }

    // Listen for token refresh
    messaging.onTokenRefresh.listen((newToken) async {
      print('📱 FCM Token refreshed: $newToken');
      await prefs.setString('fcm_token', newToken);

      // Try to register new token if user is logged in
      try {
        final authToken = await prefs.getString('auth_token');
        if (authToken != null && authToken.isNotEmpty) {
          await TokenRegistrationService(
            authLocalDataSource: sl<AuthLocalDataSource>(),
            runtimeConfig: sl<RuntimeConfig>(),
          ).registerTokenManually();
        }
      } catch (e) {
        print('⚠️ Token refresh registration failed: $e');
      }
    });

    print('✅ Firebase Messaging setup complete');
  } catch (e) {
    print('❌ Firebase Messaging setup error: $e');
  }
}

// When user clicks on a push notification
void _handleNotificationTap(Map<String, dynamic> data) {
  print('📱 Notification tap received: $data');

  // Ensure we have a valid payload with a type
  if (data.containsKey('type')) {
    NotificationHandlerService().handleNotificationClick(data);
  } else if (data.containsKey('data') && data['data'] is Map) {
    // Handle nested data structure
    NotificationHandlerService().handleNotificationClick(
      data['data'] as Map<String, dynamic>,
    );
  } else {
    print('⚠️ Notification payload missing type field');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // ✅ ADD THIS: Global key for navigation from notifications
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

        // ✅ ADD THIS: Navigator key for notification navigation
        navigatorKey: navigatorKey,

        // SIMPLIFIED: Just wrap the child with ConnectionToast
        builder: (context, child) {
          return SimpleConnectionToast(child: child!);
        },
      ),
    );
  }
}
