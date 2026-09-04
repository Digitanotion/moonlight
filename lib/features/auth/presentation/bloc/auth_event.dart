part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => [];
}

class CheckAuthStatusEvent extends AuthEvent {}

/// Refresh the signed-in user's profile from the server **without** emitting a
/// loading state. Used for background refreshes (e.g. on app resume) so the
/// cached profile stays current without ever gating the UI behind a spinner.
/// A failure is swallowed — a background refresh never logs anyone out.
class SilentUserRefreshRequested extends AuthEvent {
  const SilentUserRefreshRequested();
}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;

  const LoginRequested({required this.email, required this.password});

  @override
  List<Object> get props => [email, password];
}

// Trigger login with email/password
class LoginWithEmailRequested extends AuthEvent {
  final String email;
  final String password;

  const LoginWithEmailRequested({required this.email, required this.password});

  @override
  List<Object> get props => [email, password];
}

class SignUpRequested extends AuthEvent {
  final String email;
  final String password;
  final String? agent_name;

  const SignUpRequested({
    required this.email,
    required this.password,
    this.agent_name,
  });

  @override
  List<Object> get props => [email, password, agent_name ?? ''];
}

class SocialLoginRequested extends AuthEvent {
  final String provider;

  const SocialLoginRequested(this.provider);

  @override
  List<Object> get props => [provider];
}

class GoogleSignInRequested extends AuthEvent {
  const GoogleSignInRequested();

  @override
  List<Object> get props => [];
}

class LogoutRequested extends AuthEvent {}

class ForgotPasswordRequested extends AuthEvent {
  final String email;

  const ForgotPasswordRequested({required this.email});

  @override
  List<Object> get props => [email];
}
