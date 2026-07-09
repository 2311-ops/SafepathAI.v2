---
phase: 01-backend-auth-foundation
plan: 08
subsystem: auth
tags: [flutter, supabase, oauth, google-sign-in, riverpod, go_router, android, ios]

# Dependency graph
requires:
  - phase: 01-backend-auth-foundation
    provides: Supabase Auth-based AuthApi/AuthController/AuthState machinery and go_router redirect logic (01-03)
provides:
  - "AuthApi.signInWithGoogle() / SupabaseAuthApi.signInWithGoogle() wrapping Supabase's signInWithOAuth(OAuthProvider.google)"
  - "AuthController.signInWithGoogle() reusing AuthLoading/AuthAuthenticated/AuthError/AuthUnauthenticated (no new AuthState subtype), with a re-entrancy guard"
  - "WidgetsBindingObserver-based resume-recovery for a stuck AuthLoading state left by a cancelled/abandoned OAuth flow (D-08-6)"
  - "GoogleSignInButton shared widget, wired onto Welcome + Login (not Register)"
  - "safepathai:// deep-link scheme registered on Android (intent-filter) and iOS (CFBundleURLTypes) — closes a pre-existing gap shared with password reset"
affects: [phase-02-real-time-location, mobile-auth-testing-conventions]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "AuthApi interface methods that only 'launch' a flow (Future<bool>) resolve to AuthAuthenticated later via the existing authStateChanges listener, never directly from the triggering method"
    - "Notifier subclasses that need WidgetsBinding must guard addObserver/removeObserver against 'binding not initialized' so they remain usable from bare ProviderContainer unit tests (this feature's own established test convention)"
    - "Shared buttons take optional foregroundColor/borderColor overrides (mirrors PrimaryButton) for the one documented dark-background exception (Welcome's gradient hero) instead of forking a second widget"

key-files:
  created:
    - mobile/lib/shared_widgets/google_sign_in_button.dart
    - mobile/test/shared_widgets/google_sign_in_button_test.dart
  modified:
    - mobile/lib/features/auth/data/auth_api.dart
    - mobile/lib/features/auth/application/auth_controller.dart
    - mobile/lib/features/auth/presentation/welcome_screen.dart
    - mobile/lib/features/auth/presentation/login_screen.dart
    - mobile/android/app/src/main/AndroidManifest.xml
    - mobile/ios/Runner/Info.plist
    - mobile/test/features/auth/auth_controller_test.dart
    - mobile/test/features/auth/auth_state_stream_test.dart
    - mobile/test/helpers/fake_auth_api.dart
    - mobile/test/theme_test.dart
    - mobile/test/widget_test.dart
    - mobile/test/features/auth/login_screen_test.dart
    - mobile/README.md

key-decisions:
  - "Reused the existing safepathai://reset-password redirect URL for Google OAuth too (D-08-2) — zero new Supabase dashboard configuration."
  - "No post-OAuth role-selection screen; Google sign-ups land as Member via the existing handle_new_auth_user trigger's COALESCE default (D-08-4)."
  - "Google button deliberately excluded from Register (D-08-5) — Register is a two-step drafted flow that doesn't fit an atomic OAuth action."
  - "Guarded WidgetsBinding.instance.addObserver/removeObserver with try/catch so AuthController.build() doesn't crash in plain test() unit tests that use a bare ProviderContainer with no Flutter binding — a real bug found and fixed during Task 1, not present in the plan's design."

patterns-established:
  - "Optional color-override params on shared buttons for the single documented dark-background exception, rather than a second widget or a BuildContext-based theme branch."

requirements-completed: [AUTH-06, DESIGN-01]

