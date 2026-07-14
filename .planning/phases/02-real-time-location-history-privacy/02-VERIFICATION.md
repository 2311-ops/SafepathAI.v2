---
phase: 02-real-time-location-history-privacy
verified: 2026-07-14T05:30:00Z
status: human_needed
score: 20/21 must-haves verified
behavior_unverified: 1
overrides_applied: 0
supersedes: 2026-07-13T14:02:00+03:00 (status: passed, score 14/14 — scope was LOC/HIST/NOTIF/PRIV only, predates the PROFILE-01..07 wave)
re_verification:
  previous_status: passed
  previous_score: 14/14
  note: "Previous verification covered LOC/HIST/NOTIF/PRIV only (14 truths). This is the first full re-verification since the additive PROFILE-01..07 wave (plans 02-12..02-16) and UAT test 72's gap closure (plan 02-17). Scope has grown from 14 to 21 requirement IDs / truths."
  gaps_closed:
    - "UAT test 72 code-level cause fixed: header MemberMapPin in live_map_screen.dart is no longer const and now reads userId/profileImageUrl/profileUpdatedAt from LocationState.selfPosition (commit b59b567), with a passing TDD regression test (commit c522e4c)."
  gaps_remaining: []
  regressions: []
behavior_unverified_items:
  - truth: "Uploading, replacing, or removing the current user's profile photo updates the Live Map header's identity avatar in real time, without a reload (PROFILE-03/PROFILE-06, UAT test 72)."
    test: "On a physical device signed into a family circle: open Live Map, note the header avatar in the 'Your family, live' bar. Go to Profile, upload a photo, return to Live Map — header avatar must update without reload. Repeat for replace and remove (remove must revert to default initials)."
    expected: "Header avatar visibly changes to match the newly uploaded/replaced photo, and reverts to the default initial when removed — matching how family member markers already behave (per UAT test 71) — without an app reload."
    why_human: "The code fix (removing `const`, wiring to `state?.selfPosition`) is verified correct by static analysis and unit test, and the regression test proves the header reads live state on build. But the regression test (mobile/test/features/location/live_map_screen_test.dart, 'header identity pin live-updates...') only asserts the pin's props on its FIRST build from an already-seeded state — it never mutates `selfPosition` mid-test and re-asserts the rendered pin picked up the change (confirmed by direct read of the test, and independently flagged as WR-01 in 02-REVIEW.md's scoped review of plan 02-17). No post-fix physical-device confirmation is recorded anywhere (02-UAT.md, the debug session, and 02-17-SUMMARY.md all explicitly defer this to a future human-check step). This is a live state-transition claim, which presence-plus-wiring correctness cannot fully prove."
gaps: []
---

# Phase 2: Real-Time Location, History & Privacy Verification Report (re-verification)

