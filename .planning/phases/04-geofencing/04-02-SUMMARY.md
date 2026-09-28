---
phase: 04-geofencing
plan: 02
subsystem: database
tags: [dotnet, ef-core, postgresql, geofencing, quiet-hours, retention]
requires:
  - phase: 04-geofencing
    provides: authenticated safe-zone, recipient, registration, and candidate persistence
provides:
  - Durable geofence confirmation, activation, activity, feed, and routine-job records
  - Recipient-owned, disabled-by-default quiet-hours persistence
  - Applied PostgreSQL schema with activity retention and zone-deletion preservation
affects: [04-07-geofence-confirmation, routine-notifications, geofence-activity-history]
actuals:
  tokens: 26818
  tasks: 2
  commits: 3
tech-stack:
  added: []
  patterns: [EF Core relational constraints, immutable activity history, durable routine delivery jobs]
key-files:
  created:
    - backend/src/SafePath.Domain/Entities/GeofencingRecords.cs
    - backend/src/SafePath.Infrastructure/Persistence/EntityConfigurations/GeofencingConfiguration.cs
    - backend/src/SafePath.Infrastructure/Persistence/Migrations/20260811173100_AddGeofencing.cs
    - backend/tests/SafePath.Application.Tests/Geofencing/GeofencingSchemaTests.cs
  modified:
    - backend/src/SafePath.Application/Common/Interfaces/IApplicationDbContext.cs
    - backend/src/SafePath.Infrastructure/Persistence/ApplicationDbContext.cs
    - backend/src/SafePath.Infrastructure/Persistence/Migrations/ApplicationDbContextModelSnapshot.cs
key-decisions:
  - "Activities retain a nullable zone reference plus a display-name snapshot, so zone deletion cannot erase seven-day history or recipient feed rows."
  - "Quiet hours are one recipient-owned setting with local TimeOnly bounds, an IANA time-zone identifier, and an explicit disabled default; SOS has no relation to it."
  - "The generated EF snapshot is retained as output; the migration applies only additive operations because the prior tracer snapshot had not recorded its already-versioned tables."
requirements-completed: [GEO-01, GEO-02, GEO-03, NOTIF-02]
coverage:
  - id: D1
    description: Normalized recipient, registration-generation, candidate, confirmation, and activation schema constraints
    requirement: GEO-02
    verification:
      - kind: unit
        ref: dotnet test backend/tests/SafePath.Application.Tests --filter "FullyQualifiedName~GeofencingSchemaTests"
        status: pass
      - kind: integration
        ref: dotnet ef database update --project backend/src/SafePath.Infrastructure --startup-project backend/src/SafePath.Api
        status: pass
    human_judgment: false
  - id: D2
    description: Durable activity, recipient feed, routine-job, visit-pairing, and seven-day retention schema
    requirement: GEO-03
    verification:
      - kind: unit
        ref: backend/tests/SafePath.Application.Tests/Geofencing/GeofencingSchemaTests.cs
        status: pass
      - kind: integration
        ref: dotnet test backend/SafePath.sln
        status: pass
    human_judgment: false
  - id: D3
    description: Recipient-owned quiet-hours setting defaults disabled and defers only routine delivery infrastructure
    requirement: NOTIF-02
    verification:
      - kind: unit
        ref: backend/tests/SafePath.Application.Tests/Geofencing/GeofencingSchemaTests.cs
        status: pass
      - kind: integration
        ref: dotnet ef migrations has-pending-model-changes --project backend/src/SafePath.Infrastructure --startup-project backend/src/SafePath.Api
        status: pass
    human_judgment: false
duration: 64min
completed: 2026-08-11
status: complete
---

# Phase 04 Plan 02: Geofencing persistence schema Summary

**A deployed normalized geofencing schema for durable confirmed activity, recipient feed delivery, routine jobs, and recipient-owned quiet hours.**

## Performance

- **Duration:** 64 min
- **Started:** 2026-08-11T16:40:43Z
- **Completed:** 2026-08-11T17:44:38Z
- **Tasks:** 2/2
- **Files modified:** 8

## Accomplishments

