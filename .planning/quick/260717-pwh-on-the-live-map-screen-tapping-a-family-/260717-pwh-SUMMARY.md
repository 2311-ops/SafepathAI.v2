---
phase: quick-260717-pwh
plan: 01
subsystem: ui
tags: [flutter, flutter_map, riverpod, widget-test]

# Dependency graph
requires:
  - phase: 02-real-time-location-history-privacy
    provides: LiveMapScreen built on flutter_map (OSM) with LiveMemberMarker and _MemberStatusRail
provides:
  - LiveMapScreen as a ConsumerStatefulWidget owning a MapController
  - Rail-card tap recenters the map camera on that member's exact live LatLng at zoom 17
  - Marker-pin tap (LiveMemberMarker.onTap) unchanged — still opens the member detail sheet
affects: [location, live-map]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "@visibleForTesting constructor seam (mapController) lets a widget test own and read a MapController's camera without adding a test-only exported field"

key-files:
  created: []
  modified:
    - mobile/lib/features/location/presentation/live_map_screen.dart
    - mobile/test/features/location/live_map_screen_test.dart

key-decisions:
  - "Converted LiveMapScreen from ConsumerWidget to ConsumerStatefulWidget so a single MapController can persist across rebuilds and be driven imperatively from the rail-card tap handler"
  - "MapController ownership is tracked via _ownsController so a test-injected controller is never disposed by the State (test owns its own teardown)"

patterns-established:
  - "Test-owned MapController via @visibleForTesting constructor param: inject a controller in tests to assert on controller.camera after simulated interactions"

requirements-completed: ["260717-pwh"]

coverage:
  - id: D1
    description: "Tapping a member's rail card recenters the FlutterMap camera on that member's exact LatLng at zoom 17 and does not open the member detail sheet"
    requirement: "260717-pwh"
    verification:
      - kind: unit
        ref: "mobile/test/features/location/live_map_screen_test.dart#tapping a rail card recenters the map on that member and does not open the detail sheet"
        status: pass
    human_judgment: false
  - id: D2
    description: "Tapping a member's map marker pin (LiveMemberMarker.onTap) still opens the member detail bottom sheet, unchanged"
    requirement: "260717-pwh"
    verification:
      - kind: unit
        ref: "mobile/test/features/location/live_member_marker_test.dart#tapping the marker invokes onTap"
        status: pass
    human_judgment: false

# Metrics
duration: ~20min
completed: 2026-07-17
status: complete
---

# Quick Task 260717-pwh: Rail-Card-Tap-Recenters-Map Summary

**Rail-card tap now pans the FlutterMap camera (via a State-owned MapController) onto a member's exact live LatLng at zoom 17, instead of opening the member detail sheet; marker-pin tap keeps opening the sheet.**

## Performance

- **Duration:** ~20 min
- **Completed:** 2026-07-17T15:54:41Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- `LiveMapScreen` converted from `ConsumerWidget` to `ConsumerStatefulWidget` (`_LiveMapScreenState`), owning a `MapController` created in `initState` and disposed in `dispose` (only when State-created — a test-injected controller is left for the test to dispose).
- `FlutterMap` wired to that `MapController`.
- `_MemberStatusRail`'s `onMemberTap` now calls `_mapController.move(LatLng(member.location.lat, member.location.lng), 17)` instead of `showMemberDetailSheet`.
- `LiveMemberMarker.onTap` (marker-pin path) left completely unchanged — still opens the member detail sheet.
- Each `_MemberStatusCard` now carries a stable `ValueKey('member-card-<userId>')` for test targeting.
- New widget test proves the rail-card tap recenters the injected controller's camera to the exact expected LatLng/zoom and that no `MemberDetailSheet` appears.

## Task Commits

Each task was committed atomically:

1. **Task 1: Convert LiveMapScreen to a ConsumerStatefulWidget owning a MapController and recenter on rail-card tap** - `4ddb746` (feat)
2. **Task 2: Add a widget test proving rail-card tap recenters the map and does not open the detail sheet** - `2a3eb7d` (test)

**Plan metadata:** (this commit)

## Files Created/Modified
- `mobile/lib/features/location/presentation/live_map_screen.dart` - LiveMapScreen is now a ConsumerStatefulWidget owning a MapController; rail-card tap recenters the map instead of opening the detail sheet; marker-pin tap unchanged
- `mobile/test/features/location/live_map_screen_test.dart` - New test asserting rail-card tap recenters an injected MapController's camera and does not open MemberDetailSheet

## Decisions Made
- Used a `@visibleForTesting` `mapController` constructor param as the test seam (per plan) rather than exposing the State or a provider, keeping production callers unchanged (`const LiveMapScreen()`).
- Kept the static `_memberColor`/`_memberName` helpers inside `_LiveMapScreenState` (same-file private access, no cross-class qualification needed) rather than referencing them via `LiveMapScreen._memberColor`.

## Deviations from Plan

None - plan executed exactly as written. One incidental lint cleanup: initially imported `package:flutter/foundation.dart` for `@visibleForTesting`, but `flutter analyze` flagged it as an `unnecessary_import` (the annotation is already re-exported by `package:flutter/material.dart`, which the file already imports) — removed the redundant import before committing. This is not a deviation from plan behavior, just keeping `flutter analyze` clean as the plan's own verify step requires.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- No blockers. The rail-card-tap-to-recenter interaction is fully wired and tested; marker-pin-tap-to-detail-sheet is verified unchanged via the pre-existing `live_member_marker_test.dart`.

---
*Plan: quick-260717-pwh*
*Completed: 2026-07-17*

## Self-Check: PASSED

- FOUND: mobile/lib/features/location/presentation/live_map_screen.dart
- FOUND: mobile/test/features/location/live_map_screen_test.dart
- FOUND: .planning/quick/260717-pwh-on-the-live-map-screen-tapping-a-family-/260717-pwh-SUMMARY.md
- FOUND commit: 4ddb746
- FOUND commit: 2a3eb7d