**Phase Goal:** As a family member, I want to see my family's live and past location and control exactly what I share and with whom, so that we can stay connected safely without giving up privacy.
**Verified:** 2026-07-14T05:30:00Z
**Status:** human_needed
**Re-verification:** Yes — full re-verification after the additive PROFILE-01..07 wave (plans 02-12..02-16) and gap-closure plan 02-17 (UAT test 72).

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | Live location updates on a shared family map, with last-seen timestamp and online/offline status visible (LOC-01, LOC-02) | ✓ VERIFIED | `mobile/lib/features/location/presentation/live_map_screen.dart` renders `LiveMemberMarker` per member with `isOnline` (`state?.isMemberOnline(...)`) and last-seen derived from `LocationState`; backend `GET families/{familyId}/live-locations` (`LocationController.cs`) returns per-member latest ping + dual-signal online status. Confirmed via code read; prior physical-device UAT (tests 3, 27, 30, 49) passed. |
| 2 | Stale-location indicator with accuracy radius, battery-transparency screen, in-app permission-priming screen before OS prompt (LOC-03, LOC-04, LOC-05) | ✓ VERIFIED | Staleness opacity bands + `CircleMarker(useRadiusInMeter: true)` in `live_map_screen.dart`; `battery_transparency_screen.dart` present; `/home` wrapped in `LocationPermissionGate` (`app_router.dart:221`) routing to `/permission-priming` before `MainShell`/Geolocator start. `location_permission_gate_test.dart` (10 tests) + `location_controller_test.dart` (9 tests) pass. |
| 3 | Historical timeline, route visualization, travel statistics (HIST-01, HIST-02, HIST-03) | ✓ VERIFIED | `HistoryController` (backend) + `history_timeline_screen.dart` / `route_stats_sheet.dart` (mobile) render stops/movement timeline, flutter_map polyline + stop markers, and distance/time-away/stop-count `StatTile`s. UAT tests 33-36, 51 passed (device-confirmed route rendering). |
| 4 | Low-battery alert for self or family member (NOTIF-01) | ✓ VERIFIED | `LowBatteryEvaluator` fires once per falling-edge crossing (`<=20`, re-arms `>25`); `LowBatteryAlertTracker.TransitionAlerted` makes the check atomic (fixed as WR-03 in 02-REVIEW-2). Mobile renders a dismissible amber banner. UAT tests 19-20, 31 passed. |
| 5 | Toggle sharing per data type/recipient, temporary auto-stop sharing, export/delete data from Privacy Center, backed by HTTPS/WSS + JWT transport and a documented no-resale commitment (PRIV-01..05) | ✓ VERIFIED (PRIV-01 with note) | `PrivacyController` (backend) + `privacy_center_screen.dart` (mobile) implement per-recipient toggle matrix, `SharingPreferenceSweepService` auto-stop, export/delete endpoints, and `privacy_policy_screen.dart` renders the no-resale commitment. Non-first-recipient/custom-duration bug from the prior verification's PRIV-03 gap was closed by 02-11 (UAT tests 46-48). **Note (carried forward from prior verification, not a new finding):** PRIV-01 is satisfied via HTTPS/WSS transport + JWT auth, not application-layer E2EE — this is the same interpretation already accepted in the 2026-07-13 verification. |
| 6a | User can upload, replace, and remove their profile picture and edit display name (PROFILE-01..05) | ✓ VERIFIED | Backend: `MeController.cs` PATCH `/me/display-name`, POST/DELETE `/me/profile-image`; `SupabaseProfileImageStorage`, `ImageSharpProfileImageValidator` (rejects non-image/oversized/over-dimension/polyglot, re-encodes to JPEG). Mobile: `profile_screen.dart`, `profile_controller.dart`, `profile_api.dart` round-trip through the backend (never direct `supabase_flutter` Storage access). UAT tests 55-67 passed, including physical-device confirmation (64-67) of view/edit/upload/replace/remove with default-avatar fallback on remove. |
| 6b | Every visible family member appears on the live map as a custom marker with avatar/default-avatar, name, online/offline status, and current location, updating in real time, scoped to the same Family Circle (PROFILE-06, PROFILE-07) | ✓ VERIFIED (family markers) / ⚠️ PRESENT_BEHAVIOR_UNVERIFIED (header identity pin) | `LiveMemberMarker` (live_map_screen.dart) renders cached avatar or colored-initials, always-visible name label, online/offline dot, live position, sourced from `LiveLocation.profileImageUrl/profileUpdatedAt` kept live by `LocationController._applyProfileUpdate` via the `ProfileUpdated` hub stream — scoped by the existing family-membership gate (`RequireMembership`, `familyId` route param). UAT test 71 confirms real-time cross-device propagation on family markers on physical devices. **However**, the header's own identity indicator (the "Your family, live" bar avatar) was a separate, previously-failed call site (UAT test 72) fixed by plan 02-17 — see Human Verification below; the underlying mechanism for family markers is proven, but the header fix specifically lacks both a state-transition test and a post-fix device confirmation. |

