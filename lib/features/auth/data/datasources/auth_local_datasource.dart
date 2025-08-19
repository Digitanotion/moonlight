import 'package:moonlight/features/auth/data/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class AuthLocalDataSource {
  Future<String?> getAuthToken();
  Future<void> cacheToken(String token);
  Future<void> clearToken();
  Future<void> cacheUser(UserModel user);
  Future<UserModel> getCurrentUser();
  Future<void> clearUserData();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final SharedPreferences sharedPreferences;

  AuthLocalDataSourceImpl({required this.sharedPreferences});

  @override
  Future<String?> getAuthToken() async {
    return sharedPreferences.getString('auth_token');
  }

  @override
  Future<void> cacheToken(String token) async {
    await sharedPreferences.setString('auth_token', token);
  }

  @override
  Future<void> clearToken() async {
    await sharedPreferences.remove('auth_token');
  }

  @override
  Future<void> cacheUser(UserModel user) async {
    // Implement your user caching logic
    // Example: await sharedPreferences.setString('user_data', user.toJson());
  }

  @override
  Future<UserModel> getCurrentUser() async {
    // Implement your user retrieval logic
    // Example: final json = sharedPreferences.getString('user_data');
    // return UserModel.fromJson(json!);
    throw UnimplementedError();
  }

  @override
  Future<void> clearUserData() async {
    await sharedPreferences.remove('user_data');
  }
}
