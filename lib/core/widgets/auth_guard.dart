import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moonlight/core/routing/route_names.dart';

/// Wrap a protected page with this.
///
/// It is a **non-blocking** gate: the protected screen renders immediately.
/// The only thing it does is send the user to Login if the auth state is (or
/// becomes) [AuthUnauthenticated] — an explicit logout, or a startup check
/// that found no session.
///
/// It deliberately does NOT re-verify auth on every navigation:
///  * you can only reach a guarded route after the splash screen's auth check,
///    so the session is already known-good by the time this builds;
///  * a stale/expired token is handled by `AuthInterceptor` (refresh + retry)
///    on the screen's first API call;
///  * the previous implementation dispatched `CheckAuthStatusEvent` on every
///    mount, which forced `AuthLoading` and blocked the whole screen behind a
///    full `/profile/me` network round-trip (the black screen + orange
///    spinner). Profile freshness is now a silent background refresh
///    (`SilentUserRefreshRequested`) triggered on app resume instead.
class AuthGuard extends StatefulWidget {
  final Widget child;

  const AuthGuard({super.key, required this.child});

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  bool _redirecting = false;

  @override
  void initState() {
    super.initState();
    // Cover the case where we somehow arrive here already logged out
    // (BlocListener only fires on state *changes*, not the initial state).
    if (context.read<AuthBloc>().state is AuthUnauthenticated) {
      _goToLogin();
    }
  }

  void _goToLogin() {
    if (_redirecting) return;
    _redirecting = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Replace so back can't return to the protected screen.
        Navigator.of(context).pushReplacementNamed(RouteNames.login);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (prev, curr) =>
          curr is AuthUnauthenticated && prev is! AuthUnauthenticated,
      listener: (context, state) => _goToLogin(),
      // Only rebuild when we cross the unauthenticated boundary — a loading
      // state from an unrelated auth flow, or a silent profile refresh, must
      // never flip this guard or flash a spinner.
      buildWhen: (prev, curr) =>
          (prev is AuthUnauthenticated) != (curr is AuthUnauthenticated),
      builder: (context, state) {
        if (state is AuthUnauthenticated) {
          return const SizedBox.shrink();
        }
        return widget.child;
      },
    );
  }
}
