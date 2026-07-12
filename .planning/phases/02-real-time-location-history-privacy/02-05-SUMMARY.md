---
phase: 02-real-time-location-history-privacy
plan: 05
subsystem: backend-privacy-notifications
tags: [location, signalr, low-battery, privacy, export, delete, tdd]

requires:
  - phase: 02-real-time-location-history-privacy
    provides: LocationPing persistence, SharingPreference privacy gates, ILocationBroadcastService, PrivacyController
provides:
  - LowBatteryEvaluator alert-at-20 clear-above-25 hysteresis
  - LowBatteryAlertTracker singleton behind an Application interface
  - LowBattery SignalR client method and broadcast service fan-out
  - ReportLocationCommand low-battery falling-edge broadcast using LiveLocation recipient filtering
  - ExportMyDataQuery and DeleteMyDataCommand for caller-owned data
  - PrivacyController export, delete, and no-data-resale policy endpoints
affects: [02-07, 02-09, 03-sos-fast-path]

tech-stack:
  added: []
  patterns:
    - "Application handlers continue to depend on Application interfaces; Infrastructure owns SignalR and in-memory tracker implementations."
    - "Low-battery alerts reuse the existing LiveLocation sharing recipient filter before hub fan-out."
    - "Privacy export/delete commands scope strictly to CallerUserId and never accept a user id from client route/body."

key-files:
  created:
    - backend/src/SafePath.Application/Common/Interfaces/ILowBatteryAlertTracker.cs
    - backend/src/SafePath.Application/Location/LowBatteryEvaluator.cs
    - backend/src/SafePath.Infrastructure/RealTime/LowBatteryAlertTracker.cs
    - backend/src/SafePath.Application/Privacy/ExportMyDataQuery.cs
    - backend/src/SafePath.Application/Privacy/DeleteMyDataCommand.cs
    - backend/tests/SafePath.Application.Tests/Location/LowBatteryAlertTests.cs
    - backend/tests/SafePath.Application.Tests/Privacy/ExportDeleteTests.cs
  modified:
    - backend/src/SafePath.Application/Common/Interfaces/ILocationBroadcastService.cs
    - backend/src/SafePath.Application/Location/LocationDtos.cs
    - backend/src/SafePath.Application/Location/ReportLocationCommand.cs
    - backend/src/SafePath.Application/Privacy/PrivacyDtos.cs
    - backend/src/SafePath.Application/DependencyInjection.cs
    - backend/src/SafePath.Infrastructure/RealTime/ILocationClient.cs
    - backend/src/SafePath.Infrastructure/RealTime/LocationBroadcastService.cs
    - backend/src/SafePath.Infrastructure/DependencyInjection.cs
    - backend/src/SafePath.Api/Controllers/PrivacyController.cs

key-decisions:
  - "LowBatteryAlertTracker is injected through ILowBatteryAlertTracker to preserve the Application-to-Infrastructure boundary while still using the planned Infrastructure singleton."
  - "LowBattery alerts are sent through Clients.Users with the same eligible recipient list used for LocationUpdated, preventing non-sharing recipients from receiving battery alerts."
  - "DeleteMyDataCommand hard-deletes only LocationPings for CallerUserId and leaves other users' rows untouched; repeat calls return 0."
  - "Privacy policy text is static authenticated controller output with no DB table or new dependency."

requirements-completed: [NOTIF-01, PRIV-04, PRIV-05]

coverage:
  - id: D1
    description: "LowBatteryEvaluator fires exactly once on a <=20 downward crossing and re-arms only after battery rises above 25."
    requirement: NOTIF-01
    verification:
      - kind: unit
        ref: "dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Location.LowBatteryAlertTests"
        status: pass
    human_judgment: false
  - id: D2
    description: "ReportLocationCommand broadcasts LowBattery over the hub only after persistence, using the LiveLocation recipient filter."
    requirement: NOTIF-01
    verification:
      - kind: unit
        ref: "LowBatteryAlertTests.Handle_LowBatteryCrossing_BroadcastsOnceToEligibleLiveLocationRecipients"
        status: pass
    human_judgment: false
  - id: D3
    description: "ExportMyDataQuery returns only caller-owned LocationPing and SharingPreference rows."
    requirement: PRIV-04
    verification:
      - kind: unit
        ref: "dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Privacy.ExportDeleteTests"
        status: pass
    human_judgment: false
  - id: D4
    description: "DeleteMyDataCommand hard-deletes only caller LocationPing rows and is idempotent."
    requirement: PRIV-04
    verification:
      - kind: unit
        ref: "ExportDeleteTests.DeleteMyData_HardDeletesOnlyCallerLocationRows and DeleteMyData_IsIdempotentWhenRunTwice"
        status: pass
    human_judgment: false
  - id: D5
    description: "PrivacyController exposes authenticated export, delete, and policy routes; export uses MVC JSON options."
    requirement: PRIV-05
    verification:
      - kind: integration
        ref: "dotnet build backend/SafePath.sln -c Debug"
        status: pass
    human_judgment: false

duration: 8min
completed: 2026-07-12
status: complete
---

# Phase 02 Plan 05: Low-Battery Alert + Privacy Export/Delete Summary

**Low-battery hub alerts now fire once per threshold crossing, and the Privacy Center backend can export, delete, and explain SafePath's no-data-resale commitment.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-07-12T21:12:43Z
- **Completed:** 2026-07-12T21:20:18Z
- **Tasks:** 3 completed
- **Files modified:** 18 plan files plus this summary

