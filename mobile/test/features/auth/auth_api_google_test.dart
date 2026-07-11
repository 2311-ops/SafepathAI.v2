import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:mobile/features/auth/data/auth_api.dart';

void main() {
  sb.SupabaseClient client() =>
      sb.SupabaseClient('https://example.supabase.co', 'test-anon-key');

  test(
    'Google sign-in passes both ID token and access token to Supabase',
    () async {
      String? capturedIdToken;
      String? capturedAccessToken;

      final api = SupabaseAuthApi(
        client(),
        googleSignInTokensProvider: () async => const GoogleSignInTokens(
          idToken: 'google-id-token',
          accessToken: 'google-access-token',
        ),
        googleIdTokenSignIn:
            ({required String idToken, required String accessToken}) async {
              capturedIdToken = idToken;
              capturedAccessToken = accessToken;
            },
      );

      final signedIn = await api.signInWithGoogle();

      expect(signedIn, isTrue);
      expect(capturedIdToken, 'google-id-token');
      expect(capturedAccessToken, 'google-access-token');
    },
  );

  test('Google sign-in uses the native account picker path first', () async {
    var nativeTokensCalled = false;

    final api = SupabaseAuthApi(
      client(),
      googleSignInTokensProvider: () async {
        nativeTokensCalled = true;
        return const GoogleSignInTokens(
          idToken: 'google-id-token',
          accessToken: 'google-access-token',
        );
      },
      googleIdTokenSignIn:
          ({required String idToken, required String accessToken}) async {},
    );

    final signedIn = await api.signInWithGoogle();

    expect(signedIn, isTrue);
    expect(nativeTokensCalled, isTrue);
  });

  test(
    'Google sign-in rejects a missing access token before Supabase call',
    () async {
      var supabaseCalled = false;

      final api = SupabaseAuthApi(
        client(),
        googleSignInTokensProvider: () async => const GoogleSignInTokens(
          idToken: 'google-id-token',
          accessToken: '',
        ),
        googleIdTokenSignIn:
            ({required String idToken, required String accessToken}) async {
              supabaseCalled = true;
            },
      );

      await expectLater(
        api.signInWithGoogle(),
        throwsA(
          isA<AuthApiException>()
              .having((error) => error.issue, 'issue', AuthIssue.unknown)
              .having(
                (error) => error.message,
                'message',
                contains('access token'),
              ),
        ),
      );

      expect(supabaseCalled, isFalse);
    },
  );

  test(
    'Google sign-in cancellation returns false without Supabase call',
    () async {
      var supabaseCalled = false;

      final api = SupabaseAuthApi(
        client(),
        googleSignInTokensProvider: () async {
          throw const gsi.GoogleSignInException(
            code: gsi.GoogleSignInExceptionCode.canceled,
          );
        },
        googleIdTokenSignIn:
            ({required String idToken, required String accessToken}) async {
              supabaseCalled = true;
            },
      );

      final signedIn = await api.signInWithGoogle();

      expect(signedIn, isFalse);
      expect(supabaseCalled, isFalse);
    },
  );

  test('Google sign-in surfaces native client configuration errors', () async {
    var supabaseCalled = false;

    final api = SupabaseAuthApi(
      client(),
      googleSignInTokensProvider: () async {
        throw const gsi.GoogleSignInException(
          code: gsi.GoogleSignInExceptionCode.clientConfigurationError,
          description: 'ApiException: 10',
        );
      },
      googleIdTokenSignIn:
          ({required String idToken, required String accessToken}) async {
            supabaseCalled = true;
          },
    );

    await expectLater(
      api.signInWithGoogle(),
      throwsA(
        isA<AuthApiException>()
            .having((error) => error.issue, 'issue', AuthIssue.unknown)
            .having(
              (error) => error.message,
              'message',
              contains('ApiException: 10'),
            ),
      ),
    );

    expect(supabaseCalled, isFalse);
  });

  test('Google sign-in rejects missing ID tokens', () async {
    final api = SupabaseAuthApi(
      client(),
      googleSignInTokensProvider: () async => const GoogleSignInTokens(
        idToken: '',
        accessToken: 'google-access-token',
      ),
    );

    await expectLater(
      api.signInWithGoogle(),
      throwsA(
        isA<AuthApiException>()
            .having((error) => error.issue, 'issue', AuthIssue.unknown)
            .having((error) => error.message, 'message', contains('ID token')),
      ),
    );
  });

  test(
    'Google sign-in times out if the native picker never completes',
    () async {
      final api = SupabaseAuthApi(
        client(),
        googleSignInTokensProvider: () =>
            Completer<GoogleSignInTokens>().future,
        googleNativeSignInTimeout: const Duration(milliseconds: 1),
      );

      await expectLater(
        api.signInWithGoogle(),
        throwsA(
          isA<AuthApiException>()
              .having((error) => error.issue, 'issue', AuthIssue.unknown)
              .having(
                (error) => error.message,
                'message',
                contains('timed out'),
              ),
        ),
      );
    },
  );
}
