import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/routing/app_router.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/services/service_registration_manager.dart';
import 'package:moonlight/core/theme/app_theme.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moonlight/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🚀 App starting...');

  // Initialize Firebase
  await Firebase.initializeApp();
  debugPrint('✅ Firebase initialized');

  // Load essential dependencies
  await SplashOptimizer.loadEssentialsOnly();
  debugPrint('✅ Essential dependencies loaded');

  // Start loading remaining dependencies in background
  final dependencyFuture = SplashOptimizer.loadRemainingDependencies()
      .then((_) => debugPrint('🎉 All background dependencies loaded'))
      .catchError((e) => debugPrint('⚠️ Background loading error: $e'));

  // Run app immediately
  runApp(const MyApp());

  // Wait for dependencies in background (non-blocking)
  unawaited(dependencyFuture);
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
              // Handle service registration on auth state changes
              if (state is AuthUnauthenticated) {
                // User logged out, unregister services
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
        // Add other providers as needed
      ],
      child: MaterialApp(
        title: 'Moonlight',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        onGenerateRoute: AppRouter.generateRoute,
        initialRoute: RouteNames.splash,
      ),
    );
  }
}
