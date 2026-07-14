---
phase: 02-real-time-location-history-privacy
plan: 19
subsystem: backend-privacy
tags: [dotnet, ef-core, location, privacy, presence, tdd]

requires:
  - phase: 02-real-time-location-history-privacy
    provides: live-location sharing gates, dual-signal presence, profile timestamp gating
provides:
  - Ping-derived live-location recency is gated by LiveLocation sharing authorization
  - Regression tests for denied sharing plus recent ping recency
  - Preservation test for independent SignalR connection presence under denied sharing
affects: [phase-02-verification, phase-03-sos-fast-path, location-api, privacy-center]

tech-stack:
  added: []
  patterns:
    - TDD RED/GREEN backend privacy regression
    - Separate location-derived presence from independent connection presence

key-files:
  created:
    - .planning/phases/02-real-time-location-history-privacy/02-19-SUMMARY.md
  modified:
    - backend/tests/SafePath.Application.Tests/Location/GetLiveLocationsQueryTests.cs
    - backend/src/SafePath.Application/Location/GetLiveLocationsQuery.cs

key-decisions:
  - "Ping-derived IsOnline recency is treated as LiveLocation data and is false when canViewLocation is false."
  - "Independent IPresenceQuery.IsOnline connection presence remains visible under denied LiveLocation sharing, preserving D-03."

patterns-established:
  - "Denied LiveLocation tests must seed an explicit disabled SharingPreference for the caller recipient row."
  - "Location-derived DTO fields and location-derived status signals must use the same canViewLocation decision."

requirements-completed: [PRIV-02, LOC-02]

coverage:
  - id: D1
    description: "A viewer denied LiveLocation sharing cannot infer recent location-ping activity through IsOnline."
    requirement: PRIV-02
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Location/GetLiveLocationsQueryTests.cs#Handle_DoesNotUseRecentPingForIsOnlineWhenLiveLocationSharingDenied"
        status: pass
      - kind: other
        ref: "cd backend && dotnet test tests/SafePath.Application.Tests/SafePath.Application.Tests.csproj --filter \"FullyQualifiedName~GetLiveLocationsQueryTests\""
        status: pass
    human_judgment: false
  - id: D2
    description: "Independent SignalR connection presence remains able to mark a member online when LiveLocation sharing is denied."
    requirement: LOC-02
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Location/GetLiveLocationsQueryTests.cs#Handle_PreservesConnectionPresenceWhenLiveLocationSharingDenied"
        status: pass
      - kind: other
        ref: "cd backend && dotnet test tests/SafePath.Application.Tests/SafePath.Application.Tests.csproj"
        status: pass
    human_judgment: false
  - id: D3
    description: "Denied LiveLocation sharing continues to null location-derived fields, ProfileImageUrl, and ProfileUpdatedAt."
    requirement: PRIV-02
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Location/GetLiveLocationsQueryTests.cs#Handle_DoesNotUseRecentPingForIsOnlineWhenLiveLocationSharingDenied"
        status: pass
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Location/GetLiveLocationsQueryTests.cs#Handle_PreservesConnectionPresenceWhenLiveLocationSharingDenied"
        status: pass
    human_judgment: false

duration: 20min
completed: 2026-07-14
status: complete
---

# Phase 02 Plan 19: Live Presence Privacy Gate Summary

**Live-location ping recency is now sharing-gated while independent connection presence remains intact.**

## Performance

- **Duration:** 20 min
- **Started:** 2026-07-14T22:39:00Z
- **Completed:** 2026-07-14T22:59:05Z
- **Tasks:** 2 completed
- **Files modified:** 3

## Accomplishments

- Added RED regressions for denied LiveLocation sharing with a fresh location ping, proving the pre-fix `IsOnline` leak.
- Changed `GetLiveLocationsQueryHandler` so `isRecent` is false unless `canViewLocation` is true.
- Preserved `_presence.IsOnline(member.UserId)` as an independent connection-presence signal under denied LiveLocation sharing.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add regression tests for denied sharing plus recent ping recency** - `97269df` (test)
2. **Task 2: Gate only location-ping recency behind canViewLocation** - `7686571` (fix)

