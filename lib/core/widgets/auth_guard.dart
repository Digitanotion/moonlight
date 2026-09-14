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
///
/// One exception: seeing [AuthUnauthenticated] gets a single fast
/// re-verification before actually redirecting, instead of trusting it
/// blindly. Reported symptom this fixes: on a genuinely fresh install (not a
/// hot restart), reaching a guarded screen soon after launch could bounce to
/// Login even though the user really was signed in — a known class of race
/// on true cold starts, where secure-storage's native channel isn't fully
/// warmed up yet and the very first token read comes back empty a moment
/// before a second read would have found it. Hot restart never showed it
/// because the native process (and its keystore/channel) was already warm.
/// This doesn't reintroduce the old blocking spinner — the child renders
/// immediately either way; only the *redirect* now waits for confirmation.
class AuthGuard extends StatefulWidget {
  final Widget child;

  const AuthGuard({super.key, required this.child});

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  bool _redirecting = false;
  bool _reverifying = false;

  @override
  void initState() {
    super.initState();
    // Cover the case where we somehow arrive here already logged out
    // (BlocListener only fires on state *changes*, not the initial state).
    if (context.read<AuthBloc>().state is AuthUnauthenticated) {
      _reverifyThenMaybeRedirect();
    }
  }

  /// Don't trust a single AuthUnauthenticated reading — re-run the check
  /// once and only redirect if that confirms it. Cheap and fast in the
  /// genuinely-logged-out case (still redirects promptly); only matters in
  /// the rare cold-start race where the first reading was a false negative.
  Future<void> _reverifyThenMaybeRedirect() async {
    if (_reverifying || _redirecting) return;
    _reverifying = true;

    final bloc = context.read<AuthBloc>();
    bloc.add(CheckAuthStatusEvent());

    AuthState result;
    try {
      result = await bloc.stream
          .firstWhere((s) => s is AuthAuthenticated || s is AuthUnauthenticated)
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      // Timed out or the stream errored — fall back to redirecting rather
      // than leaving the guard stuck re-verifying forever.
      result = AuthUnauthenticated();
    }

    _reverifying = false;
    if (!mounted) return;

    if (result is AuthUnauthenticated) {
      _goToLogin();
    } else {
      // Confirmed authenticated after all — nudge the builder to
      // re-evaluate against the now-current bloc state.
      setState(() {});
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
      listener: (context, state) => _reverifyThenMaybeRedirect(),
      // Only rebuild when we cross the unauthenticated boundary — a loading
      // state from an unrelated auth flow, or a silent profile refresh, must
      // never flip this guard or flash a spinner.
      buildWhen: (prev, curr) =>
          (prev is AuthUnauthenticated) != (curr is AuthUnauthenticated),
      builder: (context, state) {
        // While re-verifying a possibly-false-negative reading, keep
        // showing the child rather than blanking the screen — if it turns
        // out to genuinely be unauthenticated, _goToLogin() navigates away
        // a moment later anyway, which reads as a smooth transition rather
        // than a flash of blank content for what's usually a non-issue.
        if (state is AuthUnauthenticated && !_reverifying && !_redirecting) {
          return const SizedBox.shrink();
        }
        return widget.child;
      },
    );
  }
}
