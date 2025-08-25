import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:moonlight/features/onboarding/presentation/widgets/dot_indicator.dart';
import 'package:moonlight/features/onboarding/presentation/widgets/onboarding_page.dart';
import 'package:moonlight/features/onboarding/presentation/widgets/secondary_button.dart';
import 'package:moonlight/features/onboarding/presentation/widgets/skip_button.dart';

// ✅ Added import for AuthBloc
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
// ✅ Added import for SharedPreferences
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatelessWidget {
  final PageController _pageController = PageController();

  OnboardingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            Navigator.pushReplacementNamed(context, RouteNames.home);
          } else if (state is AuthUnauthenticated) {
            Navigator.pushReplacementNamed(context, RouteNames.register);
          }
        },
        child: BlocBuilder<OnboardingBloc, OnboardingState>(
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
                    onPressed: () async {
                      context.read<OnboardingBloc>().add(OnboardingSkip());
                      // ✅ Persist onboarding completion for skip
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('hasCompletedOnboarding', true);
                      Navigator.pushReplacementNamed(
                        context,
                        RouteNames.register,
                      );
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
                    onPressed: () async {
                      if (state.currentPage == state.pages.length - 1) {
                        context.read<OnboardingBloc>().add(
                          OnboardingComplete(),
                        );

                        // ✅ Persist onboarding completion
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('hasCompletedOnboarding', true);

                        // ✅ Trigger auth check instead of direct navigation
                        context.read<AuthBloc>().add(CheckAuthStatusEvent());
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
      ),
    );
  }
}
