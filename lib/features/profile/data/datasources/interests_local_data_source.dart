import 'package:shared_preferences/shared_preferences.dart';

abstract class InterestsLocalDataSource {
  Future<void> setCompleted(bool value);
  Future<bool> getCompleted();
}

const _kCompletedKey = 'interests_completed';

class InterestsLocalDataSourceImpl implements InterestsLocalDataSource {
  final SharedPreferences prefs;
  InterestsLocalDataSourceImpl(this.prefs);

  @override
  Future<void> setCompleted(bool value) async {
    await prefs.setBool(_kCompletedKey, value);
  }

  @override
  Future<bool> getCompleted() async {
    return prefs.getBool(_kCompletedKey) ?? false;
  }
}
