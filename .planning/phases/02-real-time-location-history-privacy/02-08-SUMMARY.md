---
phase: 02-real-time-location-history-privacy
plan: 08
subsystem: mobile-location-history
tags: [flutter, riverpod, google-maps, location-history, ui, tdd]

# Dependency graph
requires:
  - phase: 02-real-time-location-history-privacy
    provides: P04 history and travel-stats endpoints, P06 Google Maps shell, P07 live-map patterns
provides:
  - Mobile LocationApi history and travel-stats methods for the P04 endpoints
  - LocationHistory, RoutePoint, HistoryStop, and TravelStats mobile models
  - HistoryController with loading, denied-error, and empty-range states
  - Activity tab history timeline with member/date controls, stat tiles, and timeline nodes
  - Route stats sheet rendering past travel through google_maps_flutter Polyline and stop markers
affects: [02-09, 03-sos-fast-path, 05-ai-analytics]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Mobile history reads infer the active family from FamilyController, then call LocationApi.getHistory and getTravelStats for the selected member/day."
    - "Travel stats render through shared StatTile using AppTypography.statValue at 20px/800."
    - "Past routes render with google_maps_flutter Polyline, never CustomPainter."

key-files:
  created:
    - mobile/lib/features/location/application/history_controller.dart
    - mobile/lib/features/location/presentation/history_timeline_screen.dart
    - mobile/lib/features/location/presentation/route_stats_sheet.dart
    - mobile/lib/shared_widgets/stat_tile.dart
    - mobile/lib/shared_widgets/timeline_node.dart
    - mobile/test/features/location/history_controller_test.dart
    - mobile/test/features/location/history_timeline_screen_test.dart
  modified:
    - mobile/lib/features/location/data/location_api.dart
    - mobile/lib/features/location/data/location_models.dart
    - mobile/lib/features/home/presentation/main_shell.dart
    - mobile/lib/core/theme/app_typography.dart
    - mobile/test/helpers/fake_location_api.dart

key-decisions:
  - "HistoryController derives familyId from FamilyController instead of duplicating family discovery in the location feature."
  - "Mobile TravelStats accepts both backend totalDistanceMeters and plan shorthand distanceMeters, and parses TimeSpan string formats defensively."
  - "Activity is hosted directly inside MainShell's IndexedStack; no separate /activity route was needed."
  - "The remaining SOS, Insights, and Privacy shell placeholders stay intentionally scoped to later plans/phases."

patterns-established:
  - "Use seeded HistoryController overrides for history UI widget tests so GoogleMap routes are not instantiated unless the route sheet is opened."
  - "Keep route visualization map-specific code in route_stats_sheet.dart and timeline/list code in history_timeline_screen.dart."

requirements-completed: [HIST-01, HIST-02, HIST-03]

coverage:
  - id: D1
    description: "HistoryController loads route polyline points, detected stops, and travel stats for a selected member/date range, with friendly 403 and empty-range states."
    requirement: HIST-01
    verification:
      - kind: unit
        ref: "flutter test test/features/location/history_controller_test.dart"
        status: pass
    human_judgment: false
  - id: D2
    description: "Activity tab renders history stat tiles and a scrollable timeline of stops/movement with the locked No history yet copy."
    requirement: HIST-01
    verification:
      - kind: automated_ui
        ref: "flutter test test/features/location/history_timeline_screen_test.dart"
        status: pass
      - kind: integration
        ref: "flutter test test/features/location"
        status: pass
    human_judgment: false
  - id: D3
    description: "Past routes render in a bottom sheet using google_maps_flutter Polyline and stop Markers, paired with travel stat tiles."
    requirement: HIST-02
    verification:
      - kind: integration
        ref: "flutter analyze lib/features/location lib/features/home"
        status: pass
      - kind: other
        ref: "Select-String route_stats_sheet.dart for Polyline and absence of CustomPainter route rendering"
        status: pass
    human_judgment: true
    rationale: "Real map tile rendering and camera framing need device/API-key visual review even though static API usage is verified."
  - id: D4
    description: "Travel statistics show distance, time away, and stop count as shared StatTile widgets using the new stat value typography role."
    requirement: HIST-03
    verification:
      - kind: automated_ui
        ref: "mobile/test/features/location/history_timeline_screen_test.dart#renders stat tiles and timeline nodes from seeded history"
        status: pass
    human_judgment: false

