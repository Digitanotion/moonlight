// lib/main.dart
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/routing/app_router.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/services/connection_monitor.dart';
import 'package:moonlight/core/services/runtime_config_refresh_service.dart';
import 'package:moonlight/core/services/service_registration_manager.dart';
import 'package:moonlight/core/theme/app_theme.dart';
import 'package:moonlight/core/widgets/connection_toast.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moonlight/features/onboarding/presentation/bloc/onboarding_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🚀 App starting with fast splash...');

  // Initialize Firebase (non-blocking)
  final firebaseFuture = Firebase.initializeApp();

  // Load absolute minimum essentials (cached)
  await SplashOptimizer.loadEssentialsOnly();

  // Wait for Firebase (should be fast)
  await firebaseFuture;
  debugPrint('✅ Firebase initialized');

  // Start connection monitoring
  await ConnectionMonitor().startMonitoring();

  // Run app IMMEDIATELY (no waiting for background services)
  runApp(const MyApp());

  // Start background service loading AFTER app is running
  Future(() async {
    try {
      debugPrint('🔄 Starting background service initialization...');
      await SplashOptimizer.loadRemainingDependencies();
      debugPrint('🎉 All background services loaded');

      // Start config refresh service after dependencies are loaded
      await RuntimeConfigRefreshService().startMonitoring();
    } catch (e) {
      debugPrint('⚠️ Background service loading error: $e (app continues)');
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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

        // SIMPLIFIED: Just wrap the child with ConnectionToast
        builder: (context, child) {
          return SimpleConnectionToast(child: child!);
        },
      ),
    );
  }
}
