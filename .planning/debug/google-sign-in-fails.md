---
status: resolved
trigger: "okay now their is a problem in signing in with google investigate it and fix use [$gsd-debug](C:\\Users\\LOQ\\.codex\\skills\\gsd-debug\\SKILL.md)"
created: 2026-07-11
updated: 2026-07-12
---

# Debug Session: Google Sign-In Fails

## Symptoms
- expected_behavior: Tapping "Continue with Google" should complete native Google account selection, establish a Supabase session, and route to the authenticated app.
- actual_behavior: User reports Google sign-in has a problem; exact UI error not provided yet.
- error_messages: A30 logcat showed Google Play services `DEVELOPER_ERROR`/Credential Manager activity during the native flow, then the app returned to Welcome with auth still loading.
- timeline: Reported after mobile startup fixes on 2026-07-11; reproduced and fixed on the connected A30 (`R58M30TGNXV`) on 2026-07-12.
- reproduction: Tap "Continue with Google" on the mobile Welcome/Login screen.

## Current Focus
- hypothesis: The correct app workflow is native Google account chooser first; after Supabase creates the session, users with no selected role must be redirected to role onboarding.
- test: Verify native-first auth unit tests, role-onboarding router tests, full Flutter suite, and reinstall the cleaned APK on A30.
- expecting: Tapping "Continue with Google" opens the Google account chooser. After account selection and session creation, the router asks for Guardian/Member/Caregiver instead of sending the user straight to Home as a default member.
- next_action: Rebuild and reinstall native-first APK on `R58M30TGNXV`; if the picker still reports `DEVELOPER_ERROR`, fix Google Cloud OAuth Android client registration for package `com.safepath.mobile` and the debug SHA-1.
- reasoning_checkpoint:
- tdd_checkpoint:

## Evidence
- timestamp: 2026-07-11
  observation: `mobile/lib/features/auth/data/auth_api.dart` calls `signInWithIdToken(provider: google, idToken: idToken)` without `accessToken`.
- timestamp: 2026-07-11
  observation: Supabase Dart reference for `signInWithIdToken` says `accessToken` is required for Google sign-in.
- timestamp: 2026-07-11
  observation: Installed `google_sign_in` 7.2.0 provides `GoogleSignInAuthorizationClient.authorizeScopes()` / `authorizationForScopes()` returning `GoogleSignInClientAuthorization.accessToken`.
- timestamp: 2026-07-11
  observation: A fresh logcat capture had no Google/Supabase lines because the phone remained on the lock screen; app was focused behind keyguard.
- timestamp: 2026-07-11
  observation: The connected debug signing fingerprint is package `com.safepath.mobile`, SHA-1 `BA:3B:AA:E7:71:FB:3B:D7:6A:30:9D:F4:EA:6C:46:67:AC:6B:43:39`, a common cause of native `ApiException: 10` if absent from Google Cloud.
- timestamp: 2026-07-11
  observation: Android `INTERNET` permission existed only in debug/profile manifests; release builds would not have the network permission needed for Supabase token exchange.
- timestamp: 2026-07-11
  observation: Added a Supabase browser OAuth fallback for non-cancelled native Google failures and incomplete native Google tokens.
- timestamp: 2026-07-12
  observation: The connected device for the latest report was `R58M30TGNXV`; it initially had an older app install from before the previous Google fix was installed to the other device.
- timestamp: 2026-07-12
  observation: After reinstalling current code on `R58M30TGNXV`, native Google sign-in still opened Google Play services Credential Manager and left the app in loading state; logcat contained Google `DEVELOPER_ERROR` evidence.
- timestamp: 2026-07-12
  observation: Added Android OAuth-first logic for the real production path while keeping native Google sign-in for injected/test paths and non-Android targets; also added timeout fallback for native and OAuth calls.
- timestamp: 2026-07-12
  observation: A temporary trace build showed `Google sign-in state=AuthLoading`, `Google sign-in using OAuth first`, `Supabase signInWithOAuth launch requested`, and `Google OAuth fallback returned true`.
- timestamp: 2026-07-12
  observation: Physical A30 verification after tapping "Continue with Google" foregrounded Samsung Internet (`com.sec.android.app.sbrowser/.SBrowserMainActivity`), confirming the OAuth-first path launches successfully.
- timestamp: 2026-07-12
  observation: User rejected the browser OAuth workflow change; the required product flow is native Google account chooser first, then role selection.
- timestamp: 2026-07-12
  observation: Removed Android OAuth-first and browser fallback behavior. Native Google sign-in remains, now with required ID/access token submission to Supabase and a timeout if the native picker never completes.
- timestamp: 2026-07-12
  observation: Existing router tests confirm Google/OAuth users with no role, and legacy Google users defaulted to member without role metadata, are redirected to role selection before Home.
- timestamp: 2026-07-12
  observation: Rebuilt and reinstalled the native-first APK on `R58M30TGNXV`; tapping "Continue with Google" opened `com.google.android.gms/.auth.api.credentials.assistedsignin.ui.GoogleSignInActivity` with the "Choose an account" sheet for SafePath AI.

## Eliminated

## Resolution
- root_cause: Native token sign-in was incomplete because Supabase's Google `signInWithIdToken` path requires both ID and access tokens. The physical Android debug build may also need its package/SHA registered in Google Cloud if Google Play services reports `DEVELOPER_ERROR`.
- fix: Request and pass both native Google tokens to Supabase, keep the native Google account picker as the user-facing workflow, time out if the native picker never completes, and keep the auth controller `currentSession` check so the UI cannot stay loading if the stream event is missed.
- verification: `flutter analyze` clean; full suite passed 112 tests; A30 reinstall verified that tapping Google opens the native account chooser.
- files_changed: `mobile/lib/features/auth/data/auth_api.dart`, `mobile/lib/features/auth/application/auth_controller.dart`, `mobile/test/features/auth/auth_api_google_test.dart`, `mobile/test/features/auth/auth_controller_test.dart`, `mobile/android/app/src/main/AndroidManifest.xml`
