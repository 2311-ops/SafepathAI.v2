---
phase: 02-real-time-location-history-privacy
verified: 2026-07-14T23:11:57Z
status: passed
score: 7/8 must-haves verified
behavior_unverified: 1
overrides_applied: 0
supersedes: "2026-07-14T07:00:00Z (status: gaps_found, score 6/8, CR-01 blocker open)"
re_verification:
  previous_status: gaps_found
  previous_score: 6/8
  gaps_closed:

    - "CR-01: ping-derived IsOnline recency is now gated behind canViewLocation in GetLiveLocationsQueryHandler."
    - "Regression tests now cover denied LiveLocation sharing plus a recent ping with no independent presence, and denied LiveLocation sharing plus independent connection presence."
  gaps_remaining: []
  regressions: []
behavior_unverified_items:

  - truth: "After a full app close-and-reopen, the Live Map header avatar and family member markers show the current profile photo, not a stale cached one, matching the in-session behavior already confirmed for UAT test 72."
    test: "On a physical device signed into a family circle: upload a profile photo, fully close the app (swipe away or force-stop, not just background it), reopen it, and confirm the Live Map header avatar and family markers show the latest photo. Repeat after replace and after remove."
    expected: "Header avatar and family markers show the current photo immediately on cold start; after remove, they show the default initials avatar. No stale cached image appears."
    why_human: "The code and unit tests prove ProfileUpdatedAt is threaded through the cold-start bootstrap, but no automated test restarts a real Flutter process or exercises cached_network_image/flutter_cache_manager's persistent disk cache across an OS-level app close/reopen. 02-UAT.md still records test 73 as an issue, and no later artifact records the physical-device retest as passed."
human_verification:

  - test: "UAT 73 physical-device cold-start avatar retest"
    expected: "After upload, replace, and remove, a full app close and reopen shows the latest avatar state in both the Live Map header and all family markers."
    why_human: "Requires a real device/process restart and persistent image cache behavior; automated tests only cover the data path feeding the cache key."
---

# Phase 2: Real-Time Location, History & Privacy Verification Report

**Phase Goal:** As a family member, I want to see my family's live and past location and control exactly what I share and with whom, so that we can stay connected safely without giving up privacy.
**Verified:** 2026-07-14T23:11:57Z
**Status:** human_needed
**Re-verification:** Yes, after gap-closure plan 02-19.

## User Flow Coverage

User story: "As a family member, I want to see my family's live and past location and control exactly what I share and with whom, so that we can stay connected safely without giving up privacy."

