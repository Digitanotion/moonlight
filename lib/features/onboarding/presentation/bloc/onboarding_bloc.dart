// onboarding_bloc.dart
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:moonlight/core/utils/asset_paths.dart';
import 'package:moonlight/features/onboarding/domain/entities/onboarding_page_entity.dart';
import 'package:moonlight/features/onboarding/domain/repositories/onboarding_repository.dart';

part 'onboarding_event.dart';
part 'onboarding_state.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  final OnboardingRepository repository;

  OnboardingBloc({required this.repository})
    : super(OnboardingState.initial()) {
    // Event handlers
    on<LoadOnboardingStatus>(_onLoadStatus);
    on<CheckFirstLaunchStatus>(_onCheckFirstLaunchStatus); // ✅ NEW
    on<OnboardingPageChanged>(_onPageChanged);
    on<OnboardingSkip>(_onSkip);
    on<OnboardingComplete>(_onComplete);

    // ✅ MODIFIED: Use a delayed trigger to prevent splash conflicts
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!isClosed) {
        add(LoadOnboardingStatus());
      }
    });
  }

  // Load first-launch flag from repository (for BLoC initialization)
  Future<void> _onLoadStatus(
    LoadOnboardingStatus event,
    Emitter<OnboardingState> emit,
  ) async {
    try {
      final firstLaunch = await repository.isFirstLaunch();
      emit(state.copyWith(isFirstLaunch: firstLaunch));
      debugPrint('✅ OnboardingBloc loaded: isFirstLaunch=$firstLaunch');
    } catch (e) {
      debugPrint('❌ Error loading onboarding status: $e');
      emit(
        state.copyWith(isFirstLaunch: true),
      ); // Default to first launch on error
    }
  }

  // ✅ NEW: Simple status check for splash screen
  Future<void> _onCheckFirstLaunchStatus(
    CheckFirstLaunchStatus event,
    Emitter<OnboardingState> emit,
  ) async {
    try {
      // Just read current state without emitting changes
      debugPrint('🔍 Splash checking: isFirstLaunch=${state.isFirstLaunch}');

      // If state is still null (BLoC not initialized), fetch it
      if (state.isFirstLaunch == null) {
        final firstLaunch = await repository.isFirstLaunch();
        emit(state.copyWith(isFirstLaunch: firstLaunch));
        debugPrint('✅ Splash fetched: isFirstLaunch=$firstLaunch');
      }
    } catch (e) {
      debugPrint('⚠️ Splash onboarding check error: $e');
      // Don't emit error state - keep current state
    }
  }

  // Handle page change
  void _onPageChanged(
    OnboardingPageChanged event,
    Emitter<OnboardingState> emit,
  ) {
    emit(state.copyWith(currentPage: event.pageIndex));
  }

  // Handle skip button
  Future<void> _onSkip(
    OnboardingSkip event,
    Emitter<OnboardingState> emit,
  ) async {
    await repository.setOnboardingCompleted();
    emit(state.copyWith(isFirstLaunch: false));
  }

  // Handle get started / complete button
  Future<void> _onComplete(
    OnboardingComplete event,
    Emitter<OnboardingState> emit,
  ) async {
    await repository.setOnboardingCompleted();
    emit(state.copyWith(isFirstLaunch: false));
  }
}
