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
    on<OnboardingPageChanged>(_onPageChanged);
    on<OnboardingSkip>(_onSkip);
    on<OnboardingComplete>(_onComplete);

    // Trigger the loading of first-launch status
    add(LoadOnboardingStatus());
  }

  // Load first-launch flag from repository
  Future<void> _onLoadStatus(
    LoadOnboardingStatus event,
    Emitter<OnboardingState> emit,
  ) async {
    final firstLaunch = await repository.isFirstLaunch();
    emit(state.copyWith(isFirstLaunch: firstLaunch));
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
