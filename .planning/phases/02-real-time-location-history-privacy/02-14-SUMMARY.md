---
phase: 02-real-time-location-history-privacy
plan: 14
subsystem: backend
tags: [profile, api, signalr, signed-url, security]

requires:
  - phase: 02-real-time-location-history-privacy
    provides: User profile fields, Supabase avatar storage, and image validation from 02-13
provides:
  - Profile display-name and avatar write endpoints on /me
  - Signed profileImageUrl projection on /me and live-locations snapshots
  - Family-scoped ProfileUpdated SignalR broadcast for profile changes
affects: [profile, live-map-identity, mobile-profile-ui, map-avatar-markers]

tech-stack:
  added: []
  patterns: [TDD profile command handlers, backend-signed avatar URL factory, group-scoped SignalR profile broadcasts]

key-files:
  created:
    - backend/src/SafePath.Application/Common/ProfileImageUrlFactory.cs
    - backend/src/SafePath.Application/Profile/UpdateDisplayNameCommand.cs
    - backend/src/SafePath.Application/Profile/UploadProfileImageCommand.cs
    - backend/src/SafePath.Application/Profile/DeleteProfileImageCommand.cs
    - backend/src/SafePath.Application/Profile/ProfileProjection.cs
  modified:
    - backend/src/SafePath.Api/Controllers/MeController.cs
    - backend/src/SafePath.Application/Common/Interfaces/ILocationBroadcastService.cs
    - backend/src/SafePath.Application/DependencyInjection.cs
    - backend/src/SafePath.Application/Families/GetMeQuery.cs
    - backend/src/SafePath.Application/Families/UpdateMyRoleCommand.cs
    - backend/src/SafePath.Application/Location/GetLiveLocationsQuery.cs
    - backend/src/SafePath.Application/Location/LocationDtos.cs
    - backend/src/SafePath.Infrastructure/RealTime/ILocationClient.cs
    - backend/src/SafePath.Infrastructure/RealTime/LocationBroadcastService.cs
    - backend/tests/SafePath.Application.Tests/Profile/ProfileCommandTests.cs
    - backend/tests/SafePath.Application.Tests/Location/GetLiveLocationsQueryTests.cs
    - backend/tests/SafePath.Application.Tests/Location/LowBatteryAlertTests.cs
    - backend/tests/SafePath.Application.Tests/Location/ReportLocationCommandHandlerTests.cs
    - backend/tests/SafePath.Application.Tests/Privacy/BroadcastGatingTests.cs

key-decisions:
  - "Profile writes remain /me-only and derive CallerUserId exclusively from ICurrentUserService."
  - "Signed avatar URLs use the shared ProfileImageUrlFactory with a 1-hour TTL."
  - "ProfileUpdated is broadcast only on profile changes, while LocationUpdateDto remains the lean per-ping payload."

patterns-established:
  - "Profile command handlers return the same GetMeResult projection used by GET /me so mobile can refresh state from write responses."
  - "Live-location avatar URLs inherit the existing RequireMembership plus SharingPreference canViewLocation gate."

requirements-completed: [PROFILE-01, PROFILE-02, PROFILE-03, PROFILE-04, PROFILE-05, PROFILE-06, PROFILE-07]

coverage:
  - id: D1
    description: "PATCH /me/display-name, POST /me/profile-image, and DELETE /me/profile-image mutate only the authenticated caller's profile and return refreshed profile data."
    requirement: PROFILE-01
    verification:
      - kind: unit
        ref: "dotnet test backend/tests/SafePath.Application.Tests/SafePath.Application.Tests.csproj --filter FullyQualifiedName~ProfileCommand"
        status: pass
      - kind: other
        ref: "dotnet build backend/SafePath.sln"
        status: pass
    human_judgment: false
  - id: D2
    description: "GET /me returns displayName, profileImageUrl, profileUpdatedAt, role, email, fullName, userId, and subject."
    requirement: PROFILE-05
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Profile/ProfileCommandTests.cs#GetMe_ReturnsDisplayNameFallbackAndSignedProfileUrl"
        status: pass
    human_judgment: false
  - id: D3
    description: "GET /families/{familyId}/live-locations includes a signed profileImageUrl only when the existing live-location sharing gate allows the viewer."
    requirement: PROFILE-06
    verification:
      - kind: unit
        ref: "dotnet test backend/tests/SafePath.Application.Tests/SafePath.Application.Tests.csproj --filter FullyQualifiedName~GetLiveLocations"
        status: pass
    human_judgment: false
  - id: D4
    description: "ProfileUpdated broadcasts once per display-name/upload/delete change to the caller's active family group, without adding avatar fields to LocationUpdateDto."
    requirement: PROFILE-07
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Profile/ProfileCommandTests.cs#ProfileUpdated broadcast tests"
        status: pass
      - kind: other
        ref: "Select-String LocationDtos.cs LocationUpdateDto"
        status: pass
    human_judgment: false

duration: 10min
completed: 2026-07-13
status: complete
---

# Phase 02 Plan 14: Backend Profile Endpoints and Map Identity Propagation Summary

**Profile write APIs with signed avatar URLs on /me and live-location snapshots, plus family-scoped ProfileUpdated SignalR broadcasts.**

## Performance

- **Duration:** 10 min
- **Started:** 2026-07-13T15:45:52Z
- **Completed:** 2026-07-13T15:55:10Z
- **Tasks:** 3 completed
- **Files modified:** 19

## Accomplishments

