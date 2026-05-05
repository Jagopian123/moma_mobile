import '../models/user_model.dart';

enum AuthStatus { unknown, authenticated, unauthenticated, loading, error }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;

  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
  });

  const AuthState.unknown()
      : status = AuthStatus.unknown,
        user = null,
        errorMessage = null;

  const AuthState.loading()
      : status = AuthStatus.loading,
        user = null,
        errorMessage = null;

  const AuthState.authenticated(UserModel user)
      : status = AuthStatus.authenticated,
        user = user,
        errorMessage = null;

  const AuthState.unauthenticated()
      : status = AuthStatus.unauthenticated,
        user = null,
        errorMessage = null;

  const AuthState.error(String message)
      : status = AuthStatus.error,
        user = null,
        errorMessage = message;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
  bool get isUnknown => status == AuthStatus.unknown;
}
