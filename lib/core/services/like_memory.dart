import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LikeMemory {
  LikeMemory(this._prefs) {
    final raw = _prefs.getString(_k) ?? '[]';
    try {
      _ids.addAll((jsonDecode(raw) as List).cast<String>());
    } catch (_) {
      /* ignore bad data */
    }
  }

  final SharedPreferences _prefs;
  static const _k = 'liked_posts_v1';
  final Set<String> _ids = {};

  bool isLiked(String postId) => _ids.contains(postId);

  void setLiked(String postId, bool liked) {
    if (liked) {
      _ids.add(postId);
    } else {
      _ids.remove(postId);
    }
    _prefs.setString(_k, jsonEncode(_ids.toList()));
  }
}
