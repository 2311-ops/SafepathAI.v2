---
phase: 01-backend-auth-foundation
plan: 03
subsystem: mobile-auth
tags: [flutter, riverpod, go_router, dio, flutter_secure_storage, auth, walking-skeleton]

# Dependency graph
requires:
  - "01-01: backend /auth/register|login|refresh|logout endpoints, Role enum (Guardian/Member/Caregiver/OrgAdmin), AuthResult contract"
  - "01-02: dioProvider, tokenStorageProvider, SafePath theme tokens, PrimaryButton/SafePathTextField shared widgets, go_router shell"
provides:
  - AuthApi (dio-backed client for /auth/register, /auth/login, /auth/logout, /auth/refresh) + authApiProvider
  - Auth DTOs (RegisterRequest, LoginRequest, AuthResponse) and mobile Role enum mirroring the backend
  - AuthController (Riverpod Notifier) + sealed AuthState (Unknown/Loading/Authenticated/Unauthenticated/Error)
  - Auth screens (Welcome, Register, Role select, Login) built to 01-UI-SPEC.md
  - Deliberately-plain Material 3 landing stub with confirm-gated Logout (UI-SPEC Scope Resolution #2)
  - routerProvider with auth redirect guard (/, /register, /register/role, /login, /home)
affects: [01-04, 01-05, 01-06, 01-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Feature-first layout: lib/features/<feature>/{data,application,presentation} — data holds DTOs + API client, application holds Riverpod controller + state, presentation holds screens"
    - "AuthApiException carries statusCode + serverMessage; controller maps them to UI-SPEC Copywriting Contract strings — raw server errors never reach the UI"
    - "Router reacts to auth state via a refreshListenable bridging ref.listen(authControllerProvider) to GoRouter, so the GoRouter instance is created once and never rebuilt on state change"
    - "Cross-screen form data (Register -> Role select) travels via GoRouterState.extra as a typed RegisterDraft, not via a shared mutable provider"

key-files:
  created:
    - mobile/lib/features/auth/data/auth_models.dart
    - mobile/lib/features/auth/data/auth_api.dart
    - mobile/lib/features/auth/application/auth_state.dart
    - mobile/lib/features/auth/application/auth_controller.dart
    - mobile/lib/features/auth/presentation/welcome_screen.dart
    - mobile/lib/features/auth/presentation/register_screen.dart
    - mobile/lib/features/auth/presentation/role_select_screen.dart
    - mobile/lib/features/auth/presentation/login_screen.dart
    - mobile/lib/features/home/presentation/landing_stub_screen.dart
    - mobile/test/features/auth/auth_controller_test.dart
    - mobile/test/features/auth/register_screen_test.dart
  modified:
    - mobile/lib/core/router/app_router.dart
    - mobile/lib/app.dart
    - mobile/lib/core/theme/app_colors.dart
    - mobile/lib/shared_widgets/primary_button.dart
    - mobile/lib/shared_widgets/safepath_text_field.dart

key-decisions:
  - "Register -> Role-select carries entered values as a typed RegisterDraft via GoRouterState.extra (single register() call at role confirm) rather than a draft provider — simplest thing that satisfies AUTH-05's role-at-setup requirement"
  - "Login maps every AuthApiException (401, network, anything) to the single enumeration-safe 'Incorrect email or password. Try again.' — matches server AuthResult.Invalid behavior (T-03-01)"
  - "logout() revokes server-side best-effort but ALWAYS clears TokenStorage locally, so a dead backend can never trap a user in a logged-in state"
  - "Router redirect treats only AuthAuthenticated as authenticated — AuthUnknown/Loading/Error all bounce off /home (T-03-03 deny-by-default)"

patterns-established:
  - "TDD RED->GREEN commit pair per plan (test(01-03) 70c4269 -> feat(01-03) c2a9750)"
  - "Shared widgets are extended backward-compatibly (optional named params), never forked per-screen"

requirements-completed: [AUTH-01, AUTH-02, AUTH-03, AUTH-05, DESIGN-01]

coverage:
  - id: C1
    description: "AuthController: register saves tokens -> Authenticated; duplicate email surfaces 'already exists' without saving; login 200 saves tokens; login 401 -> enumeration-safe error, no tokens; logout clears storage -> Unauthenticated"
    requirement: "AUTH-01, AUTH-02, AUTH-03, AUTH-05"
    verification:
      - kind: unit
        ref: "mobile/test/features/auth/auth_controller_test.dart — 5/5 pass (flutter test, 2026-07-07)"
        status: pass
    human_judgment: false
  - id: C2
    description: "Register screen renders FULL NAME/EMAIL/PASSWORD labels + Continue CTA; invalid email blocks navigation to role select"
    requirement: "AUTH-01, DESIGN-01"
    verification:
      - kind: unit
        ref: "mobile/test/features/auth/register_screen_test.dart — 2/2 pass"
        status: pass
    human_judgment: false
  - id: C3
    description: "auth_api.dart contains the literal endpoint paths /auth/register, /auth/login, /auth/logout, /auth/refresh; controller calls TokenStorage.saveTokens on success and clear on logout"
    requirement: "AUTH-01, AUTH-02, AUTH-03"
    verification:
      - kind: other
        ref: "grep '/auth/' mobile/lib/features/auth/data/auth_api.dart; grep 'saveTokens\\|clear' mobile/lib/features/auth/application/auth_controller.dart — all present"
        status: pass
    human_judgment: false
  - id: C4
    description: "flutter analyze clean; full flutter test suite green (theme + smoke + auth controller + register screen)"
    requirement: "DESIGN-01"
    verification:
      - kind: other
        ref: "flutter analyze — No issues found; flutter test — 11/11 pass (2026-07-07)"
        status: pass
    human_judgment: false
  - id: C5
    description: "Live end-to-end Walking Skeleton: register on a device/emulator creates a Supabase Users row with the chosen role; login/logout round-trip; wrong password shows the amber inline error"
    requirement: "AUTH-01, AUTH-02, AUTH-03, AUTH-05"
    verification: []
    human_judgment: true
    rationale: "Register/login/logout flow is covered by 11/11 automated tests (controller + widget), but live end-to-end verification against the running backend + Supabase on a device/emulator defers to end-of-phase UAT per config human_verify_mode: end-of-phase. Steps preserved verbatim in 'Deferred human verification' below."

# Metrics
duration: ~30min
completed: 2026-07-07
status: complete
---

# Phase 01 Plan 03: Mobile Auth Screens + Walking Skeleton Summary

**Riverpod auth controller + dio AuthApi wired to the plan-01 backend, with Welcome/Register/Role-select/Login screens built to 01-UI-SPEC.md, an auth-gated go_router redirect, and a deliberately-plain Material 3 landing stub — completing the client side of the Walking Skeleton (Flutter UI -> dio -> ASP.NET Core -> EF Core -> Supabase -> JWT -> secure storage -> authenticated screen).**

## Performance

- **Duration:** ~30 min
- **Completed:** 2026-07-07
- **Tasks:** 2 executed + 1 checkpoint deferred to end-of-phase UAT
- **Files:** 11 created, 5 modified

## Accomplishments
- `AuthApi` hitting `/auth/register`, `/auth/login`, `/auth/logout`, `/auth/refresh` through `dioProvider`, with `AuthApiException` normalizing dio failures (status code + server `error` field)
- DTOs (`RegisterRequest`/`LoginRequest`/`AuthResponse`) and a mobile `Role` enum whose wire values (`Guardian`/`Member`/`Caregiver`/`OrgAdmin`) mirror the backend's string-enum JSON exactly
- `AuthController` (Riverpod `Notifier`, sealed `AuthState`): register/login persist tokens via `TokenStorage.saveTokens` on success only; logout revokes server-side best-effort and always clears local storage; all error copy comes from the UI-SPEC Copywriting Contract
- TDD RED (`70c4269`, 5/5 failing against a stub) -> GREEN (`c2a9750`, 5/5 passing) commit pair for the controller behavior
- Welcome (deep-teal `#1FA89B`->`#0C3A3F` gradient hero, 38/800 wordmark, accent-mint "Create your circle" CTA), Register (FULL NAME/EMAIL/PASSWORD + client validation, teal "Continue"), Role select (4 role cards with teal selected border/shadow, confirm calls `register(...)` with the chosen role — AUTH-05), Login ("Welcome back.", amber inline 401 error under the password field)
- Landing stub: default Material 3 only (no `app_theme`/`AppColors` imports), no bottom nav, "Just you so far" empty state, Logout behind a confirm dialog ("Log out of SafePath AI?") per UI-SPEC
- `routerProvider` redirect guard: only `AuthAuthenticated` may reach `/home`; authenticated users are bounced off all onboarding routes to `/home`; reacts to controller state via a `refreshListenable` without rebuilding the router

## Task Commits

1. **Task 1 (RED): failing auth controller tests + API client/DTOs/state** — `70c4269` (test)
2. **Task 1 (GREEN): AuthController register/login/logout implemented** — `c2a9750` (feat)
3. **Task 2: Welcome/Register/Role/Login screens + landing stub, routed and wired** — `bbe2cf7` (feat)
4. **Task 3 (checkpoint:human-verify): DEFERRED** to end-of-phase UAT per `workflow.human_verify_mode: end-of-phase` — see below

## Deferred human verification (for end-of-phase UAT — run verbatim)

1. Start the backend: `dotnet run --project backend/src/SafePath.Api` (from repo root).
2. Run the app pointed at it: `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5xxx` (Android emulator; use your machine's LAN IP instead of `10.0.2.2` for a physical device) — substitute the actual port the backend binds to (check the `dotnet run` console output).
3. Register a new account, pick the "Guardian / Parent" role, submit → you should land on the plain landing stub ("Your circle" AppBar, "Just you so far" empty state).
4. In the Supabase table editor, confirm a new row exists in `Users` with your email and `Role = Guardian`.
5. Use the Logout action (top-right overflow menu → Logout → confirm) → you should return to Welcome.
6. Log back in with the same credentials from the Login screen → you should reach the landing stub again.
7. Try logging in with a wrong password → you should see the amber "Incorrect email or password. Try again." inline error under the password field.

## Decisions Made
- **RegisterDraft via `GoRouterState.extra`:** Register's Continue carries the entered values to Role select as a typed immutable object; the single `register()` call happens at role confirm, satisfying AUTH-05 (role picked during setup) without a draft provider or partial server calls.
- **Enumeration-safe login errors:** every `AuthApiException` from login (401 or otherwise) maps to the one Copywriting Contract string — mirrors the server's own indistinguishable `AuthResult.Invalid()` for unknown-email vs wrong-password (T-03-01).
- **Logout is locally unconditional:** server-side refresh-token revoke is best-effort (swallowed `AuthApiException`); `TokenStorage.clear()` always runs so a dead backend can never trap a user logged-in on-device.
- **Deny-by-default route guard:** `AuthUnknown`/`AuthLoading`/`AuthError` are all treated as unauthenticated by the redirect — only an explicit `AuthAuthenticated` opens `/home` (T-03-03).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Extended plan-02 shared widgets/tokens backward-compatibly**
- **Found during:** Task 2
- **Issue:** The plan's screens need capabilities plan-02's foundation didn't expose: Welcome's CTA must be accent-mint on deep teal (PrimaryButton had no color override), Register needs form validation (SafePathTextField had no `validator` passthrough), and `AppColors` lacked the `#1FA89B` gradient-start stop the UI-SPEC specifies for the Welcome hero.
- **Fix:** `PrimaryButton` gained optional `backgroundColor`/`foregroundColor`; `SafePathTextField` gained an optional `validator`; `AppColors.heroGradientStart` added with a doc comment citing the UI-SPEC. All additive/optional — no existing call site changed behavior.
- **Files modified:** `mobile/lib/shared_widgets/primary_button.dart`, `mobile/lib/shared_widgets/safepath_text_field.dart`, `mobile/lib/core/theme/app_colors.dart`
- **Commit:** `bbe2cf7`

**2. [Rule 3 - Blocking] `SafePathApp` converted to `ConsumerWidget`**
- **Found during:** Task 2
- **Issue:** The auth redirect guard must react to `AuthController` state, so the router became a Riverpod `routerProvider` (replacing plan-02's static `appRouter` global); `app.dart` had to watch it.
- **Fix:** `SafePathApp` is now a `ConsumerWidget` watching `routerProvider`. The plan listed `app_router.dart` in `files_modified`, so the router rework itself was in scope; the `app.dart` touch is the minimal knock-on.
- **Files modified:** `mobile/lib/app.dart`, `mobile/lib/core/router/app_router.dart`
- **Commit:** `bbe2cf7`

**Total deviations:** 2 auto-fixed (both Rule 3, both minimal knock-ons of planned work). No scope creep.

## Deviations — checkpoint disposition
- **Task 3 (`checkpoint:human-verify`) deferred, not failed:** per project config `workflow.human_verify_mode: "end-of-phase"`, the live device/emulator Walking-Skeleton verification defers to end-of-phase UAT (same treatment as plan 01-02's device-render check, coverage item D3 there). Full steps preserved above.

## Issues Encountered
None beyond the documented deviations. `flutter analyze` clean and all 11 tests green on first full-suite run after Task 2.

## Known Stubs
- `mobile/lib/features/home/presentation/landing_stub_screen.dart` — **intentional by design** (UI-SPEC Scope Resolution #2): a deliberately-plain Material 3 placeholder with a static "Just you so far" empty state and no real member list. The real Home/Live Map screen is Phase 3's deliverable; circle member data arrives with plan 01-04/01-05 (family circle backend) and later phases.
- `login_screen.dart` "Forgot password?" routes to `/forgot`, which has no route yet — the Forgot/Reset Password screens are plan 06's deliverable (plan text: "screen delivered in plan 06"). Tapping it before plan 06 will surface go_router's error screen; acceptable inside this phase since plan 06 is part of the same phase.

## Next Phase Readiness
- `authControllerProvider`, `authApiProvider`, and the routed auth flow are ready for plans 04-07 (circle creation, invites, forgot-password screens) to build on.
- Plan 06 should add the `/forgot` route + screens; plan 04+ replaces the landing stub's static empty state with real circle data.
- No blockers. One deferred item for end-of-phase UAT (live Walking-Skeleton run, steps above).

## Addendum (2026-07-08) — Auth mechanism superseded

Everything above describes the state as of this plan's completion: custom JWT via `/auth/register|login|logout|refresh`, tokens persisted through `TokenStorage.saveTokens`. This has since been replaced by **Supabase-managed auth**: the mobile app reads tokens from Supabase's own session object (`token_storage.dart` deleted), and the backend validates Supabase-issued JWTs instead of minting its own (`AuthController.cs` deleted, replaced by `MeController.cs`). The orphaned custom-JWT command handlers and identity helpers from plan 01-01 were removed from the codebase during planning-doc sync. See the superseding note on locked decision D6 in `01-01-PLAN.md`. Treat this summary's "Accomplishments" and "key-decisions" sections as historical record of what plan 03 delivered at the time, not a description of the current auth architecture.

## Addendum (2026-07-09) — Registration-flow repair + branding sync

Root cause found for a reported bug where completing Register -> Role select -> Continue bounced the user back to the Register screen with all entered data lost: `RoleSelectScreen` received the entered form data only via `GoRouterState.extra` (`app_router.dart`, with a fallback to re-render `RegisterScreen()` if `extra` was null). `authControllerProvider` drives the router's `refreshListenable`, which fires on every auth-state transition during `register()` (`AuthLoading` -> `AuthPendingVerification`/`AuthAuthenticated`/`AuthError`); each notification re-evaluates the current route, and `extra` was observed to be dropped on that re-evaluation, triggering the fallback.

**Fix:** the register draft now lives in a Riverpod `NotifierProvider` (`registerDraftProvider` in `register_screen.dart`) instead of `GoRouterState.extra` — it survives router re-evaluation. `RoleSelectScreen` no longer takes a constructor-supplied `draft`; it reads the provider directly.

**Also added:** a `/verify-email` route + `CheckEmailScreen` — previously `AuthPendingVerification` just disabled a button on Role select with no dedicated destination, so a successful signup requiring email confirmation had no visible next step. `RoleSelectScreen` now navigates to `/verify-email` on that state.

**Branding sync:** Android `AndroidManifest.xml` and iOS `Info.plist` still had the Flutter-template placeholder app name (`"mobile"`/`"Mobile"`) instead of "SafePath AI" — fixed on both platforms. Added a `SafePathLogo` widget (`mobile/lib/shared_widgets/safepath_logo.dart`) — recovered from a repo-root file pair with swapped extensions (`safepath_logo (1).svg` was actually Dart `CustomPaint` code matching the app's exact color tokens; `safepath_logo (1).dart` was an HTML design-doc export) — and wired it into Welcome (replacing a generic Material icon), Login, Register, and the new Check-Email screen.

**Confirmed non-issues:** No Resend or custom-SMTP code exists anywhere in the codebase — registration/password-reset email is entirely delegated to Supabase Auth's native `signUp`/`resetPasswordForEmail`, with SMTP being a Supabase Dashboard-only setting. Nothing needed changing here.

Verified: `flutter analyze` clean, all 12 existing tests still pass, live-tested on a physical device (register -> role select -> check-email screen navigates correctly without data loss).

---
*Phase: 01-backend-auth-foundation*
*Completed: 2026-07-07*