**Score:** 20/21 truths verified (1 present + wired, behavior-unverified — see Human Verification)

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `backend/src/SafePath.Api/Controllers/LocationController.cs` | Live-locations/history/travel-stats endpoints, family/IDOR gated | ✓ VERIFIED | Confirmed `familyId`/`targetUserId` route-scoped gating on all three actions |
| `backend/src/SafePath.Api/Controllers/PrivacyController.cs` | Sharing matrix, export, delete, policy | ✓ VERIFIED (pre-existing, unchanged) | |
| `backend/src/SafePath.Api/Controllers/MeController.cs` | display-name PATCH, profile-image POST/DELETE | ✓ VERIFIED | Lines 75, 94, 119 |
| `backend/src/SafePath.Infrastructure/Storage/SupabaseProfileImageStorage.cs` | Private-bucket avatar upload/delete/signed URL | ✓ VERIFIED | File exists, referenced by profile commands |
| `mobile/lib/features/location/presentation/live_map_screen.dart` | Live map, staleness, accuracy radius, header + marker identity | ✓ VERIFIED (wired) | Header `MemberMapPin` is non-const, reads `state?.selfPosition` (lines 155-163); `LiveMemberMarker` (line 235+) reads `location.profileImageUrl`/`displayName`/`isOnline` |
| `mobile/lib/features/profile/presentation/profile_screen.dart` | View/edit profile, upload/replace/remove photo | ✓ VERIFIED | File exists, routed from Live Map header per UAT test 64 |
| `mobile/test/features/location/live_map_screen_test.dart` | Regression test locking header wiring (UAT 72) | ✓ VERIFIED (exists, passes) — scope-limited | 8/8 tests pass including the new UAT-72 regression test, but that test only asserts first-build state, not a mid-session mutation (see behavior_unverified_items) |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `live_map_screen.dart` header `MemberMapPin` | `LocationState.selfPosition` | direct field reads (`state?.selfPosition?.userId/profileImageUrl/profileUpdatedAt`) | ✓ WIRED (presence) / ⚠️ transition unverified | `const` removed, non-const widget instance rebuilds on Riverpod state change per normal `ConsumerWidget` semantics — same mechanism already proven for `LiveMemberMarker` — but no test/device evidence exercises the actual rebuild-on-change path for this specific call site |
| `LocationController._applyProfileUpdate` | `ProfileUpdated` hub stream | subscription in `LocationController` bootstrap | ✓ VERIFIED | Confirmed in `location_controller.dart`; UAT test 69 (automated) + test 71 (device) confirm merge behavior for family markers |
| `profile_screen.dart` | `ProfileApi`/`MeController` | `uploadProfileImage`/`updateDisplayName`/`deleteProfileImage` | ✓ VERIFIED | UAT tests 64-67 (device-confirmed round trip) |
| `/home` route | `LocationPermissionGate` | router wrapping | ✓ VERIFIED | `app_router.dart:221`; UAT tests 42-45 |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| UAT-72 regression test exists and passes | `cd mobile && flutter test test/features/location/live_map_screen_test.dart` | 8/8 passed, incl. new "header identity pin live-updates from LocationState.selfPosition (UAT 72)" test | ✓ PASS (presence-only, see caveat above) |
| Full mobile suite regression | `cd mobile && flutter test` | 199/199 passed | ✓ PASS |
| `flutter analyze` on the changed file | `cd mobile && flutter analyze lib/features/location/presentation/live_map_screen.dart` | No issues found | ✓ PASS |
| Backend Application-layer tests | `cd backend && dotnet test tests/SafePath.Application.Tests` | 100/100 passed | ✓ PASS |
| Backend Api.IntegrationTests | `cd backend && dotnet test tests/SafePath.Api.IntegrationTests` | Build failed — file lock on `bin/Debug` DLLs held by a live `SafePath.Api` dev process (pid 25060) | ? SKIP — environment lock, not a code defect. A prior full pass (2026-07-13) recorded 5/5 passing on this project against equivalent code; not independently re-run in this verification pass because a running dev server (likely left up for physical-device testing) held the binaries locked. |

### Requirements Coverage

