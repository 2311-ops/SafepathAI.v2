import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/token_storage.dart';
import '../data/auth_api.dart';
import '../data/auth_models.dart';
import 'auth_state.dart';

/// Riverpod controller driving register/login/logout against [AuthApi] +
/// [TokenStorage] (D1: Riverpod, not Bloc).
///
/// Error messages are enumeration-safe, user-facing strings from the
/// UI-SPEC Copywriting Contract — the raw server error is never surfaced.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthUnknown();

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    required Role role,
  }) async {
    state = const AuthLoading();
    try {
      final response = await ref.read(authApiProvider).register(
        RegisterRequest(
          email: email,
          password: password,
          fullName: fullName,
          role: role,
        ),
      );
      await ref
          .read(tokenStorageProvider)
          .saveTokens(access: response.accessToken, refresh: response.refreshToken);
      state = const AuthAuthenticated();
    } on AuthApiException catch (e) {
      state = AuthError(_registerErrorMessage(e));
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AuthLoading();
    try {
      final response = await ref
          .read(authApiProvider)
          .login(LoginRequest(email: email, password: password));
      await ref
          .read(tokenStorageProvider)
          .saveTokens(access: response.accessToken, refresh: response.refreshToken);
      state = const AuthAuthenticated();
    } on AuthApiException catch (_) {
      // Enumeration-safe: same message for unknown-email and wrong-password
      // (T-03-01) — matches the server's own AuthResult.Invalid() behavior.
      state = const AuthError('Incorrect email or password. Try again.');
    }
  }

  Future<void> logout() async {
    final tokenStorage = ref.read(tokenStorageProvider);
    final refreshToken = await tokenStorage.readRefreshToken();
    if (refreshToken != null) {
      try {
        await ref.read(authApiProvider).logout(refreshToken);
      } on AuthApiException {
        // Best-effort server-side revoke — always clear locally regardless
        // so the user is never stuck "logged in" on this device.
      }
    }
    await tokenStorage.clear();
    state = const AuthUnauthenticated();
  }

  String _registerErrorMessage(AuthApiException e) {
    if (e.statusCode == 409 || e.statusCode == 400) {
      return 'An account with this email already exists. Try logging in instead.';
    }
    return "Couldn't connect. Check your connection and try again.";
  }
}

/// Riverpod provider exposing the single [AuthController] instance.
final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