coverage:
  - id: D1
    description: "AuthApi.signInWithGoogle() / SupabaseAuthApi.signInWithGoogle() wraps signInWithOAuth(OAuthProvider.google) with the existing error-mapping pattern"
    requirement: "AUTH-06"
    verification:
      - kind: unit
        ref: "mobile/test/features/auth/auth_controller_test.dart#signInWithGoogle launch success + a later session event transitions to Authenticated"
        status: pass
      - kind: unit
        ref: "mobile/test/features/auth/auth_controller_test.dart#signInWithGoogle network failure surfaces the enumeration-safe network error"
        status: pass
    human_judgment: false
  - id: D2
    description: "AuthController.signInWithGoogle() reuses existing AuthState machinery, is re-entrancy-guarded, and recovers from a stuck AuthLoading state after a cancelled OAuth flow (D-08-6)"
    requirement: "AUTH-06"
    verification:
      - kind: unit
        ref: "mobile/test/features/auth/auth_controller_test.dart#signInWithGoogle re-entrancy guard only invokes the API once while a call is pending"
        status: pass
      - kind: unit
        ref: "mobile/test/features/auth/auth_controller_test.dart#resume-recovery resets a stuck AuthLoading to Unauthenticated only when currentSession is null"
        status: pass
    human_judgment: false
  - id: D3
    description: "GoogleSignInButton renders on Welcome + Login (not Register), disables + spinners while AuthLoading, and exposes an accessible semantics label"
    requirement: "DESIGN-01"
    verification:
      - kind: unit
        ref: "mobile/test/shared_widgets/google_sign_in_button_test.dart#renders \"Continue with Google\", enabled, and tapping calls signInWithGoogle"
        status: pass
      - kind: unit
        ref: "mobile/test/shared_widgets/google_sign_in_button_test.dart#disables and shows a spinner while AuthLoading; tapping while disabled is a no-op"
        status: pass
    human_judgment: false
  - id: D4
    description: "End-to-end Google OAuth flow on a real device (external browser/Custom Tab -> Google account picker -> deep-link redirect -> /home) and cancellation recovery"
    verification: []
    human_judgment: true
    rationale: "Requires a real device/emulator with Google Play Services and a real Google account; cannot be automated in this environment (documented in mobile/README.md's testing note and the plan's <verification> section)."

# Metrics
duration: ~40min
completed: 2026-07-09
status: complete
---

# Phase 01 Plan 08: Google Sign-In via Supabase Native OAuth Summary

**"Continue with Google" on Welcome/Login via Supabase's `signInWithOAuth`, reusing the existing `AuthController`/`AuthState`/go_router machinery with zero new Supabase dashboard config and a lifecycle-resume recovery for cancelled OAuth attempts.**

## Performance

- **Duration:** ~40 min
- **Completed:** 2026-07-09
- **Tasks:** 3 (all `type="auto"`, no checkpoints)
- **Files modified:** 13 (2 created, 11 modified)

