---
phase: 02-real-time-location-history-privacy
plan: 03
subsystem: backend-privacy
tags: [privacy, sharing-preferences, ef-core, signalr, background-service, clean-architecture]

# Dependency graph
requires:
  - phase: 02-real-time-location-history-privacy
    provides: LocationPing persistence, ReportLocationCommand, GetLiveLocationsQuery, SignalR broadcast seam
provides:
  - Server-authoritative SharingPreference table and SharedDataType enum
  - ISharingAuthorizationService gate for per-data-type/per-recipient sharing
  - Privacy sharing matrix query and update command exposed through PrivacyController
  - Broadcast-time and read-time LiveLocation filtering in the location pipeline
  - BackgroundService sweep that auto-stops expired temporary sharing rows
affects: [02-04, 02-05, 02-07, 02-09, 03-sos-fast-path]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SharingPreference is a separate owner-controlled privacy axis alongside FamilyMember.Permissions."
    - "Location privacy is enforced in Application handlers through ISharingAuthorizationService before SignalR fan-out or DTO location fields are returned."
    - "Temporary sharing expiry is enforced both at authorization time and by an Infrastructure hosted sweep service."

key-files:
  created:
    - backend/src/SafePath.Domain/Entities/SharingPreference.cs
    - backend/src/SafePath.Domain/Enums/SharedDataType.cs
    - backend/src/SafePath.Application/Common/Interfaces/ISharingAuthorizationService.cs
    - backend/src/SafePath.Application/Privacy/UpdateSharingPreferenceCommand.cs
    - backend/src/SafePath.Application/Privacy/GetSharingMatrixQuery.cs
    - backend/src/SafePath.Application/Privacy/PrivacyDtos.cs
    - backend/src/SafePath.Infrastructure/Identity/SharingAuthorizationService.cs
    - backend/src/SafePath.Infrastructure/Persistence/EntityConfigurations/SharingPreferenceConfiguration.cs
    - backend/src/SafePath.Infrastructure/Persistence/Migrations/20260712200555_AddSharingPreference.cs
    - backend/src/SafePath.Infrastructure/RealTime/SharingPreferenceSweepService.cs
    - backend/src/SafePath.Api/Controllers/PrivacyController.cs
    - backend/tests/SafePath.Application.Tests/Privacy/SharingPreferenceTests.cs
    - backend/tests/SafePath.Application.Tests/Privacy/BroadcastGatingTests.cs
    - backend/tests/SafePath.Application.Tests/Privacy/SweepServiceTests.cs
  modified:
    - backend/src/SafePath.Application/Common/Interfaces/IApplicationDbContext.cs
    - backend/src/SafePath.Application/DependencyInjection.cs
    - backend/src/SafePath.Application/Location/ReportLocationCommand.cs
    - backend/src/SafePath.Application/Location/GetLiveLocationsQuery.cs
    - backend/src/SafePath.Infrastructure/DependencyInjection.cs
    - backend/src/SafePath.Infrastructure/Persistence/ApplicationDbContext.cs
    - backend/src/SafePath.Infrastructure/Persistence/Migrations/ApplicationDbContextModelSnapshot.cs
    - backend/tests/SafePath.Application.Tests/Location/ReportLocationCommandHandlerTests.cs
    - backend/tests/SafePath.Application.Tests/Location/GetLiveLocationsQueryTests.cs

key-decisions:
  - "SharingPreference rows are additive to FAM-04 PermissionLevel; PermissionLevel remains a guardian/member capability axis and is not consulted by the privacy sharing gate."
  - "Absent sharing rows default to shared-with-family, while explicit recipient rows override the null-recipient family default; expired rows are denied even before the sweep flips IsEnabled=false."
  - "PrivacyController and UpdateSharingPreferenceCommand force OwnerUserId to the authenticated caller and never accept an owner id from the client."
  - "Temporary sharing expiry uses a hosted BackgroundService plus authorization-time expiry checks; no queue or cryptography library was introduced."

patterns-established:
  - "Use ISharingAuthorizationService.FilterRecipients at broadcast time for any pushed owner data."
  - "Use ISharingAuthorizationService.CanView at read time and keep unauthorized members listed with location fields nulled."
  - "Use SharingPreferenceSweepService.SweepExpired for testable temporary-share expiry logic; the timer wrapper is not unit-tested directly."

