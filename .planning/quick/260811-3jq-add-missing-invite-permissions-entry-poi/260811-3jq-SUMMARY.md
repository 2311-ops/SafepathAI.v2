---
phase: quick-260811-3jq
plan: 01
subsystem: ui
tags: [flutter, riverpod, privacy-center, family-circle, guardian]

# Dependency graph
requires:
  - phase: 01-backend-auth-foundation
    provides: InviteMemberScreen (/circle/invite), ManagePermissionsScreen (/circle/permissions) — already-registered, fully built GoRouter routes with zero live callers
provides:
  - Guardian-gated Invite and Permissions IconButtons on PrivacyCenterScreen's populated-state AppBar
affects: [privacy-center, family-circle]

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - mobile/lib/features/privacy/presentation/privacy_center_screen.dart
    - mobile/test/features/privacy/privacy_center_screen_test.dart

key-decisions:
  - "Reproduced the retired landing_stub_screen.dart's Guardian-gating logic (hasFamily && isGuardian, effectiveRole fallback to profile role) verbatim in PrivacyCenterScreen rather than inventing new authorization semantics."
  - "Overrode profileControllerProvider in the test file's _app()/_routerApp() helpers since the screen now watches it — without the override, ProfileController.build() fires a real Dio network call in tests, leaving a pending timer that fails widget-tree disposal."

patterns-established: []

requirements-completed: [QUICK-PRIVACY-INVITE-PERMISSIONS-ENTRY]

coverage:
  - id: D1
    description: "Guardian who belongs to a family circle sees Invite and Permissions app-bar actions on Privacy Center, pushing /circle/invite and /circle/permissions respectively"
    requirement: "QUICK-PRIVACY-INVITE-PERMISSIONS-ENTRY"
    verification:
      - kind: unit
        ref: "mobile/test/features/privacy/privacy_center_screen_test.dart (full suite, 12 tests)"
        status: pass
      - kind: other
        ref: "flutter analyze mobile/lib/features/privacy/presentation/privacy_center_screen.dart"
        status: pass
    human_judgment: false
  - id: D2
    description: "Non-Guardian members and users without a family circle never see the Invite/Permissions actions; the no-family empty state's AppBar is unchanged"
    requirement: "QUICK-PRIVACY-INVITE-PERMISSIONS-ENTRY"
    verification: []
    human_judgment: true
    rationale: "No existing widget test asserts on AppBar action visibility for a non-Guardian member in the populated (has-family) state; visual/behavioral confirmation is best done via manual UAT rather than inferred from the gating expression alone."

# Metrics
duration: 15min
completed: 2026-08-10
status: complete
---

# Quick Task 260811-3jq: Add missing Invite/Permissions entry points Summary

**Guardian-gated Invite and Permissions IconButtons added to Privacy Center's app bar, reviving two fully-built but orphaned routes (/circle/invite, /circle/permissions) that lost their only caller when the app's home route moved from LandingStubScreen to MainShell.**

## Performance

- **Duration:** 15 min
- **Completed:** 2026-08-10T23:42:45Z
- **Tasks:** 1
- **Files modified:** 2

## Accomplishments
- Restored Guardian access to InviteMemberScreen and ManagePermissionsScreen via two new app-bar `IconButton`s on `PrivacyCenterScreen`'s populated-state `Scaffold`.
- Reproduced the Guardian-gating logic (`hasFamily && isGuardian`, with `profileControllerProvider` role fallback) exactly as it existed in the now-dead `landing_stub_screen.dart`, introducing no new authorization semantics.
- Fixed a genuine test regression surfaced by the new `profileControllerProvider` watch: the `_app()`/`_routerApp()` test helpers previously relied on `profileControllerProvider` never being read, so adding the watch caused a real (unmocked) network call and a pending-timer test failure.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add Guardian-gated Invite/Permissions app-bar actions to Privacy Center** - `4c4073c` (feat)

**Plan metadata:** committed separately by the orchestrator (docs commit not created by this executor per task constraints).

## Files Created/Modified
- `mobile/lib/features/privacy/presentation/privacy_center_screen.dart` - Added `auth_models.dart`/`profile_controller.dart` imports, Guardian-gating computation (`profileState`, `effectiveUserId`, `hasFamily`, `currentMember`, `effectiveRole`, `isGuardian`), and two gated `IconButton`s (Invite/Permissions) in the populated-state AppBar before `LogoutAction()`.
- `mobile/test/features/privacy/privacy_center_screen_test.dart` - Added `profileControllerProvider.overrideWith(() => _SeededProfileController(Role.guardian))` to `_app()` and `_routerApp()` so the newly-watched provider doesn't trigger a real network call during tests.

## Decisions Made
- Reused `landing_stub_screen.dart`'s exact gating derivation rather than simplifying it, to guarantee behavioral parity with the dead stub's previously-shipped UX.
- Fixed the test helpers' missing `profileControllerProvider` override as a direct, in-scope consequence of this task's own change (the screen didn't watch that provider before), rather than treating it as a pre-existing unrelated issue.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed a real widget-test failure caused directly by this task's new `profileControllerProvider` watch**
- **Found during:** Task 1 verification (`flutter test test/features/privacy/privacy_center_screen_test.dart`)
- **Issue:** `PrivacyCenterScreen` now watches `profileControllerProvider` (required for the Guardian-gating fallback, per plan). The test file's `_app()` and `_routerApp()` helpers never overrode that provider, so in the real `ProfileController.build()`, `AuthAuthenticated` state triggers `Future.microtask(refresh)`, which calls the real `DioProfileApi.getMe()`. In the "tapping a toggle calls the privacy controller" test (which uses a single `tester.pump()` rather than `pumpAndSettle()`), this left a pending Dio/fake_async timer at test teardown, causing `A Timer is still pending even after the widget tree was disposed`.
- **Fix:** Added `profileControllerProvider.overrideWith(() => _SeededProfileController(Role.guardian))` to both `_app()` and `_routerApp()`, matching the pattern `_noCircleApp()` already used. `Role.guardian` matches the seeded family's `self-user` Guardian membership, so gating behavior is unchanged.
- **Files modified:** `mobile/test/features/privacy/privacy_center_screen_test.dart`
- **Verification:** Full 12-test suite passes (`flutter test test/features/privacy/privacy_center_screen_test.dart`).
- **Committed in:** `4c4073c` (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 bug fix, in-scope test regression)
**Impact on plan:** Necessary to keep the existing test suite green per the plan's own contingency instructions ("If ... a test genuinely breaks because of the new buttons, fix that specific test minimally"). No scope creep — no new test cases were added beyond the required provider override.

## Issues Encountered
None beyond the deviation documented above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
Guardian users can now reach both `/circle/invite` and `/circle/permissions` from a live, reachable UI surface. No blockers for subsequent Phase 4 (Geofencing) work.

---
*Phase: quick-260811-3jq*
*Completed: 2026-08-10*

## Self-Check: PASSED

- FOUND: mobile/lib/features/privacy/presentation/privacy_center_screen.dart
- FOUND: mobile/test/features/privacy/privacy_center_screen_test.dart
- FOUND commit: 4c4073c
