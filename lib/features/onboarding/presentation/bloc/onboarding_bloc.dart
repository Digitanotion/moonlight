// onboarding_bloc.dart
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/utils/asset_paths.dart';
import 'package:moonlight/features/onboarding/domain/entities/onboarding_page_entity.dart';
import 'package:moonlight/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:moonlight/features/profile_setup/domain/repositories/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'onboarding_event.dart';
part 'onboarding_state.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  final OnboardingRepository repository;

  // NOTE: ProfileRepository is deliberately NOT a constructor dependency.
  // OnboardingBloc is registered in Track 1 (sync, pre-runApp) of the
  // two-track injection system, but ProfileRepository is only registered
  // in Track 2 (async, post-runApp, inside _initFullGraph()). Taking it
  // as a constructor param made GetIt try to resolve a Track 2 dependency
  // the instant MyApp asks for OnboardingBloc — which happens well before
  // Track 2 finishes — causing a crash on every cold start.
  //
  // Instead, it's fetched lazily via GetIt.instance at the point of
  // actual use (_fetchLiveProfileCompletion), which by then only ever
  // runs after CheckFirstLaunchStatus fires from SplashScreen — and
  // SplashScreen only fires that AFTER DependencyManager confirms Track 2
  // is done. If it's somehow still unavailable, the existing try/catch
  // below just falls back to the cached value instead of crashing.
  ProfileRepository? get _profileRepository {
    try {
      return GetIt.instance<ProfileRepository>();
    } catch (_) {
      return null;
    }
  }

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

  /// Fields that must all be present for a profile to count as complete.
  /// Kept in one place so the "what counts as complete" definition can't
  /// drift between this bloc and ProfileSetupScreen's own validation.
  bool _isProfileComplete(dynamic user) {
    if (user == null) return false;
    final fullname = (user.fullname ?? '').toString().trim();
    final country = (user.country ?? '').toString().trim();
    final gender = (user.gender ?? '').toString().trim();
    final phone = (user.phone ?? '').toString().trim();
    return fullname.isNotEmpty &&
        country.isNotEmpty &&
        gender.isNotEmpty &&
        phone.isNotEmpty;
  }

  /// Fetches the authoritative profile-completion state from the server
  /// and caches it locally purely as an offline fallback — never as the
  /// thing itself being trusted. Returns null if ProfileRepository isn't
  /// available yet, the fetch fails, or it times out (e.g. no network),
  /// so the caller can fall back to the cached value in any of those
  /// cases rather than crashing or stalling app startup.
  Future<bool?> _fetchLiveProfileCompletion() async {
    final repo = _profileRepository;
    if (repo == null) {
      debugPrint('⚠️ OnboardingBloc: ProfileRepository not available yet');
      return null;
    }

    try {
      final user = await repo.fetchMyProfile().timeout(
        const Duration(seconds: 3),
      );
      final complete = _isProfileComplete(user);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasCompletedProfile', complete);

      return complete;
    } on TimeoutException {
      debugPrint('⚠️ OnboardingBloc: live profile check timed out (slow/no network)');
      return null;
    } catch (e) {
      debugPrint('⚠️ OnboardingBloc: live profile check failed: $e');
      return null; // signal "couldn't verify" — caller falls back to cache
    }
  }

  Future<void> _onLoadStatus(
    LoadOnboardingStatus event,
    Emitter<OnboardingState> emit,
  ) async {
    try {
      final firstLaunch = await repository.isFirstLaunch();

      final prefs = await SharedPreferences.getInstance();
      final cachedCompletion = prefs.getBool('hasCompletedProfile') ?? false;

      // Emit the cached value immediately so the UI isn't blocked on a
      // network round trip this early — CheckFirstLaunchStatus (fired
      // from Splash, after auth resolves) is what performs the
      // authoritative live re-check before any navigation decision
      // actually gets made.
      emit(
        state.copyWith(
          isFirstLaunch: firstLaunch,
          hasCompletedProfile: cachedCompletion,
        ),
      );

      debugPrint(
        '✅ OnboardingBloc loaded: isFirstLaunch=$firstLaunch, '
        'hasCompletedProfile(cached)=$cachedCompletion',
      );
    } catch (e) {
      debugPrint('❌ Error loading onboarding status: $e');
      emit(state.copyWith(isFirstLaunch: true, hasCompletedProfile: false));
    }
  }

  /// One-time grandfather decision, made exactly once per device/install.
  ///
  /// The first time this runs after the mandatory-fields update ships, it
  /// checks whether THIS device already had `hasCompletedProfile: true`
  /// cached from before the change — meaning the person already
  /// completed (or was let through) profile setup under the old, looser
  /// rules. If so, that device is permanently exempted: it will never be
  /// forced through the new required-fields screen, no matter what the
  /// live server profile actually contains.
  ///
  /// Devices where the old flag was false or absent (fresh installs,
  /// or someone who genuinely never finished setup) are NOT exempted —
  /// they go through the normal live-check flow below and must complete
  /// fullname/country/gender/phone like any new signup.
  ///
  /// This decision is written once and read forever after — it does
  /// NOT re-evaluate on every launch, so a legacy user who is exempted
  /// today stays exempted even if they later clear some unrelated cache
  /// key, as long as 'legacyProfileExempt' itself persists.
  Future<bool> _resolveLegacyExemption(SharedPreferences prefs) async {
    if (!prefs.containsKey('legacyProfileExempt')) {
      final hadOldFlagTrue = prefs.getBool('hasCompletedProfile') ?? false;
      await prefs.setBool('legacyProfileExempt', hadOldFlagTrue);
      debugPrint(
        '🕰️ OnboardingBloc: legacy grandfather decision made once — '
        'exempt=$hadOldFlagTrue (based on pre-existing hasCompletedProfile)',
      );
    }
    return prefs.getBool('legacyProfileExempt') ?? false;
  }

  Future<void> _onCheckFirstLaunchStatus(
    CheckFirstLaunchStatus event,
    Emitter<OnboardingState> emit,
  ) async {
    try {
      debugPrint('🔍 Splash checking: isFirstLaunch=${state.isFirstLaunch}');

      final firstLaunch = await repository.isFirstLaunch();
      final prefs = await SharedPreferences.getInstance();

      // Grandfather check FIRST — if this device is exempt, skip the
      // live server check entirely and never show the mandatory screen.
      final isExempt = await _resolveLegacyExemption(prefs);
      if (isExempt) {
        emit(
          state.copyWith(
            isFirstLaunch: firstLaunch,
            hasCompletedProfile: true,
            profileCheckResolved: true,
          ),
        );
        debugPrint(
          '✅ Splash fetched: isFirstLaunch=$firstLaunch, '
          'hasCompletedProfile=true (legacy-exempt device)',
        );
        return;
      }

      // Not exempt — this is either a genuinely new signup, or a device
      // that never had the old flag set, so the normal live-check flow
      // applies: re-derive completion from the actual server profile.
      final liveCompletion = await _fetchLiveProfileCompletion();

      bool hasCompletedProfile;
      if (liveCompletion != null) {
        hasCompletedProfile = liveCompletion;
      } else {
        hasCompletedProfile = prefs.getBool('hasCompletedProfile') ?? false;
        debugPrint(
          '⚠️ OnboardingBloc: using cached fallback hasCompletedProfile=$hasCompletedProfile',
        );
      }

      emit(
        state.copyWith(
          isFirstLaunch: firstLaunch,
          hasCompletedProfile: hasCompletedProfile,
          profileCheckResolved: true,
        ),
      );

      debugPrint(
        '✅ Splash fetched: isFirstLaunch=$firstLaunch, '
        'hasCompletedProfile(live)=$hasCompletedProfile',
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