## Accomplishments
- `AuthApi.signInWithGoogle()` / `SupabaseAuthApi.signInWithGoogle()` wrap `signInWithOAuth(OAuthProvider.google, redirectTo: supabaseRedirectUrl, authScreenLaunchMode: LaunchMode.externalApplication)`, mapping errors the same way every other `AuthApi` method does.
- `AuthController.signInWithGoogle()` reuses `AuthLoading`/`AuthAuthenticated`/`AuthError`/`AuthUnauthenticated` — no new `AuthState` subtype — with a private re-entrancy guard covering double-tap even before the button-level guard.
- Cancellation recovery: a `WidgetsBindingObserver` resets a stuck `AuthLoading` state back to `AuthUnauthenticated` on app resume, but only when no real session has arrived (`recoverFromStuckLoadingOnResume`, exposed `@visibleForTesting`).
- `GoogleSignInButton` (outlined, matches `SecondaryButton`'s hierarchy, minimal "G" glyph, 48dp touch target, `Semantics` label) wired onto Welcome and Login only — Register deliberately excluded per D-08-5.
- Android (`intent-filter`) and iOS (`CFBundleURLTypes`) now register the `safepathai://` scheme, which was previously unregistered on both platforms — this closes the redirect-back gap for Google OAuth *and* the pre-existing password-reset deep link.
- `mobile/README.md` documents the dashboard-side-only config, the redirect-URL reuse rationale, the new deep-link registration, and the mocked-testing convention.

## Task Commits

Each task was committed atomically:

1. **Task 1: AuthApi.signInWithGoogle + AuthController.signInWithGoogle (+ cancellation recovery), with tests** - `12c7f57` (feat)
2. **Task 2: GoogleSignInButton widget, Welcome/Login wiring, and Android/iOS deep-link registration** - `25ce81a` (feat)
3. **Task 3: Documentation** - `a259183` (docs)

_No TDD-cycle multi-commits were needed; Task 1 was written test-alongside per its `tdd="true"` marker but landed as a single commit since the plan's behavior spec didn't require a separate RED-phase failing-test commit for this additive-only surface._

## Files Created/Modified
- `mobile/lib/features/auth/data/auth_api.dart` - Added `signInWithGoogle()` to `AuthApi`/`SupabaseAuthApi`
- `mobile/lib/features/auth/application/auth_controller.dart` - Added `signInWithGoogle()`, re-entrancy guard, `WidgetsBindingObserver`-based resume recovery
- `mobile/lib/shared_widgets/google_sign_in_button.dart` - New shared outlined Google sign-in button
- `mobile/lib/features/auth/presentation/welcome_screen.dart` - Wired `GoogleSignInButton` (white/light override for the gradient hero)
- `mobile/lib/features/auth/presentation/login_screen.dart` - Wired `GoogleSignInButton` (default teal styling)
- `mobile/android/app/src/main/AndroidManifest.xml` - `safepathai://` browsable intent-filter on `MainActivity`
- `mobile/ios/Runner/Info.plist` - `CFBundleURLTypes` entry for `safepathai://`
- `mobile/test/features/auth/auth_controller_test.dart` - 5 new Google sign-in test cases + `FakeAuthApi` extensions
- `mobile/test/shared_widgets/google_sign_in_button_test.dart` - New widget tests (enabled/tap, disabled+spinner, semantics)
- `mobile/test/features/auth/auth_state_stream_test.dart`, `mobile/test/helpers/fake_auth_api.dart`, `mobile/test/theme_test.dart`, `mobile/test/widget_test.dart` - Added `signInWithGoogle()` implementations to keep every `AuthApi` fake compiling against the widened interface
- `mobile/test/features/auth/login_screen_test.dart` - Scrolled the "Don't have an account?" tap into view (the new button pushed it below the default test viewport fold)
- `mobile/README.md` - New "Google Sign-In" documentation section

## Decisions Made
- D-08-1 through D-08-6 followed exactly as specified in the plan's `<locked_decisions_applied>` (native `signInWithOAuth`, reused redirect URL, deep-link registration as a prerequisite-gap fix, no post-OAuth role screen, Register exclusion, lifecycle-resume cancellation recovery).
- `GoogleSignInButton` gained optional `foregroundColor`/`borderColor` overrides (not in the plan's literal action text) so it reads correctly on Welcome's deep-teal gradient hero — the default themed outlined style (teal border/text) would otherwise be nearly invisible there, the same contrast problem `PrimaryButton` already documents an override for on that exact screen.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `AuthController.build()` crashed in every plain `test()` unit test (not just this plan's new tests) because `WidgetsBinding.instance` throws when no Flutter binding is initialized**
- **Found during:** Task 1, running the full test suite after wiring the `WidgetsBindingObserver`
- **Issue:** `WidgetsBinding.instance.addObserver(this)` in `build()` requires `WidgetsFlutterBinding`/`TestWidgetsFlutterBinding` to already be initialized. This codebase's established test convention drives `AuthController` via a bare `ProviderContainer` in plain `test()` bodies (no `testWidgets`, no pumped widget tree) across `auth_controller_test.dart`, `auth_state_stream_test.dart`, and every screen test that reads `authControllerProvider` before the first `pumpWidget` — none of those had a binding initialized, so every one of them started throwing `FlutterError: Binding has not yet been initialized.`
- **Fix:** Wrapped `WidgetsBinding.instance.addObserver`/`removeObserver` in `_addLifecycleObserver()`/`_removeLifecycleObserver()` helpers that swallow the binding-not-initialized case. In a real app or `testWidgets` context (binding always initialized before `build()` runs) behavior is unchanged; in a bare `ProviderContainer` unit test, the resume-recovery heuristic simply doesn't auto-register, which is fine since `recoverFromStuckLoadingOnResume()` is exercised directly in tests per the plan's own testing guidance.
- **Files modified:** `mobile/lib/features/auth/application/auth_controller.dart`
- **Verification:** Full `flutter test` suite green (77/77) after the fix; was red (66 passed / 8 failed) before it.
- **Committed in:** `12c7f57` (Task 1 commit)

**2. [Rule 3 - Blocking] Every other `AuthApi` fake implementer needed `signInWithGoogle()` to keep compiling**
- **Found during:** Task 1, immediately after widening the `AuthApi` interface
- **Issue:** Adding `signInWithGoogle()` to the `AuthApi` abstract class broke compilation of every other hand-written fake implementing it: `test/features/auth/auth_state_stream_test.dart`'s `_StreamFakeAuthApi`, `test/helpers/fake_auth_api.dart`'s shared `FakeAuthApi`, `test/theme_test.dart`'s `_FakeAuthApi`, and `test/widget_test.dart`'s `_FakeAuthApi`.
- **Fix:** Added a `signInWithGoogle()` implementation to each, matching that file's existing fake conventions (the shared helper got full `googleSignInShouldLaunch`/`googleSignInShouldFail`/`googleSignInIssue`/call-count knobs matching its other methods' pattern; the three simpler fakes got a one-line `async => true`).
- **Files modified:** `mobile/test/features/auth/auth_state_stream_test.dart`, `mobile/test/helpers/fake_auth_api.dart`, `mobile/test/theme_test.dart`, `mobile/test/widget_test.dart`
- **Verification:** `flutter analyze` clean; full suite green.
- **Committed in:** `12c7f57` (Task 1 commit)

**3. [Rule 1 - Bug] `login_screen_test.dart`'s "Don't have an account?" tap started missing its hit-test after Task 2's layout change**
- **Found during:** Task 2, running the full test suite after wiring `GoogleSignInButton` into `LoginScreen`
- **Issue:** The added button + spacing pushed the "Don't have an account? Create one" `TextButton` below the default 800x600 test-surface fold inside the screen's `SingleChildScrollView`; `tester.tap()` computes a widget's center point without scrolling and the point fell outside the render tree bounds.
- **Fix:** Added `await tester.ensureVisible(find.text(...))` before the tap in that one test case.
- **Files modified:** `mobile/test/features/auth/login_screen_test.dart`
- **Verification:** Full suite green (77/77).
- **Committed in:** `25ce81a` (Task 2 commit)

---

**Total deviations:** 3 auto-fixed (1 bug found in the new lifecycle-observer code itself, 1 blocking interface-completeness fix, 1 bug in an existing test caused directly by this plan's layout change)
**Impact on plan:** All three were necessary to keep the full test suite green; none represent scope creep beyond what this plan's own changes required.

## Issues Encountered
None beyond the auto-fixed deviations above.

## User Setup Required

None - no external service configuration required. The Google provider is already configured on the Supabase dashboard (per the plan's locked decisions), and this plan makes zero Supabase dashboard changes.

## Next Phase Readiness

- Google Sign-In is fully wired and unit/widget-tested (`flutter analyze` clean, 77/77 tests passing); end-to-end verification on a real device/emulator with Google Play Services is the one remaining manual step (D4 above), consistent with the plan's own `<verification>` section.
- Phase 01 (backend-auth-foundation) now has all of its planned auth surface (register/login/reset/logout/Google sign-in) and family-circle mobile UI (01-07) built. No blockers for Phase 2.

---
*Phase: 01-backend-auth-foundation*
*Completed: 2026-07-09*
