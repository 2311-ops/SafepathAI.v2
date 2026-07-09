---
phase: 01-backend-auth-foundation
plan: 09
subsystem: auth
tags: [flutter, supabase, google_sign_in, oauth, riverpod, android, ios]

# Dependency graph
requires:
  - phase: 01-backend-auth-foundation
    provides: "AuthApi/AuthController/AuthState Supabase-Auth machinery and the browser-based Google OAuth flow this plan supersedes (01-08)"
provides:
  - "SupabaseAuthApi.signInWithGoogle() reimplemented on google_sign_in's native GoogleSignIn.instance.authenticate() + Supabase signInWithIdToken(), replacing signInWithOAuth"
  - "googleServerClientId String.fromEnvironment constant in supabase_config.dart (Web OAuth client ID, GOOGLE_SERVER_CLIENT_ID dart-define)"
  - "AuthController simplified — WidgetsBindingObserver-based lifecycle-resume recovery (D-08-6) fully removed as dead code"
affects: [phase-02-real-time-location, mobile-auth-testing-conventions]

# Tech tracking
tech-stack:
  added: ["google_sign_in ^7.2.0 (google_sign_in_android 7.2.15, google_sign_in_ios 6.3.0)"]
  patterns:
    - "GoogleSignIn.instance.initialize() must be called exactly once and awaited before any other GoogleSignIn method — SupabaseAuthApi caches the in-flight/completed Future in a private field so repeated/concurrent signInWithGoogle() calls never re-initialize"
    - "google_sign_in 7.x's AuthenticationTokenData carries only idToken (no accessToken) — Supabase's signInWithIdToken accepts accessToken as optional, so it is omitted rather than assumed present"

key-files:
  created: []
  modified:
    - mobile/pubspec.yaml
    - mobile/lib/features/auth/data/auth_api.dart
    - mobile/lib/features/auth/application/auth_controller.dart
    - mobile/lib/core/config/supabase_config.dart
    - mobile/test/features/auth/auth_controller_test.dart
    - mobile/README.md

key-decisions:
  - "Verified google_sign_in's actual resolved API (7.2.0, the post-6.x GoogleSignIn.instance.authenticate()/GoogleSignInException surface) directly from the package's own README/example/types.dart in pub-cache after `flutter pub add`, per the plan's explicit warning not to assume the API from memory."
  - "GoogleSignInExceptionCode.canceled maps to a `false` return from signInWithGoogle() — preserves the exact Future<bool> contract AuthController already handled, so no FakeAuthApi test-double semantics needed to change."
  - "googleServerClientId reads via String.fromEnvironment (not hardcoded) and signInWithGoogle() throws a StateError loudly if it is empty, rather than silently attempting to initialize GoogleSignIn with a blank serverClientId."

requirements-completed: [AUTH-06]

coverage:
  - id: D1
    description: "SupabaseAuthApi.signInWithGoogle() reimplemented on google_sign_in's native picker (GoogleSignIn.instance.authenticate()) + Supabase signInWithIdToken(), replacing signInWithOAuth's browser/Custom Tab flow"
    requirement: "AUTH-06"
    verification:
      - kind: unit
        ref: "mobile/test/features/auth/auth_controller_test.dart#signInWithGoogle success + a later session event transitions to Authenticated"
        status: pass
      - kind: unit
        ref: "mobile/test/features/auth/auth_controller_test.dart#signInWithGoogle network failure surfaces the enumeration-safe network error"
        status: pass
    human_judgment: false
  - id: D2
    description: "Cancellation of the native picker returns false (Unauthenticated, no error) with no lifecycle-resume recovery needed; the dead WidgetsBindingObserver-based recovery code (D-08-6) is fully removed from AuthController and its test"
    requirement: "AUTH-06"
    verification:
      - kind: unit
        ref: "mobile/test/features/auth/auth_controller_test.dart#signInWithGoogle cancellation transitions to Unauthenticated with no error"
        status: pass
      - kind: unit
        ref: "mobile/test/features/auth/auth_controller_test.dart#signInWithGoogle re-entrancy guard only invokes the API once while a call is pending"
        status: pass
    human_judgment: false
  - id: D3
    description: "End-to-end native Google sign-in on a real device (tap Continue with Google -> native account picker with no browser/URL visible -> /home) and picker-cancellation recovery"
    verification: []
    human_judgment: true
    rationale: "Requires a real Android device/emulator with Google Play Services, a real Google account, and the Android OAuth client (package name + SHA-1) correctly registered in Google Cloud Console per D-09-2 — cannot be automated in this environment; documented in mobile/README.md and this plan's <verification> section."

