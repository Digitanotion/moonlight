// lib/core/auth/auth_gate.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';

/// Central check used anywhere before opening protected screens.
/// - If we're already authenticated, calls onSuccess()
/// - If status is unknown, it triggers CheckAuthStatusEvent and waits
/// - If unauthenticated, it routes to Login
class AuthGate {
  static Future<void> ensureAuthenticated(
    BuildContext context, {
    required VoidCallback onSuccess,
    bool pushLoginIfNeeded = true,
  }) async {
    final bloc = context.read<AuthBloc>();
    final current = bloc.state;

    // Fast path: already authenticated
    if (current is AuthAuthenticated) {
      onSuccess();
      return;
    }

    // If state is unknown/initial, trigger a check and wait for a decisive state
    if (current is! AuthAuthenticated && current is! AuthUnauthenticated) {
      bloc.add(CheckAuthStatusEvent());
      final next = await bloc.stream.firstWhere(
        (s) => s is AuthAuthenticated || s is AuthUnauthenticated,
      );
      if (next is AuthAuthenticated) {
        onSuccess();
        return;
      } else {
        if (pushLoginIfNeeded && context.mounted) {
          Navigator.pushNamed(context, RouteNames.login);
        }
        return;
      }
    }

    // We are explicitly unauthenticated
    if (pushLoginIfNeeded && context.mounted) {
      Navigator.pushNamed(context, RouteNames.login);
    }
  }
}
