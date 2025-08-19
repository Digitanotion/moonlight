import 'package:shared_preferences/shared_preferences.dart';

abstract class OnboardingLocalDataSource {
  Future<bool> isFirstLaunch();
  Future<void> setOnboardingCompleted();
}

class OnboardingLocalDataSourceImpl implements OnboardingLocalDataSource {
  final SharedPreferences sharedPreferences;

  OnboardingLocalDataSourceImpl({required this.sharedPreferences});

  @override
  Future<bool> isFirstLaunch() async {
    return sharedPreferences.getBool('isFirstLaunch') ?? true;
  }

  @override
  Future<void> setOnboardingCompleted() async {
    await sharedPreferences.setBool('isFirstLaunch', false);
  }
}
