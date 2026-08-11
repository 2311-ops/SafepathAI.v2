---
phase: 04-geofencing
plan: 01
subsystem: api
tags: [dotnet, ef-core, postgresql, geofencing, authorization]
requires:
  - phase: 01-backend-auth-foundation
    provides: authenticated current-user and family authorization seams
  - phase: 02-real-time-location-history-privacy
    provides: family membership and durable location conventions
provides:
  - Guardian-managed circular zone configuration with an assigned-member registration generation
  - Current-user-bound acknowledgement and idempotent native candidate ingestion
affects: [04-07-geofence-confirmation, android-geofence-tracer, routine-notifications]
actuals:
  tokens: 12690
  tasks: 2
  commits: 3
tech-stack:
  added: []
  patterns: [normalized geofence persistence, server-bound candidate idempotency]
key-files:
  created:
    - backend/src/SafePath.Application/Geofencing/GeofenceTracer.cs
    - backend/src/SafePath.Api/Controllers/GeofenceCandidatesController.cs
    - backend/src/SafePath.Domain/Entities/SafeZone.cs
  modified:
    - backend/src/SafePath.Infrastructure/Persistence/ApplicationDbContext.cs
key-decisions:
  - "Native callbacks remain immutable candidates; no SOS, push, activity, or notification behavior is invoked by the tracer."
  - "Candidate event IDs are globally unique and backed by a database constraint to preserve replay idempotency."
requirements-completed: [GEO-01, GEO-02]
coverage:
  - id: D1
    description: Guardian zone creation through assigned-member registration acknowledgement and candidate ingestion
    requirement: GEO-01
    verification:
      - kind: integration
        ref: dotnet test backend/tests/SafePath.Api.IntegrationTests --filter "FullyQualifiedName~GeofenceTracerEndpointTests"
        status: unknown
    human_judgment: true
    rationale: "The integration host cannot build without the repository's unconfigured SixLabors ImageSharp 4 license."
  - id: D2
    description: Candidate replay, generation binding, inactive-membership rejection, and SOS isolation
    requirement: GEO-02
    verification:
      - kind: unit
        ref: dotnet test backend/tests/SafePath.Application.Tests --filter "FullyQualifiedName~GeofenceTracerTests"
        status: unknown
    human_judgment: true
    rationale: "The test project references Infrastructure and is blocked by the same ImageSharp license configuration."
duration: 32min
completed: 2026-08-11
status: complete
---

# Phase 04 Plan 01: Geofence tracer backend Summary

**A durable, authenticated Guardian-zone to assigned-member native-candidate path with generation binding and replay-safe persistence.**

## Performance

- **Duration:** 32 min
- **Started:** 2026-08-11T15:12:00Z
- **Completed:** 2026-08-11T15:43:51Z
- **Tasks:** 2/2
- **Files modified:** 13

## Accomplishments

- Added normalized safe-zone, recipient, registration, and immutable candidate entities with a durable PostgreSQL migration.
- Added authenticated endpoints for Guardian creation, assigned-member configuration retrieval/acknowledgement, and native candidate submission.
- Bound every operation to `ICurrentUserService` plus active family authorization; candidate event IDs are replay-safe and generation-bound.
- Added endpoint and handler tests covering current-user binding, role/family checks, stale generation refusal, inactive membership, replay, and SOS isolation.

## Task Commits

1. **Task 1: Wire one authenticated zone/config/candidate path end to end** - `5fcd80f` (test RED), `027624c` (feat)
2. **Task 2: Lock caller binding, replay, and inactive-registration behavior** - `d8a0ef4` (test)

## Files Created/Modified

- `backend/src/SafePath.Domain/Entities/SafeZone.cs` - normalized zone, recipient, registration, and candidate records.
- `backend/src/SafePath.Application/Geofencing/GeofenceTracer.cs` - authorization-bound tracer contracts and handlers.
- `backend/src/SafePath.Api/Controllers/GeofenceCandidatesController.cs` - authenticated tracer HTTP API.
- `backend/src/SafePath.Infrastructure/Persistence/Migrations/20260811160000_AddGeofenceTracer.cs` - production schema for tracer persistence.
- `backend/tests/SafePath.Api.IntegrationTests/GeofenceTracerEndpointTests.cs` - end-to-end host coverage.
- `backend/tests/SafePath.Application.Tests/Geofencing/GeofenceTracerTests.cs` - focused handler and isolation coverage.

## Decisions Made

- A callback persists only as a candidate. Dwell/accuracy confirmation, activity creation, and routine notifications remain isolated for later Phase 4 plans.
- The server owns family, assigned-member, and registration-generation authority; requests cannot submit any family or recipient authority field.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added a durable migration and database uniqueness backstop**
- **Found during:** Task 1
- **Issue:** Durable production tracer persistence requires a schema migration, and an application-only replay check cannot make concurrent uploads idempotent.
- **Fix:** Added the normalized schema migration and a unique `GeofenceCandidates.EventId` index with duplicate recovery.
- **Files modified:** `ApplicationDbContext.cs`, `20260811160000_AddGeofenceTracer.cs`, `GeofenceTracer.cs`
- **Committed in:** `027624c`

---

**Total deviations:** 1 auto-fixed (Rule 2)
**Impact on plan:** Required for durable, race-safe candidate ingestion; no scope expansion into confirmation, push, or SOS behavior.

## Issues Encountered

- `dotnet test` for both planned suites is blocked before compilation by the pre-existing `SixLabors.ImageSharp` 4.0.0 build-time license requirement. No `SixLaborsLicenseKey`, `SixLaborsLicenseFile`, or `sixlabors.lic` is configured. The changed Application project built successfully with .NET SDK 9.0.316.

## User Setup Required

Configure the existing SixLabors ImageSharp license (`SIXLABORS_LICENSE_KEY`/`SixLaborsLicenseKey` or a local `sixlabors.lic`) before running the focused integration and application test suites.

## Next Phase Readiness

The Android tracer can target the production-shaped candidate endpoint after subsequent native registration/outbox work. The confirmation and routine-delivery phases can consume durable candidates without touching the SOS fast path.

## Self-Check: PASSED

- Verified all listed tracer source, migration, and test files exist.
- Verified commits `5fcd80f`, `027624c`, and `d8a0ef4` exist in git history.

---
*Phase: 04-geofencing*
*Completed: 2026-08-11*
