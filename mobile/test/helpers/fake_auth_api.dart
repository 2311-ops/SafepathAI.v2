// Shared configurable fake for [AuthApi], used across the auth-flow test
// suite (register/role-select/login/check-email/router navigation tests).
// Mirrors the fakes already hand-written per-file in auth_controller_test.dart
// and widget_test.dart but exposes every knob those tests needed plus
// call-count tracking (for the "no duplicate submissions" tests).

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_models.dart';

class FakeAuthApi implements AuthApi {
  FakeAuthApi({this.initialSession});

  /// Set to a non-null value to simulate an already-restored Supabase
  /// session at app boot (session-persistence tests).
  sb.Session? initialSession;

  bool registerShouldRequireVerification = false;
  bool registerShouldFail = false;
  AuthIssue registerFailureIssue = AuthIssue.emailAlreadyRegistered;
  bool loginShouldFail = false;
  AuthIssue loginFailureIssue = AuthIssue.invalidCredentials;

  bool resetShouldFail = false;
  bool updatePasswordShouldFail = false;

  int registerCallCount = 0;
  int loginCallCount = 0;
  int resetCallCount = 0;
  int updatePasswordCallCount = 0;
  bool logoutCalled = false;

  String? lastRegisterEmail;
  String? lastRegisterFullName;
  Role? lastRegisterRole;
  String? lastLoginEmail;
  String? lastLoginPassword;
  String? lastResetEmail;
  String? lastUpdatedPassword;

  /// Optional artificial delay so tests can observe the loading state before
  /// the future resolves (e.g. to assert a button is disabled mid-flight).
  Duration responseDelay = Duration.zero;

  final StreamController<dynamic> _controller =
      StreamController<dynamic>.broadcast();

  @override
  sb.Session? get currentSession => initialSession;

  @override
  Stream<dynamic> get authStateChanges => _controller.stream;

  @override
  Future<AuthSessionResult> register({
    required String email,
    required String password,
    required String fullName,
    required Role role,
  }) async {
    registerCallCount++;
    lastRegisterEmail = email;
    lastRegisterFullName = fullName;
    lastRegisterRole = role;

    if (responseDelay > Duration.zero) await Future.delayed(responseDelay);

    if (registerShouldFail) {
      throw AuthApiException(registerFailureIssue, message: 'register failed');
    }

    return AuthSessionResult(
      signedIn: !registerShouldRequireVerification,
      requiresEmailVerification: registerShouldRequireVerification,
    );
  }

  @override
  Future<AuthSessionResult> login({
    required String email,
    required String password,
  }) async {
    loginCallCount++;
    lastLoginEmail = email;
    lastLoginPassword = password;

    if (responseDelay > Duration.zero) await Future.delayed(responseDelay);

    if (loginShouldFail) {
      throw AuthApiException(loginFailureIssue, message: 'login failed');
    }

    return const AuthSessionResult(signedIn: true);
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    resetCallCount++;
    lastResetEmail = email;

    if (responseDelay > Duration.zero) await Future.delayed(responseDelay);

    if (resetShouldFail) {
      throw AuthApiException(AuthIssue.network, message: 'reset failed');
    }
  }

  @override
  Future<void> updatePassword({required String password}) async {
    updatePasswordCallCount++;
    lastUpdatedPassword = password;

    if (responseDelay > Duration.zero) await Future.delayed(responseDelay);

    if (updatePasswordShouldFail) {
      throw AuthApiException(AuthIssue.network, message: 'update password failed');
    }
  }

  @override
  Future<AuthSessionResult> refreshSession() async {
    return const AuthSessionResult(signedIn: true);
  }

  /// Pushes a PASSWORD_RECOVERY event onto [authStateChanges], the same event
  /// Supabase emits when a user opens a password-reset deep link — drives
  /// AuthController into AuthRecovery so reset_password_screen tests can
  /// exercise the "recovery session active" path.
  void emitPasswordRecovery() {
    _controller.add(
      sb.AuthState(
        sb.AuthChangeEvent.passwordRecovery,
        sb.Session(
          accessToken: 'fake-recovery-token',
          tokenType: 'bearer',
          user: sb.User(
            id: 'fake-user-id',
            appMetadata: const {},
            userMetadata: const {},
            aud: 'authenticated',
            createdAt: DateTime.now().toIso8601String(),
          ),
        ),
      ),
    );
  }

  /// Pushes a SIGNED_IN event with a session onto [authStateChanges] — the
  /// event Supabase emits once a user completes email verification and the
  /// client picks up the resulting session (e.g. via a deep link back into
  /// the app), driving AuthController into AuthAuthenticated.
  void emitSignedIn() {
    _controller.add(
      sb.AuthState(
        sb.AuthChangeEvent.signedIn,
        sb.Session(
          accessToken: 'fake-verified-token',
          tokenType: 'bearer',
          user: sb.User(
            id: 'fake-user-id',
            appMetadata: const {},
            userMetadata: const {},
            aud: 'authenticated',
            createdAt: DateTime.now().toIso8601String(),
          ),
        ),
      ),
    );
  }

  void dispose() {
    _controller.close();
  }
}
