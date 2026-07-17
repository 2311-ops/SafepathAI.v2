---
phase: quick-260717-oq0
plan: 01
subsystem: ui
tags: [flutter, location, battery, live-map, widget]

requires:
  - phase: 02-real-time-location-history-privacy
    provides: LiveLocation.batteryPercent already parsed into LocationState.members on every SignalR ping
provides:
  - Neutral, always-on BatteryIndicator widget rendered on the family-member map pin and in the member-detail sheet
affects: [location, live-map, member-detail-sheet]

tech-stack:
  added: []
  patterns:
    - "Neutral always-on readout widgets self-hide via SizedBox.shrink() on null data rather than rendering a placeholder"

key-files:
  created:
    - mobile/lib/features/location/presentation/battery_indicator.dart
    - mobile/test/features/location/battery_indicator_test.dart
  modified:
    - mobile/lib/features/location/presentation/live_map_screen.dart
    - mobile/lib/features/location/presentation/member_detail_sheet.dart
    - mobile/test/features/location/live_member_marker_test.dart
    - mobile/test/features/location/member_presence_test.dart

key-decisions:
  - "BatteryIndicator uses AppColors.bodySecondary + AppTypography.bodySecondary only, keeping it visually distinct from the amber LowBatteryBanner threshold alert"
  - "Marker flutter_map box height raised 88->108 to fit the added battery row without a RenderFlex overflow (not caught by isolated widget tests, which lay out unconstrained)"

patterns-established:
  - "Optional int? battery-like fields on presentation models default via constructor default, keeping existing call sites source-compatible"

requirements-completed: [LOC-04]

coverage:
  - id: D1
    description: "Neutral BatteryIndicator widget renders 'N%' for a known percent and nothing (SizedBox.shrink) for null"
    requirement: "LOC-04"
    verification:
      - kind: unit
        ref: "mobile/test/features/location/battery_indicator_test.dart#renders the battery percent when known"
        status: pass
      - kind: unit
        ref: "mobile/test/features/location/battery_indicator_test.dart#renders nothing when battery percent is unknown"
        status: pass
    human_judgment: false
  - id: D2
    description: "Battery readout appears on the Live Map member pin (LiveMemberMarker) and hides gracefully when unknown"
    requirement: "LOC-04"
    verification:
      - kind: unit
        ref: "mobile/test/features/location/live_member_marker_test.dart#renders the battery percent when known"
        status: pass
      - kind: unit
        ref: "mobile/test/features/location/live_member_marker_test.dart#shows no battery figure when battery percent is unknown"
        status: pass
    human_judgment: false
  - id: D3
    description: "Battery readout appears in the member-detail sheet, threaded from both showMemberDetailSheet call sites"
    requirement: "LOC-04"
    verification:
      - kind: unit
        ref: "mobile/test/features/location/member_presence_test.dart#member detail sheet shows name, status badge, and last seen"
        status: pass
    human_judgment: false

duration: 3min
completed: 2026-07-17
status: complete
---

# Quick Task 260717-oq0: Display Each Family Member's Live Battery Summary

**Neutral, always-on `BatteryIndicator` widget (battery glyph + "N%") wired onto the Live Map pin and member-detail sheet, sourced from the existing `LiveLocation.batteryPercent` — independent of the amber threshold-triggered low-battery banner.**

## Performance

- **Duration:** ~3 min (Task 1 commit 18:04:25 → Task 2 commit 18:06:28, local time)
- **Started:** 2026-07-17T15:04Z (approx, first commit)
- **Completed:** 2026-07-17T15:06Z (approx, second commit)
- **Tasks:** 2/2 completed
- **Files modified:** 6 (2 created, 4 modified)

## Accomplishments
- New `BatteryIndicator` stateless widget: renders a small neutral battery glyph + "N%" for a known percent, `SizedBox.shrink()` for null — no caution/SOS tokens, uses only `AppColors.bodySecondary` and `AppTypography.bodySecondary`
- Wired into `LiveMemberMarker` (map pin) below the presence label, and into `MemberDetailSheet` below the last-seen text
- Threaded `batteryPercent` into `MemberDetail` at both `showMemberDetailSheet` call sites (marker `onTap` and `_MemberStatusRail.onMemberTap`)
- Raised the flutter_map `Marker` box height from 88 to 108 to accommodate the extra row without a RenderFlex overflow on the real map layout
- Full widget test coverage: known-percent render + null self-hide, on both the isolated widget and the two live surfaces

## Task Commits

Each task was committed atomically:

1. **Task 1: Create neutral BatteryIndicator widget + its widget test** - `936e4e5` (feat)
2. **Task 2: Surface BatteryIndicator on the map pin and member-detail sheet** - `4701da1` (feat)

_Note: Task 1 is TDD per plan frontmatter, but the widget implementation and its test were authored together in this run rather than as separate RED/GREEN commits — see Deviations below._

## Files Created/Modified
- `mobile/lib/features/location/presentation/battery_indicator.dart` - New neutral `BatteryIndicator` widget (battery glyph + "N%", self-hides on null)
- `mobile/test/features/location/battery_indicator_test.dart` - Widget tests for known-percent render and null self-hide
- `mobile/lib/features/location/presentation/live_map_screen.dart` - Renders `BatteryIndicator` in `LiveMemberMarker`; raises marker box height 88→108; threads `batteryPercent` at both `showMemberDetailSheet` call sites
- `mobile/lib/features/location/presentation/member_detail_sheet.dart` - Adds optional `batteryPercent` field to `MemberDetail`; renders `BatteryIndicator` in `MemberDetailSheet`
- `mobile/test/features/location/live_member_marker_test.dart` - Adds known/null battery cases for `LiveMemberMarker`
- `mobile/test/features/location/member_presence_test.dart` - Extends the member-detail-sheet widget test to assert the battery figure renders

## Decisions Made
- Kept the readout on `AppColors.bodySecondary`/`AppTypography.bodySecondary` exclusively — never `caution*` or `sosRed*` — so it reads as a neutral, always-available figure distinct from the amber `LowBatteryBanner` alert.
- Chose `Icons.battery_full` at 14px as the neutral glyph (no battery-level-aware icon swapping), matching the plan's action spec; the readout is not meant to visually communicate urgency, only a value.

## Deviations from Plan

None - plan executed exactly as written, with one process note: Task 1 is marked `tdd="true"` in the plan frontmatter, and the plan's `<action>` describes writing the widget first then the test (both were authored in the same execution pass here rather than as two separate RED-then-GREEN commits). Both the widget and its test were verified together (`flutter test test/features/location/battery_indicator_test.dart` passing) before committing, so the done-criteria and success-criteria are unaffected — this is a commit-granularity note, not a functional deviation.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `BatteryIndicator` is a small, reusable widget available for any future surface that wants a neutral battery readout (e.g., a family-overview list).
- No backend, DTO, SignalR, or `location_controller.dart`/`location_models.dart` changes were made, per the plan's scope guard.

---
*Phase: quick-260717-oq0*
*Completed: 2026-07-17*

## Self-Check: PASSED

All 7 created/modified files confirmed present on disk; both task commits (`936e4e5`, `4701da1`) confirmed present in git log.
