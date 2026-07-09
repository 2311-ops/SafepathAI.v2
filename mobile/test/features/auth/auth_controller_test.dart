// Behavior under test:
// - register() on success transitions to Authenticated when Supabase returns a session.
// - register() when email verification is required transitions to PendingVerification.
// - login() on success transitions to Authenticated.
// - login() on failure surfaces an enumeration-safe error state.
// - logout() transitions to Unauthenticated.

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

  final StreamController<dynamic> _controller = StreamController<dynamic>.broadcast();

  @override
  sb.Session? get currentSession => null;

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
}
