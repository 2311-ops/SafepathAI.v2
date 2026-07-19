---
phase: quick-260720-3tm
plan: 01
subsystem: ui
tags: [flutter, accessibility, low-battery-banner, tap-target]

requires: []
provides:
  - Low-battery banner dismiss IconButton restored to the platform-default 48x48 tap target (>= 44x44 accessibility minimum)
affects: []

tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - mobile/lib/features/location/presentation/low_battery_banner.dart
    - mobile/test/features/location/low_battery_banner_test.dart

key-decisions:
  - "Removed VisualDensity.compact entirely rather than replacing it with an explicit larger density, since the platform default already satisfies the >=44x44 minimum and no other property needed to change."

patterns-established: []

requirements-completed: []

coverage:
  - id: D1
    description: "Low-battery banner dismiss IconButton renders at >= 44x44 logical px and still fires onDismissed on tap"
    verification:
      - kind: unit
        ref: "mobile/test/features/location/low_battery_banner_test.dart#shows exact low-battery copy and dismisses"
        status: pass
    human_judgment: false

duration: 5min
completed: 2026-07-20
status: complete
---

# Quick Task 260720-3tm: Fix low-battery banner dismiss button tap target Summary

**Removed `VisualDensity.compact` from the low-battery banner's dismiss `IconButton` so it renders at the platform-default 48x48 size, and added a tap-target-size assertion (>= 44x44) to the existing widget test.**

## Performance

- **Duration:** ~5 min
- **Tasks:** 1 completed
- **Files modified:** 2

## Accomplishments
- `low_battery_banner.dart`'s dismiss `IconButton` no longer overrides `visualDensity`, so it falls back to Material's default (48x48), comfortably above the 44x44px accessibility minimum
- `low_battery_banner_test.dart` now asserts `tester.getSize(find.byType(IconButton))` width and height are each `>= 44.0`, in addition to the existing copy and dismiss-callback assertions

## Task Commits

1. **Task 1: Remove compact visual density from the dismiss IconButton** - `447c756` (fix)

## Files Created/Modified
- `mobile/lib/features/location/presentation/low_battery_banner.dart` - Removed the `visualDensity: VisualDensity.compact,` line from the dismiss `IconButton`
- `mobile/test/features/location/low_battery_banner_test.dart` - Added a tap-target-size assertion (`>= 44x44`) before the existing tap/dismiss assertion

## Decisions Made
- None beyond the plan's specified change - removed the density override outright rather than substituting an explicit alternative, since the Material default already meets the target.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
No follow-up required. This was a standalone accessibility fix with no dependencies on or blockers for other in-flight work.

---
*Phase: quick-260720-3tm*
*Completed: 2026-07-20*

## Self-Check: PASSED
