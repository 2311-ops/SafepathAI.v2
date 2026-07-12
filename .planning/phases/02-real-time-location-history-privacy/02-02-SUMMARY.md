---
phase: 02-real-time-location-history-privacy
plan: 02
subsystem: backend-location
tags: [ef-core, signalr, location, presence, clean-architecture, sqlite-tests]

# Dependency graph
requires:
  - phase: 02-real-time-location-history-privacy
    provides: Authenticated SignalR LocationHub, PresenceTracker, ILocationBroadcastService, Supabase subject user identity
provides:
  - LocationPing entity, EF configuration, DbSet, and AddLocationPing migration
  - GeoMath.HaversineMeters and DwellTimeDefaults shared thresholds
  - ReportLocationCommand handler that persists pings then broadcasts family updates
  - LocationHub.ReportLocation method deriving caller identity from Context.UserIdentifier
  - GetLiveLocationsQuery and LocationController GET endpoint for family-scoped last-known positions
  - IPresenceQuery Application seam implemented by Infrastructure PresenceTracker
affects: [02-03, 02-04, 02-06, 02-07, 03-sos-fast-path, 04-geofencing]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Application owns location DTOs under SafePath.Application.Location; Infrastructure hub/client code consumes that contract."
    - "Location writes persist first, then broadcast through ILocationBroadcastService."
    - "Read-side presence combines IPresenceQuery connection state with recent ping recency."
    - "Location read/write handlers re-check family membership before touching or returning family-scoped data."

key-files:
  created:
    - backend/src/SafePath.Domain/Entities/LocationPing.cs
    - backend/src/SafePath.Domain/Constants/DwellTimeDefaults.cs
    - backend/src/SafePath.Application/Location/GeoMath.cs
    - backend/src/SafePath.Application/Location/LocationDtos.cs
    - backend/src/SafePath.Application/Location/ReportLocationCommand.cs
    - backend/src/SafePath.Application/Location/GetLiveLocationsQuery.cs
    - backend/src/SafePath.Application/Common/Interfaces/IPresenceQuery.cs
    - backend/src/SafePath.Infrastructure/Persistence/EntityConfigurations/LocationPingConfiguration.cs
    - backend/src/SafePath.Infrastructure/Persistence/Migrations/20260712195036_AddLocationPing.cs
    - backend/src/SafePath.Api/Controllers/LocationController.cs
    - backend/tests/SafePath.Application.Tests/Location/ReportLocationCommandHandlerTests.cs
  modified:
    - backend/src/SafePath.Application/Common/Interfaces/IApplicationDbContext.cs
    - backend/src/SafePath.Application/Common/Interfaces/ILocationBroadcastService.cs
    - backend/src/SafePath.Application/DependencyInjection.cs
    - backend/src/SafePath.Infrastructure/DependencyInjection.cs
    - backend/src/SafePath.Infrastructure/Persistence/ApplicationDbContext.cs
    - backend/src/SafePath.Infrastructure/Persistence/Migrations/ApplicationDbContextModelSnapshot.cs
    - backend/src/SafePath.Infrastructure/RealTime/LocationHub.cs
    - backend/src/SafePath.Infrastructure/RealTime/PresenceTracker.cs
    - backend/tests/SafePath.Application.Tests/Location/GetLiveLocationsQueryTests.cs

key-decisions:
  - "Location DTOs were moved from Common.Interfaces into SafePath.Application.Location so the feature contract is owned by Application but grouped with the location subsystem."
  - "GetLiveLocationsQuery uses a 2-minute ping freshness window and ORs it with live connection state, preserving the connected-but-stale case through RecordedAtUtc."
  - "ReportLocationCommand adds battery percent and accuracy sanity validation in addition to required coordinate/timestamp validation, matching the plan threat register."
  - "The AddLocationPing migration was narrowed to only the new LocationPings table/index after EF scaffolded stale role-column snapshot drift from prior hand-authored migration state."

patterns-established:
  - "Never accept a reported location user ID from a client payload; hub writes must use Context.UserIdentifier."
  - "Family-scoped location reads must call RequireMembership before querying pings."
  - "Infrastructure presence implementations must be exposed to Application via IPresenceQuery."
  - "Raw location pings use plain double latitude/longitude columns and a non-unique (UserId, RecordedAtUtc) index."

requirements-completed: [LOC-01, LOC-02, LOC-03]

