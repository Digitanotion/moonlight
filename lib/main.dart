import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonlight/core/app/app_router.dart';
import 'package:moonlight/core/app/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: MoonlightApp()));
}

class MoonlightApp extends StatelessWidget {
  const MoonlightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      onGenerateRoute: AppRouter.generateRoute,
      initialRoute: AppRouter.splash,
    );
  }
}
