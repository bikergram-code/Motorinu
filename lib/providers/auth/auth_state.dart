import '../../domain/models/user.dart';

/// Represents the authentication state of the app.
sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class Authenticated extends AuthState {
  const Authenticated(this.user);
  final User user;
}

class Unauthenticated extends AuthState {
  const Unauthenticated([this.message]);
  final String? message;
}

class AuthError extends AuthState {
  const AuthError(this.message);
  final String message;
}
