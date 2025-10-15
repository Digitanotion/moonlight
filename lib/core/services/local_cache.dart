import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalCache {
  static const _k = 'post_feature_cache_v1';

  Future<Map<String, dynamic>> read() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_k);
    if (raw == null) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> write(Map<String, dynamic> map) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_k, jsonEncode(map));
  }
}