- Added constrained confirmation-candidate and per-registration activation records alongside the existing immutable native candidates.
- Added activity, recipient feed, and routine-job records with visit identity, UTC timestamps, retention indexes, and push-failure durability.
- Added a one-per-recipient quiet-hours row with disabled default, local start/end, and IANA time zone, without an SOS relationship.
- Generated, inspected, and applied the PostgreSQL migration; EF reports no pending model changes.

## Task Commits

1. **Task 1: Define normalized activity, feed, job, and recipient quiet-hours records** - `56bc5cc` (test RED), `513f631` (feat GREEN)
2. **Task 2: Generate, inspect, and apply the geofencing migration** - `30de0de` (feat)

## Files Created/Modified

- `backend/src/SafePath.Domain/Entities/GeofencingRecords.cs` - durable activity, feed, job, activation, candidate, and quiet-hours entities.
- `backend/src/SafePath.Infrastructure/Persistence/EntityConfigurations/GeofencingConfiguration.cs` - relational keys, FKs, enum constraints, defaults, and retention indexes.
- `backend/src/SafePath.Application/Common/Interfaces/IApplicationDbContext.cs` - DbSet seams for downstream application handlers.
- `backend/src/SafePath.Infrastructure/Persistence/ApplicationDbContext.cs` - concrete DbSets and geofencing model registration.
- `backend/src/SafePath.Infrastructure/Persistence/Migrations/20260811173100_AddGeofencing.cs` - applied additive PostgreSQL migration.
- `backend/tests/SafePath.Application.Tests/Geofencing/GeofencingSchemaTests.cs` - model-level uniqueness, ownership, retention, and deletion-behavior coverage.

## Decisions Made

- Activities use `SafeZoneId` with `SetNull` plus an immutable display-name snapshot, preserving history and recipient feed rows after a zone is deleted.
- Routine jobs are one-per-feed item and independently retain retry/defer state; they do not reuse SOS delivery records or policy.
- Quiet hours use `TimeOnly` local bounds and an IANA time-zone ID, and are disabled by default for every recipient.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Used EF's dependency-ordered migration identifier**
- **Found during:** Task 2
- **Issue:** The planned static `20260810000000` identifier predates the existing tracer migration `20260811160000_AddGeofenceTracer`, which would place dependent schema operations in the wrong order.
- **Fix:** Retained EF's generated `20260811173100_AddGeofencing` identifier and its generated designer/snapshot artifacts.
- **Files modified:** `20260811173100_AddGeofencing.cs`, `.Designer.cs`, `ApplicationDbContextModelSnapshot.cs`
- **Verification:** EF applied the tracer migration before this migration and then reported no pending model changes.
- **Committed in:** `30de0de`

**2. [Rule 1 - Bug] Removed duplicate predecessor table creation from the generated migration**
- **Found during:** Task 2
- **Issue:** The prior tracer migration's snapshot had not included its SafeZone, recipient, registration, and candidate tables, so EF's generated diff would have re-created those tables after the predecessor migration.
- **Fix:** Preserved the EF-generated final snapshot while replacing only duplicate predecessor creates/indexes with additive enum check constraints and matching down operations.
- **Files modified:** `backend/src/SafePath.Infrastructure/Persistence/Migrations/20260811173100_AddGeofencing.cs`
- **Verification:** Database update applied the tracer migration followed by this migration successfully, with no destructive changes to existing location, auth, family, or SOS tables.
- **Committed in:** `30de0de`

---

**Total deviations:** 2 auto-fixed (1 Rule 3 blocking issue, 1 Rule 1 migration bug)
**Impact on plan:** Both corrections preserve EF migration ordering and prevent duplicate schema creation; the final snapshot remains EF-generated and matches the model.

## Issues Encountered

- The first startup build lacked a restored analyzer package. A normal authorized restore/build resolved the existing declared dependency before EF execution.

## User Setup Required

None - the configured development connection was used privately for migration application.

## Next Phase Readiness

- Confirmation, retention, and routine-delivery handlers can now persist all resolved Phase 4 behavior without touching SOS.
- The development database contains the applied `20260811173100_AddGeofencing` migration and has no pending EF model changes.

---
*Phase: 04-geofencing*
*Completed: 2026-08-11*

## Self-Check: PASSED

- Verified all eight planned source, configuration, migration, snapshot, and schema-test files exist.
- Verified task commits `56bc5cc`, `513f631`, and `30de0de` exist in git history.
