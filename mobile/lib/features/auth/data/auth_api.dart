import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/config/supabase_client_provider.dart';
import '../../../core/config/supabase_config.dart';
import 'auth_models.dart';

enum AuthIssue {
  network,
  emailAlreadyRegistered,
  invalidCredentials,
  emailNotVerified,
  weakPassword,

  /// The refresh token itself is invalid/expired/revoked — the session is
  /// genuinely dead and cannot be silently recovered (distinct from
  /// [network], where the existing session may still be valid and a retry
  /// could succeed once connectivity returns).
  sessionInvalid,
  unknown,
}

class AuthApiException implements Exception {
  AuthApiException(this.issue, {this.message});

  final AuthIssue issue;
  final String? message;

  @override
  String toString() => 'AuthApiException(issue: $issue, message: $message)';
}

class AuthSessionResult {
  const AuthSessionResult({
    required this.signedIn,
    this.requiresEmailVerification = false,
  });

  final bool signedIn;
  final bool requiresEmailVerification;
}

abstract class AuthApi {
  sb.Session? get currentSession;

  Stream<dynamic> get authStateChanges;

  Future<AuthSessionResult> register({
    required String email,
    required String password,
    required String fullName,
    required Role role,
  });

  Future<AuthSessionResult> login({
    required String email,
    required String password,
  });

  Future<void> logout();

  Future<void> sendPasswordResetEmail({
    required String email,
  });

  Future<void> updatePassword({
    required String password,
  });

  Future<AuthSessionResult> refreshSession();

  /// Launches Supabase's native Google OAuth flow (external browser/Custom
  /// Tab + PKCE + deep-link redirect back into the app). Returns whether the
  /// flow was launched — NOT whether sign-in succeeded; the real result
  /// arrives later via [authStateChanges] (see D-08-1/D-08-2 in
  /// `01-08-PLAN.md`).
  Future<bool> signInWithGoogle();
}

class SupabaseAuthApi implements AuthApi {
  SupabaseAuthApi(this._client);

  final sb.SupabaseClient _client;

  @override
  sb.Session? get currentSession => _client.auth.currentSession;

  @override
  Stream<dynamic> get authStateChanges => _client.auth.onAuthStateChange;

  @override
  Future<AuthSessionResult> register({
    required String email,
    required String password,
    required String fullName,
    required Role role,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'role': role.wireValue,
        },
        emailRedirectTo: supabaseRedirectUrl,
      );

      return AuthSessionResult(
        signedIn: response.session != null,
        requiresEmailVerification: response.session == null,
      );
    } on sb.AuthWeakPasswordException catch (error) {
      throw AuthApiException(AuthIssue.weakPassword, message: error.message);
    } on sb.AuthException catch (error) {
      throw AuthApiException(_issueFromMessage(error.message), message: error.message);
    } catch (error) {
      throw AuthApiException(AuthIssue.network, message: error.toString());
    }
  }

  @override
  Future<AuthSessionResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      return AuthSessionResult(signedIn: response.session != null);
    } on sb.AuthException catch (error) {
      throw AuthApiException(_issueFromMessage(error.message), message: error.message);
    } catch (error) {
      throw AuthApiException(AuthIssue.network, message: error.toString());
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _client.auth.signOut();
    } catch (error) {
      throw AuthApiException(AuthIssue.network, message: error.toString());
    }
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
  }) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: supabaseRedirectUrl,
      );
    } on sb.AuthException catch (error) {
      throw AuthApiException(_issueFromMessage(error.message), message: error.message);
    } catch (error) {
      throw AuthApiException(AuthIssue.network, message: error.toString());
    }
  }

  @override
  Future<void> updatePassword({
    required String password,
  }) async {
    try {
      await _client.auth.updateUser(
        sb.UserAttributes(password: password),
      );
    } on sb.AuthException catch (error) {
      throw AuthApiException(_issueFromMessage(error.message), message: error.message);
    } catch (error) {
      throw AuthApiException(AuthIssue.network, message: error.toString());
    }
  }

  @override
  Future<AuthSessionResult> refreshSession() async {
    try {
      final response = await _client.auth.refreshSession();
      return AuthSessionResult(signedIn: response.session != null);
    } on sb.AuthException catch (error) {
      // Supabase raises AuthException specifically when the refresh token
      // itself is rejected (invalid/expired/revoked) — the session is
      // genuinely dead. Any other failure (timeout, DNS/socket error,
      // unexpected exception) is transient: the existing session may still
      // be valid, so it must not be treated the same as a dead session.
      throw AuthApiException(AuthIssue.sessionInvalid, message: error.message);
    } catch (error) {
      throw AuthApiException(AuthIssue.network, message: error.toString());
    }
  }

  @override
  Future<bool> signInWithGoogle() async {
    try {
      return await _client.auth.signInWithOAuth(
        sb.OAuthProvider.google,
        redirectTo: supabaseRedirectUrl,
        authScreenLaunchMode: sb.LaunchMode.externalApplication,
      );
    } on sb.AuthException catch (error) {
      throw AuthApiException(AuthIssue.unknown, message: error.message);
    } catch (error) {
      throw AuthApiException(AuthIssue.network, message: error.toString());
    }
  }

  AuthIssue _issueFromMessage(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('already registered')) {
      return AuthIssue.emailAlreadyRegistered;
    }
    if (normalized.contains('invalid login credentials') ||
        normalized.contains('invalid credentials')) {
      return AuthIssue.invalidCredentials;
    }
    if (normalized.contains('email not confirmed') ||
        normalized.contains('email not verified')) {
      return AuthIssue.emailNotVerified;
    }
    return AuthIssue.unknown;
  }
}

final authApiProvider = Provider<AuthApi>(
  (ref) => SupabaseAuthApi(ref.watch(supabaseClientProvider)),
);
