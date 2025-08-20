import 'package:moonlight/core/errors/exceptions.dart';

abstract class ProfileRemoteDataSource {
  Future<List<String>> getCountries();
  Future<void> updateProfile(Map<String, dynamic> profileData);
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  @override
  Future<List<String>> getCountries() async {
    // Simulate API call - would typically use Dio
    await Future.delayed(const Duration(milliseconds: 500));

    // This would come from an API
    return [
      'United States',
      'United Kingdom',
      'Canada',
      'Australia',
      'Germany',
      'France',
      // ... more countries
    ];
  }

  @override
  Future<void> updateProfile(Map<String, dynamic> profileData) async {
    // Simulate API call
    await Future.delayed(const Duration(seconds: 1));

    // This would typically make a POST/PUT request to update profile
    // throw ServerException('Failed to update profile');
  }
}