duration: 9min
completed: 2026-07-13
status: complete
---

# Phase 02 Plan 08: Mobile History Timeline, Route, and Stats Summary

**Activity tab history with authorized member/day timeline, native Google Maps route polyline, and distance/time/stops stat tiles.**

## Performance

- **Duration:** 9 min
- **Started:** 2026-07-13T00:25:51Z
- **Completed:** 2026-07-13T00:34:33Z
- **Tasks:** 3 completed
- **Files modified:** 12 plan files plus this summary

## Accomplishments

- Extended the mobile location data layer with history and travel-stats calls matching the P04 backend endpoint shapes.
- Added `HistoryController` with tested loading, History-share-denied, and empty-range states.
- Built shared `StatTile` and `TimelineNode` widgets plus the Activity timeline screen.
- Added a route stats bottom sheet that renders a Google Maps `Polyline` and stop markers for past travel.
- Replaced the Activity placeholder in `MainShell` with the live history timeline.

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: History controller behavior tests** - `053e8a5` (test)
2. **Task 1 GREEN: History data layer and controller** - `46cd981` (feat)
3. **Task 2: StatTile, TimelineNode, and history timeline UI** - `736a290` (feat)
4. **Task 3: Route stats sheet and Activity tab wiring** - `d76abcf` (feat)

**Plan metadata:** pending close-out commit

## Files Created/Modified

- `mobile/lib/features/location/application/history_controller.dart` - Riverpod controller for selected member/day history and stats.
- `mobile/lib/features/location/data/location_api.dart` - Added `getHistory` and `getTravelStats` endpoint calls.
- `mobile/lib/features/location/data/location_models.dart` - Added history, route point, stop, and travel stats models.
- `mobile/lib/features/location/presentation/history_timeline_screen.dart` - Activity tab timeline, member/date controls, stats, empty/error/loading states, and route action.
- `mobile/lib/features/location/presentation/route_stats_sheet.dart` - GoogleMap route sheet with native `Polyline`, stop markers, and stat tiles.
- `mobile/lib/shared_widgets/stat_tile.dart` - Shared stat tile using the 20px/800 stat value role.
- `mobile/lib/shared_widgets/timeline_node.dart` - Shared timeline stop/transit node.
- `mobile/lib/features/home/presentation/main_shell.dart` - Activity tab now hosts `HistoryTimelineScreen`.
- `mobile/lib/core/theme/app_typography.dart` - Added `statValue` role required by the UI-SPEC.
- `mobile/test/helpers/fake_location_api.dart` - Extended fake to satisfy the expanded `LocationApi` contract.
- `mobile/test/features/location/history_controller_test.dart` - TDD coverage for load/error/empty behavior.
- `mobile/test/features/location/history_timeline_screen_test.dart` - Widget coverage for stats, timeline nodes, and empty copy.

## Decisions Made

- `HistoryController.load(targetUserId, fromUtc, toUtc)` reads the active `familyId` from `FamilyController`; this keeps family bootstrap centralized and avoids another family-discovery path.
- The Activity tab remains inside `MainShell`'s `IndexedStack`; no `/activity` route was added because the tab is already shell-hosted.
- `TravelStats.fromJson` accepts the actual backend `totalDistanceMeters` field and the plan shorthand `distanceMeters`, and defensively parses common `TimeSpan` string forms.
- Route rendering is isolated to `route_stats_sheet.dart`; timeline rendering stays in `history_timeline_screen.dart`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added AppTypography.statValue**
- **Found during:** Task 2
- **Issue:** The UI-SPEC required a 20px/800 "Stat value" role, but the existing design token file did not expose it.
- **Fix:** Added `AppTypography.statValue` and used it from `StatTile`.
- **Files modified:** `mobile/lib/core/theme/app_typography.dart`, `mobile/lib/shared_widgets/stat_tile.dart`
- **Verification:** `flutter test test/features/location/history_timeline_screen_test.dart`; `flutter analyze`
- **Committed in:** `736a290`

