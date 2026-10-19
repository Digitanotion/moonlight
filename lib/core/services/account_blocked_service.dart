// lib/core/services/account_blocked_service.dart
//
// When an admin bans (or suspends) a user, the API revokes their tokens and
// answers every further request with 403 + code ACCOUNT_BANNED /
// ACCOUNT_SUSPENDED. Without this the app just looked broken — every screen
// failed with no explanation. Now the first such response signs the user out
// and shows a clear, non-dismissible "account banned" dialog.
//
// Sign-in requests carry no Authorization header, so they're left alone: the
// login screen already shows the server's message for those.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moonlight/main.dart' show MyApp;

class AccountBlockedService {
  AccountBlockedService._();

  static const _codes = {'ACCOUNT_BANNED', 'ACCOUNT_SUSPENDED'};

  static bool _handling = false;

  /// Call from the Dio error hook. Returns true when [e] was a ban/suspension
  /// on an authenticated request (the sign-out has been kicked off).
  static bool handleDioError(DioException e) {
    final res = e.response;
    if (res?.statusCode != 403) return false;
    final data = res?.data;
    if (data is! Map) return false;
    final code = data['code']?.toString();
    if (!_codes.contains(code)) return false;
    if (e.requestOptions.headers['Authorization'] == null) return false;

    final message = data['message']?.toString();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _signOut(code!, message),
    );
    return true;
  }

  static Future<void> _signOut(String code, String? message) async {
    if (_handling) return;
    final ctx = MyApp.navigatorKey.currentContext;
    if (ctx == null) return;
    _handling = true;

    // Finish the local sign-out first so auth listeners don't navigate over
    // the dialog afterwards.
    try {
      final auth = ctx.read<AuthBloc>();
      final done = auth.stream
          .firstWhere((s) => s is AuthUnauthenticated || s is AuthFailure)
          .timeout(const Duration(seconds: 5));
      auth.add(LogoutRequested());
      await done;
    } catch (_) {}

    final nav = MyApp.navigatorKey.currentState;
    nav?.pushNamedAndRemoveUntil(RouteNames.login, (_) => false);

    final dialogCtx = MyApp.navigatorKey.currentContext;
    if (dialogCtx == null) {
      _handling = false;
      return;
    }
    final banned = code == 'ACCOUNT_BANNED';
    await showDialog<void>(
      context: dialogCtx,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1C1533),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Icon(
              banned ? Icons.block_rounded : Icons.pause_circle_outline_rounded,
              color: Colors.redAccent,
              size: 56,
            ),
            const SizedBox(height: 10),
            Text(
              banned ? 'Account banned' : 'Account suspended',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          message ??
              (banned
                  ? 'Your account has been banned. Please contact support to appeal.'
                  : 'Your account has been suspended. Please contact support.'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.deepOrangeAccent),
            ),
          ),
        ],
      ),
    );
    _handling = false;
  }
}
