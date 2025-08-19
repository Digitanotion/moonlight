part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => [];
}

// Triggered when app checks if user is authenticated
class CheckAuthStatusEvent extends AuthEvent {}

// Triggered when user attempts email/password login
// For login (only needs email and password)
class LoginRequested extends AuthEvent {
  final String email;
  final String password;

  const LoginRequested({required this.email, required this.password});

  @override
  List<Object> get props => [email, password];
}

// Triggered when user attempts registration
class SignUpRequested extends AuthEvent {
  final String email;
  final String password;
  final String? name; // Make name optional

  const SignUpRequested({
    required this.email,
    required this.password,
    this.name, // Mark as optional parameter
  });

  @override
  List<Object> get props => [email, password, name ?? ''];
}

// Triggered when user attempts social login
class SocialLoginRequested extends AuthEvent {
  final String provider; // 'google', 'apple', 'facebook'

  const SocialLoginRequested(this.provider);

  @override
  List<Object> get props => [provider];
}

// Triggered when user logs out
class LogoutRequested extends AuthEvent {}
