---
phase: 04-geofencing
plan: 08
subsystem: api
tags: [dotnet, ef-core, geofencing, activity, retention]
requires:
  - phase: 04-geofencing
    provides: durable confirmed geofence activity, feed, and routine-job records
provides:
  - Guardian-scoped newest-first geofence activity reads with composable filters
  - Paired/in-progress/unmatched visit projection with exact UTC timestamps
  - Seven-day read boundary and automatic storage cleanup for geofence activity/feed/jobs
affects: [04-09-routine-notifications, 04-14-geofence-activity-ui]
actuals:
  tokens: 9280
  tasks: 2
  commits: 4
tech-stack:
  added: []
  patterns: [family-scoped activity query, deterministic retention sweep, background cleanup worker]
key-files:
  created:
    - backend/src/SafePath.Application/Geofencing/GetGeofenceActivityQuery.cs
    - backend/src/SafePath.Infrastructure/Geofencing/GeofenceRetentionService.cs
    - backend/tests/SafePath.Application.Tests/Geofencing/GeofenceActivityQueryTests.cs
    - backend/tests/SafePath.Application.Tests/Geofencing/GeofenceRetentionTests.cs
  modified:
    - backend/src/SafePath.Application/DependencyInjection.cs
    - backend/src/SafePath.Api/Controllers/GeofencesController.cs
    - backend/src/SafePath.Infrastructure/DependencyInjection.cs
key-decisions:
  - "Activity timestamps are returned in UTC only; clients localize without server-side timezone guesses."
  - "Unmatched exits remain explicit exit rows and in-progress entries keep null duration rather than inventing paired visit data."
  - "Retention deletes expired geofence activity/feed/job rows but leaves safe zones, SOS sessions, and ordinary location history untouched."
requirements-completed: [GEO-03]
coverage:
  - id: D1
    description: Guardian activity reads are newest-first, family-scoped, filterable, and accurately pair/in-progress/unmatched transitions.
    requirement: GEO-03
    verification:
      - kind: unit
        ref: F:\DevTools\dotnet\dotnet.exe test backend/tests/SafePath.Application.Tests --filter "FullyQualifiedName~GeofenceActivityQueryTests" --no-restore
        status: pass
    human_judgment: false
  - id: D2
    description: Geofence activity/feed/job records older than the seven-day boundary are hidden at read time and purged without touching zones, SOS, or location history.
    requirement: GEO-03
    verification:
      - kind: unit
        ref: F:\DevTools\dotnet\dotnet.exe test backend/tests/SafePath.Application.Tests --filter "FullyQualifiedName~GeofenceRetentionTests" --no-restore
        status: pass
      - kind: integration
        ref: F:\DevTools\dotnet\dotnet.exe test backend/SafePath.sln --no-restore
        status: pass
    human_judgment: false
duration: 29min
completed: 2026-08-14
status: complete
---

# Phase 04 Plan 08: Geofence Activity and Retention Summary

**Guardians can now read honest, filterable safe-zone activity while expired geofence feed/history rows are automatically removed without touching SOS or core location history.**

## Performance

- **Duration:** 29 min
- **Completed:** 2026-08-14
- **Tasks:** 2/2
- **Files modified:** 7

## Accomplishments

- Added Guardian-only family and zone activity endpoints backed by a composable query.
- Returned exact UTC times for paired visits, in-progress entries, and unmatched exits; no duration is invented when pairing evidence is missing.
- Enforced the seven-day read window in the query and added a geofence-specific background retention worker.
- Verified cleanup deletes expired geofence activity/feed/job rows while preserving SafeZones, SOS sessions, and LocationPings.

## Task Commits

1. **Task 1: Query filtered paired and unmatched activity** - `44f64ae` (TDD RED), `57700b9` (feat GREEN)
2. **Task 2: Enforce seven-day read and purge boundaries** - `8302f7d` (TDD RED), `9f7e610` (feat GREEN)

## Verification

- Passed: `F:\DevTools\dotnet\dotnet.exe test backend\tests\SafePath.Application.Tests --filter "FullyQualifiedName~GeofenceActivityQueryTests" --no-restore` - 2/2 tests.
- Passed: `F:\DevTools\dotnet\dotnet.exe test backend\tests\SafePath.Application.Tests --filter "FullyQualifiedName~GeofenceRetentionTests" --no-restore` - 2/2 tests.
- Passed: `F:\DevTools\dotnet\dotnet.exe test backend\tests\SafePath.Application.Tests --filter "FullyQualifiedName~GeofenceActivityQueryTests|FullyQualifiedName~GeofenceRetentionTests" --no-restore` - 4/4 tests.
- Passed: `F:\DevTools\dotnet\dotnet.exe test backend\SafePath.sln --no-restore` - 220 application and 23 API integration tests.

## Decisions Made

- Activity pairing is performed after database materialization because visit reconstruction needs ordered in-memory state.
- The activity query clamps client-supplied date filters to the same seven-day retention boundary used by the sweeper.
- Expiration uses a strict `< nowUtc` cutoff so rows exactly at the boundary remain visible until they are truly older than the retention point.

## Deviations from Plan

None - plan scope was executed as written.

## Issues Encountered

- The first activity query implementation projected a custom record inside the EF query, which SQLite could not translate. The projection was moved after `ToListAsync` while preserving database-side filtering and ordering.
- The initial retention test seed used stale SOS/location property names; the seed was corrected to the current domain model before committing.

## User Setup Required

None - no external service configuration is required.

## Next Phase Readiness

- 04-09 routine-notification delivery can consume retained feed/job records.
- 04-14 activity UI can call the new family/zone activity endpoints and render UTC timestamps client-side.

## Self-Check: PASSED

- Verified planned files exist and are committed.
- Verified focused 04-08 tests and the full backend suite pass.
- Verified 04-05 remains incomplete and no `04-05-SUMMARY.md` was created.

---
*Phase: 04-geofencing*
*Completed: 2026-08-14*
