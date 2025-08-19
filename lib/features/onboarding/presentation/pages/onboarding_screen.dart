// onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:moonlight/core/routing/app_router.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_theme.dart';
import 'package:moonlight/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:moonlight/features/onboarding/presentation/widgets/dot_indicator.dart';
import 'package:moonlight/features/onboarding/presentation/widgets/onboarding_page.dart';
import 'package:moonlight/features/onboarding/presentation/widgets/primary_button.dart';
import 'package:moonlight/features/onboarding/presentation/widgets/secondary_button.dart';
import 'package:moonlight/features/onboarding/presentation/widgets/skip_button.dart';

class OnboardingScreen extends StatelessWidget {
  final PageController _pageController = PageController();

  OnboardingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<OnboardingBloc, OnboardingState>(
        builder: (context, state) {
          return Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: state.pages.length,
                onPageChanged: (index) {
                  context.read<OnboardingBloc>().add(
                    OnboardingPageChanged(index),
                  );
                },
                itemBuilder: (context, index) {
                  return OnboardingPage(page: state.pages[index]);
                },
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 24,
                child: SkipButton(
                  onPressed: () {
                    context.read<OnboardingBloc>().add(OnboardingSkip());
                    Navigator.pushReplacementNamed(context, RouteNames.login);
                  },
                ),
              ),
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 80,
                left: 24,
                right: 24,
                child: SecondaryButton(
                  text: state.currentPage == state.pages.length - 1
                      ? 'Get Started'
                      : 'Next',
                  onPressed: () {
                    if (state.currentPage == state.pages.length - 1) {
                      context.read<OnboardingBloc>().add(OnboardingComplete());
                      Navigator.pushReplacementNamed(context, RouteNames.login);
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeIn,
                      );
                    }
                  },
                ),
              ),

              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 40,
                left: 0,
                right: 0,
                child: Center(
                  child: DotIndicator(
                    pageCount: state.pages.length,
                    currentPage: state.currentPage,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