**Plan metadata:** committed separately as the GSD close-out commit.

## Files Created/Modified

- `backend/tests/SafePath.Application.Tests/Location/GetLiveLocationsQueryTests.cs` - Added the denied-sharing privacy regression and connection-presence preservation tests.
- `backend/src/SafePath.Application/Location/GetLiveLocationsQuery.cs` - Gated only the latest-ping recency contribution behind `canViewLocation`.
- `.planning/phases/02-real-time-location-history-privacy/02-19-SUMMARY.md` - Captures execution, verification, deviations, and self-check.

## Decisions Made

- Ping-derived `IsOnline` recency is LiveLocation-derived data, so it must not cross a denied `SharedDataType.LiveLocation` sharing boundary.
- Connection presence from `IPresenceQuery.IsOnline` remains separate from location sharing, matching D-03 and the plan's accepted threat posture.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Stopped local API process locking backend build outputs**
- **Found during:** Task 2 verification
- **Issue:** `dotnet build SafePath.sln` failed because `SafePath.Api.exe` process `24900` held `SafePath.Domain.dll`, `SafePath.Application.dll`, and `SafePath.Infrastructure.dll` in `src/SafePath.Api/bin/Debug/net9.0`.
- **Fix:** Identified the process path, stopped the local `SafePath.Api` process, and reran the build.
- **Files modified:** None
- **Verification:** `cd backend && dotnet build SafePath.sln` succeeded with 0 warnings and 0 errors after the process was stopped.
- **Committed in:** Not applicable - environment-only verification unblock

---

**Total deviations:** 1 auto-fixed (1 blocking environment issue)
**Impact on plan:** No code-scope expansion. The build lock was unrelated to the implementation and was resolved only to complete required verification.

## Issues Encountered

- RED gate behaved as expected: `Handle_DoesNotUseRecentPingForIsOnlineWhenLiveLocationSharingDenied` failed before the handler change with `Assert.False()` because `IsOnline` was true from recent ping recency.
- Initial backend build attempt was blocked by the already-running local API process described above; rerun passed after stopping it.

## Verification

- RED check after Task 1: `cd backend && dotnet test tests/SafePath.Application.Tests/SafePath.Application.Tests.csproj --filter "FullyQualifiedName~GetLiveLocationsQueryTests"` failed as expected: 1 failed, 11 passed, 12 total.
- GREEN scoped check after Task 2: same command passed: 12/12.
- Backend regression check: `cd backend && dotnet test tests/SafePath.Application.Tests/SafePath.Application.Tests.csproj` passed: 105/105.
- Backend build check: `cd backend && dotnet build SafePath.sln` passed with 0 warnings and 0 errors after clearing the local file lock.

## Known Stubs

None. Stub scan found only intentional nullable defaults in backend constructors/entities/tests, not placeholders or unwired UI data.

## Threat Flags

None. This plan changed an existing authenticated read handler and tests only; it did not introduce new network endpoints, schema changes, auth paths, file access, or package dependencies.

## Authentication Gates

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

CR-01 is closed for automated backend verification: denied LiveLocation sharing no longer leaks recent ping activity through `IsOnline`, while D-03 connection presence remains preserved. The separate physical-device retest for UAT 73 cold-start avatar behavior remains recorded in `02-VERIFICATION.md` and is outside this backend-only gap closure.

## Self-Check: PASSED

- Summary file exists at `.planning/phases/02-real-time-location-history-privacy/02-19-SUMMARY.md`.
- Task commits exist: `97269df`, `7686571`.
- Key files exist: `backend/tests/SafePath.Application.Tests/Location/GetLiveLocationsQueryTests.cs`, `backend/src/SafePath.Application/Location/GetLiveLocationsQuery.cs`.
- Required verification commands completed with the results listed above.

---
*Phase: 02-real-time-location-history-privacy*
*Completed: 2026-07-14*
