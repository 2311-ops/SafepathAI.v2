/// Auth session state driven by [AuthController].
sealed class AuthState {
  const AuthState();
}

/// Initial state before any auth check/action has run.
class AuthUnknown extends AuthState {
  const AuthUnknown();
}

/// A register/login/logout call is in flight.
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// A valid session exists — tokens are persisted in [TokenStorage].
class AuthAuthenticated extends AuthState {
  const AuthAuthenticated();
}

/// No valid session — user should see the Welcome/Login flow.
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// The last register/login attempt failed. [message] is always an
/// enumeration-safe, user-facing string from the UI-SPEC Copywriting
/// Contract — never a raw server error.
class AuthError extends AuthState {
  const AuthError(this.message);

  final String message;
}