requirements-completed: [PRIV-02, PRIV-03, PRIV-01]

coverage:
  - id: D1
    description: "SharingPreference schema, string-converted SharedDataType, migration, DbSet, and authorization service enforce default rows, explicit recipient overrides, disabled rows, and expiry."
    requirement: PRIV-02
    verification:
      - kind: unit
        ref: "dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Privacy.SharingPreferenceTests"
        status: pass
      - kind: integration
        ref: "dotnet build backend/SafePath.sln"
        status: pass
    human_judgment: false
  - id: D2
    description: "Sharing preference update/matrix handlers and PrivacyController expose caller-owned sharing settings only, with owner forced to the authenticated caller."
    requirement: PRIV-02
    verification:
      - kind: unit
        ref: "dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Privacy.BroadcastGatingTests"
        status: pass
      - kind: integration
        ref: "dotnet build backend/SafePath.sln"
        status: pass
    human_judgment: false
  - id: D3
    description: "ReportLocationCommand and GetLiveLocationsQuery enforce the double gate: active family membership plus enabled, unexpired SharingPreference."
    requirement: PRIV-02
    verification:
      - kind: unit
        ref: "dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Privacy.BroadcastGatingTests"
        status: pass
      - kind: unit
        ref: "dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Location"
        status: pass
    human_judgment: false
  - id: D4
    description: "Temporary shares auto-stop through SharingPreferenceSweepService, while read/broadcast gates deny expired rows immediately."
    requirement: PRIV-03
    verification:
      - kind: unit
        ref: "dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Privacy.SweepServiceTests"
        status: pass
      - kind: unit
        ref: "dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Privacy"
        status: pass
    human_judgment: false
  - id: D5
    description: "PRIV-01 transport posture remains HTTPS/WSS through existing UseHttpsRedirection and JWT RequireHttpsMetadata; no cryptographic package was added."
    requirement: PRIV-01
    verification:
      - kind: other
        ref: "Select-String Program.cs for UseHttpsRedirection and RequireHttpsMetadata; git diff csproj for PackageReference changes"
        status: pass
    human_judgment: false

duration: 9min
completed: 2026-07-12
status: complete
---

# Phase 02 Plan 03: Privacy Sharing Matrix + Temporary Sharing Summary

**Server-enforced per-recipient sharing preferences with temporary expiry and live-location broadcast/read double-gates.**

## Performance

- **Duration:** 9 min
- **Started:** 2026-07-12T20:03:01Z
- **Completed:** 2026-07-12T20:12:02Z
- **Tasks:** 3 completed
- **Files modified:** 24 plan files plus 1 close-out summary

## Accomplishments

- Added `SharingPreference` and `SharedDataType` with EF configuration, DbSet exposure, and `AddSharingPreference` migration.
- Added `ISharingAuthorizationService` so per-recipient privacy decisions are centralized, tested, and independent of FAM-04 `PermissionLevel`.
- Added `UpdateSharingPreferenceCommand`, `GetSharingMatrixQuery`, DTOs, DI wiring, and authenticated `PrivacyController` routes.
- Retrofitted `ReportLocationCommandHandler` and `GetLiveLocationsQueryHandler` so disabled or expired LiveLocation sharing removes recipients from SignalR fan-out and nulls read-side location fields.
- Added `SharingPreferenceSweepService` as a hosted service with a pure `SweepExpired` method for temporary sharing auto-stop.

## Task Commits

Each TDD task was committed atomically:

1. **Task 1 RED: SharingPreference gate tests** - `fa69a3b` (test)
2. **Task 1 GREEN: SharingPreference schema, migration, and authorization service** - `b6cf1c0` (feat)
3. **Task 2 RED: Broadcast/read privacy gate tests** - `4cc0d82` (test)
4. **Task 2 GREEN: Toggle/matrix handlers and location double-gate** - `646b19e` (feat)
5. **Task 3 RED: Sweep service tests** - `f112254` (test)
6. **Task 3 GREEN: Temporary sharing sweep service** - `e4a2fc5` (feat)

**Plan metadata:** pending close-out commit

## Files Created/Modified

