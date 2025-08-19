import 'package:moonlight/core/utils/asset_paths.dart';
import 'package:moonlight/features/onboarding/data/datasources/onboarding_local_datasource.dart';
import 'package:moonlight/features/onboarding/domain/entities/onboarding_page_entity.dart';
import 'package:moonlight/features/onboarding/domain/repositories/onboarding_repository.dart';

class OnboardingRepositoryImpl implements OnboardingRepository {
  final OnboardingLocalDataSource localDataSource;

  OnboardingRepositoryImpl({required this.localDataSource});

  @override
  Future<bool> isFirstLaunch() async {
    return await localDataSource.isFirstLaunch();
  }

  @override
  Future<void> setOnboardingCompleted() async {
    await localDataSource.setOnboardingCompleted();
  }

  @override
  List<OnboardingPageEntity> getOnboardingPages() {
    // This could be moved to a remote data source in the future
    return [
      OnboardingPageEntity(
        imagePath: AssetPaths.onboard_1,
        title: 'Welcome to Moonlight',
        description: 'Where streaming meets community',
      ),
      OnboardingPageEntity(
        imagePath: AssetPaths.onboard_2,
        title: 'Go Live Like A Pro',
        description:
            'High-quality live streaming\nEarn coins from virtual gifts\nProfessional filters & effects',
      ),
      OnboardingPageEntity(
        imagePath: AssetPaths.onboard_3,
        title: 'You\'re not Alone',
        description:
            'Connect with over 50,000 creators\n1M+ Active Users\n50K+ Live Clubs',
      ),
    ];
  }
}
