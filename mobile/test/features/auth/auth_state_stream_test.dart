// Behavior under test — how AuthController reacts to every event Supabase's
// own onAuthStateChange stream can emit (auth_controller.dart's build()
// listener), independent of the imperative register()/login()/logout() paths
// already covered in auth_controller_test.dart:
// - Initial session present at boot -> Authenticated (no stream event needed).
// - Initial session absent at boot -> Unauthenticated.
// - INITIAL_SESSION event with a session (session restored after restart) -> Authenticated.
// - SIGNED_OUT event (session expired or explicit sign-out) -> Unauthenticated.
// - TOKEN_REFRESHED event with a session -> stays Authenticated.
// - PASSWORD_RECOVERY event -> AuthRecovery, regardless of prior state.
// - USER_UPDATED event with a session (e.g. email verification completing
//   while the recovery/session link is opened) -> Authenticated.
// - Multiple events in sequence transition state correctly at each step.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/application/auth_state.dart';
import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_models.dart';

class _StreamFakeAuthApi implements AuthApi {
  sb.Session? initialSession;
  final StreamController<dynamic> _controller =
      StreamController<dynamic>.broadcast();

  void emit(sb.AuthChangeEvent event, {sb.Session? session}) {
    _controller.add(sb.AuthState(event, session));
  }

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
  }) async => const AuthSessionResult(signedIn: false);

  @override
  Future<AuthSessionResult> login({
    required String email,
    required String password,
  }) async => const AuthSessionResult(signedIn: false);

  @override
  Future<void> logout() async {}

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}

  @override
  Future<void> updatePassword({required String password}) async {}

  @override
  Future<void> updateRoleMetadata(Role role) async {}

  @override
  Future<AuthSessionResult> refreshSession() async =>
      const AuthSessionResult(signedIn: false);

  @override
  Future<bool> signInWithGoogle() async => true;

  void dispose() => _controller.close();
}

sb.Session _session() => sb.Session(
  accessToken: 'fake-access-token',
  tokenType: 'bearer',
  user: sb.User(
    id: 'fake-user-id',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: DateTime.now().toIso8601String(),
  ),
);

void main() {
  late _StreamFakeAuthApi fakeApi;
  late ProviderContainer container;

  setUp(() {
    fakeApi = _StreamFakeAuthApi();
  });

  tearDown(() {
    container.dispose();
    fakeApi.dispose();
  });

  ProviderContainer buildContainer() {
    container = ProviderContainer(
      overrides: [authApiProvider.overrideWithValue(fakeApi)],
    );
    // Force build() to run and subscribe to the stream.
    container.read(authControllerProvider);
    return container;
  }

  test('a session already present at boot starts Authenticated', () {
    fakeApi.initialSession = _session();
    buildContainer();

    expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
  });

  test('no session at boot starts Unauthenticated', () {
    buildContainer();

    expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
  });

  test(
    'INITIAL_SESSION with a session (restored after restart) -> Authenticated',
    () async {
      buildContainer();
      fakeApi.emit(sb.AuthChangeEvent.initialSession, session: _session());
      await Future<void>.delayed(Duration.zero);

      expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
    },
  );

  test(
    'SIGNED_OUT (explicit sign-out or expired session) -> Unauthenticated',
    () async {
      fakeApi.initialSession = _session();
      buildContainer();
      expect(container.read(authControllerProvider), isA<AuthAuthenticated>());

      fakeApi.emit(sb.AuthChangeEvent.signedOut);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(authControllerProvider),
        isA<AuthUnauthenticated>(),
      );
    },
  );

  test('TOKEN_REFRESHED with a session keeps the user Authenticated', () async {
    fakeApi.initialSession = _session();
    buildContainer();

    fakeApi.emit(sb.AuthChangeEvent.tokenRefreshed, session: _session());
    await Future<void>.delayed(Duration.zero);

    expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
  });

  test(
    'PASSWORD_RECOVERY moves to AuthRecovery from any prior state',
    () async {
      buildContainer();

      fakeApi.emit(sb.AuthChangeEvent.passwordRecovery, session: _session());
      await Future<void>.delayed(Duration.zero);

      expect(container.read(authControllerProvider), isA<AuthRecovery>());
    },
  );

  test(
    'USER_UPDATED with a session (e.g. email verification completing) -> Authenticated',
    () async {
      buildContainer();
      expect(
        container.read(authControllerProvider),
        isA<AuthUnauthenticated>(),
      );

      fakeApi.emit(sb.AuthChangeEvent.userUpdated, session: _session());
      await Future<void>.delayed(Duration.zero);

      expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
    },
  );

  test(
    'a sequence of events transitions state correctly at each step',
    () async {
      buildContainer();
      expect(
        container.read(authControllerProvider),
        isA<AuthUnauthenticated>(),
      );

      fakeApi.emit(sb.AuthChangeEvent.signedIn, session: _session());
      await Future<void>.delayed(Duration.zero);
      expect(container.read(authControllerProvider), isA<AuthAuthenticated>());

      fakeApi.emit(sb.AuthChangeEvent.passwordRecovery, session: _session());
      await Future<void>.delayed(Duration.zero);
      expect(container.read(authControllerProvider), isA<AuthRecovery>());

      fakeApi.emit(sb.AuthChangeEvent.signedOut);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(authControllerProvider),
        isA<AuthUnauthenticated>(),
      );
    },
  );
}
