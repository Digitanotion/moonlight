import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moonlight/core/routing/route_names.dart';

/// Wrap any protected page with this guard.
/// It ensures we’re looking at a *fresh* AuthState by dispatching CheckAuthStatusEvent
/// once (only if needed), then routes to Login if unauthenticated, or shows [child] if authenticated.
class AuthGuard extends StatefulWidget {
  final Widget child;

  const AuthGuard({super.key, required this.child});

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  bool _dispatched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bloc = context.read<AuthBloc>();

    // If we haven’t dispatched in this guard lifetime, do a fresh check.
    if (!_dispatched) {
      _dispatched = true;
      bloc.add(CheckAuthStatusEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (prev, curr) => curr is AuthUnauthenticated,
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          // Replace with Login so back button won’t pop back into the protected screen.
          Navigator.of(context).pushReplacementNamed(RouteNames.login);
        }
      },
      builder: (context, state) {
        if (state is AuthAuthenticated) {
          return widget.child;
        }

        // For AuthLoading, AuthFailure, or initial/unknown: keep a lightweight loader.
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
