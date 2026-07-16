---
phase: 02-real-time-location-history-privacy
plan: 04
subsystem: backend-location-history
tags: [location-history, privacy, ef-core, tdd, clean-architecture]

# Dependency graph
requires:
  - phase: 02-real-time-location-history-privacy
    provides: LocationPing persistence, GeoMath.HaversineMeters, DwellTimeDefaults, SharingPreference History gate
provides:
  - StopDetection.DetectStops pure dwell-time clustering using DwellTimeDefaults and GeoMath
  - GetLocationHistoryQuery returning bounded ordered polyline points and detected stops
  - GetTravelStatsQuery returning total distance, time away, and stop count
  - LocationController history and travel-stats endpoints gated by current user, membership, target re-scope, and History sharing
affects: [02-08, 04-geofencing, 05-ai-analytics]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "History reads always execute RequireMembership, target-in-family re-scope, then SharedDataType.History authorization before querying LocationPings."
    - "Location history and stats use bounded UserId + RecordedAtUtc range reads over the existing composite index."
    - "Read-time stop detection remains a pure Application utility and reuses DwellTimeDefaults for Phase 4 consistency."

key-files:
  created:
    - backend/src/SafePath.Application/Location/StopDetection.cs
    - backend/src/SafePath.Application/Location/GetLocationHistoryQuery.cs
    - backend/src/SafePath.Application/Location/GetTravelStatsQuery.cs
    - backend/tests/SafePath.Application.Tests/Location/StopDetectionTests.cs
    - backend/tests/SafePath.Application.Tests/Location/GetLocationHistoryQueryTests.cs
    - backend/tests/SafePath.Application.Tests/Location/GetTravelStatsQueryTests.cs
  modified:
    - backend/src/SafePath.Application/Location/LocationDtos.cs
    - backend/src/SafePath.Application/DependencyInjection.cs
    - backend/src/SafePath.Api/Controllers/LocationController.cs

key-decisions:
  - "TimeAway is defined as the elapsed time between the first and last ping in the requested range, or zero when the range has fewer than two pings."
  - "StopDetection represents a stop using the average latitude/longitude of the dwell cluster and the first/last cluster timestamps."
  - "History and travel-stats authorization intentionally uses SharedDataType.History, independent of LiveLocation sharing."

patterns-established:
  - "Use StopDetection.DetectStops for read-time dwell clustering before adding geofence-specific divergence."
  - "Use the same membership -> target re-scope -> History sharing sequence for all historical location read surfaces."

requirements-completed: [HIST-01, HIST-02, HIST-03]

coverage:
  - id: D1
    description: "StopDetection.DetectStops converts raw pings into stays using the shared 100m/5min dwell defaults and handles movement, split clusters, and empty inputs."
    requirement: HIST-01
    verification:
      - kind: unit
        ref: "dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Location.StopDetectionTests"
        status: pass
    human_judgment: false
  - id: D2
    description: "GetLocationHistoryQuery returns authorized, bounded, ordered route polyline points and detected stops for a family member."
    requirement: HIST-02
    verification:
      - kind: unit
        ref: "dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Location.GetLocationHistoryQueryTests"
        status: pass
    human_judgment: false
  - id: D3
    description: "GetTravelStatsQuery returns total distance, time away, and stop count for an authorized bounded history range."
    requirement: HIST-03
    verification:
      - kind: unit
        ref: "dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Location.GetTravelStatsQueryTests"
        status: pass
    human_judgment: false
  - id: D4
    description: "LocationController exposes GET history and travel-stats endpoints deriving caller identity from ICurrentUserService and mapping authorization denial to 403."
    requirement: HIST-01
    verification:
      - kind: integration
        ref: "dotnet build backend/SafePath.sln"
        status: pass
      - kind: other
        ref: "Select-String LocationController.cs for /history, /travel-stats, ICurrentUserService, Forbid"
        status: pass
    human_judgment: false

duration: 7min
completed: 2026-07-12
status: complete
---

# Phase 02 Plan 04: Location History + Route + Travel Stats Summary

**Bounded historical location reads with dwell-time stops, route polyline points, travel stats, and server-side History privacy gates.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-07-12T20:40:43Z
- **Completed:** 2026-07-12T20:47:10Z
- **Tasks:** 3 completed
- **Files modified:** 9 plan files plus this summary

## Accomplishments