# Metrics
duration: ~25min
completed: 2026-07-09
status: complete
---

# Phase 01 Plan 09: Native Google Sign-In (Supersedes Browser Flow) Summary

**`SupabaseAuthApi.signInWithGoogle()` reimplemented on `google_sign_in` 7.2.0's native `GoogleSignIn.instance.authenticate()` account picker + Supabase's `signInWithIdToken()`, replacing 01-08's `signInWithOAuth` browser/Custom Tab flow so no Supabase/Google URL is ever shown during sign-in.**

## Performance

- **Duration:** ~25 min
- **Completed:** 2026-07-09
- **Tasks:** 2 (both `type="auto"`, no checkpoints)
- **Files modified:** 6

## Accomplishments
- `google_sign_in ^7.2.0` added; its actual current API (post-6.x `GoogleSignIn.instance.authenticate()` / `GoogleSignInException` surface, `AuthenticationTokenData` carrying only `idToken`) was verified directly from the resolved package's README/example/types.dart in pub-cache, not assumed from memory, per the plan's explicit instruction.
- `SupabaseAuthApi.signInWithGoogle()` now: initializes `GoogleSignIn.instance` exactly once (cached `Future`), calls `authenticate()` to show the native Android account picker, extracts `idToken` from `account.authentication`, and signs into Supabase via `signInWithIdToken(provider: OAuthProvider.google, idToken: ...)`. Returns `true` on success, `false` on `GoogleSignInExceptionCode.canceled` — the exact same `Future<bool>` contract `AuthController` already handled, so the controller's success/false/exception branches needed zero logic changes.
- `googleServerClientId` added to `supabase_config.dart` as a `String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID')` constant (the Web OAuth client ID already configured as Supabase's Google provider); `signInWithGoogle()` throws a `StateError` loudly if it's empty rather than failing silently.
- `AuthController`'s `WidgetsBindingObserver` mixin, `_addLifecycleObserver`/`_removeLifecycleObserver`, and `recoverFromStuckLoadingOnResume` (01-08's D-08-6 cancellation-recovery hack) are fully deleted — dead code now that `authenticate()` is synchronously awaitable end-to-end, so cancellation can never leave a stuck `AuthLoading` state. The `flutter/widgets.dart` import is removed along with it. The `_googleSignInInFlight` re-entrancy guard is unchanged/kept.
- `auth_controller_test.dart`'s Google test cases reduced from 5 to 4 (the dedicated resume-recovery test deleted along with the method it tested); the remaining 4 (success+session-event, cancellation, network-failure, re-entrancy) pass unchanged against the new implementation because the `FakeAuthApi` contract (`Future<bool>`, throws `AuthApiException`) never needed to change.
- `mobile/README.md`'s Google Sign-In section rewritten for the native flow: documents the required `GOOGLE_SERVER_CLIENT_ID` env.json key, the Android OAuth client (package name + per-developer debug SHA-1, with the `keytool` command to get it) prerequisite in Google Cloud Console, that release builds need a separately-registered SHA-1, and that the `safepathai://` deep link is now only relevant to password reset (Google Sign-In no longer opens a browser or needs a redirect URL).

## Task Commits

Each task was committed atomically:

1. **Task 1: Add google_sign_in, reimplement AuthApi.signInWithGoogle on the native picker, remove the now-dead lifecycle-resume hack** - `e5a6997` (feat)
2. **Task 2: Full regression pass + docs update** - `c352f0c` (docs)

_No TDD RED-phase commit was needed; Task 1's `tdd="true"` marker was satisfied by writing the rewritten tests alongside the implementation and landing as a single commit, consistent with 01-08's precedent for this additive/replace-in-place surface._