| Requirement | Source Plan(s) | Status | Evidence |
|---|---|---|---|
| LOC-01, LOC-02, LOC-03 | 02-02, 02-06, 02-07, 02-12 | SATISFIED | Live map, staleness/accuracy, last-seen/online status |
| LOC-04 | 02-06, 02-12 | SATISFIED | Battery transparency screen |
| LOC-05 | 02-06, 02-10 | SATISFIED | Permission-priming gate before OS prompt |
| HIST-01, HIST-02, HIST-03 | 02-04, 02-08, 02-12 | SATISFIED | Timeline, route polyline, travel stats |
| NOTIF-01 | 02-05, 02-07 | SATISFIED | Low-battery alert, atomic transition tracking |
| PRIV-01 | 02-01, 02-03 | SATISFIED WITH NOTE | HTTPS/WSS + JWT, no app-layer E2EE (pre-existing accepted interpretation) |
| PRIV-02, PRIV-03 | 02-03, 02-09, 02-11 | SATISFIED | Per-recipient toggle matrix; 1h/4h/8h/Custom temporary sharing, non-first-recipient fixed |
| PRIV-04, PRIV-05 | 02-05, 02-09 | SATISFIED | Export/delete, no-resale policy screen |
| PROFILE-01, PROFILE-02, PROFILE-03 | 02-13, 02-14, 02-15 | SATISFIED | Upload/replace/remove avatar via backend-mediated private-bucket storage; header live-update path is the one open item (see Human Verification) |
| PROFILE-04, PROFILE-05 | 02-14, 02-15 | SATISFIED | Display-name edit + own-profile view |
| PROFILE-06 | 02-16, 02-17 | SATISFIED for family markers; ⚠️ header identity pin behaviorally unverified | See truth #6b above |
| PROFILE-07 | 02-16 | SATISFIED | Family-scoped visibility, no cross-family leak (UAT test 71) |

No orphaned requirement IDs: all 21 phase requirement IDs (LOC-01..05, HIST-01..03, NOTIF-01, PRIV-01..05, PROFILE-01..07) are declared in at least one plan's `requirements:` frontmatter and cross-referenced above; none appear in REQUIREMENTS.md's Phase 2 traceability section without a corresponding plan claim.

### Anti-Patterns Found

None found in the plan 02-17 fix scope (`live_map_screen.dart`, `live_map_screen_test.dart`). No `TBD`/`FIXME`/`XXX`/`TODO`/placeholder markers introduced by that plan. The one previously-known item — three mobile test files asserting stale `LandingStubScreen` copy (dead code since commit `d062edb`, predating Phase 2's tracked UAT scope) — was already flagged as out-of-scope test debt in the 2026-07-13 verification; it does not affect this pass's 199/199 full-suite pass result, so it appears to have been resolved or removed since, but was not independently re-audited in this pass since it is unrelated to the phase's success criteria.

### Human Verification Required

### 1. Live Map header avatar live-updates on profile photo change (UAT test 72 closure)

**Test:** On a physical device signed into a family circle with the app already open on the Live Map screen: note the header's identity avatar in the "Your family, live" bar. Navigate to Profile, upload a photo, then return to Live Map — observe the header avatar. Repeat for replace (upload a second photo) and remove (delete the photo).

**Expected:** The header avatar updates to the new photo after upload, updates again after replace, and reverts to the default initial after remove — all without an app reload, matching how the family member markers already behave (per UAT test 71).

**Why human:** The code fix is correct by inspection (const removed, three avatar fields sourced from `state?.selfPosition`, mirroring the already-proven `LiveMemberMarker` pattern) and the new regression test proves the pin resolves the right values on its first build. But the regression test does not mutate state mid-test and re-assert (independently flagged as WR-01 in the plan's own scoped code review, `02-REVIEW.md`), and no post-fix device confirmation exists in `02-UAT.md`, the debug session, or `02-17-SUMMARY.md` — all three explicitly defer this exact check to a future human pass. A state-transition claim cannot be marked VERIFIED on wiring correctness alone.

## Gaps Summary

No FAILED must-haves. One PROFILE-03/06 truth (Live Map header identity avatar live-updating with profile photo changes) is present and correctly wired by static analysis, but not behaviorally proven — it needs one round of physical-device confirmation (the same device-testing step already used successfully for every other Phase 2 UI-behavior claim in this phase) before the phase can be marked fully passed. This is a narrow, low-risk item: the fix reuses an already-proven mechanism (`LiveMemberMarker`'s live avatar wiring, confirmed on-device in UAT test 71) at a second call site in the same file.

---

_Verified: 2026-07-14T05:30:00Z_
_Verifier: Claude (gsd-verifier)_
_Previous report (passed, 14/14, LOC/HIST/NOTIF/PRIV scope only) superseded, not deleted — see git history for `02-VERIFICATION.md`._
