---
phase: 01-backend-auth-foundation
plan: 10
subsystem: api
tags: [aspnet-core, ef-core, riverpod, dio, flutter, gap-closure]

# Dependency graph
requires:
  - phase: 01-backend-auth-foundation (plan 05)
    provides: Family circle backend (Families/FamilyMembers/FamilyInvitations), FamilyAuthorizationService, FamiliesController
  - phase: 01-backend-auth-foundation (plan 07)
    provides: Family-circle mobile UI (FamilyController/FamilyApi, create/invite/accept/permissions screens, landing_stub_screen member list)
provides:
  - "GET /families/mine backend endpoint: the caller's own active family memberships (id, name, role, permissions), never 404 for zero memberships"
  - "Mobile FamilyController bootstrap fetch on auth: build()-time check for an already-authenticated session (cold start) plus a ref.listen transition trigger (fresh login) restore the family/member list from the backend instead of relying on in-session state only"
  - "FamilyState.isLoading flag so landing_stub_screen can show a spinner during the bootstrap fetch instead of flashing the 'create a circle' empty state"
affects: [02-real-time-location]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "AsyncNotifier bootstrap-on-auth: build() reads another controller's state synchronously (ref.read(authControllerProvider)) to decide whether to fire an unawaited bootstrap fetch, and separately uses ref.listen for the same controller's future transitions — covers both 'already authenticated at construction' and 'just logged in' without polling or re-fetching on every screen visit"
    - "Fire-and-forget post-build side effects via Future.microtask(_bootstrap) rather than awaiting inside build() itself, since AsyncNotifier assigns `state` from build()'s return value immediately after it returns — awaiting inline would race that assignment"

key-files:
  created:
    - backend/tests/SafePath.Application.Tests/Families/ListMyFamiliesQueryTests.cs
    - backend/src/SafePath.Application/Families/ListMyFamiliesQuery.cs
  modified:
    - backend/src/SafePath.Application/DependencyInjection.cs
    - backend/src/SafePath.Api/Controllers/FamiliesController.cs
    - mobile/lib/features/family/data/family_api.dart
    - mobile/lib/features/family/data/family_models.dart
    - mobile/lib/features/family/application/family_controller.dart
    - mobile/lib/features/home/presentation/landing_stub_screen.dart
    - mobile/test/features/family/family_controller_test.dart
    - mobile/test/features/family/invite_member_screen_test.dart

key-decisions:
  - "D-10-1 applied as written: ListMyFamiliesQuery returns ALL active memberships server-side (no artificial single-family cap), but FamilyController only takes the first one — marked with a TODO(multi-family) comment, no family-switcher UI built"
  - "D-10-2 applied as written: GET /families/mine has no familyId route param, scoped purely by the ICurrentUserService.UserId claim, mirrors ListFamilyMembersQuery's handler/controller pattern exactly"
  - "D-10-3 applied as written: two fetch triggers — build()-time synchronous check of authControllerProvider (cold start with an existing session) and a ref.listen transition into AuthAuthenticated from any other state (fresh login) — both funnel into the same _bootstrap() method, no duplicate-fetch risk since ref.listen only fires on actual state changes, not on initial subscription"
  - "isLoading modeled as a plain bool field on FamilyState (not the outer AsyncValue's loading state) because landing_stub_screen only reads FamilyState.value — relying on the outer AsyncValue would make the screen fall through to the empty-state UI during the fetch instead of showing a spinner"

patterns-established:
  - "TDD RED->GREEN commit pairs per task (test(01-10) commit -> feat(01-10) commit), consistent with 01-05's established convention for this codebase"

requirements-completed: [FAM-01, FAM-04, FAM-05]

coverage:
  - id: D1
    description: "GET /families/mine returns the caller's own active family memberships (id, name, role, permissions); empty list (not 404) when the caller has none; excludes soft-removed memberships; returns all memberships if more than one exists (no server-side single-family cap)"
    requirement: "FAM-01"
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Families/ListMyFamiliesQueryTests.cs#Handle_UserWithOneActiveMembership_ReturnsThatFamily"
        status: pass
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Families/ListMyFamiliesQueryTests.cs#Handle_UserWithNoMemberships_ReturnsEmptyList"
        status: pass
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Families/ListMyFamiliesQueryTests.cs#Handle_RemovedMembership_IsExcluded"
        status: pass
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Families/ListMyFamiliesQueryTests.cs#Handle_UserWithTwoActiveMemberships_ReturnsBoth"
        status: pass
    human_judgment: false
  - id: D2
    description: "Mobile FamilyController restores family + member state from GET /families/mine on cold app start (if a session already exists) and on every fresh login transition, so a Guardian/Member no longer loses their circle after logout/login"
    requirement: "FAM-04"
    verification:
      - kind: unit
        ref: "mobile/test/features/family/family_controller_test.dart#controller built while already authenticated fetches and restores the first family"
        status: pass
      - kind: unit
        ref: "mobile/test/features/family/family_controller_test.dart#a fresh login transition fetches and restores the family"
        status: pass
      - kind: unit
        ref: "mobile/test/features/family/family_controller_test.dart#getMyFamilies() returning empty leaves family null with no error"
        status: pass
      - kind: unit
        ref: "mobile/test/features/family/family_controller_test.dart#getMyFamilies() throwing surfaces the error without crashing, family stays null"
        status: pass
    human_judgment: false
  - id: D3
    description: "landing_stub_screen shows a loading spinner (not the 'create a circle' empty state) while the bootstrap fetch is in flight; permissions screen after a fresh login sees all members, not just the caller, once bootstrap completes"
    requirement: "FAM-05"
    verification: []
    human_judgment: true
    rationale: "The isLoading branch and post-bootstrap member visibility are exercised by unit tests on FamilyController's state, but the end-to-end 'log out, log back in, see the same circle' user-facing flow against a live backend is the manual UAT scenario this plan exists to fix — not re-verifiable by an automated widget/unit test in this codebase's current test setup."

