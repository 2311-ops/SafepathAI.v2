---
phase: 02-real-time-location-history-privacy
plan: 18
subsystem: location
tags: [gap-closure, uat-73, profile-identity, live-locations, cache-busting]
status: complete
dependency-graph:
  requires:
    - "User.ProfileUpdatedAt (Phase 02-13/02-14, already stamped by Upload/Delete/UpdateDisplayName profile commands)"
    - "GetLiveLocationsQueryHandler canViewLocation sharing gate (Phase 02-03)"
    - "LiveLocation.fromJson / cacheKey construction (Phase 02-16, 02-17)"
  provides:
    - "MemberLiveLocationDto.ProfileUpdatedAt on GET /families/{familyId}/live-locations"
    - "Cold-start cache-busting timestamp for header + family map avatars"
  affects:
    - "backend/src/SafePath.Application/Location/LocationDtos.cs"
    - "backend/src/SafePath.Application/Location/GetLiveLocationsQuery.cs"
    - "mobile/lib/features/location/application/location_controller.dart (bootstrap consumer, unchanged but now regression-locked)"
tech-stack:
  added: []
  patterns:
    - "Gate new profile-derived fields behind the existing canViewLocation sharing check, identical to ProfileImageUrl, rather than adding a new authorization call"
key-files:
  created: []
  modified:
    - backend/src/SafePath.Application/Location/LocationDtos.cs
    - backend/src/SafePath.Application/Location/GetLiveLocationsQuery.cs
    - backend/tests/SafePath.Application.Tests/Location/GetLiveLocationsQueryTests.cs
    - mobile/test/features/location/location_controller_test.dart
decisions:
  - "MemberLiveLocationDto.ProfileUpdatedAt was appended as the LAST positional record parameter so the single existing construction site is the only caller requiring a change, and positional order of pre-existing fields is preserved."
  - "ProfileUpdatedAt is gated by the already-computed canViewLocation boolean (no new authorization call), mirroring exactly how ProfileImageUrl is already nulled for viewers without sharing permission."
metrics:
  duration: ~25min
  completed: 2026-07-14
---

# Phase 02 Plan 18: Cold-start header/family avatar cache-busting via ProfileUpdatedAt Summary

Threaded the authoritative `User.ProfileUpdatedAt` timestamp through `GET /families/{familyId}/live-locations` so cold-start app launches receive a real, mutation-updated value instead of a permanent `null` — fixing the stale Live Map avatar (UAT test 73) for both the header self-pin and every family marker.

## What Shipped

- `MemberLiveLocationDto` (backend) gained a new `ProfileUpdatedAt` field, appended last to preserve the existing positional-record construction order.
- `GetLiveLocationsQueryHandler`'s LINQ projection now selects `user.ProfileUpdatedAt` alongside the other user fields, and the per-member DTO construction gates it behind the existing `canViewLocation` sharing check — identical treatment to `ProfileImageUrl` — so a viewer denied a member's live location learns nothing about that member's profile-change timing (threat T-02-18-01).
- No controller or mobile production code changes were required: `LocationController` returns the DTO directly (camelCase `profileUpdatedAt` serializes automatically), and `LiveLocation.fromJson` plus the `MemberMapPin`/`LiveMemberMarker` `CachedNetworkImage` cacheKeys (`${userId}-${profileUpdatedAt}`) already consumed this field correctly from prior work (02-16/02-17) — they were just never given a real value on cold start.
- Backend regression tests assert: (1) a real `ProfileUpdatedAt` flows through when the caller can view the member's location, (2) a member with no profile update returns `null`, and (3) a denied sharing gate nulls `ProfileUpdatedAt` exactly like `ProfileImageUrl`.
- A mobile regression test locks in that `LocationController._bootstrap()` threads `profileUpdatedAt` from `getLiveLocations` into both `state.selfPosition` and family member entries in `state.members`, exercising the exact cold-start path that was failing per UAT test 73.

## Deviations from Plan

None — plan executed exactly as written. Task 2 required no production code change, as anticipated by the plan (the mobile consumption chain was already correct from 02-16/02-17; only the backend was omitting the field).

## Verification

- `cd backend && dotnet test tests/SafePath.Application.Tests/SafePath.Application.Tests.csproj --filter "FullyQualifiedName~GetLiveLocationsQueryTests"` — 10/10 passed (3 new + 7 pre-existing).
- `cd backend && dotnet build src/SafePath.Application/SafePath.Application.csproj` — Build succeeded, 0 warnings, 0 errors. (A full-solution `dotnet build` hit an unrelated file lock from a running `SafePath.Api.exe` dev-server process holding output DLLs open; this is a pre-existing local dev-server artifact, not caused by this change, and was left untouched per the destructive-actions and scope-boundary rules — no dev server was killed.)
- `cd mobile && flutter test test/features/location/location_controller_test.dart` — 21/21 passed, including the new cold-start bootstrap test.
- `cd mobile && flutter analyze lib/features/location test/features/location` — No issues found.

## TDD Gate Compliance

Task 1 followed full RED/GREEN: `test(02-18)` commit added three failing tests (compile error — `ProfileUpdatedAt` did not exist on the DTO), confirmed RED via `dotnet test`, then `feat(02-18)` commit added the DTO field and query projection, confirmed GREEN (10/10 passed).

Task 2 is a pure regression-lock test with no corresponding implementation commit, as explicitly specified by the plan action ("No production code change is required") — the mobile consumption chain was already correct. The test passed on first run (21/21), which is expected and intentional here, not a RED-phase violation: this is not a bugfix task adding new behavior, it is a regression guard for behavior already delivered by 02-16/02-17 and unlocked end-to-end by Task 1's backend fix.

## Human Verification (Deferred to Phase Verification Workflow)

Per `human_verify_mode=end-of-phase`, on-device re-verification of UAT test 73 (upload/replace/remove a profile photo, fully close and reopen the app, confirm the Live Map header avatar and family markers show the latest photo) is handled by the phase verification workflow, not this plan.

## Known Stubs

None.

## Threat Flags

None — this change adds one already-authoritative field to an existing authenticated, sharing-gated endpoint; no new trust boundary or surface introduced. Both identified threats (T-02-18-01 Information Disclosure, T-02-18-02 Tampering) were mitigated/accepted as specified in the plan's threat model, with the Information Disclosure gate covered by a backend test.

## Self-Check: PASSED

- FOUND: backend/src/SafePath.Application/Location/LocationDtos.cs
- FOUND: backend/src/SafePath.Application/Location/GetLiveLocationsQuery.cs
- FOUND: backend/tests/SafePath.Application.Tests/Location/GetLiveLocationsQueryTests.cs
- FOUND: mobile/test/features/location/location_controller_test.dart
- FOUND commit 13d9eb3 (test(02-18): add failing tests for ProfileUpdatedAt in live-locations DTO)
- FOUND commit 0178ce9 (feat(02-18): thread ProfileUpdatedAt through live-locations DTO)
- FOUND commit ee399d0 (test(02-18): lock cold-start bootstrap threading of profileUpdatedAt)
