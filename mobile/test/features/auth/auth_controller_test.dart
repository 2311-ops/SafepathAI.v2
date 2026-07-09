// Behavior under test:
// - register() on success transitions to Authenticated when Supabase returns a session.
// - register() when email verification is required transitions to PendingVerification.
// - login() on success transitions to Authenticated.
// - login() on failure surfaces an enumeration-safe error state.
// - logout() transitions to Unauthenticated.
// - signInWithGoogle() success + a later authStateChanges session event
//   transitions to Authenticated (01-09-PLAN.md D-09-1/D-09-3, native
//   picker + signInWithIdToken, supersedes 01-08's browser flow).
// - signInWithGoogle() returning false (cancelled before completing the
//   native picker) transitions to Unauthenticated with no error banner.
// - signInWithGoogle() throwing AuthApiException(network) surfaces AuthError.
// - signInWithGoogle() re-entrancy: calling it twice while the first call's
//   Future is still pending only invokes the fake once.
//
// Note: 01-08's lifecycle-resume cancellation-recovery test is intentionally
// removed here — google_sign_in's authenticate() is synchronously awaitable
// end-to-end (cancellation resolves the same await, no stuck-loading state
// possible), so AuthController's WidgetsBindingObserver-based recovery
// (D-08-6) is dead code after 01-09 and was deleted (D-09-4).

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/application/auth_state.dart';
import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_models.dart';

class FakeAuthApi implements AuthApi {
  FakeAuthApi();

  bool registerShouldRequireVerification = false;
  bool registerShouldFail = false;
  bool loginShouldFail = false;
  bool logoutCalled = false;
  bool updatePasswordCalled = false;
  bool requestPasswordResetCalled = false;
  String? lastResetEmail;
  String? lastUpdatedPassword;
  String? lastLoginEmail;
  String? lastLoginPassword;

  /// Whether [signInWithGoogle] completes successfully (returns `true`) or
  /// the user cancels the native picker before completing it (returns
  /// `false`).
  bool googleSignInShouldLaunch = true;

  /// When set, [signInWithGoogle] throws instead of returning.
  bool googleSignInShouldFail = false;
  AuthIssue googleSignInIssue = AuthIssue.network;

  /// Number of times [signInWithGoogle] has actually been invoked — used to
  /// assert the controller's re-entrancy guard only lets one call through.
  int googleSignInCallCount = 0;

  /// Settable so tests can simulate an already-restored Supabase session at
  /// controller build time.
  sb.Session? sessionOverride;

  final StreamController<dynamic> _controller = StreamController<dynamic>.broadcast();

  @override
  sb.Session? get currentSession => sessionOverride;

  @override
  Stream<dynamic> get authStateChanges => _controller.stream;

