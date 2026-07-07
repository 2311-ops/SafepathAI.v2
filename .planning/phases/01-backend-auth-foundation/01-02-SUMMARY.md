---
phase: 01-backend-auth-foundation
plan: 02
subsystem: mobile-foundation
tags: [flutter, riverpod, go_router, google_fonts, dio, flutter_secure_storage, design-system]

# Dependency graph
requires: []
provides:
  - Flutter mobile app scaffold (`mobile/`, org com.safepath, android+ios)
  - SafePath design-system token layer (AppColors/AppSpacing/AppTypography) + buildSafePathTheme()
  - Shared design-system widgets (PrimaryButton, SecondaryButton, SafePathTextField, SafePathCard)
  - dio HTTP client with auth interceptor + secure token storage (Riverpod providers)
  - go_router shell with a themed placeholder route
affects: [01-03, 01-06, 01-07]

# Tech tracking
tech-stack:
  added: [flutter_riverpod 3.3.2, go_router 16.3.0, google_fonts 8.1.0, flutter_secure_storage 10.3.1, dio 5.9.0, qr_flutter 4.1.0, share_plus 13.2.0]
  patterns:
    - "Riverpod providers for cross-cutting singletons (tokenStorageProvider, dioProvider) — later plans consume via ref.watch, never instantiate directly"
    - "dio auth interceptor uses a separate interceptor-free Dio instance for the /auth/refresh call to avoid recursive interception"
    - "google_fonts calls in ThemeData construction are tested via testWidgets (not bare test()) — flutter_test's mocked HttpClient makes the background font-fetch Future reject, which testWidgets tolerates but a synchronous test() attributes as a hard failure"

key-files:
  created:
    - mobile/pubspec.yaml
    - mobile/lib/main.dart
    - mobile/lib/app.dart
    - mobile/lib/core/theme/app_colors.dart
    - mobile/lib/core/theme/app_spacing.dart
    - mobile/lib/core/theme/app_typography.dart
    - mobile/lib/core/theme/app_theme.dart
    - mobile/lib/core/router/app_router.dart
    - mobile/lib/core/network/dio_client.dart
    - mobile/lib/core/network/auth_interceptor.dart
    - mobile/lib/core/storage/token_storage.dart
    - mobile/lib/shared_widgets/primary_button.dart
    - mobile/lib/shared_widgets/secondary_button.dart
    - mobile/lib/shared_widgets/safepath_text_field.dart
    - mobile/lib/shared_widgets/safepath_card.dart
    - mobile/test/theme_test.dart
  modified:
    - mobile/test/widget_test.dart

key-decisions:
  - "Kept the default flutter_create widget_test.dart but rewrote it (it referenced the now-deleted counter-demo MyApp) — Rule 1 auto-fix, direct consequence of scaffolding"
  - "Used testWidgets (not bare test()) for all theme_test.dart assertions after discovering flutter_test's TestWidgetsFlutterBinding unconditionally mocks HttpClient to return 400, which makes google_fonts' fire-and-forget background font-fetch Future reject — testWidgets/pump tolerates the resulting unhandled async error, a synchronous test() body does not"
  - "AuthInterceptor takes a public refreshDio field (not a private renamed one) to satisfy the prefer_initializing_formals lint cleanly"

patterns-established:
  - "Design tokens live in mobile/lib/core/theme/ as const classes (AppColors/AppSpacing) plus lazy-getter classes for font-dependent styles (AppTypography) — later screens must consume these, never inline hex/font values"
  - "GoogleFonts.config.allowRuntimeFetching = false in test setUpAll for deterministic, offline-safe test runs"

requirements-completed: [DESIGN-01]

