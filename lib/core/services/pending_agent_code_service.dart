import 'package:play_install_referrer/play_install_referrer.dart';
import 'package:flutter/foundation.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/features/agents/data/agent_remote_data_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers an agent invite code (from an invite link or typed on the
/// register screen) until the user is signed in, then attaches the account
/// to that agent. Best-effort and silent: a refusal (code invalid, account
/// not new, already has an agent) just clears the code — it must never
/// block or break sign-up/login.
class PendingAgentCodeService {
  PendingAgentCodeService._();
  static const _key = 'pending_agent_code';
  static bool _applying = false;

  static String? normalise(String? raw) {
    final c = (raw ?? '').trim().toUpperCase();
    return RegExp(r'^[A-Z0-9]{4,16}$').hasMatch(c) ? c : null;
  }

  static Future<void> save(String? raw) async {
    final c = normalise(raw);
    if (c == null) return;
    try {
      (await SharedPreferences.getInstance()).setString(_key, c);
    } catch (e) {
      debugPrint('PendingAgentCode.save: $e');
    }
  }

  static const _referrerDoneKey = 'agent_referrer_checked';

  /// People who open an invite link without the app land on the web page,
  /// whose Play Store button carries `referrer=agent=CODE`. On the first
  /// launch after install we read it back and remember the code. Android
  /// only, once per install, and never allowed to fail the app.
  static Future<void> captureInstallReferrer() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_referrerDoneKey) == true) return;
      await prefs.setBool(_referrerDoneKey, true);
      final details = await PlayInstallReferrer.installReferrer.timeout(
        const Duration(seconds: 5),
      );
      final raw = details.installReferrer ?? '';
      final code = Uri.splitQueryString(raw)['agent'];
      await save(code);
    } catch (e) {
      debugPrint('PendingAgentCode.captureInstallReferrer: $e');
    }
  }

  /// The stored code, if any (used to pre-fill the register field).
  static Future<String?> peek() async {
    try {
      return (await SharedPreferences.getInstance()).getString(_key);
    } catch (_) {
      return null;
    }
  }

  /// Call once the user is authenticated (AppShell start, after a link).
  ///
  /// Returns what happened so a caller that just opened an invite link can
  /// react: [PendingAgentResult.needsSignIn] means nobody is signed in yet.
  static Future<(PendingAgentResult, String?)> applyIfPending() async {
    if (_applying) return (PendingAgentResult.none, null);
    _applying = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_key);
      if (code == null) return (PendingAgentResult.none, null);
      final result = await sl<AgentRemoteDataSource>().join(code);
      // Keep it only if we weren't signed in / the network failed.
      if (result == AgentRemoteDataSource.retryLater) {
        return (PendingAgentResult.needsSignIn, null);
      }
      await prefs.remove(_key);
      return result == null
          ? (PendingAgentResult.joined, null)
          : (PendingAgentResult.refused, result);
    } catch (e) {
      debugPrint('PendingAgentCode.apply: $e');
      return (PendingAgentResult.none, null);
    } finally {
      _applying = false;
    }
  }
}

enum PendingAgentResult { none, joined, refused, needsSignIn }
