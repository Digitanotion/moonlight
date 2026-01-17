import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/utils/asset_paths.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moonlight/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:moonlight/features/onboarding/presentation/widgets/dot_indicator.dart';
import 'package:moonlight/features/onboarding/presentation/widgets/onboarding_page.dart';
import 'package:moonlight/features/onboarding/presentation/widgets/secondary_button.dart';
import 'package:moonlight/features/onboarding/presentation/widgets/skip_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  bool _isCompleting = false;
  bool _isSkipping = false;
  StreamSubscription<AuthState>? _authSubscription;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _disposed = true;
    _pageController.dispose();
    _authSubscription?.cancel();
    super.dispose();
  }

  /// Helper to safely update state if widget is still mounted
  void _safeSetState(VoidCallback fn) {
    if (mounted && !_disposed) {
      setState(fn);
    }
  }

  /// Unified method to handle onboarding completion
  Future<void> _completeOnboarding({bool skipped = false}) async {
    // Prevent multiple taps
    if (_isCompleting || _isSkipping) return;

    _safeSetState(() {
      if (skipped) {
        _isSkipping = true;
      } else {
        _isCompleting = true;
      }
    });

    try {
      // Dispatch appropriate event to BLoC
      final bloc = context.read<OnboardingBloc>();
      if (skipped) {
        bloc.add(OnboardingSkip());
      } else {
        bloc.add(OnboardingComplete());
      }

      // Trigger auth check
      final authBloc = context.read<AuthBloc>();
      authBloc.add(CheckAuthStatusEvent());

      // Listen for auth state changes with timeout
      final completer = Completer<void>();
      final timeoutDuration = const Duration(seconds: 5);

      _authSubscription?.cancel();
      _authSubscription = authBloc.stream.listen((state) {
        if (state is AuthAuthenticated) {
          if (!completer.isCompleted) {
            completer.complete();
          }
        } else if (state is AuthUnauthenticated) {
          if (!completer.isCompleted) {
            completer.complete();
          }
        }
      });

      // Add timeout safety
      final timeoutFuture = Future.delayed(timeoutDuration, () {
        if (!completer.isCompleted) {
          debugPrint('⚠️ Auth check timeout, proceeding to register');
          completer.complete();
        }
      });

      await completer.future;
      await timeoutFuture;

      // Navigate based on auth state
      final currentAuthState = authBloc.state;

      if (!mounted) return;

      if (currentAuthState is AuthAuthenticated) {
        _navigateTo(RouteNames.home);
      } else {
        _navigateTo(RouteNames.register);
      }
    } catch (e, stack) {
      debugPrint('❌ Onboarding completion error: $e');
      debugPrint('Stack trace: $stack');

      if (mounted) {
        // Fallback navigation on error
        _navigateTo(RouteNames.register);
      }
    } finally {
      _safeSetState(() {
        _isCompleting = false;
        _isSkipping = false;
      });
    }
  }

  /// Safe navigation method with error handling
  void _navigateTo(String routeName) {
    if (!mounted) return;

    try {
      Navigator.pushReplacementNamed(context, routeName);
    } catch (e) {
      debugPrint('❌ Navigation error to $routeName: $e');
      // Emergency fallback
      if (routeName == RouteNames.register) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(RouteNames.register, (route) => false);
      }
    }
  }

  /// Handle next button tap
  void _handleNextButton(OnboardingState state) {
    if (state.currentPage == state.pages.length - 1) {
      // Last page - complete onboarding
      _completeOnboarding(skipped: false);
    } else {
      // Next page
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          // This listener handles auth state changes that might happen
          // independently of user interaction
          if (state is AuthAuthenticated && !_isCompleting && !_isSkipping) {
            // User was authenticated in background (rare case)
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _navigateTo(RouteNames.home);
            });
          }
        },
        child: BlocBuilder<OnboardingBloc, OnboardingState>(
          builder: (context, state) {
            return Stack(
              children: [
                // Page View
                PageView.builder(
                  controller: _pageController,
                  physics: const ClampingScrollPhysics(),
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

                // Skip Button (only show if not on last page)
                if (state.currentPage < state.pages.length - 1)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 16,
                    right: 24,
                    child: SkipButton(
                      onPressed: _isSkipping
                          ? null
                          : () => _completeOnboarding(skipped: true),
                      isLoading: _isSkipping,
                    ),
                  ),

                // Bottom Controls
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).padding.bottom + 20,
                      left: 24,
                      right: 24,
                      top: 20,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.surface.withOpacity(0.9),
                          AppColors.surface,
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        // Dot Indicators
                        DotIndicator(
                          pageCount: state.pages.length,
                          currentPage: state.currentPage,
                        ),
                        const SizedBox(height: 24),

                        // Next/Get Started Button
                        SizedBox(
                          width: double.infinity,
                          child: SecondaryButton(
                            text: state.currentPage == state.pages.length - 1
                                ? 'Get Started'
                                : 'Next',
                            onPressed: _isCompleting || _isSkipping
                                ? null
                                : () => _handleNextButton(state),
                            isLoading:
                                _isCompleting &&
                                state.currentPage == state.pages.length - 1,
                            loadingText: 'Setting up...',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Loading Overlay (for completion)
                // if (_isCompleting || _isSkipping)
                //   Container(
                //     color: Colors.black.withOpacity(0.5),
                //     child: const Center(
                //       child: CircularProgressIndicator(
                //         valueColor: AlwaysStoppedAnimation<Color>(
                //           AppColors.primary_,
                //         ),
                //       ),
                //     ),
                //   ),
              ],
            );
          },
        ),
      ),
    );
  }
}