| Step | Expected | Evidence | Status |
|---|---|---|---|
| Open Live Map | Family members appear on a shared map with current location, last-seen, online/offline status, staleness, and accuracy radius. | `live_map_screen.dart` renders `FlutterMap`, `CircleMarker(useRadiusInMeter: true)`, `LiveMemberMarker`, and header count from `LocationState`; backend `GetLiveLocationsQueryHandler` feeds the snapshot. | VERIFIED |
| View Past Location | User can inspect historical route, timeline, and travel stats. | Phase 02 UAT tests 33-36 remain passed; roadmap success criteria and requirements map to 02-04/02-08 artifacts. | VERIFIED |
| Control Sharing | LiveLocation denial suppresses location-derived values and ping-derived recency while preserving independent connection presence. | `GetLiveLocationsQuery.cs:56-76`; tests `Handle_DoesNotUseRecentPingForIsOnlineWhenLiveLocationSharingDenied` and `Handle_PreservesConnectionPresenceWhenLiveLocationSharingDenied`; scoped suite passed 12/12. | VERIFIED |
| Manage Privacy/Data | Temporary sharing, export/delete, and no-data-resale policy are present in backend and mobile Privacy Center. | 02-UAT tests 37-41 pass; requirements PRIV-03/04/05 accounted for in 02-05/02-09/02-11. | VERIFIED |
| Manage Profile Identity | Upload/replace/remove profile photo, edit display name, and render avatar/name markers. | 02-UAT tests 55-72 record profile and in-session map identity behavior as passed/resolved. | VERIFIED |
| Outcome: stay connected safely without giving up privacy | Automated privacy blocker is closed; only the physical cold-start cache retest remains. | CR-01 fixed by 02-19. UAT 73 still has no recorded physical-device pass after 02-18's cache-key fix. | HUMAN NEEDED |

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | User's live location updates on a shared family map, with each member's last-seen timestamp and online/offline status visible (LOC-01, LOC-02). | VERIFIED | `LocationController` bootstraps `/live-locations`, subscribes to hub location/presence streams, and `live_map_screen.dart` renders markers/status. 02-19 preserved LOC-02 independent connection presence. |
| 2 | User sees a stale-location indicator with accuracy radius, a battery-usage transparency screen, and an in-app permission-priming screen before the OS prompt (LOC-03, LOC-04, LOC-05). | VERIFIED | Prior passed UAT/tests unchanged; `live_map_screen.dart` uses staleness opacity and meter radius. Permission gating and battery screen were closed by 02-06/02-10. |
| 3 | User can view a family member's historical timeline, route visualization, and travel statistics (HIST-01, HIST-02, HIST-03). | VERIFIED | Prior passed UAT/tests unchanged; 02-04/02-08 cover backend history/stats and mobile Activity route UI. |
| 4 | User receives a low-battery alert for themselves or a family member (NOTIF-01). | VERIFIED | Prior passed UAT/tests unchanged; low-battery evaluator and mobile banner remain in the Phase 2 coverage. |
| 5 | User can toggle sharing per data type/recipient, enable temporary auto-stopping location sharing, and export/delete data from Privacy Center with documented no-data-resale posture (PRIV-01..05). | VERIFIED | CR-01 is closed: `GetLiveLocationsQuery.cs:65` gates ping-derived `isRecent` with `canViewLocation`; tests at `GetLiveLocationsQueryTests.cs:213` and `:255` prove denied recent ping is not disclosed and independent presence remains visible. |
| 6 | User can upload, replace, and remove profile picture and edit display name (PROFILE-01..05). | VERIFIED | 02-UAT tests 55-67 record pass; profile/live-location DTO path includes `ProfileUpdatedAt`. |
| 7 | Every visible family member appears as a custom marker with avatar/default avatar, name, online/offline status, and current location, updating in real time and scoped to Family Circle (PROFILE-06, PROFILE-07). | VERIFIED | `LiveMemberMarker` and header `MemberMapPin` read `profileImageUrl`/`profileUpdatedAt`; UAT 71 and resolved UAT 72 cover real-time visible marker/header behavior while app is open. |
| 8 | After a full app close-and-reopen, header avatar and family markers show the current photo/default initials rather than stale cached image (UAT 73 cold-start behavior). | PRESENT_BEHAVIOR_UNVERIFIED | Backend/mobile data path is present and tested, but 02-UAT.md still records test 73 as an issue and no artifact records the required physical-device close/reopen retest as passed. |

