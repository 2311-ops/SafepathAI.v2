---
phase: 02-real-time-location-history-privacy
plan: 17
subsystem: ui
tags: [flutter, riverpod, live-map, avatar, profile]

# Dependency graph
requires:
  - phase: 02-real-time-location-history-privacy (plans 13-16)
    provides: profile photo upload/replace/remove pipeline, ProfileUpdated hub stream, LocationController._applyProfileUpdate, LiveMemberMarker live-avatar wiring for family member map pins
provides:
  - Live Map header identity pin (the "Your family, live" bar avatar) now reads userId/profileImageUrl/profileUpdatedAt from LocationState.selfPosition instead of a hardcoded const MemberMapPin
affects: [location, profile]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Header/self identity widgets in live_map_screen.dart must be non-const and sourced from state?.selfPosition (mirroring how LiveMemberMarker sources each family member's LiveLocation) — a const widget instance is structurally immune to Riverpod state rebuilds."

key-files:
  created: []
  modified:
    - mobile/lib/features/location/presentation/live_map_screen.dart
    - mobile/test/features/location/live_map_screen_test.dart

key-decisions:
  - "Read the header's avatar fields from state?.selfPosition (null-safe), not from the `self` fallback variable already used for the map camera target — falling back to `locations.first` would risk showing another family member's photo as the current user's own identity when selfPosition is temporarily null."
  - "label stays hardcoded 'You' per existing screen convention (_memberName already returns 'You' for the self user) — only the avatar-related fields (userId, profileImageUrl, profileUpdatedAt) needed to become state-driven."

patterns-established:
  - "Any future self/header identity element on this screen must be fed from state?.selfPosition and must not be a `const` widget instance."

requirements-completed: [PROFILE-03, PROFILE-06]

coverage:
  - id: D1
    description: "Live Map header identity avatar ('Your family, live' bar) updates live when the current user uploads, replaces, or removes their profile photo, matching family member markers"
    requirement: "PROFILE-03"
    verification:
      - kind: unit
        ref: "mobile/test/features/location/live_map_screen_test.dart#header identity pin live-updates from LocationState.selfPosition (UAT 72)"
        status: pass
      - kind: manual_procedural
        ref: "Physical device: Live Map -> Profile -> upload/replace/remove photo -> return to Live Map, header avatar updates without reload"
        status: unknown
    human_judgment: true
    rationale: "Widget test proves the pin is wired to selfPosition and rebuilds non-const; the actual end-to-end photo upload -> cache-bust -> visual avatar swap on a real device (including CachedNetworkImage re-fetch behavior) requires human device verification per the plan's human-check step."
  - id: D2
    description: "Header pin reverts to default 'You' initials (no borrowed avatar) when selfPosition is null, and to the default initial when the photo is removed"
    requirement: "PROFILE-06"
    verification:
      - kind: unit
        ref: "mobile/test/features/location/live_map_screen_test.dart#header identity pin live-updates from LocationState.selfPosition (UAT 72)"
        status: pass
    human_judgment: false

duration: 7min
completed: 2026-07-14
status: complete
---

# Phase 02 Plan 17: Live Map Header Identity Pin Wiring Summary

**Removed the `const` modifier from the Live Map header's MemberMapPin and fed it userId/profileImageUrl/profileUpdatedAt from `LocationState.selfPosition`, closing UAT test 72 (the header avatar previously never live-updated with profile photo changes while family member markers already did).**

## Performance

- **Duration:** 7 min
- **Started:** 2026-07-14T01:19:57Z
- **Completed:** 2026-07-14T01:26:44Z
- **Tasks:** 1
- **Files modified:** 2

## Accomplishments
- Live Map header identity pin ("Your family, live" bar) is now a non-const `MemberMapPin` reading `userId`, `profileImageUrl`, and `profileUpdatedAt` from `state?.selfPosition`, mirroring the existing `LiveMemberMarker` pattern.
- Added a regression widget test (`header identity pin live-updates from LocationState.selfPosition (UAT 72)`) that seeds a self position with a live avatar and asserts the header `MemberMapPin` resolves those fields — this test fails if the pin is ever reverted to a hardcoded/const instance.
- Confirmed `flutter analyze` is clean on the modified file (no unused-const or lint regressions).

## Task Commits

Each task was committed atomically (TDD: RED then GREEN):

1. **Task 1 (RED): Regression test for header identity pin** - `c522e4c` (test)
2. **Task 1 (GREEN): Wire header pin to selfPosition** - `b59b567` (fix)

**Plan metadata:** pending (docs: complete plan commit follows this SUMMARY)

_Note: No REFACTOR commit was needed — the GREEN fix was a minimal, already-clean 3-line addition plus removing `const`._

## Files Created/Modified
- `mobile/lib/features/location/presentation/live_map_screen.dart` - Removed `const` from the header `MemberMapPin`; added `userId`, `profileImageUrl`, `profileUpdatedAt` sourced from `state?.selfPosition`.
- `mobile/test/features/location/live_map_screen_test.dart` - Added `_SeededSelfAvatarLocationController` (self position with a live avatar) and the UAT-72 regression test asserting the header pin resolves avatar fields from state.

## Decisions Made
- Sourced the header's avatar fields from `state?.selfPosition` (null-safe) rather than the pre-existing `self` fallback variable (which can fall back to `locations.first` for camera centering) — this guarantees the header never borrows another family member's photo when `selfPosition` is momentarily null; it instead falls back to the neutral "You" initials.
- Kept `label: 'You'` fixed per the screen's existing self-identity convention; only the avatar-related fields needed to become state-driven.

## Deviations from Plan

None - plan executed exactly as written. Single call-site wiring fix plus a regression test, no new widgets, no redesign, no change to `MemberMapPin` itself.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- UAT test 72 (header identity avatar live-update) is now closed; the header and family member markers both source live avatar data from the same `ProfileUpdated`-driven state.
- Manual device verification (upload/replace/remove photo, observe header avatar updates without reload) remains a human-check step per the plan's `<verify>` block — recommended before closing out Phase 02's UAT pass fully.
- No blockers for subsequent Phase 02 plans or Phase 3.

---
*Phase: 02-real-time-location-history-privacy*
*Completed: 2026-07-14*

## Self-Check: PASSED

- FOUND: mobile/lib/features/location/presentation/live_map_screen.dart
- FOUND: mobile/test/features/location/live_map_screen_test.dart
- FOUND: commit c522e4c (test)
- FOUND: commit b59b567 (fix)
- FOUND: commit 81cf2fc (docs: summary)