# Metrics
duration: 11min
completed: 2026-07-09
status: complete
---

# Phase 01 Plan 10: Family Circle State Restoration (Gap Closure) Summary

**`GET /families/mine` backend endpoint + mobile `FamilyController` bootstrap fetch (build()-time check + auth-transition listener) so a Guardian/Member's family circle survives logout/login and cold app restarts, closing the in-memory-only gap discovered during Phase 1 manual UAT**

## Performance

- **Duration:** 11 min
- **Started:** 2026-07-09T17:20:47+03:00
- **Completed:** 2026-07-09T17:31:27+03:00
- **Tasks:** 2
- **Files modified:** 10 (2 created, 8 modified)

## Accomplishments
- `ListMyFamiliesQuery`/`ListMyFamiliesQueryHandler` (backend): joins the caller's active `FamilyMembers` rows to `Families`, scoped purely by the JWT `UserId` claim — no route param, mirrors `ListFamilyMembersQuery`'s existing handler/controller conventions
- `GET /families/mine` on `FamiliesController`: 200 with an empty array for a user with no family, correct array for one or multiple memberships (D-10-1: server never artificially caps to one)
- `FamilyApi.getMyFamilies()`/`MyFamily` model (mobile): typed client for the new endpoint
- `FamilyController` bootstrap: fetches on `build()` if already `AuthAuthenticated` (cold start with an existing session) and on any `Unauthenticated -> AuthAuthenticated` transition via `ref.listen` (fresh login) — takes the first membership only (D-10-1 simplification, `TODO(multi-family)` marked), populates `family` + full member roster via the existing `listMembers` call
- `FamilyState.isLoading` flag + `landing_stub_screen.dart` update: shows a spinner during the bootstrap fetch instead of momentarily flashing the "create a circle" empty state
- All 18 backend Application tests green (4 new + 14 existing), all 80 mobile tests green (4 new controller tests + zero regressions), `flutter analyze` and a scratch-directory `dotnet build` of the Api project both clean

## Task Commits

Each task was executed as a TDD RED -> GREEN commit pair:

1. **Task 1: Backend — GET /families/mine**
   - `0f9bd7e` (test) — 4 failing cases for `ListMyFamiliesQueryHandler` (compile-fail RED: handler/query types didn't exist yet)
   - `b6966d3` (feat) — `ListMyFamiliesQuery`/handler + `FamiliesController.GetMine` + DI registration
2. **Task 2: Mobile — fetch and restore family state on auth**
   - `9643965` (feat) — `FamilyApi.getMyFamilies()`, `MyFamily` model, `FamilyController` bootstrap (build()-time check + `ref.listen` transition), `FamilyState.isLoading`, `landing_stub_screen.dart` loading branch, 4 new controller tests, `invite_member_screen_test.dart` fake updated for the new abstract method

**Plan metadata:** this commit (docs: complete plan)

_Note: Task 2 was implemented and verified as a single unit (models/API/controller/screen/tests together) rather than a separate RED commit, since it extends an existing tested controller rather than introducing a wholly new untested one — all 4 new + 76 pre-existing tests were run and confirmed green before committing._

## Files Created/Modified
- `backend/tests/SafePath.Application.Tests/Families/ListMyFamiliesQueryTests.cs` - 4 test cases (one active membership, zero memberships, removed membership excluded, two active memberships)
- `backend/src/SafePath.Application/Families/ListMyFamiliesQuery.cs` - `ListMyFamiliesQuery`/`MyFamilyDto`/`ListMyFamiliesQueryHandler`
- `backend/src/SafePath.Application/DependencyInjection.cs` - registered the new handler alongside the other Families handlers
- `backend/src/SafePath.Api/Controllers/FamiliesController.cs` - `GET /families/mine` action
- `mobile/lib/features/family/data/family_api.dart` - `getMyFamilies()` on the `FamilyApi` interface + `DioFamilyApi` implementation
- `mobile/lib/features/family/data/family_models.dart` - `MyFamily` model
- `mobile/lib/features/family/application/family_controller.dart` - `build()` bootstrap check + `ref.listen`, `_bootstrap()`, `FamilyState.isLoading`
- `mobile/lib/features/home/presentation/landing_stub_screen.dart` - loading-spinner branch ahead of the empty/member-list branches
- `mobile/test/features/family/family_controller_test.dart` - `_FakeAuthApi`, `FakeFamilyApi.getMyFamilies` support, 4 new bootstrap-fetch tests, shared `setUp` now overrides `authApiProvider` (unauthenticated by default) so the 6 pre-existing tests are unaffected
- `mobile/test/features/family/invite_member_screen_test.dart` - `_FakeFamilyApi.getMyFamilies()` stub added (Rule 3 — the abstract method addition made this file's fake non-abstract-compliant; unrelated to this plan's own scope but required to compile)

## Decisions Made
See `key-decisions` in frontmatter for D-10-1/D-10-2/D-10-3 application detail. One additional implementation-level decision: `isLoading` is a plain `bool` field on `FamilyState` (the AsyncNotifier's inner value), not inferred from the outer `AsyncValue`'s loading state — `landing_stub_screen.dart` only ever reads `.value`, so relying on the outer `AsyncLoading` would have made the screen fall through to the "create a circle" empty state during the fetch instead of showing a spinner.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `invite_member_screen_test.dart`'s fake `FamilyApi` needed the new abstract method implemented**
- **Found during:** Task 2 (`flutter analyze` after adding `getMyFamilies()` to the `FamilyApi` interface)
- **Issue:** `FamilyApi` gained a new abstract method (`getMyFamilies()`). `invite_member_screen_test.dart`'s `_FakeFamilyApi implements FamilyApi` (not in this plan's `files_modified` list) failed to compile with `non_abstract_class_inherits_abstract_member` since it no longer satisfied the interface.
- **Fix:** Added a minimal `Future<List<MyFamily>> getMyFamilies() async => const [];` stub — this test never exercises the bootstrap fetch (it seeds `FamilyController` directly via a `_SeededFamilyController` subclass that overrides `build()` entirely), so an empty-list stub is sufficient and inert.
- **Files modified:** `mobile/test/features/family/invite_member_screen_test.dart`
- **Verification:** `flutter analyze` clean; both tests in the file still pass.
- **Committed in:** `9643965` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary for the codebase to compile after extending the `FamilyApi` interface; no scope creep beyond a one-line stub.

## Issues Encountered
Two of the four new mobile bootstrap-fetch tests initially failed on first run: the assertion order didn't trigger `FamilyController.build()` before `pumpEventQueue()`, so the read that was meant to observe the settled post-fetch state instead observed the pre-fetch (or, worse, a disposed-container) state. Fixed by explicitly reading `familyControllerProvider` once (to trigger `build()`/the bootstrap microtask) before `await pumpEventQueue()`, then reading again for final assertions. This is a test-authoring correction, not a deviation from the plan's behavior contract — no production code changed as a result.

## User Setup Required
**A backend restart is required to pick up the new `GET /families/mine` endpoint.** The user has a real device mid-manual-UAT against this backend in the same session — the running `SafePath.Api` process (confirmed via a locked-DLL build error during Task 1) predates this plan's controller change and will not serve the new route until restarted. No other external service configuration is needed; no new environment variables, migrations, or dashboard changes.

## Next Phase Readiness
- Family-circle state (FAM-01/04/05) is now genuinely durable across logout/login and cold app restarts, not just within the session that created/joined it — Phase 1's manual UAT gap is closed pending the backend restart + a manual re-verification pass (create circle -> log out -> log back in -> circle still visible, both as Guardian and as an invite-accepting Member).
- `D-10-4` reaffirmed as still out of scope: `FamilyMemberDto` still has no `fullName`, so member rows in `manage_permissions_screen.dart`/`landing_stub_screen.dart` show raw user IDs, not names — this needs a `Users` table join in `ListFamilyMembersQuery` and is display-polish, not data-loss; noted here again as still-open per the plan's own instruction.
- No other blockers. Ready for phase-01 verification/close-out once the user has restarted the backend and re-run the logout/login UAT scenario.

---
*Phase: 01-backend-auth-foundation*
*Completed: 2026-07-09*

## Self-Check: PASSED

All claimed files verified present on disk (`ListMyFamiliesQueryTests.cs`, `ListMyFamiliesQuery.cs`, `family_controller.dart`, this SUMMARY.md); all 3 task commits (`0f9bd7e`, `b6966d3`, `9643965`) verified present in `git log`.