coverage:
  - id: D1
    description: "Flutter app scaffolds, builds, analyzes clean; flutter test test/theme_test.dart passes"
    requirement: "DESIGN-01"
    verification:
      - kind: unit
        ref: "mobile/test/theme_test.dart#buildSafePathTheme exposes the exact SafePath color tokens"
        status: pass
      - kind: unit
        ref: "mobile/test/theme_test.dart#buildSafePathTheme uses Manrope for headings and JetBrains Mono for the mono style"
        status: pass
      - kind: unit
        ref: "mobile/test/theme_test.dart#SafePathApp builds and shows the themed placeholder route"
        status: pass
      - kind: other
        ref: "flutter analyze (mobile/) — No issues found"
        status: pass
    human_judgment: false
  - id: D2
    description: "dio client + auth interceptor + secure token storage wired as Riverpod providers; tokens only ever touch flutter_secure_storage"
    requirement: "DESIGN-01"
    verification:
      - kind: unit
        ref: "mobile/test/widget_test.dart#SafePathApp pumps without exceptions"
        status: pass
      - kind: other
        ref: "grep -rln \"^import 'package:shared_preferences\" mobile/lib — no matches"
        status: pass
      - kind: other
        ref: "flutter analyze (mobile/) — No issues found"
        status: pass
    human_judgment: false
  - id: D3
    description: "The app visually renders the SafePath theme on a real device/emulator (flutter run)"
    verification: []
    human_judgment: true
    rationale: "Widget tests confirm the theme is wired and the placeholder route renders, but pixel-level visual fidelity on a physical device/emulator was not observed during this automated execution — defer to end-of-phase human verification per config human_verify_mode: end-of-phase."

# Metrics
duration: 30min
completed: 2026-07-07
status: complete
---

# Phase 01 Plan 02: Flutter Mobile Foundation Summary

**Flutter app scaffold with the SafePath ThemeData (Manrope/JetBrains Mono, teal/SOS-red tokens), Riverpod state management, go_router shell, and a dio client with a 401-refresh-retry auth interceptor backed exclusively by flutter_secure_storage.**

## Performance

- **Duration:** ~30 min
- **Started:** 2026-07-07T09:51:00Z (environment gate verification)
- **Completed:** 2026-07-07T09:16:41Z (final task commit)
- **Tasks:** 2 (plus 1 pre-satisfied environment checkpoint)
- **Files modified:** 81 (78 from `flutter create` scaffold + 3 network/storage files; 15 hand-authored source files plus 2 test files among these)

## Accomplishments
- Scaffolded `mobile/` (Flutter 3.44.5, org `com.safepath`, android+ios) with `flutter_riverpod`, `go_router`, `google_fonts`, `flutter_secure_storage`, `dio`, `qr_flutter`, `share_plus` in `pubspec.yaml`
- Built the exact SafePath token layer (`AppColors`, `AppSpacing`, `AppTypography`) and `buildSafePathTheme()` — verified against `01-UI-SPEC.md` hex values (`#15807C` primary teal, `#DE3B40` SOS red, `#ECF0EF` app background) and Manrope/JetBrains Mono type roles
- Shared design-system widgets: `PrimaryButton`, `SecondaryButton`, `SafePathTextField` (mono uppercase label + amber invalid state), `SafePathCard`
- `go_router`-based `app_router.dart` with a single themed placeholder route; `SafePathApp` (`MaterialApp.router`) wrapped in `ProviderScope` at `main.dart`
- `TokenStorage` (flutter_secure_storage-only), `AuthInterceptor` (bearer attach + single 401 refresh-retry), `buildDio()`/`dioProvider` reading `API_BASE_URL` via `--dart-define`

## Task Commits

Each task was committed atomically:

1. **Task 1: Scaffold the Flutter app and build the SafePath theme + shared widgets** - `f547b09` (feat)
2. **Task 2: Wire the dio client, auth interceptor, and secure token storage** - `bf488c2` (feat)

_Note: the first plan task (`checkpoint:human-action` environment gate) was pre-satisfied — the orchestrator had already installed Flutter 3.44.5 with a working Android toolchain before this executor ran; verified via `flutter --version` before Task 1._

## Files Created/Modified
- `mobile/pubspec.yaml` - Adds flutter_riverpod, go_router, google_fonts, flutter_secure_storage, dio, qr_flutter, share_plus
- `mobile/lib/core/theme/app_colors.dart` - Named SafePath color constants (primaryTeal, sosRed, appBg, caution, etc.)
- `mobile/lib/core/theme/app_spacing.dart` - 4pt spacing scale (xs/sm/xsMd/md/lg/xl)
- `mobile/lib/core/theme/app_typography.dart` - Manrope + JetBrains Mono text styles (display/heading/title/body/bodySecondary/caption/code)
- `mobile/lib/core/theme/app_theme.dart` - `buildSafePathTheme()` assembling the Material 3 ThemeData
- `mobile/lib/core/router/app_router.dart` - go_router with the themed placeholder route
- `mobile/lib/shared_widgets/{primary_button,secondary_button,safepath_text_field,safepath_card}.dart` - Shared design-system widgets
- `mobile/lib/app.dart` - `SafePathApp` (MaterialApp.router)
- `mobile/lib/main.dart` - `ProviderScope` root
- `mobile/lib/core/storage/token_storage.dart` - `TokenStorage` over `flutter_secure_storage`; `tokenStorageProvider`
- `mobile/lib/core/network/auth_interceptor.dart` - `AuthInterceptor` (bearer attach + 401 refresh-retry)
- `mobile/lib/core/network/dio_client.dart` - `buildDio()`/`dioProvider`
- `mobile/test/theme_test.dart` - Asserts exact SafePath theme tokens + font families
- `mobile/test/widget_test.dart` - Rewritten smoke test (default counter-demo test referenced deleted `MyApp`)