  @override
  Future<AuthSessionResult> register({
    required String email,
    required String password,
    required String fullName,
    required Role role,
  }) async {
    if (registerShouldFail) {
      throw AuthApiException(
        AuthIssue.emailAlreadyRegistered,
        message: 'User already registered',
      );
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
    lastLoginEmail = email;
    lastLoginPassword = password;

    if (loginShouldFail) {
      throw AuthApiException(
        AuthIssue.invalidCredentials,
        message: 'Invalid login credentials',
      );
    }

    return const AuthSessionResult(signedIn: true);
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    requestPasswordResetCalled = true;
    lastResetEmail = email;
  }

  @override
  Future<void> updatePassword({required String password}) async {
    updatePasswordCalled = true;
    lastUpdatedPassword = password;
  }

  @override
  Future<AuthSessionResult> refreshSession() async {
    return const AuthSessionResult(signedIn: true);
  }

  @override
  Future<bool> signInWithGoogle() async {
    googleSignInCallCount++;

    if (googleSignInShouldFail) {
      throw AuthApiException(googleSignInIssue, message: 'google sign-in failed');
    }

    return googleSignInShouldLaunch;
  }

  /// Pushes a SIGNED_IN event with [session] (defaulting to a fake session)
  /// onto [authStateChanges] — simulates Supabase completing the OAuth
  /// token exchange after the app is redirected back into via deep link.
  void emitSession([sb.Session? session]) {
    _controller.add(
      sb.AuthState(
        sb.AuthChangeEvent.signedIn,
        session ??
            sb.Session(
              accessToken: 'fake-google-token',
              tokenType: 'bearer',
              user: sb.User(
                id: 'fake-google-user-id',
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

void main() {
  late FakeAuthApi fakeApi;
  late ProviderContainer container;

  setUp(() {
    fakeApi = FakeAuthApi();
    container = ProviderContainer(
      overrides: [
        authApiProvider.overrideWithValue(fakeApi),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    fakeApi.dispose();
  });

  test(
    'register success saves the authenticated state when Supabase returns a session',
    () async {
      await container.read(authControllerProvider.notifier).register(
            email: 'new@family.com',
            password: 'correct-horse-1',
            fullName: 'New Guardian',
            role: Role.guardian,
          );

      expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
    },
  );

  test(
    'register can surface pending email verification when Supabase requires confirm email',
    () async {
      fakeApi.registerShouldRequireVerification = true;

      await container.read(authControllerProvider.notifier).register(
            email: 'pending@family.com',
            password: 'correct-horse-1',
            fullName: 'Pending Guardian',
            role: Role.guardian,
          );

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthPendingVerification>());
      expect(
        (state as AuthPendingVerification).message,
        contains('verify your email'),
      );
    },
  );

  test(
    'register duplicate email surfaces an "already exists" error without signing in',
    () async {
      fakeApi.registerShouldFail = true;

      await container.read(authControllerProvider.notifier).register(
            email: 'dup@family.com',
            password: 'correct-horse-1',
            fullName: 'Dup Guardian',
            role: Role.guardian,
          );

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthError>());
      expect((state as AuthError).message, contains('already exists'));
    },
  );

  test('login success saves the authenticated state', () async {
    await container.read(authControllerProvider.notifier).login(
          email: 'existing@family.com',
          password: 'correct-horse-1',
        );

    expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
    expect(fakeApi.lastLoginEmail, 'existing@family.com');
    expect(fakeApi.lastLoginPassword, 'correct-horse-1');
  });

  test(
    'login failure surfaces an enumeration-safe error and does not authenticate',
    () async {
      fakeApi.loginShouldFail = true;

      await container.read(authControllerProvider.notifier).login(
            email: 'existing@family.com',
            password: 'wrong-password',
          );

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthError>());
      expect(
        (state as AuthError).message,
        'Incorrect email or password. Try again.',
      );
    },
  );

  test('logout transitions to Unauthenticated', () async {
    await container.read(authControllerProvider.notifier).logout();

    expect(fakeApi.logoutCalled, isTrue);
    expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
  });

  test(
    'signInWithGoogle success + a later session event transitions to Authenticated',
    () async {
      await container.read(authControllerProvider.notifier).signInWithGoogle();

      // Sign-in succeeded — state stays Loading until the real session event
      // arrives via authStateChanges (D-09-1/D-09-3), never set directly.
      expect(container.read(authControllerProvider), isA<AuthLoading>());

      fakeApi.emitSession();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
    },
  );

  test(
    'signInWithGoogle cancellation transitions to Unauthenticated with no error',
    () async {
      fakeApi.googleSignInShouldLaunch = false;

      await container.read(authControllerProvider.notifier).signInWithGoogle();

      expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
    },
  );

  test(
    'signInWithGoogle network failure surfaces the enumeration-safe network error',
    () async {
      fakeApi.googleSignInShouldFail = true;
      fakeApi.googleSignInIssue = AuthIssue.network;

      await container.read(authControllerProvider.notifier).signInWithGoogle();

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthError>());
      expect(
        (state as AuthError).message,
        "Couldn't connect. Check your connection and try again.",
      );
    },
  );

  test(
    'signInWithGoogle re-entrancy guard only invokes the API once while a call is pending',
    () async {
      final notifier = container.read(authControllerProvider.notifier);

      final first = notifier.signInWithGoogle();
      final second = notifier.signInWithGoogle();

      await first;
      await second;

      expect(fakeApi.googleSignInCallCount, 1);
    },
  );
}
