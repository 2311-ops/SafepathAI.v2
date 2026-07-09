---
phase: 01-backend-auth-foundation
plan: 06
subsystem: mobile-auth
tags: [flutter, riverpod, supabase-auth, password-reset, superseded]

requires:
  - "01-01-04 (superseded): AUTH-04 satisfied by Supabase Auth's native reset flow, not a custom backend"
  - "01-03: AuthController, AuthApi, routerProvider, auth screens shell"
provides:
  - "ForgotPasswordScreen + ResetPasswordScreen wired directly to Supabase Auth (no password_reset_controller.dart — logic lives in the existing AuthController)"
  - "'/forgot-password' and '/reset-password' routes, with AuthRecovery-state-driven guard on the reset screen"
affects: []

tech-stack:
  added: []
  patterns:
    - "Password recovery is driven by Supabase's own PASSWORD_RECOVERY auth-state-change event rather than a token+email query-string deep link — AuthController listens for it and exposes AuthRecovery, which ResetPasswordScreen and the router redirect guard both key off of"

key-files:
  created:
    - mobile/lib/features/auth/presentation/forgot_password_screen.dart
    - mobile/lib/features/auth/presentation/reset_password_screen.dart
    - mobile/test/features/auth/forgot_password_screen_test.dart
    - mobile/test/features/auth/reset_password_screen_test.dart
  modified:
    - mobile/lib/core/router/app_router.dart
    - mobile/lib/features/auth/application/auth_controller.dart
    - mobile/lib/features/auth/data/auth_api.dart

key-decisions:
  - "No password_reset_controller.dart or forgot_password_sent_screen.dart were built — the originally-planned separate controller and confirmation screen are unnecessary: AuthController already exposes requestPasswordReset()/completePasswordReset(), and ForgotPasswordScreen shows its confirmation inline (a status message) rather than navigating to a dedicated screen."
  - "Reset screen gates on AuthState is AuthRecovery (driven by Supabase's PASSWORD_RECOVERY stream event) instead of parsing a token+email from the deep link manually — Supabase's SDK handles the recovery session establishment itself."

patterns-established:
  - "Inline status/error messaging on the same screen (not a navigated confirmation screen) for enumeration-safe async actions where staying in place is simpler than adding a route"

requirements-completed: [AUTH-04, DESIGN-01]

coverage:
  - id: C1
    description: "Forgot-password: email validation, loading state, duplicate-submission prevention, success status message, error handling with form-state preservation"
    requirement: "AUTH-04"
    verification:
      - kind: unit
        ref: "mobile/test/features/auth/forgot_password_screen_test.dart — 6/6 pass"
        status: pass
    human_judgment: false
  - id: C2
    description: "Reset-password: submit disabled without an active recovery session, password validation (length + confirm-match), successful reset navigates to Login, failure shows inline error, duplicate-submission prevention"
    requirement: "AUTH-04"
    verification:
      - kind: unit
        ref: "mobile/test/features/auth/reset_password_screen_test.dart — 6/6 pass"
        status: pass
    human_judgment: false
  - id: C3
    description: "flutter analyze clean; full flutter test suite green"
    requirement: "DESIGN-01"
    verification:
      - kind: other
        ref: "flutter analyze — No issues found; flutter test — 60/60 pass (2026-07-09)"
        status: pass
    human_judgment: false

duration: n/a (built incrementally across this session's Supabase Auth pivot + repair passes)
completed: 2026-07-09
status: complete
---

# Phase 01 Plan 06: Forgot/Reset Password Screens — Satisfied via Supabase Auth

**Built against Supabase Auth's native password-reset flow instead of the plan-04 custom backend this plan originally specified (see the superseding note on `01-04-PLAN.md`). The user-facing outcome — AUTH-04's mobile half — is complete and tested.**

## Accomplishments
- `ForgotPasswordScreen`: email validation, `AuthController.requestPasswordReset()` call, loading state ("Sending link..."), inline neutral success message (enumeration-safe — never reveals whether the account exists), inline error on failure with the entered email preserved
- `ResetPasswordScreen`: gated on `AuthState is AuthRecovery` (only reachable via a real Supabase recovery deep link), password + confirm validation, `AuthController.completePasswordReset()` call, navigates to `/login` on success
- Router: `/forgot-password` and `/reset-password` routes added; the redirect guard treats `AuthRecovery` as requiring `/reset-password` regardless of the current route

## Deviations from Plan
- **No separate `password_reset_controller.dart`**: `AuthController` (already built in plan 03) was extended with `requestPasswordReset`/`completePasswordReset` methods instead of introducing a second controller — avoids splitting auth state across two Notifiers for what is still fundamentally one auth session's lifecycle.
- **No `forgot_password_sent_screen.dart`**: the confirmation is an inline status message on `ForgotPasswordScreen` rather than a navigation target — simpler for a single-field form with no further user action needed.
- **No token+email deep-link parsing**: Supabase's SDK establishes the recovery session itself and emits `AuthChangeEvent.passwordRecovery`; the app reacts to that state rather than manually parsing reset-link query parameters.

## Next Phase Readiness
AUTH-04 and DESIGN-01 (for this slice) are complete. Phase 1's remaining real work is the family-circle backend (`01-05-PLAN.md`) and mobile screens (`01-07-PLAN.md`) — both still valid, unaffected by the auth pivot.

---
*Phase: 01-backend-auth-foundation*
*Completed: 2026-07-09*
