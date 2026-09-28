---
phase: quick-260820-6mb
plan: 01
subsystem: ui
tags: [flutter, dart, live-map, typography, text-rich]

# Dependency graph
requires:
  - phase: quick-260820-5xp
    provides: AppColors.offline token (0xFF8B96A3) used as the offline segment color
provides:
  - _CompactStatusSummary on the Live Map screen now renders the online count in AppColors.safe green and the offline count in AppColors.offline slate, as two independently-colored TextSpans within one Text.rich run
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns: ["Two-toned inline text via Text.rich(TextSpan(children: [...])) with a shared base style on the outer widget and only color overridden per child span"]

key-files:
  created: []
  modified:
    - mobile/lib/features/location/presentation/live_map_screen.dart

key-decisions:
  - "Separator TextSpan ('  ') left unstyled so it inherits the base Text.rich style rather than being explicitly colored, per plan instruction to keep it simple."

patterns-established: []

requirements-completed: []

coverage:
  - id: D1
    description: "Live Map compact status pill splits '$onlineCount on  $offlineCount off' into two colored TextSpans (online in AppColors.safe, offline in AppColors.offline) instead of one uniformly-green Text"
    verification:
      - kind: unit
        ref: "flutter analyze lib/features/location/presentation/live_map_screen.dart"
        status: pass
      - kind: integration
        ref: "mobile/test/features/location/live_map_screen_test.dart (full suite, 9 tests)"
        status: pass
    human_judgment: true
    rationale: "No existing widget test asserts on this pill's rendered text/colors specifically (confirmed via grep during planning) — actual two-toned rendering needs a quick visual check, though analyze+existing suite confirm no regressions."

duration: 10min
completed: 2026-08-20
status: complete
---

# Phase quick-260820-6mb: Split two-toned colors in the aggregate status pill Summary

**Live Map's online/offline count pill now renders via `Text.rich(TextSpan(...))` with the online segment in `AppColors.safe` green and the offline segment in `AppColors.offline` slate, instead of the whole string in one green color.**

## Performance

- **Duration:** ~10 min
- **Completed:** 2026-08-20T01:50:49Z
- **Tasks:** 2 completed (1 code change + 1 verification-only)
- **Files modified:** 1

## Accomplishments
- `_CompactStatusSummary.build()` in `live_map_screen.dart` replaced its single `Text('$onlineCount on  $offlineCount off', ...)` with `Text.rich(TextSpan(children: [...]))`: online segment styled `AppColors.safe`, a plain "  " separator, offline segment styled `AppColors.offline`.
- Verified `flutter analyze` is clean across the whole `mobile` package and the existing `live_map_screen_test.dart` suite (9 tests) still passes unchanged.

## Task Commits

Each task was committed atomically:

1. **Task 1: Split the online/offline pill text into two colored spans** - `2c3e89d` (feat)
2. **Task 2: Verify no regressions in the touched file's test coverage** - no commit (verification-only, no files modified)

**Plan metadata:** committed separately by orchestrator (docs commit)

## Files Created/Modified
- `mobile/lib/features/location/presentation/live_map_screen.dart` - `_CompactStatusSummary` now renders `Text.rich` with three `TextSpan`s (online count in `AppColors.safe`, separator, offline count in `AppColors.offline`); `maxLines`/`overflow` moved onto the `Text.rich` widget; DecoratedBox background/border, wifi icon, and all other widgets in the file untouched.

## Decisions Made
- Left the "  " separator span unstyled (inherits the base `Text.rich` style) rather than giving it an explicit neutral color, matching the plan's simplicity guidance.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- No blockers. This closes the direct visual follow-up to quick task 260820-5xp (which added the `AppColors.offline` token but never wired it into this pill's text).
- Visual confirmation (online count reads green, offline count reads slate, both within the same pill, background/border/icon unchanged) is a quick manual/UAT check since no widget test asserts on this pill's colors specifically.

---
*Phase: quick-260820-6mb*
*Completed: 2026-08-20*

## Self-Check: PASSED
- FOUND: mobile/lib/features/location/presentation/live_map_screen.dart
- FOUND: commit 2c3e89d
- FOUND: SUMMARY.md