- Added `StopDetection.DetectStops`, a pure dwell-time clustering function using `DwellTimeDefaults` and `GeoMath`.
- Added `GetLocationHistoryQuery` returning ordered bounded polyline points plus detected stops.
- Added `GetTravelStatsQuery` returning total Haversine distance, elapsed time away, and stop count.
- Added `GET families/{familyId}/members/{targetUserId}/history` and `GET families/{familyId}/members/{targetUserId}/travel-stats`.
- Enforced membership, target-in-family re-scope, and `SharedDataType.History` sharing authorization before historical pings are read.

## Task Commits

Each TDD task was committed atomically:

1. **Task 1 RED: StopDetection dwell-time tests** - `5c2b3f1` (test)
2. **Task 1 GREEN: StopDetection dwell clustering** - `b83461e` (feat)
3. **Task 2 RED: Location history query tests** - `2111b4b` (test)
4. **Task 2 GREEN: Gated history query** - `7f9d390` (feat)
5. **Task 3 RED: Travel stats query tests** - `c8fbf63` (test)
6. **Task 3 GREEN: Travel stats and endpoints** - `055756d` (feat)

**Plan metadata:** pending close-out commit

## Files Created/Modified

- `backend/src/SafePath.Application/Location/StopDetection.cs` - Pure stop detection over ordered pings.
- `backend/src/SafePath.Application/Location/GetLocationHistoryQuery.cs` - History timeline and polyline read handler with IDOR/privacy gates.
- `backend/src/SafePath.Application/Location/GetTravelStatsQuery.cs` - Distance/time-away/stop-count stats handler with the same gates.
- `backend/src/SafePath.Application/Location/LocationDtos.cs` - Added history point/history/stats DTOs.
- `backend/src/SafePath.Application/DependencyInjection.cs` - Registered history and stats handlers.
- `backend/src/SafePath.Api/Controllers/LocationController.cs` - Added history and travel-stats GET endpoints.
- `backend/tests/SafePath.Application.Tests/Location/StopDetectionTests.cs` - Stop-detection behavior tests.
- `backend/tests/SafePath.Application.Tests/Location/GetLocationHistoryQueryTests.cs` - History authorization/range tests.
- `backend/tests/SafePath.Application.Tests/Location/GetTravelStatsQueryTests.cs` - Stats authorization/range tests.

## Decisions Made

- Time away is the elapsed time between the first and last ping in the bounded range. This is simple, deterministic, and documented on `TravelStatsDto`.
- Stop coordinates use the average of pings in a dwell cluster, which gives a stable representative point without adding geocoding or rollups.
- The new history surfaces use `SharedDataType.History`; disabling live location does not automatically disable history, and disabling history does not depend on live sharing.

## Deviations from Plan

None - plan executed as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None. Stub-pattern scanning of the plan-created/modified production files found no placeholder UI data or mock-only production paths; matches were optional parameters and test fixture null values.

## Verification

- `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Location.StopDetectionTests` - passed, 4 tests.
- `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Location.GetLocationHistoryQueryTests` - passed, 5 tests.
- `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Location.GetTravelStatsQueryTests` - passed, 4 tests.
- `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Location` - passed, 26 tests.
- `dotnet build backend/SafePath.sln` - passed, 0 warnings/errors.
- Source scans confirmed `StopDetection` references `DwellTimeDefaults`, history/stats handlers use bounded `RecordedAtUtc` range filters, and endpoints derive caller id from `ICurrentUserService`.

## TDD Gate Compliance

- RED commits present: `5c2b3f1`, `2111b4b`, `c8fbf63`
- GREEN commits present after RED: `b83461e`, `7f9d390`, `055756d`
- No refactor commit was needed.

## Next Phase Readiness

- Plan 02-08 can consume the backend history and stats endpoints for mobile timeline, route, and stats screens.
- Phase 4 can reuse `DwellTimeDefaults` and `StopDetection` as the baseline for geofence dwell behavior, or deliberately diverge with a documented reason.
- Phase 5 can build higher-level movement analytics on the same bounded history query pattern.

---
*Phase: 02-real-time-location-history-privacy*
*Completed: 2026-07-12*

## Self-Check: PASSED

Created/modified plan artifacts exist on disk (`StopDetection.cs`, `GetLocationHistoryQuery.cs`, `GetTravelStatsQuery.cs`, `LocationController.cs`, and `02-04-SUMMARY.md`); task commits `5c2b3f1`, `b83461e`, `2111b4b`, `7f9d390`, `c8fbf63`, and `055756d` are present in git log; final verification commands listed above passed.
