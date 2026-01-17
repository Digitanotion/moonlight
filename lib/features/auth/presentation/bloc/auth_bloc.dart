import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:moonlight/core/errors/failures.dart';
import 'package:moonlight/core/services/current_user_service.dart';
import 'package:moonlight/core/services/unread_badge_service.dart';
import 'package:moonlight/features/auth/domain/entities/user_entity.dart';
import 'package:moonlight/features/auth/domain/repositories/auth_repository.dart';
import 'package:moonlight/features/auth/domain/usecases/check_auth_status.dart'
    hide Logout;
import 'package:moonlight/features/auth/domain/usecases/get_current_user.dart';
import 'package:moonlight/features/auth/domain/usecases/login_with_email.dart';
import 'package:moonlight/features/auth/domain/usecases/logout.dart';
import 'package:moonlight/features/auth/domain/usecases/sign_up_with_email.dart';
import 'package:moonlight/features/auth/domain/usecases/social_login.dart';

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

  AuthBloc({
    required this.loginWithEmail,
    required this.signUpWithEmail,
    required this.socialLogin,
    required this.checkAuthStatusUseCase,
    required this.logout,
    required this.getCurrentUser,
    required this.authRepository,
    required this.currentUserService,
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
        ) {
          currentUserService.setUser(user); // Sync with service
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
    emit(AuthLoading());

    final result = await loginWithEmail(
      email: event.email,
      password: event.password,
    );

    result.fold((failure) => emit(AuthFailure(failure.message)), (user) {
      currentUserService.setUser(user); // Sync with service
      emit(AuthAuthenticated(user));
    });
  }

  Future<void> _onLoginWithEmailRequested(
    LoginWithEmailRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await authRepository.loginWithEmail(
      event.email,
      event.password,
    );

    result.fold((failure) => emit(AuthFailure(failure.message)), (user) {
      currentUserService.setUser(user); // Sync with service
      emit(AuthAuthenticated(user));
    });
  }

  Future<void> _onSignUpRequested(
    SignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await signUpWithEmail(
      email: event.email,
      password: event.password,
      agent_name: event.agent_name,
    );

    result.fold(
      (failure) => emit(AuthFailure(failure.message)),
      (user) => emit(RegistrationSuccess(user)),
    );
  }

  Future<void> _onSocialLoginRequested(
    SocialLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await socialLogin(event.provider);

    result.fold((failure) => emit(AuthFailure(failure.message)), (user) {
      currentUserService.setUser(user); // Sync with service
      emit(AuthAuthenticated(user));
    });
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      // 1. Clean up unread service first
      try {
        final unreadService = GetIt.instance<UnreadBadgeService>();
        await unreadService.disconnect();
        debugPrint('✅ UnreadBadgeService cleaned up on logout');
      } catch (e) {
        debugPrint('⚠️ Error cleaning up unread service: $e');
        // Continue with logout even if cleanup fails
      }

      // 2. Perform the actual logout
      final result = await logout();

      result.fold((failure) => emit(AuthFailure(failure.message)), (_) {
        // 3. Clear services and emit unauthenticated state
        currentUserService.clearUser();
        emit(AuthUnauthenticated());
      });
    } catch (e) {
      debugPrint('❌ Unexpected error during logout: $e');
      emit(AuthFailure('Logout failed: ${e.toString()}'));
    }
  }

  Future<void> _onGoogleSignInRequested(
    GoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await authRepository.loginWithGoogle();

    result.fold(
      (failure) => emit(AuthFailure(failure.message)),
      (user) => emit(AuthAuthenticated(user)),
    );
  }

  Future<void> _onForgotPasswordRequested(
    ForgotPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await authRepository.forgotPassword(event.email);

    result.fold(
      (failure) => emit(AuthFailure(failure.message)),
      (message) => emit(AuthForgotPasswordSuccess(message)),
    );
  }
}