## Decisions Made
- Kept `mobile/test/widget_test.dart` but rewrote its contents: `flutter create`'s default test imports `MyApp` (the counter-demo widget), which no longer exists after `main.dart` was replaced with `SafePathApp`/`ProviderScope` — this was a direct, unavoidable consequence of Task 1's scaffolding (Rule 1 auto-fix), not scope creep.
- Converted all `theme_test.dart` assertions to `testWidgets` rather than bare `test()` after discovering `flutter_test`'s `TestWidgetsFlutterBinding` unconditionally mocks `HttpClient` (always returns 400) to keep tests hermetic/offline. `google_fonts` fires an unawaited background Future on every `GoogleFonts.<family>()` call to fetch/cache the real font; with the mocked client (or with `GoogleFonts.config.allowRuntimeFetching = false`, which was also set for determinism) that Future rejects. The synchronously-returned `TextStyle.fontFamily` — the only thing asserted on — is unaffected, but a bare synchronous `test()` body attributes the later unhandled rejection as a hard failure, while `testWidgets`'s pump lifecycle tolerates it. This is standard, documented `google_fonts` + `flutter_test` interaction, not a bug in application code.
- `AuthInterceptor`'s refresh-only `Dio` field is named `refreshDio` (public) rather than a privately-renamed field, to satisfy the `prefer_initializing_formals` lint cleanly while keeping the constructor parameter name self-documenting.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Rewrote the default `widget_test.dart` counter-demo test**
- **Found during:** Task 1 (Flutter scaffold)
- **Issue:** `flutter create`'s generated `test/widget_test.dart` pumps `MyApp` and asserts counter-increment behavior; `main.dart` was replaced with `SafePathApp`/`ProviderScope` per the plan, so the file no longer compiled.
- **Fix:** Replaced with a smoke test pumping `SafePathApp` inside a `ProviderScope`, asserting it renders without exceptions and shows "SafePath AI".
- **Files modified:** `mobile/test/widget_test.dart`
- **Verification:** `flutter test` green.
- **Committed in:** `f547b09` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 bug fix, direct consequence of scaffolding)
**Impact on plan:** Necessary for `flutter test` to compile/pass at all. No scope creep — no new functionality added beyond what the plan specified.

## Issues Encountered
- `google_fonts` background font-fetch Futures reject inside `flutter test` (HttpClient is mocked to return 400 by `TestWidgetsFlutterBinding`, and `GoogleFonts.config.allowRuntimeFetching = false` was also set for determinism). Resolved by using `testWidgets` for all theme assertions instead of bare `test()` — see Decisions Made above for the full explanation. No application code defect; this is inherent `google_fonts` + `flutter_test` interaction.
- Backend directory (`backend/`, plan 01's in-progress work) was left completely untouched per environment notes — confirmed via `git status`/`git diff --diff-filter=D` after each commit that no files there were modified.

## User Setup Required
None - no external service configuration required. (Android SDK/toolchain and Flutter 3.44.5 were already installed and verified before this plan began execution.)

## Next Phase Readiness
- Mobile foundation (theme, shared widgets, router shell, network + secure-storage plumbing) is in place; plans 03/06/07 can add screens/providers directly on top without re-touching scaffold, theme, or networking layers.
- `tokenStorageProvider` and `dioProvider` are ready for auth-flow plans (03) to consume for login/register/refresh calls against the backend's `/auth/*` endpoints (once plan 01's backend work completes).
- No blockers. One item deferred to end-of-phase human verification (per `human_verify_mode: end-of-phase`): visually confirming `flutter run` renders the SafePath theme correctly on a real device/emulator (widget tests already confirm the theme wiring and placeholder route render without exceptions).

---
*Phase: 01-backend-auth-foundation*
*Completed: 2026-07-07*

## Self-Check: PASSED

All key files and commits verified present on disk / in git history.
