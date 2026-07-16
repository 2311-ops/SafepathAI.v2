---
phase: 02-real-time-location-history-privacy
plan: 16
subsystem: mobile
tags: [profile, mobile, flutter-map, signalr, realtime, ui]

# Dependency graph
requires:
  - phase: 02-14
    provides: "backend profile endpoints, signed profileImageUrl on live-locations snapshot, ProfileUpdated SignalR broadcast"
  - phase: 02-15
    provides: "ProfileAvatar shared widget (cached-image + initials fallback), extended UserProfile model"
provides:
  - "LiveLocation.profileImageUrl/profileUpdatedAt (fromJson, copyWith with explicit clearProfileImage flag)"
  - "ProfileUpdate model + LocationHubClient.profileUpdates stream + 'ProfileUpdated' hub subscription"
  - "LocationController._applyProfileUpdate per-member merge (mirrors _applyPresence), including avatar-clear-on-null"
  - "Avatar-bearing, always-visible-name-label live map markers (MemberMapPin extended, LiveMemberMarker promoted to public/testable)"
affects: [live-map, profile, phase-3-sos-map-reuse]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "LiveLocation.copyWith uses an explicit clearProfileImage boolean (mirroring clearError/clearLowBatteryAlert) instead of plain ?? merging, since a removed photo must clear the field rather than be ignored"
    - "LocationController stamps a fresh local profileUpdatedAt on ProfileUpdated merge to bust the CachedNetworkImage cacheKey, since the hub payload itself carries no timestamp"
    - "Markers stay a plain List<Marker> of self-contained stateless widgets (no flutter_map_marker_cluster dependency) for future clustering compatibility (D-19)"

key-files:
  created:
    - mobile/test/features/location/live_member_marker_test.dart
  modified:
    - mobile/lib/features/location/data/location_models.dart
    - mobile/lib/features/location/data/location_hub_client.dart
    - mobile/lib/features/location/application/location_controller.dart
    - mobile/lib/shared_widgets/member_map_pin.dart
    - mobile/lib/features/location/presentation/live_map_screen.dart
    - mobile/test/features/location/location_controller_test.dart
    - mobile/test/helpers/fake_location_hub_client.dart

key-decisions:
  - "LiveLocation.copyWith gained an explicit clearProfileImage flag (mirroring clearError/clearLowBatteryAlert) so a removed profile photo actually clears the marker avatar instead of falling back via the usual ?? merge."
  - "LocationController._applyProfileUpdate stamps a fresh local profileUpdatedAt on avatar changes to bust the CachedNetworkImage cache key, since the ProfileUpdated hub payload carries no timestamp."
  - "live_map_screen.dart's marker widget was promoted from private _LiveMemberMarker to public LiveMemberMarker so it is directly testable."

patterns-established:
  - "Hub-event merges into per-member LocationController state (LocationUpdated/PresenceChanged/LowBattery/ProfileUpdated) follow one consistent shape: locate existing member entry, copyWith only the changed fields, safe no-op if the member hasn't been seen yet."

requirements-completed: [PROFILE-06, PROFILE-07]

