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

  /// The stored code, if any (used to pre-fill the register field).
  static Future<String?> peek() async {
    try {
      return (await SharedPreferences.getInstance()).getString(_key);
    } catch (_) {
      return null;
    }
  }

  /// Call once the user is authenticated (AppShell start, after a link).
  static Future<void> applyIfPending() async {
    if (_applying) return;
    _applying = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_key);
      if (code == null) return;
      final result = await sl<AgentRemoteDataSource>().join(code);
      // Keep it only if we weren't signed in / the network failed.
      if (result != AgentRemoteDataSource.retryLater) {
        await prefs.remove(_key);
      }
    } catch (e) {
      debugPrint('PendingAgentCode.apply: $e');
    } finally {
      _applying = false;
    }
  }
}
