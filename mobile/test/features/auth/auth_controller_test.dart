// Behavior under test (01-03-PLAN.md Task 1):
// - register() on success saves tokens and transitions to Authenticated.
// - register() on a duplicate-email (409/400) surfaces an "already exists"
//   error without saving tokens.
// - login() on 200 saves tokens -> Authenticated.
// - login() on 401 -> enumeration-safe error state, no tokens saved.
// - logout() clears TokenStorage and transitions to Unauthenticated.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/storage/token_storage.dart';
import 'package:mobile/features/auth/application/auth_controller.dart';
import 'package:mobile/features/auth/application/auth_state.dart';
import 'package:mobile/features/auth/data/auth_api.dart';
import 'package:mobile/features/auth/data/auth_models.dart';

/// Fake [AuthApi] — overrides every network call with in-memory behavior
/// controlled by the test, never touching a real Dio/HTTP stack.
class FakeAuthApi extends AuthApi {
  FakeAuthApi() : super(Dio());

  bool registerShouldFail = false;
  int registerFailStatusCode = 409;
  bool loginShouldFail = false;
  int loginFailStatusCode = 401;

  RegisterRequest? lastRegisterRequest;
  LoginRequest? lastLoginRequest;
  String? lastLogoutToken;

  @override
  Future<AuthResponse> register(RegisterRequest request) async {
    lastRegisterRequest = request;
    if (registerShouldFail) {
      throw AuthApiException(
        statusCode: registerFailStatusCode,
        serverMessage: 'Email already registered',
      );
    }
    return const AuthResponse(
      accessToken: 'access-register',
      refreshToken: 'refresh-register',
    );
  }

  @override
  Future<AuthResponse> login(LoginRequest request) async {
    lastLoginRequest = request;
    if (loginShouldFail) {
      throw AuthApiException(
        statusCode: loginFailStatusCode,
        serverMessage: 'Invalid email or password',
      );
    }
    return const AuthResponse(
      accessToken: 'access-login',
      refreshToken: 'refresh-login',
    );
  }

  @override
  Future<void> logout(String refreshToken) async {
    lastLogoutToken = refreshToken;
  }

  @override
  Future<AuthResponse> refresh(String refreshToken) async {
    return const AuthResponse(
      accessToken: 'access-refresh',
      refreshToken: 'refresh-refresh',
    );
  }
}

/// Fake [TokenStorage] — in-memory, never touches flutter_secure_storage.
class FakeTokenStorage extends TokenStorage {
  FakeTokenStorage();

  String? savedAccess;
  String? savedRefresh = 'seed-refresh-token';
  bool cleared = false;

  @override
  Future<void> saveTokens({required String access, required String refresh}) async {
    savedAccess = access;
    savedRefresh = refresh;
  }

  @override
  Future<String?> readAccessToken() async => savedAccess;

  @override
  Future<String?> readRefreshToken() async => savedRefresh;

  @override
  Future<void> clear() async {
    cleared = true;
    savedAccess = null;
    savedRefresh = null;
  }
}

void main() {
  late FakeAuthApi fakeApi;
  late FakeTokenStorage fakeStorage;
  late ProviderContainer container;

  setUp(() {
    fakeApi = FakeAuthApi();
    fakeStorage = FakeTokenStorage();
    container = ProviderContainer(
      overrides: [
        authApiProvider.overrideWithValue(fakeApi),
        tokenStorageProvider.overrideWithValue(fakeStorage),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('register success saves tokens and transitions to Authenticated', () async {
    await container.read(authControllerProvider.notifier).register(
      email: 'new@family.com',
      password: 'correct-horse-1',
      fullName: 'New Guardian',
      role: Role.guardian,
    );

    expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
    expect(fakeStorage.savedAccess, 'access-register');
    expect(fakeStorage.savedRefresh, 'refresh-register');
  });

  test(
    'register duplicate email surfaces an "already exists" error without '
    'saving tokens',
    () async {
      fakeApi.registerShouldFail = true;
      fakeApi.registerFailStatusCode = 409;
      fakeStorage.savedAccess = null;

      await container.read(authControllerProvider.notifier).register(
        email: 'dup@family.com',
        password: 'correct-horse-1',
        fullName: 'Dup Guardian',
        role: Role.guardian,
      );

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthError>());
      expect((state as AuthError).message, contains('already exists'));
      expect(fakeStorage.savedAccess, isNull);
    },
  );

  test('login success saves tokens and transitions to Authenticated', () async {
    await container.read(authControllerProvider.notifier).login(
      email: 'existing@family.com',
      password: 'correct-horse-1',
    );

    expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
    expect(fakeStorage.savedAccess, 'access-login');
    expect(fakeStorage.savedRefresh, 'refresh-login');
  });

  test(
    'login 401 surfaces enumeration-safe error and does not save tokens',
    () async {
      fakeApi.loginShouldFail = true;
      fakeApi.loginFailStatusCode = 401;

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
      expect(fakeStorage.savedAccess, isNull);
    },
  );

  test('logout clears TokenStorage and transitions to Unauthenticated', () async {
    fakeStorage.savedAccess = 'existing-access';
    fakeStorage.savedRefresh = 'existing-refresh';

    await container.read(authControllerProvider.notifier).logout();

    expect(fakeStorage.cleared, isTrue);
    expect(fakeApi.lastLogoutToken, 'existing-refresh');
    expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
  });
}
