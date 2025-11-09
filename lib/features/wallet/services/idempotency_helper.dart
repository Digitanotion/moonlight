import 'package:shared_preferences/shared_preferences.dart';

class IdempotencyHelper {
  final SharedPreferences prefs;
  static const _prefix = 'wallet_idem_';

  IdempotencyHelper(this.prefs);

  Future<void> persist(
    String idempotencyKey,
    Map<String, dynamic> payload,
  ) async {
    final key = '$_prefix$idempotencyKey';
    await prefs.setString(key, payload.isNotEmpty ? payload.toString() : '{}');
    // You can expand payload storage to json string if needed.
  }

  Future<void> complete(String idempotencyKey) async {
    final key = '$_prefix$idempotencyKey';
    if (prefs.containsKey(key)) await prefs.remove(key);
  }

  Map<String, dynamic>? recover(String idempotencyKey) {
    final key = '$_prefix$idempotencyKey';
    if (!prefs.containsKey(key)) return null;
    // payload stored as toString; for improved robustness store json-string.
    return {'raw': prefs.getString(key)};
  }

  List<String> pendingKeys() {
    return prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
  }
}
