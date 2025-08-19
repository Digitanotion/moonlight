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
    _loadFirstLaunchStatus();
    on<OnboardingPageChanged>(_onPageChanged);
    on<OnboardingSkip>(_onSkip);
    on<OnboardingComplete>(_onComplete);
  }
  void _loadFirstLaunchStatus() async {
    final firstLaunch = await repository.isFirstLaunch();
    emit(state.copyWith(isFirstLaunch: firstLaunch));
  }

  void _onPageChanged(
    OnboardingPageChanged event,
    Emitter<OnboardingState> emit,
  ) {
    emit(state.copyWith(currentPage: event.pageIndex));
  }

  void _onSkip(OnboardingSkip event, Emitter<OnboardingState> emit) async {
    await repository.setOnboardingCompleted();
    emit(state.copyWith(isFirstLaunch: false));
  }

  void _onComplete(
    OnboardingComplete event,
    Emitter<OnboardingState> emit,
  ) async {
    await repository.setOnboardingCompleted();
    emit(state.copyWith(isFirstLaunch: false));
  }
}