- `backend/src/SafePath.Domain/Entities/SharingPreference.cs` - Owner-controlled per-data-type sharing row with optional recipient and expiry.
- `backend/src/SafePath.Domain/Enums/SharedDataType.cs` - LiveLocation, History, and Wellness sharing categories.
- `backend/src/SafePath.Infrastructure/Persistence/EntityConfigurations/SharingPreferenceConfiguration.cs` - `SharingPreferences` table mapping with string enum storage and query indexes.
- `backend/src/SafePath.Infrastructure/Persistence/Migrations/20260712200555_AddSharingPreference.cs` - Migration for the new table and indexes.
- `backend/src/SafePath.Application/Common/Interfaces/ISharingAuthorizationService.cs` - Application-layer privacy authorization seam.
- `backend/src/SafePath.Infrastructure/Identity/SharingAuthorizationService.cs` - Server-side recipient filtering and `CanView` implementation.
- `backend/src/SafePath.Application/Privacy/*.cs` - Update command, matrix query, and DTOs.
- `backend/src/SafePath.Api/Controllers/PrivacyController.cs` - Authenticated sharing-matrix GET and sharing-preference PATCH routes.
- `backend/src/SafePath.Application/Location/ReportLocationCommand.cs` - Broadcast-time sharing filter.
- `backend/src/SafePath.Application/Location/GetLiveLocationsQuery.cs` - Read-time sharing filter that preserves member rows and nulls unauthorized location fields.
- `backend/src/SafePath.Infrastructure/RealTime/SharingPreferenceSweepService.cs` - Hosted expiry sweep with testable `SweepExpired`.
- `backend/tests/SafePath.Application.Tests/Privacy/*.cs` - TDD coverage for sharing gates, broadcast/read filtering, commands, matrix query, and sweep behavior.

## Decisions Made

- Kept `FamilyMember.Permissions` untouched and did not use it inside `ISharingAuthorizationService`; sharing consent and member permissions remain separate authorization axes.
- Treated no preference row as shared-with-family, matching the plan's sensible default, while explicit per-recipient rows override null-recipient defaults.
- Forced `OwnerUserId` to the authenticated caller in the update command and controller; client payloads cannot set another user's owner id.
- Kept transport/security posture unchanged: HTTPS/WSS remains the privacy transport control and no new cryptographic package was added.

## Deviations from Plan

None - plan executed as written.

## Issues Encountered

- `dotnet ef migrations add AddSharingPreference` emitted the existing EF tools/runtime warning (`9.0.3` tools vs `9.0.9` runtime). The migration generated successfully and was inspected; it only adds `SharingPreferences`.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None. Stub-pattern scanning of the created/modified 02-03 production files found only intentional nullable local variables and query null checks; test files contain expected `null` and empty-list setup values.

## Verification

- `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Privacy` - passed, 11 tests.
- `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Location` - passed, 13 tests.
- `dotnet build backend/SafePath.sln` - passed, 0 warnings/errors.
- `git diff fa69a3b^..HEAD -- backend/src/SafePath.Domain/Entities/FamilyMember.cs backend/src/SafePath.Domain/Enums/PermissionLevel.cs` - empty; FAM-04 permission files unchanged.
- `Select-String backend/src/SafePath.Api/Program.cs -Pattern 'UseHttpsRedirection|RequireHttpsMetadata'` - both present.
- `.csproj` diff scan found no new `PackageReference`; no cryptographic library was added.

## TDD Gate Compliance

- RED commits present: `fa69a3b`, `4cc0d82`, `f112254`
- GREEN commits present after RED: `b6cf1c0`, `646b19e`, `e4a2fc5`
- No refactor commit was needed.

## Next Phase Readiness

- Plan 02-04 can use `ISharingAuthorizationService.CanView` when returning history rows for other users.
- Plan 02-05 can build export/delete flows on the established privacy controller pattern.
- Plan 02-09 can consume the sharing matrix endpoints for the mobile Privacy Center.

---
*Phase: 02-real-time-location-history-privacy*
*Completed: 2026-07-12*

## Self-Check: PASSED

Created/modified plan artifacts exist on disk (`SharingPreference.cs`, `ISharingAuthorizationService.cs`, `UpdateSharingPreferenceCommand.cs`, `SharingPreferenceSweepService.cs`, `PrivacyController.cs`, `02-03-SUMMARY.md`); task commits `fa69a3b`, `b6cf1c0`, `4cc0d82`, `646b19e`, `f112254`, and `e4a2fc5` are present in git log; final verification commands listed above passed.
