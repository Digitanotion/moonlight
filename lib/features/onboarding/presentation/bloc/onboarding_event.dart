part of 'onboarding_bloc.dart';

abstract class OnboardingEvent extends Equatable {
  const OnboardingEvent();

  @override
  List<Object> get props => [];
}

// ✅ KEEP EXISTING: For OnboardingBloc's automatic loading
class LoadOnboardingStatus extends OnboardingEvent {}

// ✅ NEW: Specifically for Splash Screen to check status
class CheckFirstLaunchStatus extends OnboardingEvent {
  const CheckFirstLaunchStatus();
}

class OnboardingPageChanged extends OnboardingEvent {
  final int pageIndex;

  const OnboardingPageChanged(this.pageIndex);

  @override
  List<Object> get props => [pageIndex];
}

class OnboardingSkip extends OnboardingEvent {}

class OnboardingComplete extends OnboardingEvent {}
