import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../data/auth_api.dart';
import '../data/auth_models.dart';
import 'auth_state.dart';

/// Riverpod controller driving register/login/logout against Supabase Auth.
/// The Supabase client owns the session lifecycle; this controller turns those
/// events into the UI states that the existing router and screens already use.
class AuthController extends Notifier<AuthState> {
  StreamSubscription<dynamic>? _subscription;

  /// Re-entrancy guard for [signInWithGoogle] — covers double-tap even
  /// before the button-level guard in `GoogleSignInButton` (D-08-6).
  bool _googleSignInInFlight = false;

  @override
  AuthState build() {
    final authApi = ref.read(authApiProvider);
    _subscription = authApi.authStateChanges.listen((data) {
      final event = data.event as sb.AuthChangeEvent?;
      final session = data.session as sb.Session?;

      if (event == sb.AuthChangeEvent.passwordRecovery) {
        state = const AuthRecovery();
        return;
      }

      if (session != null) {
        state = const AuthAuthenticated();
        return;
      }

      state = const AuthUnauthenticated();
    });

    ref.onDispose(() {
      _subscription?.cancel();
    });
    return authApi.currentSession == null
        ? const AuthUnauthenticated()
        : const AuthAuthenticated();
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    required Role role,
  }) async {
    state = const AuthLoading();
    try {
      final response = await ref.read(authApiProvider).register(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
      );

      state = response.requiresEmailVerification
          ? const AuthPendingVerification(
              'Check your inbox to verify your email before logging in.',
            )
          : const AuthAuthenticated();
    } on AuthApiException catch (error) {
      state = AuthError(_registerErrorMessage(error));
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AuthLoading();
    try {
      final response = await ref.read(authApiProvider).login(
        email: email,
        password: password,
      );

      if (response.signedIn) {
        state = const AuthAuthenticated();
        return;
      }

      state = const AuthError('Incorrect email or password. Try again.');
    } on AuthApiException catch (error) {
      state = AuthError(_loginErrorMessage(error));
    }
  }

  Future<void> requestPasswordReset({required String email}) async {
    await ref.read(authApiProvider).sendPasswordResetEmail(email: email);
  }

  Future<void> completePasswordReset({required String password}) async {
    state = const AuthLoading();
    try {
      await ref.read(authApiProvider).updatePassword(password: password);
      try {
        await ref.read(authApiProvider).logout();
      } catch (_) {
        // Best-effort sign-out after a successful password update.
      }
      state = const AuthUnauthenticated();
    } on AuthApiException catch (error) {
      state = AuthError(_resetErrorMessage(error));
    }
  }

  Future<void> logout() async {
    try {
      await ref.read(authApiProvider).logout();
    } finally {
      state = const AuthUnauthenticated();
    }
  }

  /// Triggers the native Google account picker. Reuses the existing
  /// [AuthLoading]/[AuthAuthenticated]/[AuthError]/[AuthUnauthenticated]
  /// states — no new [AuthState] subtype (D-08-1, unchanged by D-09-1). On a
  /// successful pick, state stays [AuthLoading] until the [authStateChanges]
  /// listener in [build] observes the real session and flips to
  /// [AuthAuthenticated].
  Future<void> signInWithGoogle() async {
    if (_googleSignInInFlight) return;
    _googleSignInInFlight = true;
    state = const AuthLoading();
    try {
      final signedIn = await ref.read(authApiProvider).signInWithGoogle();
      if (!signedIn) {
        // User cancelled the native picker before completing it — nothing
        // went wrong, nothing happened yet, so no error banner.
        state = const AuthUnauthenticated();
      }
    } on AuthApiException catch (error) {
      state = AuthError(_googleSignInErrorMessage(error));
    } finally {
      _googleSignInInFlight = false;
    }
  }

  String _registerErrorMessage(AuthApiException error) {
    return switch (error.issue) {
      AuthIssue.emailAlreadyRegistered =>
        'An account with this email already exists. Try logging in instead.',
      AuthIssue.weakPassword =>
        'Use at least 8 characters, including a mix of letters and numbers.',
      AuthIssue.network =>
        "Couldn't connect. Check your connection and try again.",
      _ => "We couldn't create the account. Please try again.",
    };
  }

  String _loginErrorMessage(AuthApiException error) {
    return switch (error.issue) {
      AuthIssue.emailNotVerified =>
        'Verify your email before logging in.',
      AuthIssue.invalidCredentials =>
        'Incorrect email or password. Try again.',
      AuthIssue.network =>
        "Couldn't connect. Check your connection and try again.",
      _ => 'We could not log you in. Please try again.',
    };
  }

  String _resetErrorMessage(AuthApiException error) {
    return switch (error.issue) {
      AuthIssue.network =>
        "Couldn't connect. Check your connection and try again.",
      _ => 'We could not update your password. Please try again.',
    };
  }

  String _googleSignInErrorMessage(AuthApiException error) {
    return switch (error.issue) {
      AuthIssue.network =>
        "Couldn't connect. Check your connection and try again.",
      _ => 'Google sign-in failed. Please try again.',
    };
  }
}

/// Riverpod provider exposing the single [AuthController] instance.
final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