coverage:
  - id: D1
    description: "Raw location pings persist through EF Core with a non-unique (UserId, RecordedAtUtc) index, and shared dwell/distance utilities are centralized for later history/geofence work."
    requirement: LOC-01
    verification:
      - kind: unit
        ref: "dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Location.GetLiveLocationsQueryTests"
        status: pass
      - kind: integration
        ref: "dotnet build backend/SafePath.sln"
        status: pass
    human_judgment: false
  - id: D2
    description: "ReportLocationCommand persists a caller-owned LocationPing and broadcasts the saved values to eligible active family members through ILocationBroadcastService."
    requirement: LOC-01
    verification:
      - kind: unit
        ref: "dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Location.ReportLocationCommandHandlerTests"
        status: pass
    human_judgment: false
  - id: D3
    description: "LocationHub.ReportLocation derives the user ID from Context.UserIdentifier and never accepts a spoofable user ID in the request payload."
    requirement: LOC-02
    verification:
      - kind: unit
        ref: "grep/Select-String LocationHub.cs for Context.UserIdentifier and absence of request.UserId"
        status: pass
    human_judgment: false
  - id: D4
    description: "GET families/{familyId}/live-locations returns one entry per active family member with latest ping, accuracy, battery, timestamp, and dual-signal online status."
    requirement: LOC-02
    verification:
      - kind: unit
        ref: "dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Location.GetLiveLocationsQueryTests"
        status: pass
    human_judgment: false
  - id: D5
    description: "Location reads and writes are IDOR-gated by RequireMembership before returning or recording family-scoped data."
    requirement: LOC-03
    verification:
      - kind: unit
        ref: "GetLiveLocationsQueryTests.Handle_ByNonMember_IsDeniedBeforeReturningLocationRows"
        status: pass
      - kind: unit
        ref: "ReportLocationCommandHandlerTests valid command uses FamilyAuthorizationService membership gate"
        status: pass
    human_judgment: false

duration: 8min
completed: 2026-07-12
status: complete
---

# Phase 02 Plan 02: Location Persistence + Live Broadcast Summary

**Backend location spine with persisted raw pings, authenticated SignalR reporting, and family-scoped live-location initial load.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-07-12T19:49:15Z
- **Completed:** 2026-07-12T19:57:29Z
- **Tasks:** 3 completed
- **Files modified:** 24 plan files

## Accomplishments

- Added `LocationPing` persistence with EF configuration, migration, DbSet exposure, and SQLite round-trip coverage.
- Added `GeoMath.HaversineMeters` and `DwellTimeDefaults` (`100m`, `5min`) for Phase 4/history reuse.
- Added `ReportLocationCommandHandler` to membership-check, validate, persist, and broadcast reported pings.
- Added `LocationHub.ReportLocation` with spoofing mitigation: caller ID comes from `Context.UserIdentifier`, not request payload.
- Added `GetLiveLocationsQuery`, `IPresenceQuery`, and `LocationController` GET route returning active family members with latest pings and dual-signal online status.

## Task Commits

Each TDD task was committed atomically:

1. **Task 1 RED: Location foundation tests** - `05e020a` (test)
2. **Task 1 GREEN: LocationPing entity/config/migration + GeoMath/defaults** - `5579f5c` (feat)
3. **Task 2 RED: ReportLocationCommand tests** - `c114964` (test)
4. **Task 2 GREEN: ReportLocationCommand + hub method** - `66ab051` (feat)
5. **Task 3 RED: GetLiveLocationsQuery tests** - `449be5e` (test)
6. **Task 3 GREEN: live locations query/controller/presence seam** - `f7118ae` (feat)

**Plan metadata:** pending close-out commit

## Files Created/Modified

- `backend/src/SafePath.Domain/Entities/LocationPing.cs` - Raw append-only location ping entity.
- `backend/src/SafePath.Domain/Constants/DwellTimeDefaults.cs` - Shared stop/dwell defaults.
- `backend/src/SafePath.Application/Location/GeoMath.cs` - Haversine distance helper.
- `backend/src/SafePath.Application/Location/LocationDtos.cs` - Application-owned location, presence, and live-location DTOs.
- `backend/src/SafePath.Application/Location/ReportLocationCommand.cs` - Persist-then-broadcast location write handler.
- `backend/src/SafePath.Application/Location/GetLiveLocationsQuery.cs` - Family-scoped live-location initial-load query.
- `backend/src/SafePath.Application/Common/Interfaces/IPresenceQuery.cs` - Application seam over infrastructure connection presence.
- `backend/src/SafePath.Api/Controllers/LocationController.cs` - Authorized live-locations REST endpoint.
- `backend/src/SafePath.Infrastructure/RealTime/LocationHub.cs` - Added `ReportLocation` hub method.
- `backend/src/SafePath.Infrastructure/RealTime/PresenceTracker.cs` - Implements `IPresenceQuery`.
- `backend/tests/SafePath.Application.Tests/Location/*.cs` - TDD coverage for persistence, reporting, validation, IDOR, and presence.

