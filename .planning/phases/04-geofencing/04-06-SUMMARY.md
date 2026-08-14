---
phase: 04-geofencing
plan: 06
subsystem: api
tags: [dotnet, aspnet-core, ef-core, geofencing, authorization]
requires:
  - phase: 04-geofencing
    provides: durable safe-zone registrations, activity retention records, and family authorization
provides:
  - Guardian-scoped safe-zone CRUD with server-side geometry, membership, recipient, and capacity validation
  - Generation-bound registration acknowledgement and candidate submission contracts
affects: [04-07-geofence-confirmation, 04-08-geofence-activity, mobile-geofence-registration]
actuals:
  tokens: 15633
  tasks: 2
  commits: 5
tech-stack:
  added: []
  patterns: [canonical REST CRUD, family-scoped authorization, registration-generation invalidation]
key-files:
  created:
    - backend/src/SafePath.Application/Geofencing/ZoneCommands.cs
    - backend/src/SafePath.Application/Geofencing/ZoneQueries.cs
    - backend/src/SafePath.Api/Controllers/GeofencesController.cs
    - backend/tests/SafePath.Api.IntegrationTests/GeofencesControllerTests.cs
  modified:
    - backend/src/SafePath.Application/Geofencing/GeofenceTracer.cs
    - backend/src/SafePath.Api/Controllers/GeofenceCandidatesController.cs
key-decisions:
  - "The existing create route remains canonical but is now owned by GeofencesController, avoiding a second endpoint family or an ambiguous POST route."
  - "Every config mutation issues a strictly newer registration generation; only that latest generation can be acknowledged or used for candidate submission."
requirements-completed: [GEO-01]
coverage:
  - id: D1
    description: Guardian safe-zone CRUD validates all server-authoritative configuration and invalidates stale registrations.
    requirement: GEO-01
    verification:
      - kind: unit
        ref: dotnet test backend/tests/SafePath.Application.Tests --filter "FullyQualifiedName~ZoneCommandTests"
        status: pass
    human_judgment: false
  - id: D2
    description: HTTP role, IDOR, malformed-input, capacity-conflict, registration-sync, and retained-activity contracts.
    requirement: GEO-01
    verification:
      - kind: integration
        ref: dotnet test backend/tests/SafePath.Api.IntegrationTests --filter "FullyQualifiedName~GeofencesControllerTests"
        status: pass
    human_judgment: true
    rationale: "Root follow-up stopped the exact same-repo SafePath.Api process (PID 17816), then the focused HTTP integration suite passed outside the sandbox write boundary."
duration: 47min
completed: 2026-08-14
status: complete
---

# Phase 04 Plan 06: Guardian geofence CRUD Summary

**Guardian-safe-zone CRUD now validates canonical D-01–D-09 configuration server-side, limits active zones to twenty, and binds device sync and candidate acceptance to the latest server-issued registration generation.**

## Performance

- **Duration:** 47 min
- **Completed:** 2026-08-14
- **Tasks:** 2/2
- **Files modified:** 8

## Accomplishments

- Added Guardian-only create, list, get, update, disable, and retention-safe delete handlers with finite geometry, enum, active-membership, active-Guardian-recipient, and 20-zone validation.
- Moved the existing canonical create URL to `GeofencesController`; no duplicate route family was introduced.
- Issued a new registration generation for every update, disable, or delete, and restricted acknowledgement and candidate submission to the current generation.
- Added focused unit coverage and HTTP contract coverage for authorization, IDOR, conflicts, sync state, and retained activity.

## Task Commits

1. **Task 1: Complete Guardian CRUD and validation** - `21a8775` (TDD RED), `96e780b` (feat GREEN)
2. **Task 2: Prove REST role, IDOR, conflict, and sync contracts** - `84879e4` (test)

## Verification

- Passed: `F:\DevTools\dotnet\dotnet.exe test backend/tests/SafePath.Application.Tests --filter "FullyQualifiedName~ZoneCommandTests" --no-restore` — 4/4 tests.
- Passed: `F:\DevTools\dotnet\dotnet.exe test F:\SafepathAI.v2\backend\tests\SafePath.Api.IntegrationTests --filter "FullyQualifiedName~GeofencesControllerTests"` — 4/4 tests. Root follow-up first stopped the exact same-repo `SafePath.Api` PID 17816 that was locking output DLLs, then reran the command outside the sandbox write boundary.

## Decisions Made

- Empty recipient input defaults to the authenticated Guardian, so every zone has at least one active Guardian recipient without trusting a client role or family field.
- Disable and delete are both soft deactivations: monitoring/delivery stops, a new generation invalidates devices, and retained activity rows remain untouched.

## Deviations from Plan

### Dependency Bypass

**[Explicit user override] Implemented 04-06 before 04-05's physical tracer checkpoint completed.**

- **Reason:** The user explicitly directed phase execution despite the unsatisfied `depends_on: [04-05]` relationship.
- **Boundary:** No 04-05 evidence was fabricated, no `04-05-SUMMARY.md` was created, and 04-05 was not marked complete.

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Rewired the pre-existing canonical creation route and stale-generation paths**
- **Found during:** Task 1
- **Issue:** `GeofenceCandidatesController` already owned the canonical create URL with incomplete validation; historical registrations could still acknowledge or submit candidates after a mutation.
- **Fix:** Moved the create URL to `GeofencesController`, retained candidate compatibility endpoints, and made acknowledgement/candidate acceptance current-generation-only.
- **Files modified:** `backend/src/SafePath.Api/Controllers/GeofenceCandidatesController.cs`, `backend/src/SafePath.Application/Geofencing/GeofenceTracer.cs`
- **Verification:** Focused `ZoneCommandTests` passed, including stale-generation candidate refusal.
- **Committed in:** `96e780b`

---

**Total deviations:** 1 Rule-2 security/correctness fix and 1 explicit dependency bypass.

## Issues Encountered

- Initial focused integration attempts were blocked by the same-repo `SafePath.Api` process (PID 17816) and then by sandboxed F: build-temp writes. Root follow-up stopped that exact API process and reran the focused integration suite outside the sandbox write boundary; it passed 4/4.

## User Setup Required

None - no external service configuration is required.

## Next Phase Readiness

- Confirmation/activity work can rely on canonical current-generation device configuration and retention-safe zone deactivation.
- HTTP CRUD contracts are verified by the focused `GeofencesControllerTests` integration suite.

## Self-Check: PASSED

- Verified all eight planned/approved source and test files exist.
- Verified commits `21a8775`, `96e780b`, `84879e4`, and `e170100` exist in local history.
- Verified focused integration suite passed 4/4 after root follow-up.

---
*Phase: 04-geofencing*
*Completed: 2026-08-14*
