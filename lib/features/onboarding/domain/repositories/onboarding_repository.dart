// onboarding_repository.dart
import 'package:moonlight/features/onboarding/domain/entities/onboarding_page_entity.dart';

abstract class OnboardingRepository {
  Future<bool> isFirstLaunch();
  Future<void> setOnboardingCompleted();
  List<OnboardingPageEntity> getOnboardingPages();
}
