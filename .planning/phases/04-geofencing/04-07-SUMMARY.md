---
phase: 04-geofencing
plan: 07
subsystem: api
tags: [dotnet, ef-core, geofencing, dwell, idempotency, notifications]
requires:
  - phase: 04-geofencing
    provides: current-generation safe-zone registrations and durable geofence persistence entities
provides:
  - Accuracy-envelope and contiguous-dwell transition evaluation with server-owned sensitivity calibration
  - Exactly-once durable geofence activity, recipient feed, and routine-job fan-out before delivery
affects: [04-08-geofence-activity, 04-09-routine-notifications, mobile-geofence-candidates]
actuals:
  tokens: 13415
  tasks: 2
  commits: 4
tech-stack:
  added: []
  patterns: [pure geofence evaluator, confirmation-state persistence, durable routine-delivery outbox]
key-files:
  created:
    - backend/src/SafePath.Application/Geofencing/GeofenceTransitionEvaluator.cs
    - backend/src/SafePath.Application/Geofencing/SubmitGeofenceEvidenceCommand.cs
    - backend/src/SafePath.Application/Geofencing/GeofenceDtos.cs
  modified:
    - backend/src/SafePath.Api/Controllers/GeofenceCandidatesController.cs
    - backend/src/SafePath.Application/Geofencing/GeofenceTracer.cs
    - backend/tests/SafePath.Application.Tests/Geofencing/SubmitGeofenceEvidenceTests.cs
key-decisions:
  - "SafeZoneSensitivity.Conservative/Balanced/Responsive maps to server-owned 120/60/30-second dwell and 50/30/15-metre hysteresis values."
  - "Candidate upload returns Waiting while contiguous clear-side evidence accumulates; only confirmed evidence creates activity/feed/job records."
  - "GeofenceCandidate.EventId remains the immutable, unique idempotency key; replays return Duplicate without adding delivery records."
requirements-completed: [GEO-02, NOTIF-02]
coverage:
  - id: D1
    description: Accuracy-aware clear-side envelopes, contiguous dwell, reset behavior, and all three sensitivity calibrations.
    requirement: GEO-02
    verification:
      - kind: unit
        ref: F:\DevTools\dotnet\dotnet.exe test backend/tests/SafePath.Application.Tests --filter "FullyQualifiedName~GeofenceTransitionEvaluatorTests" --no-restore
        status: pass
    human_judgment: false
  - id: D2
    description: Confirmed geofence evidence atomically creates durable activity, recipient feed rows, and pending routine jobs; replay is duplicate-safe.
    requirement: NOTIF-02
    verification:
      - kind: unit
        ref: F:\DevTools\dotnet\dotnet.exe test backend/tests/SafePath.Application.Tests --filter "FullyQualifiedName~SubmitGeofenceEvidenceTests" --no-restore
        status: pass
      - kind: integration
        ref: F:\DevTools\dotnet\dotnet.exe test backend/tests/SafePath.Api.IntegrationTests --filter "FullyQualifiedName~GeofenceTracerEndpointTests|FullyQualifiedName~GeofencesControllerTests" --no-restore
        status: pass
    human_judgment: false
duration: 32min
completed: 2026-08-14
status: complete
---

# Phase 04 Plan 07: Drift-Resistant Confirmation Summary

**Server-owned geofence evidence now requires accuracy-safe, contiguous dwell before atomically recording one routine activity, recipient feed entries, and queued delivery jobs.**

## Performance

- **Duration:** 32 min
- **Started:** 2026-08-14T00:12:17Z
- **Completed:** 2026-08-14T00:44:17Z
- **Tasks:** 2/2
- **Files modified:** 9

## Accomplishments

- Added a pure evaluator that treats boundary-overlapping accuracy as ambiguous, rejects out-of-order evidence, resets clear-side dwell on reversal, and maps each sensitivity to its D-07 timing/hysteresis calibration.
- Replaced accepted-only candidate handling with Waiting, Reset, Confirmed, and Duplicate outcomes while keeping the existing `POST /geofences/candidates` route.
- Made confirmed transitions durable before delivery: activity, eligible-recipient feed rows, and pending routine jobs are saved together; no push, AlertHub, or SOS operation is invoked in the ingestion path.

## Task Commits

1. **Task 1: Implement the clear-side envelope and contiguous dwell evaluator** - `42ea710` (TDD RED), `033e41b` (feat GREEN)
2. **Task 2: Persist confirmation, feed, and jobs atomically and idempotently** - `5ee897e` (TDD RED), `fede736` (feat GREEN)

## Files Created/Modified

