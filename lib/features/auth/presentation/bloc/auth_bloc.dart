import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/config/runtime_config.dart';
import 'package:moonlight/core/errors/failures.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/services/current_user_service.dart';
import 'package:moonlight/core/services/unread_badge_service.dart';
import 'package:moonlight/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:moonlight/features/auth/domain/entities/user_entity.dart';
import 'package:moonlight/features/auth/domain/repositories/auth_repository.dart';
import 'package:moonlight/features/auth/domain/usecases/check_auth_status.dart'
    hide Logout;
import 'package:moonlight/features/auth/domain/usecases/get_current_user.dart';
import 'package:moonlight/features/auth/domain/usecases/login_with_email.dart';
import 'package:moonlight/features/auth/domain/usecases/logout.dart';
import 'package:moonlight/features/auth/domain/usecases/sign_up_with_email.dart';
import 'package:moonlight/features/auth/domain/usecases/social_login.dart';

// Import the TokenRegistrationService
import 'package:moonlight/core/services/token_registration_service.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginWithEmail loginWithEmail;
  final SignUpWithEmail signUpWithEmail;
  final SocialLogin socialLogin;
  final CheckAuthStatus checkAuthStatusUseCase;
  final Logout logout;
  final GetCurrentUser getCurrentUser;
  final AuthRepository authRepository;
  final CurrentUserService currentUserService;
  final TokenRegistrationService tokenRegistrationService;

  AuthBloc({
    required this.loginWithEmail,
    required this.signUpWithEmail,
    required this.socialLogin,
    required this.checkAuthStatusUseCase,
    required this.logout,
    required this.getCurrentUser,
    required this.authRepository,
    required this.currentUserService,
    required this.tokenRegistrationService,
  }) : super(AuthInitial()) {
    on<CheckAuthStatusEvent>(_onCheckAuthStatus);
    on<LoginRequested>(_onLoginRequested);
    on<LoginWithEmailRequested>(_onLoginWithEmailRequested);
    on<SignUpRequested>(_onSignUpRequested);
    on<SocialLoginRequested>(_onSocialLoginRequested);
    on<GoogleSignInRequested>(_onGoogleSignInRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<ForgotPasswordRequested>(_onForgotPasswordRequested);
  }

  // ---------------------------
  // Handlers
  // ---------------------------

  Future<void> _onCheckAuthStatus(
    CheckAuthStatusEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await checkAuthStatusUseCase();
    await result.fold((failure) async => emit(AuthFailure(failure.message)), (
      isLoggedIn,
    ) async {
      if (isLoggedIn) {
        final userResult = await getCurrentUser();
        userResult.fold((failure) => emit(AuthFailure(failure.message)), (
          user,
        ) async {
          currentUserService.setUser(user); // Sync with service

          // ✅ Trigger token registration after successful auth check
          _triggerTokenRegistration();

          emit(AuthAuthenticated(user));
        });
      } else {
        currentUserService.clearUser();
        emit(AuthUnauthenticated());
      }
    });
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading(loadingType: 'email'));

    final result = await loginWithEmail(
      email: event.email,
      password: event.password,
    );

    result.fold((failure) => emit(AuthFailure(failure.message)), (user) async {
      currentUserService.setUser(user); // Sync with service

      // ✅ Trigger token registration after successful login
      _triggerTokenRegistration();

      emit(AuthAuthenticated(user));
    });
  }

  Future<void> _onLoginWithEmailRequested(
    LoginWithEmailRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading(loadingType: 'email'));

    final result = await authRepository.loginWithEmail(
      event.email,
      event.password,
    );

    result.fold((failure) => emit(AuthFailure(failure.message)), (user) async {
      currentUserService.setUser(user); // Sync with service

      // ✅ Trigger token registration after successful login
      _triggerTokenRegistration();

      emit(AuthAuthenticated(user));
    });
  }

  Future<void> _onSignUpRequested(
    SignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading(loadingType: 'register'));

    final result = await signUpWithEmail(
      email: event.email,
      password: event.password,
      agent_name: event.agent_name,
    );

    result.fold((failure) => emit(AuthFailure(failure.message)), (user) {
      // For registration, don't automatically trigger token registration
      // User needs to verify email first
      emit(RegistrationSuccess(user));
    });
  }

  Future<void> _onSocialLoginRequested(
    SocialLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading(loadingType: 'social'));

    final result = await socialLogin(event.provider);

    result.fold((failure) => emit(AuthFailure(failure.message)), (user) async {
      currentUserService.setUser(user); // Sync with service

      // ✅ Trigger token registration after successful social login
      _triggerTokenRegistration();

      emit(AuthAuthenticated(user));
    });
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading(loadingType: 'logout'));

    try {
      // 1. Clean up unread service first
      try {
        final unreadService = GetIt.instance<UnreadBadgeService>();
        await unreadService.disconnect();
        debugPrint('✅ UnreadBadgeService cleaned up on logout');
      } catch (e) {
        debugPrint('⚠️ Error cleaning up unread service: $e');
      }

      // 2. Clear FCM tokens using the injected service
      try {
        await tokenRegistrationService.clearFcmData();
        debugPrint('✅ FCM tokens cleared on logout');
      } catch (e) {
        debugPrint('⚠️ Error clearing FCM data: $e');
      }

      // 3. Perform the actual logout
      final result = await logout();

      result.fold((failure) => emit(AuthFailure(failure.message)), (_) {
        // 4. Clear services and emit unauthenticated state
        currentUserService.clearUser();
        emit(AuthUnauthenticated());
      });
    } catch (e) {
      debugPrint('❌ Unexpected error during logout: $e');
      emit(AuthFailure('Logout failed: ${e.toString()}'));
    }
  }

  /// Trigger token registration in background without blocking UI
  void _triggerTokenRegistration() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // Wait a moment for auth token to be stored
        await Future.delayed(const Duration(milliseconds: 500));

        final success = await tokenRegistrationService.registerTokenManually();

        if (success) {
          debugPrint('✅ Token registered successfully after login');
        } else {
          debugPrint(
            '⚠️ Token registration failed or deferred (no auth token yet)',
          );
          // Schedule retry in 5 seconds
          Future.delayed(const Duration(seconds: 5), () async {
            await tokenRegistrationService.registerTokenManually();
          });
        }
      } catch (e) {
        debugPrint('❌ Error triggering token registration: $e');
      }
    });
  }

  Future<void> _onGoogleSignInRequested(
    GoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading(loadingType: 'google'));
    // debugPrint('Google sign-in requested');
    final result = await authRepository.loginWithGoogle();
    // debugPrint('Google sign-in result: $result');
    result.fold((failure) => emit(AuthFailure(failure.message)), (user) async {
      currentUserService.setUser(user); // Sync with service

      // ✅ Trigger token registration after successful Google login
      _triggerTokenRegistration();

      emit(AuthAuthenticated(user));
    });
  }

  Future<void> _onForgotPasswordRequested(
    ForgotPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading(loadingType: 'forgot_password'));

    final result = await authRepository.forgotPassword(event.email);

    result.fold(
      (failure) => emit(AuthFailure(failure.message)),
      (message) => emit(AuthForgotPasswordSuccess(message)),
    );
  }
}
