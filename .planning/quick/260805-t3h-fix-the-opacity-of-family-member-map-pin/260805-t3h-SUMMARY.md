---
phase: quick
plan: 260805-t3h
subsystem: ui
tags: [flutter, live-map, staleness, opacity, tdd, flutter_map]

# Dependency graph
requires:
  - phase: 260716-ue7
    provides: "Self/'You' pin locked to opacity 1.0; family-marker-still-fades regression guard (lessThan(1.0))"
provides:
  - "Raised staleness opacity floors (1.0 / 0.92 / 0.85 / 0.75) in the single stalenessFor() helper consumed by both LiveMemberMarker (on-map pins) and MemberMapPin (header identity pin)"
affects: [live-map, member-map-pin, staleness]

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created:
    - .planning/quick/260805-t3h-fix-the-opacity-of-family-member-map-pin/screenshots/01-live-map.png
    - .planning/quick/260805-t3h-fix-the-opacity-of-family-member-map-pin/screenshots/02-pin-closeup.png
    - .planning/quick/260805-t3h-fix-the-opacity-of-family-member-map-pin/screenshots/04-offline-pin.png
    - .planning/quick/260805-t3h-fix-the-opacity-of-family-member-map-pin/deferred-items.md
  modified:
    - mobile/lib/features/location/application/staleness.dart
    - mobile/test/features/location/staleness_test.dart

key-decisions:
  - "Only raised the four opacity: constants in stalenessFor(); left thresholds, badgeText, and badgeIsAmber untouched, matching the plan's single-source-of-truth root cause"
  - "Did not capture 03-online-pin.png: the developer's real family circle has exactly one other member (mohh), who was offline for the entire verification session; fabricating an online family-member state was explicitly forbidden by the plan"

requirements-completed: [QUICK-PIN-OPACITY]

coverage:
  - id: D1
    description: "stalenessFor() opacity floors raised to 1.0 / 0.92 / 0.85 / 0.75 across the four age bands, with thresholds/badgeText/badgeIsAmber unchanged"
    requirement: "QUICK-PIN-OPACITY"
    verification:
      - kind: unit
        ref: "mobile/test/features/location/staleness_test.dart#stalenessFor group (5 tests)"
        status: pass
      - kind: unit
        ref: "mobile/test/features/location/live_member_marker_test.dart (self-marker opacity 1.0 case + family-marker-still-fades lessThan(1.0) guard)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Family member Live Map pins read clearly on the connected physical device (R58M30TGNXV) after the opacity floor fix"
    requirement: "QUICK-PIN-OPACITY"
    verification:
      - kind: manual_procedural
        ref: ".planning/quick/260805-t3h-fix-the-opacity-of-family-member-map-pin/screenshots/01-live-map.png, 02-pin-closeup.png, 04-offline-pin.png"
        status: pass
    human_judgment: true
    rationale: "Visual legibility over map tiles is a perceptual judgment; screenshots were captured and read back by the agent (avatar/name/status/battery all crisply legible, no washed-out pins), but final sign-off on 'reads clearly' is a human call per the plan's own human-check verify step."

# Metrics
duration: 20min
completed: 2026-08-05
status: complete
---

# Quick Task 260805-t3h: Fix Family Member Live Map Pin Opacity Summary

**Raised `stalenessFor()`'s four opacity floors from 1.0/0.7/0.45/0.3 to 1.0/0.92/0.85/0.75 in the single helper both `LiveMemberMarker` and `MemberMapPin` consume, then verified on the connected physical device (R58M30TGNXV) that family pins no longer wash out over OSM tiles.**

## Performance

- **Duration:** ~20 min
- **Completed:** 2026-08-05T18:11:14Z (last task commit)
- **Tasks:** 2/2 completed
- **Files modified:** 2 Dart files (staleness.dart, staleness_test.dart) + 3 screenshots + 1 deviation-tracking note

## Accomplishments
- Family member pins on the Live Map now stay at 0.92/0.85/0.75 opacity instead of fading to 0.3, while remaining strictly `< 1.0` so the staleness cue and the 260716-ue7 regression guard both still hold.
- TDD RED→GREEN cycle: test file updated first (confirmed 4 failing assertions against the unchanged source), then source updated to match.
- Confirmed on-device (real family circle, real backend) that a family member's offline pin — avatar, name, presence label, battery — is crisply legible against the OSM tile layer at both the default zoom and a recentered zoom-17 closeup.
- Self ("You") pin remains exactly 1.0 opacity, untouched (verified visually and via the existing `live_member_marker_test.dart` self-marker case).

## Task Commits

Each task was committed atomically:

1. **Task 1 (RED): Update staleness_test.dart expectations to 0.92/0.85/0.75** - `47ea680` (test)
2. **Task 1 (GREEN): Raise the four opacity floors in staleness.dart** - `880aad6` (feat)
3. **Task 2: Capture and verify device screenshots** - `be645b1` (docs)

