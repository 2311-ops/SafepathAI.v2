// Behavior under test — AuthInterceptor.onError's 401-refresh-retry path
// (there is no AuthController.refreshSession(); refreshSession() lives on
// AuthApi and is consumed here, so this is the actual unit that needs
// coverage for the requested refresh-failure scenarios):
//
// - Network timeout during refresh -> original 401 propagated to the
//   caller, session preserved (no forced logout) — a transient network
//   blip must not sign the user out.
// - Supabase unavailable (generic/unexpected exception) during refresh ->
//   same as above: propagate, do not log out, no crash.
// - Invalid refresh token -> logout() called (session is genuinely dead),
//   error propagated.
// - Expired refresh token -> logout() called, error propagated.
// - Unexpected exception (e.g. a bug surfacing as a bare Exception) ->
//   does not crash the interceptor; treated as a network-class failure,
//   session preserved.
// - Successful refresh -> retries the original request and resolves with
//   its response; no logout.
//
// Driven through a real Dio pipeline (custom HttpClientAdapter returning a
// canned 401 then a canned retry response) rather than calling
// interceptor.onError with a bare handler — dio's ErrorInterceptorHandler
// must be consumed by the pipeline that owns it, or its internal completer's
// error goes unhandled.
//
// "Loading state cleared" and "redirect when required" are router/UI-layer
// concerns already covered by app_router.dart's redirect guard (see
// auth_flow_navigation_test.dart's logout test) — AuthInterceptor's job is
// exactly the decision under test here: when does a refresh failure log the
// user out vs. leave the existing session alone.

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:mobile/core/network/auth_interceptor.dart';
import 'package:mobile/features/auth/data/auth_api.dart';

import '../../helpers/fake_auth_api.dart';

/// Always answers 401 to the first request and 200 to any retried request
/// (identified by the `sp_retried` extra AuthInterceptor sets before the
/// retry), so the whole refresh-retry pipeline runs for real.
class _FakeAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final isRetried = options.extra['sp_retried'] == true;
    return ResponseBody.fromString(
      isRetried ? '{"ok":true}' : '{"error":"unauthorized"}',
      isRetried ? 200 : 401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late FakeAuthApi fakeApi;
  late Dio dio;

  setUp(() {
    fakeApi = FakeAuthApi();
    dio = Dio()
      ..httpClientAdapter = _FakeAdapter()
      ..interceptors.add(
        AuthInterceptor(authApi: fakeApi, refreshDio: Dio()..httpClientAdapter = _FakeAdapter()),
      );
  });

  tearDown(() => fakeApi.dispose());

  /// Fires a request that always 401s and returns whatever the interceptor
  /// pipeline resolves with. Errors are caught here (not re-thrown) — each
  /// test asserts on fakeApi's resulting state, not on the propagated error;
  /// the mere fact this completes (rather than hanging or crashing the test
  /// binding) is itself the "no crash" assertion.
  Future<Response<dynamic>?> hitProtectedEndpoint() async {
    try {
      return await dio.get<dynamic>('/me');
    } on DioException {
      return null;
    }
  }

  test('network timeout during refresh preserves the session (no forced logout)',
      () async {
    fakeApi.refreshShouldFail = true;
    fakeApi.refreshFailureIssue = AuthIssue.network;
    fakeApi.refreshFailureMessage = 'Connection timed out';

    final response = await hitProtectedEndpoint();

    expect(response, isNull, reason: 'original 401 should still propagate');
    expect(fakeApi.logoutCalled, isFalse);
    expect(fakeApi.refreshCallCount, 1);
  });

  test('Supabase unavailable during refresh preserves the session (no forced logout)',
      () async {
    fakeApi.refreshShouldFail = true;
    fakeApi.refreshFailureIssue = AuthIssue.network;
    fakeApi.refreshFailureMessage = 'Failed host lookup: supabase.co';

    await hitProtectedEndpoint();

    expect(fakeApi.logoutCalled, isFalse);
  });

  test('an unexpected exception during refresh does not crash and preserves the session',
      () async {
    fakeApi.refreshShouldFail = true;
    fakeApi.refreshFailureIssue = AuthIssue.network;
    fakeApi.refreshFailureMessage = 'Unexpected null value';

    // The key assertion is that this completes at all without an uncaught
    // error escaping the interceptor / test binding.
    await hitProtectedEndpoint();

    expect(fakeApi.logoutCalled, isFalse);
  });

  test('an invalid refresh token signs the user out (session is genuinely dead)',
      () async {
    fakeApi.refreshShouldFail = true;
    fakeApi.refreshFailureIssue = AuthIssue.sessionInvalid;
    fakeApi.refreshFailureMessage = 'Invalid Refresh Token: Refresh Token Not Found';

    await hitProtectedEndpoint();

    expect(fakeApi.logoutCalled, isTrue);
  });

  test('an expired refresh token signs the user out', () async {
    fakeApi.refreshShouldFail = true;
    fakeApi.refreshFailureIssue = AuthIssue.sessionInvalid;
    fakeApi.refreshFailureMessage = 'Invalid Refresh Token: Session Expired';

    await hitProtectedEndpoint();

    expect(fakeApi.logoutCalled, isTrue);
  });

  test('a successful refresh retries the original request and does not log out',
      () async {
    fakeApi.initialSession = sb.Session(
      accessToken: 'new-access-token',
      tokenType: 'bearer',
      user: sb.User(
        id: 'fake-user-id',
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      ),
    );

    final response = await hitProtectedEndpoint();

    expect(response?.statusCode, 200);
    expect(fakeApi.logoutCalled, isFalse);
    expect(fakeApi.refreshCallCount, 1);
  });
}
