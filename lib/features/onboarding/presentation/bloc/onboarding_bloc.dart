// onboarding_bloc.dart
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:moonlight/core/utils/asset_paths.dart';
import 'package:moonlight/features/onboarding/domain/entities/onboarding_page_entity.dart';
import 'package:moonlight/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'onboarding_event.dart';
part 'onboarding_state.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  final OnboardingRepository repository;

  OnboardingBloc({required this.repository})
    : super(OnboardingState.initial()) {
    on<LoadOnboardingStatus>(_onLoadStatus);
    on<CheckFirstLaunchStatus>(_onCheckFirstLaunchStatus);
    on<OnboardingPageChanged>(_onPageChanged);
    on<OnboardingSkip>(_onSkip);
    on<OnboardingComplete>(_onComplete);

    // ✅ Unchanged: delayed trigger to prevent splash conflicts
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!isClosed) add(LoadOnboardingStatus());
    });
  }

  Future<void> _onLoadStatus(
    LoadOnboardingStatus event,
    Emitter<OnboardingState> emit,
  ) async {
    try {
      final firstLaunch = await repository.isFirstLaunch();

      // ── Read profile-setup completion flag ───────────────────────────────
      final prefs = await SharedPreferences.getInstance();
      final hasCompletedProfile = prefs.getBool('hasCompletedProfile') ?? false;

      emit(
        state.copyWith(
          isFirstLaunch: firstLaunch,
          hasCompletedProfile: hasCompletedProfile,
        ),
      );

      debugPrint(
        '✅ OnboardingBloc loaded: isFirstLaunch=$firstLaunch, '
        'hasCompletedProfile=$hasCompletedProfile',
      );
    } catch (e) {
      debugPrint('❌ Error loading onboarding status: $e');
      // Default to first launch on error — safe fallback
      emit(state.copyWith(isFirstLaunch: true, hasCompletedProfile: false));
    }
  }

  Future<void> _onCheckFirstLaunchStatus(
    CheckFirstLaunchStatus event,
    Emitter<OnboardingState> emit,
  ) async {
    try {
      debugPrint('🔍 Splash checking: isFirstLaunch=${state.isFirstLaunch}');

      final firstLaunch = await repository.isFirstLaunch();
      final prefs = await SharedPreferences.getInstance();
      final hasCompletedProfile = prefs.getBool('hasCompletedProfile') ?? false;

      emit(
        state.copyWith(
          isFirstLaunch: firstLaunch,
          hasCompletedProfile: hasCompletedProfile,
        ),
      );

      debugPrint(
        '✅ Splash fetched: isFirstLaunch=$firstLaunch, '
        'hasCompletedProfile=$hasCompletedProfile',
      );
    } catch (e) {
      debugPrint('⚠️ Splash onboarding check error: $e');
      // Keep current state — don't emit error state
    }
  }

  void _onPageChanged(
    OnboardingPageChanged event,
    Emitter<OnboardingState> emit,
  ) {
    emit(state.copyWith(currentPage: event.pageIndex));
  }

  Future<void> _onSkip(
    OnboardingSkip event,
    Emitter<OnboardingState> emit,
  ) async {
    await repository.setOnboardingCompleted();
    emit(state.copyWith(isFirstLaunch: false));
  }

  Future<void> _onComplete(
    OnboardingComplete event,
    Emitter<OnboardingState> emit,
  ) async {
    await repository.setOnboardingCompleted();
    emit(state.copyWith(isFirstLaunch: false));
  }
}