**Plan metadata:** commit pending (handled separately by the orchestrator's docs commit)

_Note: Task 1 used the RED→GREEN TDD flow per `tdd="true"`; no REFACTOR commit was needed since no cleanup was required after GREEN._

## Files Created/Modified
- `mobile/lib/features/location/application/staleness.dart` - Raised the sub-15-min band (0.7→0.92), sub-1-hour band (0.45→0.85), and final fallthrough band (0.3→0.75); sub-2-min band unchanged at 1.0
- `mobile/test/features/location/staleness_test.dart` - Updated the four hard-coded alpha expectations and renamed the oldest-band test to describe the new 0.75 floor
- `.planning/quick/260805-t3h-fix-the-opacity-of-family-member-map-pin/screenshots/01-live-map.png` - Full Live Map: header "Your family, live" rail (1 online / 1 offline), self pin "You" (online, opaque), and family member "mohh" pin (offline) visible at a distance, both legible
- `.planning/quick/260805-t3h-fix-the-opacity-of-family-member-map-pin/screenshots/02-pin-closeup.png` - Camera recentered (rail-card tap, zoom 17, per 260717-pwh behavior) on "mohh"'s offline pin: avatar photo, "mohh" name label, "OFFLINE" presence label, and "100%" battery readout all crisply legible against the map tiles
- `.planning/quick/260805-t3h-fix-the-opacity-of-family-member-map-pin/screenshots/04-offline-pin.png` - Same closeup as 02, saved under the offline-state naming convention since this was the only non-self family member observable
- `.planning/quick/260805-t3h-fix-the-opacity-of-family-member-map-pin/deferred-items.md` - Logs a pre-existing, unrelated `member_map_pin_semantics_test.dart` failure found during verification

## Decisions Made
- Kept the fix to exactly the four `opacity:` literals in `stalenessFor()`, per the plan's root-cause analysis that both `LiveMemberMarker` and `MemberMapPin` read from this single helper. No changes to `live_map_screen.dart` or `member_map_pin.dart`.
- Did not capture `03-online-pin.png`. The developer's live family circle contains exactly one other member ("mohh"), who was offline for the full verification session; the only "online" entity visible was the self pin, which is a structurally different, always-opaque code path (per 260716-ue7) and not representative of the staleness fade this task tunes. Per the plan's explicit honesty rule, this limitation is stated here rather than manufacturing a fake online member.
- Used `--dart-define-from-file=env.json --dart-define=API_BASE_URL=http://127.0.0.1:5059` (per `start_mobile.md`) and `adb reverse tcp:5059 tcp:5059` to run the app against the already-running local backend — required for the app to boot at all (see Deviations).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] App failed to launch without Supabase dart-defines and backend port forward**
- **Found during:** Task 2 (starting `flutter run` on the connected device)
- **Issue:** `flutter run -d R58M30TGNXV` alone crashed on launch with `Bad state: Missing SUPABASE_URL or SUPABASE_ANON_KEY. Pass both via --dart-define.` — the plan's action text didn't specify these flags.
- **Fix:** Force-stopped the crashed app, confirmed the local backend was already listening on port 5059, ran `adb -s R58M30TGNXV reverse tcp:5059 tcp:5059`, then relaunched with `flutter run -d R58M30TGNXV --dart-define-from-file=env.json --dart-define=API_BASE_URL=http://127.0.0.1:5059` (the project's own documented `start_mobile.md` launch command). App booted successfully, Supabase init completed, and the existing session was already authenticated.
- **Files modified:** None (launch command only, no source changes)
- **Verification:** App reached the Live Map with live family data (1 online, 1 offline) within seconds of launch.
- **Committed in:** N/A (no file changes required)

**2. Git Bash `/sdcard/...` path mangling on Windows**
- **Found during:** Task 2 (first `adb shell screencap` attempt)
- **Issue:** Git Bash's MSYS path conversion silently rewrote `/sdcard/....png` before it reached `adb`, causing `screencap`/`pull` to fail with a usage error.
- **Fix:** Prefixed each `adb` invocation with `MSYS_NO_PATHCONV=1`.
- **Files modified:** None (shell invocation only)
- **Verification:** Screenshots pulled successfully afterward.
- **Committed in:** N/A

**3. [Scope Boundary - deferred, not fixed] Pre-existing `member_map_pin_semantics_test.dart` failure**
- **Found during:** Task 1's required verification run (`flutter test test/features/location/staleness_test.dart test/features/location/live_member_marker_test.dart test/shared_widgets/member_map_pin_semantics_test.dart`)
- **Issue:** Both tests in that file fail with `A SemanticsHandle was active at the end of the test` — a test-harness disposal leak unrelated to opacity, reproducing identically in isolation and with `member_map_pin.dart` untouched by this task.
- **Action taken:** NOT fixed (out of scope per the Scope Boundary rule — this task modified only `staleness.dart`/`staleness_test.dart`). Logged to `deferred-items.md` with a recommendation to file a follow-up quick task.
- **Files modified:** None (logged only)
- **Verification:** Confirmed the failure reproduces before and independent of any change in this plan.
- **Committed in:** `be645b1` (deferred-items.md)

---

**Total deviations:** 3 (2 auto-fixed launch/tooling blockers under Rule 3, 1 deferred/out-of-scope pre-existing test failure documented per the Scope Boundary rule)
**Impact on plan:** None of the deviations touched the opacity fix itself or any file outside the plan's declared `files_modified` list (plus the deviation-tracking note). No scope creep.

## Issues Encountered
- See Deviations above (app launch flags, Git Bash path mangling, pre-existing unrelated test failure). All resolved or explicitly deferred without expanding the change surface.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Family member Live Map pins now read clearly at all staleness levels (0.92 minimum for the fresh-stale band, 0.75 floor beyond one hour), closing the "too transparent" report.
- The self pin, badge text, amber styling, and staleness thresholds are unchanged and still covered by existing tests.
- Follow-up recommended (not part of this task): fix the `SemanticsHandle` disposal leak in `member_map_pin_semantics_test.dart` (see `deferred-items.md`).
- Follow-up recommended (not part of this task, informational only): if/when an online (non-self) family member becomes available on a test device, capture `03-online-pin.png` to complete the online/offline visual comparison pair.

---
*Phase: quick*
*Completed: 2026-08-05*

## Self-Check: PASSED

All files (staleness.dart, staleness_test.dart, 3 screenshots, deferred-items.md, this SUMMARY.md)
and all 3 task commit hashes (47ea680, 880aad6, be645b1) verified present.
