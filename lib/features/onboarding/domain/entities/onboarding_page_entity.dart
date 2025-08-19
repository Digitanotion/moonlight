// onboarding_page_entity.dart
class OnboardingPageEntity {
  final String imagePath;
  final String title;
  final String? description;
  final List<Map<String, dynamic>>? features; // for page 2
  final Map<String, String>? stats; // for page 3

  OnboardingPageEntity({
    required this.imagePath,
    required this.title,
    this.description,
    this.features,
    this.stats,
  });
}