- `backend/src/SafePath.Application/Geofencing/GeofenceTransitionEvaluator.cs` - Pure accuracy-envelope and dwell state machine.
- `backend/src/SafePath.Application/Geofencing/SubmitGeofenceEvidenceCommand.cs` - Authorized, idempotent persistence and durable routine-delivery fan-out.
- `backend/src/SafePath.Application/Geofencing/GeofenceDtos.cs` - Typed evidence outcomes.
- `backend/src/SafePath.Api/Controllers/GeofenceCandidatesController.cs` - Existing route now exposes the evidence outcomes.
- `backend/tests/SafePath.Application.Tests/Geofencing/GeofenceTransitionEvaluatorTests.cs` - Table-driven evaluator contract tests.
- `backend/tests/SafePath.Application.Tests/Geofencing/SubmitGeofenceEvidenceTests.cs` - Durable fan-out and replay coverage.

## Verification

- Passed: `F:\DevTools\dotnet\dotnet.exe test backend/tests/SafePath.Application.Tests --filter "FullyQualifiedName~GeofenceTransitionEvaluatorTests" --no-restore` - 8 tests.
- Passed: `F:\DevTools\dotnet\dotnet.exe test backend/tests/SafePath.Application.Tests --filter "FullyQualifiedName~SubmitGeofenceEvidenceTests" --no-restore` - 3 tests.
- Passed: `F:\DevTools\dotnet\dotnet.exe test backend/SafePath.sln --no-restore` - 216 application and 23 API integration tests.

## Decisions Made

- The evaluator is pure and receives its clock explicitly, keeping geofence decision logic deterministic and independent from persistence or delivery.
- Ambiguous measurements clear accumulated dwell but return Waiting; clear evidence on the opposite side returns Reset.
- Only currently active Guardian recipients from the server-owned zone configuration receive routine feed/job records; the assigned member is included only when the zone switch is enabled.

## Deviations from Plan

### Dependency Bypass

**[Explicit user override] Executed Plan 04-07 while Plan 04-05 remains incomplete.**

- **Reason:** The user explicitly directed phase execution under any condition.
- **Boundary:** 04-07 depends directly on the completed 04-06 implementation (`934b0eb`); no 04-05 evidence was fabricated, no `04-05-SUMMARY.md` was created, and 04-05 was not marked complete.

### Auto-fixed Issues

**1. [Rule 1 - Bug] Prevented ambiguous evidence from becoming a persisted dwell start**

- **Found during:** Task 2
- **Issue:** A boundary-overlapping observation could have been reloaded as a pending clear-side dwell timestamp.
- **Fix:** Persisted ambiguous/no-clear evaluator results as Reset state and added a regression assertion that the subsequent clear observation restarts waiting.
- **Files modified:** `backend/src/SafePath.Application/Geofencing/SubmitGeofenceEvidenceCommand.cs`, `backend/tests/SafePath.Application.Tests/Geofencing/SubmitGeofenceEvidenceTests.cs`
- **Verification:** Focused evidence suite passed.
- **Committed in:** `fede736`

**2. [Rule 1 - Bug] Updated the pre-existing tracer HTTP expectation from Accepted-only to Waiting**

- **Found during:** Task 2 integration verification
- **Issue:** The old tracer contract expected the first candidate to be accepted immediately, contradicting the planned dwell confirmation behavior.
- **Fix:** Updated the focused HTTP contract to expect a 202 Waiting result while preserving the endpoint and duplicate replay contract.
- **Files modified:** `backend/tests/SafePath.Api.IntegrationTests/GeofenceTracerEndpointTests.cs`
- **Verification:** Focused geofence integration suite passed 7/7.
- **Committed in:** `fede736`

---

**Total deviations:** 2 Rule-1 correctness fixes and 1 explicit dependency bypass.

## Issues Encountered

- The initial unprivileged focused test could not write the F: project `obj` cache (`MSB3491` access denied). The required elevated verification command completed successfully; no source change was needed for that environment restriction.

## User Setup Required

None - no external service configuration is required.

## Next Phase Readiness

- Routine delivery work can consume durable pending `GeofenceRoutineJob` rows without affecting activity history or SOS.
- Activity/history work can rely on exactly-once confirmed transitions and seven-day retention timestamps.

## TDD Gate Compliance

- Passed: Task 1 contains `test(04-07)` RED commit `42ea710` followed by feat GREEN commit `033e41b`.
- Passed: Task 2 contains `test(04-07)` RED commit `5ee897e` followed by feat GREEN commit `fede736`.

## Self-Check: PASSED

- Verified all six planned summary/source/test artifacts exist.
- Verified commits `42ea710`, `033e41b`, `5ee897e`, and `fede736` exist in local history.
