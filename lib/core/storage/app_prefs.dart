import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class AppPrefs {
  AppPrefs(this._prefs);
  final SharedPreferences _prefs;

  static Future<AppPrefs> get instance async {
    final p = await SharedPreferences.getInstance();
    return AppPrefs(p);
  }

  bool get hasCompletedOnboarding =>
      _prefs.getBool(AppKeys.hasCompletedOnboarding) ?? false;

  Future<void> setCompletedOnboarding([bool value = true]) async {
    await _prefs.setBool(AppKeys.hasCompletedOnboarding, value);
  }
}
