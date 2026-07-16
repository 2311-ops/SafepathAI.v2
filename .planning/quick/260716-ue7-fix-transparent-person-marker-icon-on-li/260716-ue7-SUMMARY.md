---
phase: quick
plan: 260716-ue7
subsystem: ui
tags: [flutter, live-map, staleness, opacity, widget-test]

requires: []
provides:
  - LiveMemberMarker forces opacity 1.0 for the self ("You") marker, bypassing stalenessFor()
  - Regression tests locking self-marker-always-opaque + family-marker-still-fades behavior
affects: [location, live-map]

tech-stack:
  added: []
  patterns:
    - "isSelf gates staleness fade in LiveMemberMarker: self markers never fade, family markers keep stalenessFor()"

key-files:
  created: []
  modified:
    - mobile/lib/features/location/presentation/live_map_screen.dart
    - mobile/test/features/location/live_member_marker_test.dart

key-decisions:
  - "Scoped the fix to LiveMemberMarker.build()'s opacity assignment only — isSelf now short-circuits to 1.0 instead of calling stalenessFor(), no changes to staleness.dart, MemberMapPin, or family-marker styling."

patterns-established: []

requirements-completed: [QUICK-MARKER-OPACITY]

coverage:
  - id: D1
    description: "Self/'You' marker on the live map renders fully opaque regardless of ping staleness"
    requirement: "QUICK-MARKER-OPACITY"
    verification:
      - kind: unit
        ref: "mobile/test/features/location/live_member_marker_test.dart#self marker stays fully opaque when its ping is stale"
        status: pass
    human_judgment: false
  - id: D2
    description: "Family-member markers keep their existing staleness fade (opacity < 1 when stale)"
    requirement: "QUICK-MARKER-OPACITY"
    verification:
      - kind: unit
        ref: "mobile/test/features/location/live_member_marker_test.dart#family member marker still fades when its ping is stale"
        status: pass
    human_judgment: false
  - id: D3
    description: "Live emulator visual confirmation that the on-map 'You' marker now renders solid, matching the header pin, after hot reload"
    verification: []
    human_judgment: true
    rationale: "Requires triggering hot reload (pressing 'r') in the attached flutter run terminal session, which is not accessible to this subagent — only the user/orchestrator holding that terminal can trigger it and visually confirm the result."

duration: 15min
completed: 2026-07-16
status: complete
---

# Quick Task 260716-ue7: Fix transparent person marker icon on live map Summary

**LiveMemberMarker now forces opacity 1.0 for the self/"You" marker, bypassing the ping-staleness fade that was incorrectly being applied to the user's own position; family-member staleness fading is unchanged.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-07-16T18:47:00Z
- **Completed:** 2026-07-16T19:01:48Z
- **Tasks:** 2 of 3 executed (Task 3 is a human-verify checkpoint, see below)
- **Files modified:** 2

## Accomplishments
- Root cause confirmed in code: `LiveMemberMarker.build()` unconditionally computed `opacity` from `stalenessFor(...).opacity`, so the user's own marker faded to 0.3/0.45 opacity whenever their own ping was more than a few minutes old — even though the device always knows its own position.
- Fixed: `opacity` is now `1.0` when `isSelf` is true; otherwise the existing `stalenessFor(...)` computation is unchanged for family members.
- Added two regression widget tests: one pins the self-marker-always-opaque behavior, the other pins that family-member staleness fading was NOT globally removed.
- Verified via `adb screencap` (pre-fix) that the on-map "You" marker was visibly faded compared to the solid header "You" pin — matches the plan's root-cause screenshot description.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add regression tests locking self-marker opacity (RED)** - `d56da90` (test)
2. **Task 2: Force full opacity for the self/person marker (GREEN)** - `5cc9cd8` (fix)

Task 3 (checkpoint:human-verify) was not auto-approved — see "Blocked / Needs Human Action" below.

_Note: docs metadata commit (SUMMARY.md, STATE.md) is created separately by the orchestrator per this quick task's constraints._

## Files Created/Modified
- `mobile/lib/features/location/presentation/live_map_screen.dart` - `LiveMemberMarker.build()`: `opacity` is `1.0` when `isSelf`, else unchanged `stalenessFor(...)` value
- `mobile/test/features/location/live_member_marker_test.dart` - added "self marker stays fully opaque when its ping is stale" (RED→GREEN) and "family member marker still fades when its ping is stale" (regression guard) tests

## Decisions Made
- Kept the fix to a single conditional expression (`isSelf ? 1.0 : stalenessFor(...).opacity`) rather than restructuring `stalenessFor()` or `LiveMemberMarker` — smallest change that satisfies both must-have truths without touching `staleness.dart`, `MemberMapPin`, or any styling/geometry.

## Deviations from Plan

None - plan executed exactly as written for Tasks 1 and 2.

## Issues Encountered

None for Tasks 1-2. `flutter test test/features/location/live_member_marker_test.dart` confirmed RED (Test A failed with `Expected: <1.0> Actual: <0.3>`, Test B and the 3 pre-existing tests passed) before the fix, then GREEN (all 5 tests pass) after.

## Blocked / Needs Human Action

**Task 3 (checkpoint:human-verify, gate="blocking") was NOT completed by this agent — it requires a manual action only the user/orchestrator holding the live `flutter run` terminal can perform:**

1. The code fix is committed and the widget-test suite proves the behavior in isolation, but the already-running app on `emulator-5554` is still running the pre-fix compiled code.
2. This subagent cannot send the hot-reload keystroke (`r`) to the attached `flutter run` process — that terminal session is not accessible to it.
3. **Action needed:** In the terminal running `flutter run`, press `r` to hot-reload, then visually confirm on `emulator-5554` that the "You" marker (avatar, name pill, "ONLINE" badge) now renders solid/opaque, matching the header "You" pin.
4. A pre-fix screenshot was captured for reference during this session (`adb -s emulator-5554 exec-out screencap -p`) confirming the on-map "You" marker was visibly faded prior to the fix, consistent with the plan's root-cause description. No post-hot-reload screenshot exists yet since hot reload was not triggered.

Do not treat this quick task as visually verified until a human performs the hot reload and confirms.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Code fix and regression tests are complete and committed; safe to build on.
- Remaining action: user must hot-reload the running app and visually confirm the fix on-device (see "Blocked / Needs Human Action" above).

---
*Quick task: 260716-ue7*
*Completed: 2026-07-16*

## Self-Check: PASSED

- FOUND: mobile/lib/features/location/presentation/live_map_screen.dart
- FOUND: mobile/test/features/location/live_member_marker_test.dart
- FOUND commit: d56da90 (test: add failing regression test)
- FOUND commit: 5cc9cd8 (fix: keep self marker fully opaque)
