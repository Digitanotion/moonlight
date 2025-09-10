import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moonlight/core/errors/exceptions.dart';
import 'package:moonlight/features/auth/data/models/user_model.dart';
import 'package:moonlight/core/network/dio_client.dart' show AuthTokenProvider;

/// Contract stays the same for the rest of your app.
abstract class AuthLocalDataSource implements AuthTokenProvider {
  Future<String?> getAuthToken(); // == readToken()
  Future<void> cacheToken(String token);
  Future<void> clearToken();

  Future<void> cacheUser(UserModel user);
  Future<UserModel> getCurrentUser();

  /// Convenience getter to read the cached user's UUID quickly.
  Future<String?> getCurrentUserUuid();
  Future<void> clearUserData();
}

/// Keys match what your Splash uses (`auth_token`)
class AuthLocalDataSourceImpl
    implements AuthLocalDataSource, AuthTokenProvider {
  final SharedPreferences sharedPreferences;
  AuthLocalDataSourceImpl({required this.sharedPreferences});

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  // ---- Token API ----

  @override
  Future<String?> getAuthToken() async {
    final raw = sharedPreferences.getString(_tokenKey);
    return _sanitize(raw);
  }

  @override
  Future<String?> getCurrentUserUuid() async {
    final jsonString = sharedPreferences.getString(_userKey);
    if (jsonString == null) return null;
    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      // Expecting your cached user JSON to include 'uuid'
      final uuid = (map['uuid'] ?? map['user_uuid']) as String?;
      return uuid?.trim().isEmpty == true ? null : uuid;
    } catch (_) {
      return null;
    }
  }

  // for DioClient interceptor (AuthTokenProvider)
  @override
  Future<String?> readToken() => getAuthToken();

  @override
  Future<void> cacheToken(String token) async {
    final clean = _sanitize(token);
    await sharedPreferences.setString(_tokenKey, clean ?? '');
  }

  @override
  Future<void> clearToken() async {
    await sharedPreferences.remove(_tokenKey);
  }

  // ---- User cache API ----

  @override
  Future<void> cacheUser(UserModel user) async {
    try {
      final userJson = jsonEncode(user.toJson());
      await sharedPreferences.setString(_userKey, userJson);
    } catch (e) {
      throw CacheException('Failed to cache user: ${e.toString()}');
    }
  }

  @override
  Future<UserModel> getCurrentUser() async {
    try {
      final jsonString = sharedPreferences.getString(_userKey);
      if (jsonString == null) {
        throw CacheException('No cached user found');
      }
      final Map<String, dynamic> userMap = jsonDecode(jsonString);
      return UserModel.fromJson(userMap);
    } catch (e) {
      if (e is CacheException) rethrow;
      throw CacheException('Failed to retrieve cached user: ${e.toString()}');
    }
  }

  @override
  Future<void> clearUserData() async {
    await sharedPreferences.remove(_userKey);
  }

  // ---- Helpers ----
  String? _sanitize(String? t) {
    if (t == null) return null;
    final s = t.trim();
    return s.startsWith('Bearer ') ? s.substring(7) : s;
  }
}