## Files Created/Modified
- `mobile/pubspec.yaml` / `mobile/pubspec.lock` - Added `google_sign_in ^7.2.0` (resolved: `google_sign_in_android 7.2.15`, `google_sign_in_ios 6.3.0`, `google_sign_in_platform_interface 3.1.0`)
- `mobile/lib/features/auth/data/auth_api.dart` - `SupabaseAuthApi.signInWithGoogle()` reimplemented on `GoogleSignIn.instance.authenticate()` + `signInWithIdToken()`; added `_ensureGoogleSignInInitialized()` helper
- `mobile/lib/features/auth/application/auth_controller.dart` - Removed `WidgetsBindingObserver` mixin, `_addLifecycleObserver`/`_removeLifecycleObserver`, `didChangeAppLifecycleState`, `recoverFromStuckLoadingOnResume`; updated doc comments
- `mobile/lib/core/config/supabase_config.dart` - Added `googleServerClientId` constant
- `mobile/test/features/auth/auth_controller_test.dart` - Removed the resume-recovery test case; renamed/updated the two Google test descriptions and comments to reflect the native flow
- `mobile/README.md` - Rewrote the "Google Sign-In" section for the native-picker flow and its Google Cloud Console/env.json prerequisites

## Decisions Made
- D-09-1 through D-09-6 followed exactly as specified in the plan's `<locked_decisions_applied>` (native `google_sign_in` + `signInWithIdToken`, Web-client `serverClientId` not Android client ID, cancellation simplification removing D-08-6, unchanged role assignment, unchanged deep-link registration).
- `_googleSignInInitialization` caching pattern added (not explicit in the plan's literal action text) because `google_sign_in`'s own API contract requires `initialize()` to be called "exactly once" and awaited before any other method — without caching, a second `signInWithGoogle()` call (e.g. after a first cancellation) would violate that contract and risk undefined behavior per the package's own documentation.

## Deviations from Plan

None beyond the `_googleSignInInitialization` caching addition documented above under Decisions Made (a direct consequence of the verified package API's own single-initialization requirement, not a design choice this plan's text anticipated in detail — tracked here rather than as a numbered auto-fix since it was required to correctly implement the plan's own instructions, not a bug found afterward).

## Issues Encountered
None.

## User Setup Required

**External Google Cloud Console configuration required before manual/device verification can succeed** (cannot be automated or verified in this environment):
- `GOOGLE_SERVER_CLIENT_ID` must be present in `mobile/env.json` (confirmed already present, matching the Web OAuth client ID from 01-08's Supabase provider config) and passed via `--dart-define-from-file` at build/run time.
- An **Android**-type OAuth client must exist in Google Cloud Console project `safepathai-501908`, registered with package name `com.safepath.mobile` and the SHA-1 of whichever keystore signs the build under test (per-developer debug keystore for local dev; a separate release-keystore SHA-1 for release builds). Per D-09-2, this plan does not re-verify that registration — a `PlatformException`/`ApiException: 10` (`DEVELOPER_ERROR`) during manual testing indicates it needs re-checking in Cloud Console, not a code bug here.

See `mobile/README.md`'s "Google Sign-In" section for the exact `keytool` command and full detail.

## Next Phase Readiness

- Native Google Sign-In is fully implemented and unit-tested (`flutter analyze` clean, 76/76 tests passing, zero regressions vs. the pre-plan 77-test baseline minus the one intentionally-deleted dead-code test). End-to-end verification on a real device with Google Play Services and the Android OAuth client prerequisite is the one remaining manual step (D3 above), consistent with the plan's own `<verification>` section.
- Phase 01 (backend-auth-foundation) remains fully built (register/login/reset/logout/Google sign-in, family-circle mobile UI) with no new blockers introduced for Phase 2.

---
*Phase: 01-backend-auth-foundation*
*Completed: 2026-07-09*

## Self-Check: PASSED

All key files confirmed present on disk; both task commit hashes (`e5a6997`, `c352f0c`) confirmed present in git history.
