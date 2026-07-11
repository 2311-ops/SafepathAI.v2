---
status: investigating
trigger: "okay now their is a problem in signing in with google investigate it and fix use [$gsd-debug](C:\\Users\\LOQ\\.codex\\skills\\gsd-debug\\SKILL.md)"
created: 2026-07-11
updated: 2026-07-11
---

# Debug Session: Google Sign-In Fails

## Symptoms
- expected_behavior: Tapping "Continue with Google" should complete native Google account selection, establish a Supabase session, and route to the authenticated app.
- actual_behavior: User reports Google sign-in has a problem; exact UI error not provided yet.
- error_messages: Initial code/docs evidence points to Supabase rejecting or being unable to complete native Google sign-in because only an ID token is submitted.
- timeline: Reported after mobile startup fixes on 2026-07-11.
- reproduction: Tap "Continue with Google" on the mobile Welcome/Login screen.

## Current Focus
- hypothesis: `SupabaseAuthApi.signInWithGoogle()` sends only `idToken` to `signInWithIdToken`, but Supabase Dart docs require `accessToken` for Google; `google_sign_in` 7.2 exposes that token via `authorizationClient`.
- test: Add/adjust unit coverage around the Google sign-in API path and run Flutter tests/analyze.
- expecting: The auth API requests the Google access token, passes both tokens to Supabase, and handles missing access tokens with a clear AuthApiException.
- next_action: Install on A30 and manually exercise Google account picker; if it still fails with ApiException 10, investigate Google Cloud SHA/client configuration separately.
- reasoning_checkpoint:
- tdd_checkpoint:

## Evidence
- timestamp: 2026-07-11
  observation: `mobile/lib/features/auth/data/auth_api.dart` calls `signInWithIdToken(provider: google, idToken: idToken)` without `accessToken`.
- timestamp: 2026-07-11
  observation: Supabase Dart reference for `signInWithIdToken` says `accessToken` is required for Google sign-in.
- timestamp: 2026-07-11
  observation: Installed `google_sign_in` 7.2.0 provides `GoogleSignInAuthorizationClient.authorizeScopes()` / `authorizationForScopes()` returning `GoogleSignInClientAuthorization.accessToken`.

## Eliminated

## Resolution
- root_cause: Native Google sign-in returned a Google ID token, but the app only sent that ID token to Supabase. Supabase Dart `signInWithIdToken` requires the Google OAuth access token too.
- fix: Request Google authorization scopes via `authorizationClient`, validate both ID/access tokens, and pass both to Supabase `signInWithIdToken`.
- verification: `flutter analyze` clean; `flutter test` passed 105 tests, including new Google token regression coverage.
- files_changed: `mobile/lib/features/auth/data/auth_api.dart`, `mobile/test/features/auth/auth_api_google_test.dart`