**Score:** 7/8 truths verified (1 present and wired, behavior-unverified).

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `backend/src/SafePath.Application/Location/GetLiveLocationsQuery.cs` | Gate only ping-derived `isRecent` behind `canViewLocation`, preserve `_presence.IsOnline`. | VERIFIED | Lines 56-65 compute `canViewLocation` before `isRecent`; line 65 includes `canViewLocation`; line 74 still ORs independent `_presence.IsOnline(member.UserId)`. |
| `backend/tests/SafePath.Application.Tests/Location/GetLiveLocationsQueryTests.cs` | Regression tests for denied recent ping and preserved connection presence. | VERIFIED | Tests exist at lines 213 and 255, seed explicit disabled `SharingPreference`, recent ping, and profile fields; scoped run passed 12/12. |
| `backend/src/SafePath.Application/Location/LocationDtos.cs` | `MemberLiveLocationDto` includes profile and presence fields. | VERIFIED | `ProfileImageUrl` and `ProfileUpdatedAt` present at lines 25-27; DTO still carries nullable location fields. |
| `mobile/lib/features/location/data/location_models.dart` | `LiveLocation` parses and carries `profileUpdatedAt`. | VERIFIED | `fromJson` parses `profileUpdatedAt` at lines 26-40; `copyWith` preserves/clears avatar timestamp intentionally. |
| `mobile/lib/features/location/application/location_controller.dart` | Cold-start bootstrap threads profile timestamps into self and members. | VERIFIED (data path) | `_bootstrap` loads `getLiveLocations` and sets `selfPosition`/`members` from returned `LiveLocation`; named unit test passed. |
| `mobile/lib/features/location/presentation/live_map_screen.dart` | Header and markers use current profile image/cache key inputs. | VERIFIED (data path) | Header `MemberMapPin` uses `state?.selfPosition?.userId/profileImageUrl/profileUpdatedAt` at lines 155-163; markers use cache key with `profileUpdatedAt` at lines 284-288. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `SharingPreference` LiveLocation denial | `MemberLiveLocationDto.IsOnline` | `ISharingAuthorizationService.CanView` -> `canViewLocation` -> `isRecent` | WIRED | `isRecent` is false when `canViewLocation` is false; regression test proves recent ping no longer leaks. |
| `IPresenceQuery.IsOnline(member.UserId)` | `MemberLiveLocationDto.IsOnline` | `_presence.IsOnline(member.UserId) || isRecent` | WIRED | Preservation test proves independent connection presence remains visible under LiveLocation denial. |
| API route | application handler | `LocationController.GetLiveLocations` -> DI registered `GetLiveLocationsQueryHandler` | WIRED | `LocationController.cs:30-43`; `DependencyInjection.cs:32`. |
| `ProfileUpdatedAt` backend snapshot | Flutter cache key | DTO JSON -> `LiveLocation.fromJson` -> `LocationController._bootstrap` -> `MemberMapPin`/`CachedNetworkImage.cacheKey` | WIRED, BEHAVIOR UNVERIFIED | Unit tests prove data path; physical persistent-cache restart behavior still needs UAT 73 retest. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|---|---|---|---|---|
| `GetLiveLocationsQueryHandler` | `MemberLiveLocationDto` | EF query over `FamilyMembers`, `Users`, latest `LocationPings`; `SharingAuthorizationService`; `IPresenceQuery` | Yes | FLOWING |
| `DioLocationApi.getLiveLocations` | `List<LiveLocation>` | `GET /families/{familyId}/live-locations` | Yes, filters null lat/lng before rendering map entries | FLOWING |
| `LocationController._bootstrap` | `LocationState.members/selfPosition` | `LocationApi.getLiveLocations(familyId)` | Yes | FLOWING |
| `LiveMapScreen` | marker/header avatar and cache key | `LocationState.selfPosition` and `members` | Yes | FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| CR-01 denied sharing cannot infer fresh ping through `IsOnline`; connection presence preserved. | `dotnet test tests/SafePath.Application.Tests/SafePath.Application.Tests.csproj --filter "FullyQualifiedName~GetLiveLocationsQueryTests"` from `backend` | Passed: 12/12 | PASS |
| Cold-start bootstrap carries `profileUpdatedAt` into self/member state. | `flutter test test/features/location/location_controller_test.dart --name "cold-start bootstrap threads profileUpdatedAt into selfPosition and family markers"` from `mobile` | Passed: 1/1 | PASS |
| API integration regression gate. | `dotnet test tests/SafePath.Api.IntegrationTests/SafePath.Api.IntegrationTests.csproj --no-restore` from `backend` | Passed: 5/5 | PASS |
| Splash regression gate reported by orchestrator. | `flutter test test/features/splash/splash_screen_test.dart test/features/splash/splash_redirect_gate_test.dart` from `mobile` | Passed: 9/9 | PASS |
| Physical cold-start avatar cache behavior. | Manual physical-device close/reopen after upload, replace, remove | No recorded pass in artifacts | HUMAN NEEDED |

### Probe Execution

No phase-specific `probe-*.sh` scripts were declared for 02-19 or required by the phase success criteria. Step skipped.

### Requirements Coverage

