import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class IdempotencyHelper {
  final SharedPreferences prefs;
  static const _prefix = 'wallet_idem_';

  IdempotencyHelper(this.prefs);

  /// Store idempotency data as JSON string
  Future<void> persist(
    String idempotencyKey,
    Map<String, dynamic> payload,
  ) async {
    final key = '$_prefix$idempotencyKey';
    // ✅ Store as proper JSON string
    final jsonString = jsonEncode(payload);
    await prefs.setString(key, jsonString);
    debugPrint('💾 Idempotency saved: $idempotencyKey');
  }

  /// Mark idempotency key as completed (remove from storage)
  Future<void> complete(String idempotencyKey) async {
    final key = '$_prefix$idempotencyKey';
    if (prefs.containsKey(key)) {
      await prefs.remove(key);
      debugPrint('✅ Idempotency completed: $idempotencyKey');
    }
  }

  /// Recover stored payload for a given key
  Map<String, dynamic>? recover(String idempotencyKey) {
    final key = '$_prefix$idempotencyKey';
    if (!prefs.containsKey(key)) return null;

    try {
      final stored = prefs.getString(key);
      if (stored != null) {
        // ✅ Parse the JSON string back to Map
        return jsonDecode(stored) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('❌ Failed to recover idempotency data: $e');
    }
    return null;
  }

  /// Get all pending idempotency keys
  List<String> pendingKeys() {
    return prefs
        .getKeys()
        .where((k) => k.startsWith(_prefix))
        .map(
          (k) => k.substring(_prefix.length),
        ) // Return just the key, not full prefixed string
        .toList();
  }

  /// Check if a key exists and is still pending
  bool isPending(String idempotencyKey) {
    final key = '$_prefix$idempotencyKey';
    return prefs.containsKey(key);
  }

  /// Generate a new idempotency key (UUID)
  String generateKey() {
    return const Uuid().v4();
  }
}
