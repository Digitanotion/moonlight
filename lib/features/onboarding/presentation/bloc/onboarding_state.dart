part of 'onboarding_bloc.dart';

class OnboardingState extends Equatable {
  final int currentPage;
  final bool isFirstLaunch;
  final List<OnboardingPageEntity> pages;

  const OnboardingState({
    required this.currentPage,
    required this.isFirstLaunch,
    required this.pages,
  });

  factory OnboardingState.initial() {
    return OnboardingState(
      currentPage: 0,
      isFirstLaunch: true,
      pages: [
        OnboardingPageEntity(
          imagePath: AssetPaths.onboard_1,
          title: 'Welcome to Moonlight',
          description: 'Where streaming meets community',
        ),
        OnboardingPageEntity(
          imagePath: AssetPaths.onboard_2,
          title: 'Go Live Like A Pro',
          features: [
            {
              'icon': Icons.videocam_outlined,
              'text': 'High-quality live streaming',
            },
            {
              'icon': Icons.monetization_on_outlined,
              'text': 'Earn coins from virtual gifts',
            },
            {
              'icon': Icons.filter_vintage_outlined,
              'text': 'Professional filters & effects',
            },
          ],
        ),
        OnboardingPageEntity(
          imagePath: AssetPaths.onboard_3,
          title: 'You\'re not Alone',
          description: 'Join a global family of creators',
          stats: {'1M+': 'Active Users', '50K+': 'Live Clubs'},
        ),
      ],
    );
  }

  OnboardingState copyWith({
    int? currentPage,
    bool? isFirstLaunch,
    List<OnboardingPageEntity>? pages,
  }) {
    return OnboardingState(
      currentPage: currentPage ?? this.currentPage,
      isFirstLaunch: isFirstLaunch ?? this.isFirstLaunch,
      pages: pages ?? this.pages,
    );
  }

  @override
  List<Object> get props => [currentPage, isFirstLaunch, pages];
}