| Requirement | Source Plan(s) | Status | Evidence |
|---|---|---|---|
| LOC-01 | 02-01, 02-02, 02-06, 02-12 | SATISFIED | Live map/bootstrap/hub coverage remains intact. |
| LOC-02 | 02-01, 02-02, 02-07, 02-12, 02-19 | SATISFIED | Online/offline status remains dual-signal; 02-19 preserves independent connection presence and gates ping-derived recency. |
| LOC-03 | 02-02, 02-07 | SATISFIED | Staleness and accuracy radius remain rendered. |
| LOC-04 | 02-06, 02-12 | SATISFIED | Battery transparency screen and map migration coverage remain passed. |
| LOC-05 | 02-06, 02-10 | SATISFIED | Permission priming before OS prompt and route/controller gates remain passed. |
| HIST-01, HIST-02, HIST-03 | 02-04, 02-08, 02-12 | SATISFIED | History timeline, route, and stats remain accounted for. |
| NOTIF-01 | 02-05, 02-07 | SATISFIED | Low-battery alert backend and mobile banner remain accounted for. |
| PRIV-01 | 02-01, 02-03 | SATISFIED WITH NOTE | Prior accepted transport-level HTTPS/WSS interpretation carried forward. |
| PRIV-02 | 02-03, 02-09, 02-19 | SATISFIED | Previous CR-01 leak closed by code and tests. |
| PRIV-03 | 02-03, 02-09, 02-11 | SATISFIED | Temporary sharing and recipient/custom duration UI remain accounted for. |
| PRIV-04, PRIV-05 | 02-05, 02-09 | SATISFIED | Export/delete and no-data-resale policy remain accounted for. |
| PROFILE-01, PROFILE-02, PROFILE-03 | 02-13, 02-14, 02-15, 02-17, 02-18 | SATISFIED, WITH UAT 73 HUMAN CHECK FOR COLD-START AVATAR | Upload/replace/remove and automated cache-key data path pass; physical close/reopen retest still needed. |
| PROFILE-04, PROFILE-05 | 02-14, 02-15, 02-18 | SATISFIED | Display name/profile view and cold-start bootstrap data path are present. |
| PROFILE-06 | 02-16, 02-17, 02-18 | SATISFIED, WITH UAT 73 HUMAN CHECK FOR COLD-START AVATAR | Marker/header in-session behavior passed; cold-start physical retest remains. |
| PROFILE-07 | 02-16 | SATISFIED | Visibility remains inherited from backend family membership and sharing gate. |

All Phase 2 requirement IDs named in the assignment are accounted for in PLAN frontmatter and cross-referenced against REQUIREMENTS.md. No additional Phase 2 IDs appear in REQUIREMENTS.md without a Phase 2 plan claim.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| `mobile/lib/features/location/presentation/live_map_screen.dart` | 291 | `placeholder:` callback for `CachedNetworkImage` | INFO | This is a legitimate image loading placeholder, not a stub. |

No `TBD`, `FIXME`, `XXX`, `HACK`, or implementation placeholder blocker was found in the scoped files reviewed for this verification.

### Human Verification Required

#### 1. UAT 73 physical-device cold-start avatar retest

**Test:** On a physical device signed into a family circle, upload a profile photo, confirm the Live Map header and family marker update while the app is open, fully close the app, reopen it, and inspect the same header and markers. Repeat after replacing the photo and after removing it.

**Expected:** The latest photo appears immediately after reopen; after remove, the default initials avatar appears. No stale cached avatar appears in the header or family markers.

**Why human:** Automated tests prove `ProfileUpdatedAt` reaches the Flutter cache key, but they do not restart a real Flutter process or validate persistent disk-cache invalidation.

### Gaps Summary

No automated blocker remains. CR-01 is closed by code and passing regression tests. Phase 02 cannot be marked `passed` yet because UAT 73's physical-device close/reopen behavior is still not recorded as passed in `.planning/phases/02-real-time-location-history-privacy/02-UAT.md` or any later artifact.

---

_Verified: 2026-07-14T23:11:57Z_
_Verifier: the agent (gsd-verifier)_