coverage:
  - id: D1
    description: "LiveLocation model carries profileImageUrl/profileUpdatedAt (fromJson/copyWith with explicit clear flag); ProfileUpdate model + LocationHubClient.profileUpdates stream subscribe 'ProfileUpdated' with malformed-message guarding"
    requirement: "PROFILE-06"
    verification:
      - kind: unit
        ref: "mobile/test/features/location/location_controller_test.dart (Task 1 parsing/stream cases)"
        status: pass
    human_judgment: false
  - id: D2
    description: "LocationController merges ProfileUpdated into per-member state (name/avatar) without disturbing position/presence, updates selfPosition when applicable, clears avatar on null, and safely no-ops for a not-yet-seen member"
    requirement: "PROFILE-06"
    verification:
      - kind: unit
        ref: "mobile/test/features/location/location_controller_test.dart (Task 2 merge/clear/no-op cases)"
        status: pass
    human_judgment: false
  - id: D3
    description: "MemberMapPin renders a cached avatar when profileImageUrl is set and the colored-initial circle otherwise, preserving staleness opacity/accuracy ring/pulse dot; LiveMemberMarker adds an always-visible name label, widened Marker box, no sosRed, plain List<Marker> (no clustering dependency)"
    requirement: "PROFILE-06"
    verification:
      - kind: unit
        ref: "mobile/test/features/location/live_member_marker_test.dart"
        status: pass
    human_judgment: false
  - id: D4
    description: "Every visible family member renders on the live map with avatar/initials, always-visible name, online/offline dot, and live position; name/photo changes on one device propagate to another device's markers in real time via ProfileUpdated without a reload; visibility stays scoped to the same Family Circle with no cross-family leak and no SOS-red on the map"
    requirement: "PROFILE-06, PROFILE-07"
    verification:
      - kind: manual_procedural
        ref: "Human-verify checkpoint (Task 4): two-account physical-device verification of avatar/name markers, live ProfileUpdated propagation (name edit, photo upload, photo removal), family-scoped visibility, and no-SOS-red"
        status: pass
    human_judgment: true
    rationale: "End-to-end real-time cross-device rendering and visual/family-scoping confirmation requires physical-device human verification — approved by user 2026-07-14."

# Metrics
duration: ~10min (Tasks 1-3 executed same session; checkpoint approved same session)
completed: 2026-07-14
status: complete
---

# Phase 02 Plan 16: Live Map Avatar Markers + Real-Time Profile Identity Summary

**Live map markers now show each family member's cached avatar (or initials fallback) with an always-visible name label that updates in real time via the ProfileUpdated SignalR event, closing the PROFILE-06/07 map-identity slice.**

## Performance

- **Duration:** ~10min (Tasks 1-3: 2026-07-14T01:05-01:11; Task 4 checkpoint approved same session)
- **Started:** 2026-07-14T01:05:12+03:00 (first task commit, ae93738)
- **Completed:** 2026-07-14 (checkpoint approval + finalization)
- **Tasks:** 4 (3 auto/TDD tasks + 1 human-verify checkpoint, all complete)
- **Files modified:** 7 (1 test file created, 6 modified)