**2. [Rule 3 - Blocking] Extended FakeLocationApi after widening LocationApi**
- **Found during:** Task 1
- **Issue:** Adding history methods to `LocationApi` made the shared fake incomplete for existing location tests.
- **Fix:** Added fake history/stats returns, call counts, and captured request arguments.
- **Files modified:** `mobile/test/helpers/fake_location_api.dart`
- **Verification:** `flutter test test/features/location`
- **Committed in:** `46cd981`

---

**Total deviations:** 2 auto-fixed (1 missing critical, 1 blocking)
**Impact on plan:** Both changes were required to satisfy the planned UI contract and keep the existing test suite compiling; no feature scope was widened.

## Issues Encountered

- `ctx7` was not installed, so `google_maps_flutter` lookup through Context7 could not run. The implementation used the already-shipped local `LiveMapScreen` Google Maps pattern and the installed package API.

## User Setup Required

Existing Plan 02-06 Maps setup still applies: real map tiles require Android/iOS Google Maps API keys in local/device builds. No new external configuration was added by this plan.

## Known Stubs

| File | Line | Stub | Reason |
|------|------|------|--------|
| `mobile/lib/features/home/presentation/main_shell.dart` | 51 | "Emergency tools are coming soon." | SOS behavior is Phase 03 scope; 02-08 only replaces Activity. |
| `mobile/lib/features/home/presentation/main_shell.dart` | 56 | "Insights are coming soon" | Insights are Phase 05 scope. |
| `mobile/lib/features/home/presentation/main_shell.dart` | 61 | "Privacy controls are coming soon." | Privacy Center mobile UI is Phase 02 Plan 09 scope. |
| `mobile/lib/features/home/presentation/main_shell.dart` | 108 | "Coming soon" snack bar | Inert SOS center tab behavior intentionally remains until Phase 03. |

## Verification

- `flutter test test/features/location/history_controller_test.dart` - passed, 3 tests.
- `flutter test test/features/location/history_timeline_screen_test.dart` - passed, 2 tests.
- `flutter analyze lib/features/location lib/features/home` - passed, no issues.
- `flutter test test/features/location` - passed, 20 tests.
- `flutter analyze` - passed, no issues.
- Static scans confirmed `route_stats_sheet.dart` uses `Polyline` and has no `CustomPainter` route implementation.
- Static scans confirmed no `sosRed` usage in `history_timeline_screen.dart`, `route_stats_sheet.dart`, `stat_tile.dart`, or `timeline_node.dart`.

## TDD Gate Compliance

- RED commit present: `053e8a5`
- GREEN commit present after RED: `46cd981`
- No refactor commit was needed.

## Next Phase Readiness

- Plan 02-09 can replace the remaining Privacy placeholder without touching the Activity history flow.
- Future analytics/dashboard work can reuse `LocationHistory` and `TravelStats` mobile models for movement summaries.
- Human/device review should still confirm Google Maps tile rendering and route camera framing with provisioned API keys.

---
*Phase: 02-real-time-location-history-privacy*
*Completed: 2026-07-13*

## Self-Check: PASSED

Created/modified plan artifacts exist on disk (`history_controller.dart`, `history_timeline_screen.dart`, `route_stats_sheet.dart`, `stat_tile.dart`, `timeline_node.dart`, and the two history tests); task commits `053e8a5`, `46cd981`, `736a290`, and `d76abcf` are present in git log; final verification commands listed above passed.