## Accomplishments

- Added pure low-battery hysteresis logic (`<=20` alert, `>25` clear) with focused TDD coverage.
- Added an Infrastructure singleton tracker behind an Application interface, then wired `ReportLocationCommandHandler` to evaluate and broadcast `LowBattery` hub events.
- Extended `ILocationClient` and `ILocationBroadcastService` with a typed `LowBatteryAlertDto` fan-out.
- Added owner-scoped JSON export and hard delete command/query handlers for caller-owned location and sharing data.
- Extended `PrivacyController` with `GET privacy/export`, `DELETE privacy/my-data`, and `GET privacy/policy`.

## Task Commits

1. **Task 1 RED: Low-battery alert tests** - `6c5e068` (test)
2. **Task 1 GREEN: Low-battery evaluator/tracker/broadcast** - `64978ec` (feat)
3. **Task 2 RED: Privacy export/delete tests** - `bc3c0fe` (test)
4. **Task 2 GREEN: Owner-scoped export/delete endpoints** - `b0976cb` (feat)
5. **Task 3: No-data-resale policy endpoint** - `a979477` (feat)

## Files Created/Modified

- `backend/src/SafePath.Application/Location/LowBatteryEvaluator.cs` - Pure alert/clear hysteresis evaluator.
- `backend/src/SafePath.Application/Common/Interfaces/ILowBatteryAlertTracker.cs` - Application seam for low-battery alert state.
- `backend/src/SafePath.Infrastructure/RealTime/LowBatteryAlertTracker.cs` - Thread-safe singleton alert-state tracker.
- `backend/src/SafePath.Application/Location/ReportLocationCommand.cs` - Persists ping, broadcasts location, then conditionally broadcasts low-battery alert to eligible recipients.
- `backend/src/SafePath.Application/Privacy/ExportMyDataQuery.cs` - Caller-owned data export query.
- `backend/src/SafePath.Application/Privacy/DeleteMyDataCommand.cs` - Caller-only hard delete of location pings.
- `backend/src/SafePath.Api/Controllers/PrivacyController.cs` - Export/delete/policy endpoints.
- `backend/tests/SafePath.Application.Tests/Location/LowBatteryAlertTests.cs` and `backend/tests/SafePath.Application.Tests/Privacy/ExportDeleteTests.cs` - TDD coverage for NOTIF-01 and PRIV-04.

## Decisions Made

- Preserved Clean Architecture by adding `ILowBatteryAlertTracker`; Application code does not reference the Infrastructure tracker concrete type.
- Used the already-computed LiveLocation eligible recipient set for low-battery alerts, so a disabled LiveLocation share also suppresses battery alerts to that recipient.
- Kept delete scope intentionally narrow to location pings, matching the plan's hard-delete requirement for location/history/stats data while leaving account/family metadata and sharing settings intact.
- Kept PRIV-05 policy as static structured API output because the requirement is a retrievable commitment, not a dynamic policy-management system.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added an Application interface for LowBatteryAlertTracker**
- **Found during:** Task 1 GREEN implementation
- **Issue:** Injecting the Infrastructure concrete tracker into `ReportLocationCommandHandler` would violate the existing Application/Infrastructure boundary and would not compile cleanly from the Application project.
- **Fix:** Added `ILowBatteryAlertTracker` in Application and registered the Infrastructure `LowBatteryAlertTracker` singleton against it.
- **Files modified:** `ILowBatteryAlertTracker.cs`, `LowBatteryAlertTracker.cs`, `ReportLocationCommand.cs`, `DependencyInjection.cs`
- **Commit:** `64978ec`

## Auth Gates

None.

## Known Stubs

None. Stub-pattern scanning of plan-created/modified production files found no TODO/FIXME/placeholder/coming-soon strings or mock-only production paths. Matches were limited to test-only empty collections and unrelated pre-existing files.

## Threat Flags

None. The new hub event and privacy endpoints match the plan's threat model surfaces and mitigations: falling-edge suppression, LiveLocation sharing filter reuse, and CallerUserId-only export/delete scope.

## Verification

- `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Location.LowBatteryAlertTests` - passed, 5 tests.
- `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Privacy.ExportDeleteTests` - passed, 3 tests.
- `dotnet test backend/tests/SafePath.Application.Tests` - passed, 81 tests.
- `dotnet build backend/SafePath.sln -c Debug` - passed, 0 warnings/errors.

## TDD Gate Compliance

- RED commits present: `6c5e068`, `bc3c0fe`
- GREEN commits present after RED: `64978ec`, `b0976cb`
- No refactor commit was needed.

## Next Phase Readiness

- Plan 02-07's mobile `LowBattery` stream now has a backend event source.
- Plan 02-09 can wire Privacy Center export/delete/policy UI to stable authenticated endpoints.

---
*Phase: 02-real-time-location-history-privacy*
*Completed: 2026-07-12*

## Self-Check: PASSED

Created/modified plan artifacts exist on disk (`02-05-SUMMARY.md`, `LowBatteryEvaluator.cs`, `LowBatteryAlertTracker.cs`, `ExportMyDataQuery.cs`, `DeleteMyDataCommand.cs`, `PrivacyController.cs`); task commits `6c5e068`, `64978ec`, `bc3c0fe`, `b0976cb`, and `a979477` are present in git log; final verification commands listed above passed.
