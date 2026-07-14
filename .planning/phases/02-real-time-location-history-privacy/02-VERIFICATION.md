---
phase: 02-real-time-location-history-privacy
verified: 2026-07-14T07:00:00Z
status: gaps_found
score: 6/8 must-haves verified
behavior_unverified: 1
overrides_applied: 0
supersedes: 2026-07-14T05:30:00Z (status: human_needed, score 20/21 — scope was pre-02-18, before UAT test 73's cold-start fix and before the CR-01 IsOnline finding)
re_verification:
  previous_status: human_needed
  previous_score: 20/21
  note: "This is the second re-verification round, after plan 02-18 (gap closure for UAT test 73: header/family avatar reverting to a stale photo on cold app restart). 02-18's own fix is correct and test-covered. However, the scoped code review conducted alongside 02-18 (02-REVIEW.md) surfaced a pre-existing CRITICAL finding in the same file (GetLiveLocationsQuery.cs) that this verification pass independently confirmed by direct code read: the IsOnline field is not gated behind the LiveLocation sharing check, unlike every other location-derived field. This is treated as a new FAILED must-have discovered during this verification pass, not carried forward from a prior VERIFICATION.md."
  gaps_closed:
    - "UAT test 72 (in-session header avatar live-update) — confirmed fixed and device-verified per plan 02-17 and the test 73 user report itself ('the new feature header avatar live-updates works')."
    - "Backend GetLiveLocationsQueryHandler now returns ProfileUpdatedAt gated by canViewLocation, closing the structural cause of UAT test 73's cold-start cache-key collapse (plan 02-18, 3 new backend tests + 1 new mobile test, all passing)."
  gaps_remaining:
    - "CR-01: IsOnline is computed from location-ping recency without going through the canViewLocation sharing gate, unlike every sibling location-derived field on the same DTO (see gap below)."
  regressions: []
behavior_unverified_items:
  - truth: "After a full app close-and-reopen, the Live Map header avatar (and every family member marker) shows the current profile photo, not a stale cached one, matching the in-session behavior already confirmed for UAT test 72."
    test: "On a physical device signed into a family circle: upload a profile photo, fully close the app (not just background it), reopen it, and confirm the Live Map header avatar and family markers show the latest photo, not a stale cached one. Repeat after a replace and after a remove (remove must show default initials on cold start too)."
    expected: "Header avatar and family markers show the current photo (or default initials after remove) immediately on cold start, with no stale image served from the persistent CachedNetworkImage disk cache."
    why_human: "Plan 02-18's backend fix (ProfileUpdatedAt now threads through GET /families/{familyId}/live-locations, gated by canViewLocation) is verified correct by direct code read, and is covered by 3 new backend tests (flow-through, null-when-unset, gated-null-when-denied) plus 1 new mobile bootstrap test — all of which this verification pass re-ran and confirmed passing (10/10 and 21/21 respectively). But the actual runtime behavior this fix targets — cached_network_image's persistent on-disk cache actually being busted by the new key across a genuine OS-level app-process restart — is a state-transition/cache-invalidation claim that unit tests exercising the Dart object graph in-process cannot fully prove (no test tears down and restarts a Flutter process to exercise flutter_cache_manager's real disk cache). No physical-device retest of UAT test 73 after the 02-18 fix is recorded anywhere in 02-UAT.md, 02-18-SUMMARY.md, or the debug session file — all explicitly defer this to the phase verification workflow's human-check step."
gaps:
  - truth: "A user who disables LiveLocation sharing for a specific family member (or recipient) withholds all location-derived information from that recipient, matching every other gated field on the same response (PRIV-02: toggle sharing per data type/recipient)."
    status: failed
    reason: "backend/src/SafePath.Application/Location/GetLiveLocationsQuery.cs:65,74 computes `isRecent` from `latestPing.RecordedAtUtc` unconditionally — NOT gated by the `canViewLocation` check that already gates Lat, Lng, AccuracyMeters, RecordedAtUtc, ProfileImageUrl, and (per this same gap-closure plan) the new ProfileUpdatedAt field. The result, `IsOnline`, is set to `_presence.IsOnline(member.UserId) || isRecent` with no gate at all, so a viewer denied LiveLocation sharing for a member can still learn 'this member's device pinged the server within the last 2 minutes' directly from the API response — a location-adjacent signal leaking straight past the sharing boundary PRIV-02 exists to enforce. Confirmed by direct code read during this verification pass (not just the code review's narration); no test in GetLiveLocationsQueryTests.cs exercises IsOnline after a sharing denial with a recent ping present (Handle_HidesProfileUpdatedAtWhenViewerCannotSeeLocation seeds ProfileUpdatedAt but no LocationPing, so it never actually exercises isRecent=true under denial). Independently corroborated as CR-01 (CRITICAL) in 02-REVIEW.md's scoped review of the same file. Mitigating factor (does not change the classification, only the currently-observed blast radius): the mobile client's DioLocationApi.getLiveLocations filters out any entry whose lat/lng are null before constructing a LiveLocation (location_api.dart:53), so the current Flutter app's Live Map UI never actually surfaces IsOnline for a location-denied member today — a denied member is dropped from the map entirely. The leak is real at the API/architecture layer (and would surface the moment any client reads isOnline independent of lat/lng, or via direct API inspection), but is not currently rendered in this specific client's UI."
    artifacts:
      - path: "backend/src/SafePath.Application/Location/GetLiveLocationsQuery.cs"
        issue: "Line 65: `var isRecent = latestPing is not null && now - latestPing.RecordedAtUtc <= PingFreshnessWindow;` computed before/independent of canViewLocation. Line 74: `_presence.IsOnline(member.UserId) || isRecent` passed to the DTO with no gate."
    missing:
      - "Gate the ping-derived half of IsOnline behind canViewLocation, e.g. `var isRecent = canViewLocation && latestPing is not null && now - latestPing.RecordedAtUtc <= PingFreshnessWindow;` (connection-presence via _presence.IsOnline can remain ungated if that's the intended product behavior for a separate non-location presence signal — that determination is a product call, not this verifier's to make)."
      - "Add a regression test mirroring Handle_HidesProfileUpdatedAtWhenViewerCannotSeeLocation that seeds a recent LocationPing AND denies LiveLocation sharing, then asserts IsOnline is false (assuming no independent presence signal is active) — the existing denial test does not seed a ping, so it cannot currently catch this."
---

# Phase 2: Real-Time Location, History & Privacy Verification Report (second re-verification)

**Phase Goal:** As a family member, I want to see my family's live and past location and control exactly what I share and with whom, so that we can stay connected safely without giving up privacy.
**Verified:** 2026-07-14T07:00:00Z
**Status:** gaps_found
**Re-verification:** Yes — second re-verification, after gap-closure plan 02-18 (UAT test 73 cold-start avatar fix) and its accompanying scoped code review (02-REVIEW.md).

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | Live location updates on a shared family map, with last-seen timestamp and online/offline status visible (LOC-01, LOC-02) | ✓ VERIFIED | Unchanged since prior pass. `live_map_screen.dart` renders `LiveMemberMarker` per member with online/offline and last-seen from `LocationState`; backend `GET families/{familyId}/live-locations` returns per-member latest ping + dual-signal online status. |
| 2 | Stale-location indicator with accuracy radius, battery-transparency screen, in-app permission-priming screen before OS prompt (LOC-03, LOC-04, LOC-05) | ✓ VERIFIED | Unchanged since prior pass. Staleness opacity bands + `CircleMarker(useRadiusInMeter: true)`; `battery_transparency_screen.dart`; `/home` wrapped in `LocationPermissionGate` before `MainShell`/Geolocator start. |
| 3 | Historical timeline, route visualization, travel statistics (HIST-01, HIST-02, HIST-03) | ✓ VERIFIED | Unchanged since prior pass. `HistoryController` + `history_timeline_screen.dart`/`route_stats_sheet.dart` render stops/movement timeline, polyline + stop markers, and distance/time-away/stop-count stat tiles. |
| 4 | Low-battery alert for self or family member (NOTIF-01) | ✓ VERIFIED | Unchanged since prior pass. `LowBatteryEvaluator` fires once per falling-edge crossing; atomic transition tracking (WR-03 fix, 02-REVIEW-2); mobile renders a dismissible amber banner. |
| 5 | Toggling sharing off for a data type/recipient withholds ALL information derived from that data type for that recipient — not just some fields (PRIV-01..05) | ✗ FAILED | `GetLiveLocationsQuery.cs:65,74`: `IsOnline` is computed from ping recency (`isRecent`) without going through the `canViewLocation` gate that correctly nulls every sibling field (`Lat`, `Lng`, `AccuracyMeters`, `RecordedAtUtc`, `ProfileImageUrl`, `ProfileUpdatedAt`). Confirmed by direct code read in this pass (not code-review narration); no existing test exercises this exact denied+recent-ping combination. See gap entry above for full detail, including the mitigating (but non-dispositive) fact that the current mobile client's list-filtering incidentally prevents this from being rendered in the Live Map UI today. |
| 6a | User can upload, replace, and remove profile picture and edit display name (PROFILE-01..05) | ✓ VERIFIED | Unchanged since prior pass; device-confirmed in UAT tests 55-67. |
| 7 | Every visible family member appears as a custom marker (avatar/initials, name, online/offline, location), updating in real time while the app is open, scoped to the same Family Circle (PROFILE-06, PROFILE-07) | ✓ VERIFIED | `LiveMemberMarker` renders per-member state kept live via `ProfileUpdated`; UAT test 71 confirms real-time cross-device propagation on physical devices. Header identity pin's in-session live-update (UAT test 72) is confirmed fixed and device-verified (plan 02-17; the test 73 report itself states the in-session behavior "works"). |
| 8 | After a full app close-and-reopen, the header avatar and family markers show the current photo, not a stale cached one (UAT test 73, PROFILE-03/06 cold-start guarantee) | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Backend fix (plan 02-18) is code-correct and covered by 3 new backend tests + 1 new mobile test, all re-run and passing in this verification pass. But the actual cache-busting behavior across a real OS-level app restart is a state-transition claim no unit test exercises (flutter_cache_manager's persistent disk cache is not torn down/restarted by any test). No physical-device retest of UAT test 73 after the fix is recorded anywhere. See Human Verification below. |

**Score:** 6/8 truths verified (1 failed — BLOCKER, 1 present + wired, behavior-unverified — see Human Verification)

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `backend/src/SafePath.Application/Location/LocationDtos.cs` | `MemberLiveLocationDto` carries `ProfileUpdatedAt` | ✓ VERIFIED | Field present as last positional parameter (line 27), confirmed by direct read. |
| `backend/src/SafePath.Application/Location/GetLiveLocationsQuery.cs` | Projection selects `user.ProfileUpdatedAt`, gated by `canViewLocation`; `IsOnline` similarly gated | ⚠️ PARTIAL | `ProfileUpdatedAt` correctly gated (line 76). `IsOnline` (line 74) is NOT gated — see gap above. |
| `backend/tests/SafePath.Application.Tests/Location/GetLiveLocationsQueryTests.cs` | Asserts `ProfileUpdatedAt` flow-through and gating; (missing) `IsOnline` gating | ⚠️ PARTIAL | 3 new tests for `ProfileUpdatedAt` all pass (re-run: 10/10 in this file). No test covers `IsOnline` under a denied+recent-ping scenario. |
| `mobile/test/features/location/location_controller_test.dart` | Cold-start bootstrap threads `profileUpdatedAt` into `selfPosition`/members | ✓ VERIFIED | Re-run: 21/21 in this file, including "cold-start bootstrap threads profileUpdatedAt into selfPosition and family markers". |
| `mobile/lib/features/location/presentation/live_map_screen.dart` | Header + marker identity wiring | ✓ VERIFIED (wired) | Header `MemberMapPin` (lines 155-163) is non-const, reads `state?.selfPosition?.userId/profileImageUrl/profileUpdatedAt`. |
| `mobile/lib/features/location/data/location_api.dart` | Live-locations parsing | ℹ️ NOTED | Line 53 filters out entries with null `lat`/`lng` before parsing — this is why the `IsOnline` leak above is not currently observable in this client's map UI, even though the API itself discloses it. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `GetLiveLocationsQueryHandler` | `ISharingAuthorizationService.CanView` | `canViewLocation` gate applied per-field | ⚠️ PARTIAL | Gates `Lat`, `Lng`, `AccuracyMeters`, `RecordedAtUtc`, `ProfileImageUrl`, `ProfileUpdatedAt` correctly; does NOT gate the ping-recency contribution to `IsOnline`. |
| `User.ProfileUpdatedAt` → `MemberLiveLocationDto.ProfileUpdatedAt` → JSON → `LiveLocation.profileUpdatedAt` → `CachedNetworkImage` cacheKey | cold-start bootstrap | ✓ WIRED (code-verified) / ⚠️ transition unverified | Full chain confirmed present and correctly threaded by direct code read across all 4 layers; the actual disk-cache-busting behavior on a real app restart is unverified (see truth #8). |
| `live_map_screen.dart` header `MemberMapPin` | `LocationState.selfPosition` | direct field reads | ✓ VERIFIED (in-session) | Confirmed working via plan 02-17 device confirmation and test 73's own user report. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Scoped `GetLiveLocationsQueryTests` re-run | `cd backend && dotnet test tests/SafePath.Application.Tests/SafePath.Application.Tests.csproj --filter "FullyQualifiedName~GetLiveLocationsQueryTests"` | 10/10 passed | ✓ PASS |
| Full backend Application-layer suite re-run | `cd backend && dotnet test tests/SafePath.Application.Tests/SafePath.Application.Tests.csproj` | 103/103 passed | ✓ PASS |
| Scoped mobile `location_controller_test.dart` re-run | `cd mobile && flutter test test/features/location/location_controller_test.dart` | 21/21 passed, incl. new cold-start bootstrap test | ✓ PASS |
| Full mobile suite re-run | `cd mobile && flutter test` | 200/200 passed | ✓ PASS |
| Direct code read of `GetLiveLocationsQuery.cs` `IsOnline` gating | manual inspection, lines 51-76 | `isRecent` computed unconditionally; `IsOnline = _presence.IsOnline(...) || isRecent` unconditionally | ✗ FAIL (confirms CR-01 is real, not narration) |
| Direct code read of `GetLiveLocationsQueryTests.cs` for an `IsOnline`-under-denial test | manual inspection, full file | No such test exists; the closest test (`Handle_HidesProfileUpdatedAtWhenViewerCannotSeeLocation`) seeds no `LocationPing`, so `isRecent` is false regardless of the gate | confirms untested gap |

I re-ran every test suite claimed in 02-18-SUMMARY.md myself in this pass rather than trusting the SUMMARY's narration; all pass counts match exactly (10/10, 103/103, 21/21, 200/200).

### Requirements Coverage

| Requirement | Source Plan(s) | Status | Evidence |
|---|---|---|---|
| LOC-01, LOC-02, LOC-03, LOC-04, LOC-05 | 02-02, 02-06, 02-07, 02-10, 02-12 | SATISFIED | Unchanged since prior pass. |
| HIST-01, HIST-02, HIST-03 | 02-04, 02-08, 02-12 | SATISFIED | Unchanged since prior pass. |
| NOTIF-01 | 02-05, 02-07 | SATISFIED | Unchanged since prior pass. |
| PRIV-01 | 02-01, 02-03 | SATISFIED WITH NOTE | HTTPS/WSS + JWT, no app-layer E2EE (pre-existing accepted interpretation, carried from initial verification). |
| PRIV-02 | 02-03, 02-09, 02-11 | **BLOCKED** | Per-recipient toggle matrix UI/API is otherwise correct, but the `IsOnline` gap above means the sharing toggle does not withhold ALL location-derived data for a denied recipient at the API layer — a partial violation of "toggle sharing per data type/recipient." REQUIREMENTS.md currently marks this `[x]` Complete; this verification pass disputes that for the reason given above. |
| PRIV-03, PRIV-04, PRIV-05 | 02-03, 02-05, 02-09, 02-11 | SATISFIED | Unchanged since prior pass. |
| PROFILE-01..05 | 02-13, 02-14, 02-15 | SATISFIED | Unchanged since prior pass, device-confirmed. |
| PROFILE-06 | 02-16, 02-17, 02-18 | SATISFIED for family markers and in-session header update; ⚠️ cold-start persistence behaviorally unverified (device retest pending, see truth #8) | |
| PROFILE-07 | 02-16 | SATISFIED | Unchanged since prior pass. |

No orphaned requirement IDs: all 21 phase requirement IDs (LOC-01..05, HIST-01..03, NOTIF-01, PRIV-01..05, PROFILE-01..07) are declared in at least one plan's `requirements:` frontmatter (confirmed by grepping all 18 `*-PLAN.md` files) and cross-referenced above; none appear in REQUIREMENTS.md's Phase 2 traceability section without a corresponding plan claim.

### Anti-Patterns Found

None (`TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER`) in the 4 files touched by plan 02-18. The CR-01 finding above is a logic/authorization gap, not a debt marker — it was found by direct code inspection of the sharing-gate logic, not a grep for markers.

Also carried forward, non-blocking (from 02-REVIEW.md, not re-litigated in this pass since they are explicitly non-critical):
- WR-01: No test locks the self-viewing-own-row path for `ProfileUpdatedAt` (relies on `SharingAuthorizationService.CanView`'s self-bypass being correct by inference from other test files).
- WR-02: `ProfileImageUrl`/`ProfileUpdatedAt` visibility is coupled to the `LiveLocation` permission rather than a dedicated `Profile`/`Identity` permission category — a design-debt item, not a regression, flagged for a possible future `SharedDataType.Profile`.

### Human Verification Required

### 1. Cold-start header/family avatar cache-busting (UAT test 73, post-02-18 fix)

**Test:** On a physical device signed into a family circle: upload a profile photo, confirm it shows correctly while the app stays open (already proven). Then fully close the app (swipe away / force-stop, not just background it), reopen it, and observe the Live Map header avatar and family markers. Repeat after a replace and after a remove.

**Expected:** The header avatar and every family marker show the current photo (or default initials after remove) immediately on cold start — no stale cached image, matching the already-proven in-session behavior.

**Why human:** The backend fix (ProfileUpdatedAt now threads through the live-locations response, gated by canViewLocation) is verified correct by code read and by 3 new backend tests + 1 new mobile bootstrap test, all re-run and passing in this pass. But the actual disk-cache-busting behavior on a genuine OS-level app process restart is a state-transition claim that in-process unit tests cannot exercise (no test restarts the Flutter process or exercises flutter_cache_manager's real persistent disk cache). No device retest after the 02-18 fix exists in any artifact.

## Gaps Summary

**One BLOCKER, one human-verification item.**

1. **BLOCKER — CR-01, IsOnline sharing-gate leak (PRIV-02).** `GetLiveLocationsQueryHandler` computes the `IsOnline` field from location-ping recency without applying the same `canViewLocation` sharing gate that correctly protects every sibling location-derived field (`Lat`, `Lng`, `AccuracyMeters`, `RecordedAtUtc`, `ProfileImageUrl`, and the newly-added `ProfileUpdatedAt`). This is a genuine, code-verified violation of the "toggle sharing per data type/recipient" guarantee that PRIV-02 exists to provide: a user who disables LiveLocation sharing for a specific recipient should not leak ANY location-adjacent signal to that recipient, but currently does — "this member's device pinged the server within the last 2 minutes" survives the sharing toggle. This predates plan 02-18 (likely originating in 02-02/02-06/02-07, before the sharing-gate work in 02-03 was retrofitted onto the earlier `IsOnline` computation) and was not introduced by 02-18's own change — but it sits squarely inside PRIV-02's declared requirement scope for this phase, was independently corroborated as CRITICAL by 02-REVIEW.md's scoped review, and I confirmed it directly by reading the current code and the current test suite (no test exercises this exact scenario). **My call:** this should be classified as a FAILED must-have (BLOCKER) rather than deferred as an out-of-scope follow-up, because (a) there is no later phase in the roadmap whose stated goal or success criteria cover privacy-sharing-gate correctness for this project (so the deferred-items mechanism in Step 9b does not legitimately apply), (b) the phase's own goal statement explicitly promises the user can "control exactly what I share," and this is a demonstrable, reproducible counter-example to that promise at the API layer, and (c) the fix is small, well-understood, and already specified (mirror the `ProfileUpdatedAt` gating pattern from this very plan) — this is not a case of ambiguous scope or a stale requirement, it's an implementation gap with a known, low-risk fix. The one mitigating fact — the current mobile client's `location_api.dart` incidentally filters out any member with null lat/lng before the leaked `IsOnline` value could ever reach the Live Map UI — reduces today's *practical* user-facing exposure but does not change the underlying API contract violation, which would resurface the moment any client (including a future one, or direct API inspection) reads `isOnline` independent of position data. If the team judges the current incidental mitigation sufficient to accept as-is, this can be recorded as an explicit VERIFICATION.md override with a named reason and approver — I am not making that call unilaterally.

2. **Human verification — UAT test 73 cold-start device retest.** The backend fix for the stale cold-start avatar (plan 02-18) is code-correct and fully test-covered by automated regression tests, all independently re-run and passing in this verification pass. What remains is exactly one physical-device confirmation step (close-reopen-observe), which no artifact in the phase records as having happened after this specific fix.

---

_Verified: 2026-07-14T07:00:00Z_
_Verifier: Claude (gsd-verifier)_
_Previous report (human_needed, 20/21, pre-02-18 scope) superseded, not deleted — see git history for `02-VERIFICATION.md`._