## Accomplishments
- Extended `LiveLocation` with `profileImageUrl`/`profileUpdatedAt` (parsed in `fromJson`, carried by `copyWith` with an explicit `clearProfileImage` flag) and added a `ProfileUpdate` model mirroring `PresenceChange`.
- Extended `LocationHubClient`/`SignalRLocationHubClient` with a `profileUpdates` stream subscribing `'ProfileUpdated'` with the same malformed-message guard used by the other hub events; extended the `FakeLocationHubClient` test double for Task 2/3 coverage.
- Wired `LocationController._applyProfileUpdate` to merge name/avatar changes into per-member state exactly like `_applyPresence` — never touching lat/lng/presence, updating `selfPosition` when the update targets the current user, clearing the avatar on a null `profileImageUrl` (photo removal), and safely no-op'ing for a not-yet-seen member.
- Extended `MemberMapPin` with an optional cached-avatar branch (reusing 02-15's `CachedNetworkImage` pattern) alongside the existing colored-initial circle, and promoted `live_map_screen.dart`'s marker widget to a public, testable `LiveMemberMarker` rendering `Column[avatar-or-initials, always-visible name label]`, widening each `Marker`'s declared box from 44x44 to 88x72 so flutter_map (no overflow anchor) doesn't clip the label. Markers remain a plain `List<Marker>` of self-contained stateless widgets — no `flutter_map_marker_cluster` dependency added.
- Human-verify checkpoint (Task 4) approved by the user 2026-07-14: avatar/name markers render correctly, name and photo changes on one device propagate live to another device's markers without a reload, photo removal reverts to initials, family-scoped visibility holds (no cross-family leak), and no SOS-red appears on the map.

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend LiveLocation + add ProfileUpdated hub stream** - `ae93738` (feat)
2. **Task 2: Merge ProfileUpdated into LocationController per-member state** - `8dd0b91` (feat)
3. **Task 3: Render avatar + always-visible name label on map markers** - `eb2aad5` (feat)
4. **Task 4 [checkpoint]: Human-verify live avatar/name markers + real-time updates + family scoping** - approved by user 2026-07-14, no code commit (verification-only checkpoint).

**Plan metadata:** (this commit)

_Note: Tasks 1-2 followed the TDD RED→GREEN cycle within a single task commit each (test file and implementation committed together per the plan's task-commit protocol); Task 3 was a straight `type="auto"` implementation task._

## Files Created/Modified
- `mobile/lib/features/location/data/location_models.dart` - `LiveLocation.profileImageUrl`/`profileUpdatedAt` + `ProfileUpdate` model
- `mobile/lib/features/location/data/location_hub_client.dart` - `profileUpdates` stream + `'ProfileUpdated'` subscription with malformed-message guard
- `mobile/lib/features/location/application/location_controller.dart` - `_applyProfileUpdate` merge + subscription lifecycle
- `mobile/lib/shared_widgets/member_map_pin.dart` - optional cached-avatar branch alongside colored-initial fallback
- `mobile/lib/features/location/presentation/live_map_screen.dart` - `LiveMemberMarker` (promoted public) with always-visible name label, widened marker box
- `mobile/test/features/location/location_controller_test.dart` - Task 1/2 parsing + merge/clear/no-op test coverage
- `mobile/test/helpers/fake_location_hub_client.dart` - `profileUpdates` + `emitProfileUpdate` test helper
- `mobile/test/features/location/live_member_marker_test.dart` - name label + initials-fallback widget tests

## Decisions Made
- `LiveLocation.copyWith` gained an explicit `clearProfileImage` flag (mirroring `clearError`/`clearLowBatteryAlert`) so a removed profile photo actually clears the marker avatar instead of being silently retained by the usual `??` merge pattern.
- `LocationController._applyProfileUpdate` stamps a fresh local `profileUpdatedAt` on avatar changes to bust the `CachedNetworkImage` cache key, since the `ProfileUpdated` hub payload itself carries no timestamp.
- `live_map_screen.dart`'s marker widget was promoted from private `_LiveMemberMarker` to public `LiveMemberMarker` specifically so it is directly unit-testable (`live_member_marker_test.dart`).

## Deviations from Plan
None - plan executed exactly as written. The three decisions above were within-scope implementation choices needed to satisfy the plan's own acceptance criteria (avatar-clear-on-null, live cache-busting, testability), not corrections to broken or missing behavior.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required beyond what 02-13/02-14/02-15 already established (Supabase `avatar` bucket, `Supabase__ServiceRoleKey`).

## Next Phase Readiness
- Phase 2 (Real-Time Location, History & Privacy) is now feature-complete: all 16 plans executed, PROFILE-01 through PROFILE-07 satisfied end-to-end (backend fields/endpoints/broadcast in 02-13/02-14, mobile profile screen in 02-15, live-map avatar/name markers with real-time updates in 02-16).
- No blockers. Human-verify checkpoint fully approved: avatar rendering, always-visible name labels, live ProfileUpdated propagation (name + photo add/remove), Family-Circle-scoped visibility, and no-SOS-red compliance all confirmed on physical devices.
- Phase-level closeout (VERIFICATION.md, ROADMAP phase-status flip to Complete) is intentionally left to the orchestrator, per this plan's finalization scope.

---
*Phase: 02-real-time-location-history-privacy*
*Completed: 2026-07-14*

## Self-Check: PASSED

- FOUND: `mobile/test/features/location/live_member_marker_test.dart`
- FOUND: `ae93738` (feat(02-16): extend LiveLocation with avatar fields + ProfileUpdated hub stream)
- FOUND: `8dd0b91` (feat(02-16): merge ProfileUpdated into LocationController per-member state)
- FOUND: `eb2aad5` (feat(02-16): render avatar + always-visible name label on live map markers)
