part of 'auth_bloc.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object> get props => [];
}

// Initial state when bloc is created
class AuthInitial extends AuthState {}

// Loading state for async operations
class AuthLoading extends AuthState {}

// When user is successfully authenticated
class AuthAuthenticated extends AuthState {
  final User user; // Your User entity

  const AuthAuthenticated(this.user);

  @override
  List<Object> get props => [user];
}

// When user is not authenticated
class AuthUnauthenticated extends AuthState {}

// When authentication fails
class AuthFailure extends AuthState {
  final String message;

  const AuthFailure(this.message);

  @override
  List<Object> get props => [message];
}

// Special state for registration success (if needed)
class RegistrationSuccess extends AuthState {
  final User user;

  const RegistrationSuccess(this.user);

  @override
  List<Object> get props => [user];
}