- Added display-name, upload-avatar, and delete-avatar command handlers that orchestrate the Plan 13 validator/storage services and stamp `ProfileUpdatedAt`.
- Extended `MeController` with `PATCH /me/display-name`, `POST /me/profile-image`, `DELETE /me/profile-image`, and `GET /me` profile fields.
- Added `ProfileImageUrlFactory` and used it in `GetMeQuery` and `GetLiveLocationsQuery` so avatar reads return short-lived signed URLs.
- Added `ProfileUpdateDto`, `ILocationClient.ProfileUpdated`, and `ILocationBroadcastService.BroadcastProfileUpdated`, emitted once after each profile change.
- Kept `LocationUpdateDto` unchanged so routine location pings remain lean.

## Task Commits

1. **Task 1 RED: Profile command tests** - `d6d9d27` (test)
2. **Task 1 GREEN: Profile command handlers and GetMe extension** - `381aba1` (feat)
3. **Task 2: MeController endpoints** - `14ab9ee` (feat)
4. **Task 3 RED: Profile update propagation tests** - `e5b1245` (test)
5. **Task 3 GREEN: Live-location signed URLs and ProfileUpdated broadcast** - `c105479` (feat)

**Plan metadata:** recorded in final docs commit for this plan.

## Files Created/Modified

- `backend/src/SafePath.Application/Common/ProfileImageUrlFactory.cs` - Shared 1-hour signed avatar URL helper.
- `backend/src/SafePath.Application/Profile/*.cs` - Profile write handlers and projection/broadcast helper.
- `backend/src/SafePath.Api/Controllers/MeController.cs` - `/me` profile endpoints and expanded response projection.
- `backend/src/SafePath.Application/Families/GetMeQuery.cs` - Signed profile image URL and display-name fallback in `/me`.
- `backend/src/SafePath.Application/Location/GetLiveLocationsQuery.cs` - Family-gated signed avatar URL projection.
- `backend/src/SafePath.Application/Location/LocationDtos.cs` - `ProfileUpdateDto` and trailing `MemberLiveLocationDto.ProfileImageUrl`; `LocationUpdateDto` unchanged.
- `backend/src/SafePath.Application/Common/Interfaces/ILocationBroadcastService.cs` - Added profile update broadcast seam.
- `backend/src/SafePath.Infrastructure/RealTime/ILocationClient.cs` - Added SignalR client method.
- `backend/src/SafePath.Infrastructure/RealTime/LocationBroadcastService.cs` - Broadcasts `ProfileUpdated` to `family:{familyId}`.
- `backend/tests/SafePath.Application.Tests/**` - Focused profile and live-location coverage plus updated broadcast fakes.

## Decisions Made

- Used `/me`-only profile writes with no route/body user id, preserving structural IDOR resistance.
- Reused the same signed URL factory for `/me`, live-location snapshots, and profile broadcasts.
- Broadcast profile changes through the existing family SignalR group instead of adding a second hub or embedding profile data in location pings.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Updated existing broadcast test fakes for the new interface method**
- **Found during:** Task 3
- **Issue:** Adding `ILocationBroadcastService.BroadcastProfileUpdated` correctly changed the interface contract, which made existing location/privacy test fakes fail to compile.
- **Fix:** Added no-op `BroadcastProfileUpdated` implementations to the existing fakes.
- **Files modified:** `backend/tests/SafePath.Application.Tests/Location/LowBatteryAlertTests.cs`, `backend/tests/SafePath.Application.Tests/Location/ReportLocationCommandHandlerTests.cs`, `backend/tests/SafePath.Application.Tests/Privacy/BroadcastGatingTests.cs`
- **Verification:** `dotnet test ... --filter "FullyQualifiedName~ProfileCommand"`, `dotnet test ... --filter "FullyQualifiedName~GetLiveLocations"`, and `dotnet build backend/SafePath.sln` passed.
- **Committed in:** `c105479`

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Interface consumers stayed consistent; no scope expansion.

## Issues Encountered

- None beyond the auto-fixed test fake compile issue documented above.

## User Setup Required

None. This plan reuses the existing private Supabase Storage bucket `avatar` and the existing gitignored `backend/.env` service-role key from 02-13. No secrets were printed or committed.

## Verification

- `dotnet test backend/tests/SafePath.Application.Tests/SafePath.Application.Tests.csproj --filter "FullyQualifiedName~ProfileCommand"` - passed, 11/11.
- `dotnet test backend/tests/SafePath.Application.Tests/SafePath.Application.Tests.csproj --filter "FullyQualifiedName~GetLiveLocations"` - passed, 8/8.
- `dotnet build backend/SafePath.sln` - passed.
- Grep/Select-String checks confirmed `/me` emits `displayName`, `profileImageUrl`, `profileUpdatedAt`; live-locations projects `ProfileImageUrl`; `LocationUpdateDto` remains unchanged.
- Grep/Select-String checks confirmed profile write endpoints are `/me/display-name` and `/me/profile-image`, and derive the acting user from `_currentUser.UserId`.

## Known Stubs

None. Nullable profile-image fields and optional constructor dependencies are deliberate runtime states, not UI stubs.

## Threat Flags

None beyond the plan threat model. The new profile write endpoints, SignalR broadcast, and signed URL surface were planned and mitigated by server-derived caller identity, family group scoping, existing sharing gates, and 1-hour signed URL TTL.

## Self-Check: PASSED

- Created files exist.
- Task commits exist: `d6d9d27`, `381aba1`, `14ab9ee`, `e5b1245`, `c105479`.
- Verification commands passed.

## Next Phase Readiness

Ready for 02-15 mobile profile data/controller and view/edit profile screen work. 02-16 can consume `profileImageUrl` from live-location snapshots and `ProfileUpdated` from SignalR without changing backend ping payloads.

---
*Phase: 02-real-time-location-history-privacy*
*Completed: 2026-07-13*