## Decisions Made

- Kept location storage as plain `double` latitude/longitude columns; no PostGIS/NetTopologySuite dependency was introduced.
- Chose a 2-minute freshness window for "recent ping" presence. A member with an open SignalR connection and a 30-minute-old ping is still online, while the old `RecordedAtUtc` remains available for stale-pin rendering.
- Kept ReportLocation as a SignalR hub write, not a REST write; REST only serves initial-load reads in this plan.
- Used `ArgumentException` for input validation failures, matching the current Application-layer family command style.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Removed unrelated role-column operations from generated migration**
- **Found during:** Task 1 migration review
- **Issue:** `dotnet ef migrations add AddLocationPing` scaffolded stale model-snapshot drift for `Users.Role` and `FamilyMembers.Role` in addition to the planned `LocationPings` table.
- **Fix:** Narrowed `20260712195036_AddLocationPing.cs` to only create/drop `LocationPings` and its `(UserId, RecordedAtUtc)` index while leaving the updated model snapshot intact.
- **Files modified:** `backend/src/SafePath.Infrastructure/Persistence/Migrations/20260712195036_AddLocationPing.cs`
- **Verification:** `dotnet build backend/SafePath.sln`; migration inspection
- **Committed in:** `5579f5c`

**2. [Rule 2 - Missing Critical] Added battery/accuracy validation to report payloads**
- **Found during:** Task 2 threat-model implementation
- **Issue:** The threat register included battery injection and polluted history, but the action text only explicitly named coordinate and future-timestamp checks.
- **Fix:** Added `AccuracyMeters >= 0` and `BatteryPercent` 0-100 validation before persistence.
- **Files modified:** `backend/src/SafePath.Application/Location/ReportLocationCommand.cs`
- **Verification:** `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Location.ReportLocationCommandHandlerTests`
- **Committed in:** `66ab051`

---

**Total deviations:** 2 auto-fixed (1 Rule 3 blocking generated migration issue, 1 Rule 2 validation hardening)
**Impact on plan:** Both changes preserve the planned architecture and reduce migration/security risk without broadening feature scope.

## Issues Encountered

- The first Task 1 verification command did not match the test class name; the test class was renamed to `GetLiveLocationsQueryTests` so the plan's exact filter executes it.
- The LocationPing round-trip test initially failed SQLite FK enforcement because the mirrored `Users` row was not seeded; the test fixture now seeds the expected user, matching production's Supabase-to-Users trigger model.

## User Setup Required

None - no external service configuration required for this backend-only plan.

## Known Stubs

None. Stub-pattern scanning found only intentional nullable test data and an empty in-memory test recorder list; no production placeholders or mock-only data paths were introduced.

## Verification

- `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Location` - passed, 11 tests.
- `dotnet build backend/SafePath.sln` - passed, 0 warnings/errors.
- `Select-String` confirmed `LocationPingConfiguration` has non-unique `HasIndex(p => new { p.UserId, p.RecordedAtUtc })`.
- `.csproj` grep found no `NetTopologySuite` or `PostGIS` references.
- Application-layer grep found no `Microsoft.AspNetCore.SignalR`, `PresenceTracker`, or `SafePath.Infrastructure` references.

## TDD Gate Compliance

- RED commits present: `05e020a`, `c114964`, `449be5e`
- GREEN commits present after RED: `5579f5c`, `66ab051`, `f7118ae`
- No refactor commit was needed.

## Next Phase Readiness

- Plan 02-03 can replace the current "all active family members" broadcast/read audience with SharingPreference gates.
- Plan 02-04 can build history and travel stats on the raw `LocationPings` table, `GeoMath`, and `DwellTimeDefaults`.
- Plan 02-06/02-07 can consume `GET families/{familyId}/live-locations` and SignalR `LocationUpdated` payloads for map and staleness rendering.

---
*Phase: 02-real-time-location-history-privacy*
*Completed: 2026-07-12*

## Self-Check: PASSED

Created/modified plan artifacts exist on disk (`LocationPing.cs`, `ReportLocationCommand.cs`, `GetLiveLocationsQuery.cs`, `LocationController.cs`, `02-02-SUMMARY.md`); task commits `05e020a`, `5579f5c`, `c114964`, `66ab051`, `449be5e`, and `f7118ae` are present in git log; final verification commands listed above passed.
