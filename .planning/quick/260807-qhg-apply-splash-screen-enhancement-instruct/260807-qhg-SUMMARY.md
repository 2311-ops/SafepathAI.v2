---
phase: quick-260807-qhg
plan: 260807-qhg
subsystem: ui
tags: [flutter, animation, splash, accessibility, semantics, widget-test]

# Dependency graph
requires:
  - phase: 01.1-animated-logo-splash-screen
    provides: SplashScreen + StartupSplashOverlay baseline motion (fade/scale/rise), splashAnimationCompleteProvider gate
provides:
  - Shared AnimatedSafePathMark widget (ring trace + staggered per-letter wordmark + halo) consumed by both splash surfaces
  - 1800ms synced duration on both SplashScreen and StartupSplashOverlay
  - FakeAsync-compatible progress timing for StartupSplashOverlay (tick accumulation instead of real Stopwatch)
affects: [splash, launch-motion, accessibility, shared_widgets]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Single shared AnimatedWidget (AnimatedSafePathMark) consumed by two callers via an Animation<double> (raw AnimationController vs AlwaysStoppedAnimation-wrapped double) so motion tweaks can never drift between the routed page and the cold-start overlay again."
    - "Timer.periodic progress computed via tick-count accumulation (ticks * fixed interval) rather than a real-time Stopwatch, so FakeAsync-driven widget tests (tester.pump(duration)) can deterministically drive Timer-based (non-AnimationController) progress."

key-files:
  created:
    - mobile/lib/shared_widgets/animated_safepath_mark.dart
  modified:
    - mobile/lib/features/splash/presentation/splash_screen.dart
    - mobile/test/features/splash/splash_screen_test.dart

key-decisions:
  - "Used AppSpacing.lg (24) instead of the handoff file's hardcoded 18 for mark-to-wordmark spacing — 18 isn't on the project's fixed 4pt scale, and 24 is what the current splash already ships and what 01-UI-SPEC.md specifies."
  - "Added a merged Semantics(label: 'SafePath AI') wrapper plus a FittedBox(fit: BoxFit.scaleDown) guard around the per-letter Row — both remediate regressions the per-letter split itself introduces (screen readers announcing 11 separate letters; RenderFlex overflow at large text scale/narrow width), not requested literally by the handoff but required by the plan's own must_haves."
  - "Replaced StartupSplashOverlay's Stopwatch.elapsedMilliseconds progress read with tick-count accumulation on the same Timer.periodic (Rule 3 deviation) — a real Stopwatch is not driven by flutter_test's FakeAsync zone, so tester.pump(duration) elapsed the fake clock without ever advancing Stopwatch's real-time read, making the overlay's progress permanently untestable."

patterns-established:
  - "Any future per-letter/staggered text reveal must wrap its Row in Semantics(label: fullText) + ExcludeSemantics to avoid the same screen-reader regression, and in FittedBox(fit: BoxFit.scaleDown) to avoid the same overflow regression."

requirements-completed: [QUICK-SPLASH-SHARED-MARK, QUICK-SPLASH-RING-TRACE, QUICK-SPLASH-LETTER-STAGGER, QUICK-SPLASH-REDUCED-MOTION, QUICK-SPLASH-DURATION-SYNC]

coverage:
  - id: D1
    description: "Shared AnimatedSafePathMark widget with traced 2*pi*r ring, halo rotation (0.42 turns), and per-letter staggered wordmark reveal, ported from the design handoff and wired directly to SafePathLogo (no placeholder indirection)"
    requirement: QUICK-SPLASH-SHARED-MARK
    verification:
      - kind: unit
        ref: "flutter analyze --no-pub lib/shared_widgets/animated_safepath_mark.dart"
        status: pass
      - kind: automated_ui
        ref: "mobile/test/features/splash/splash_screen_test.dart#content renders"
        status: pass
    human_judgment: false
  - id: D2
    description: "Ring closes fully via 2*pi*progress against the same stroked radius, present under motion and absent under reduced motion on both surfaces"
    requirement: QUICK-SPLASH-RING-TRACE
    verification:
      - kind: automated_ui
        ref: "mobile/test/features/splash/splash_screen_test.dart#ring is drawn mid-animation with motion enabled"
        status: pass
      - kind: automated_ui
        ref: "mobile/test/features/splash/splash_screen_test.dart#reduced motion path shows the full lockup and flips within ~250ms"
        status: pass
      - kind: automated_ui
        ref: "mobile/test/features/splash/splash_screen_test.dart#StartupSplashOverlay reduced motion renders the wordmark with no ring, then clears to reveal the child"
        status: pass
    human_judgment: false
  - id: D3
    description: "Wordmark letters reveal independently left to right (per-letter Opacity/Transform.translate on an easeOutQuart interval), while still announcing once as 'SafePath AI' to screen readers"
    requirement: QUICK-SPLASH-LETTER-STAGGER
    verification:
      - kind: automated_ui
        ref: "mobile/test/features/splash/splash_screen_test.dart#content renders"
        status: pass
    human_judgment: false
  - id: D4
    description: "MediaQuery.disableAnimations renders the resting frame instantly on both surfaces: no ring, no sheen, no stagger, wordmark is a single centred Text"
    requirement: QUICK-SPLASH-REDUCED-MOTION
    verification:
      - kind: automated_ui
        ref: "mobile/test/features/splash/splash_screen_test.dart#reduced motion path shows the full lockup and flips within ~250ms"
        status: pass
      - kind: automated_ui
        ref: "mobile/test/features/splash/splash_screen_test.dart#StartupSplashOverlay reduced motion renders the wordmark with no ring, then clears to reveal the child"
        status: pass
    human_judgment: false
  - id: D5
    description: "SplashScreen and StartupSplashOverlay both run 1800ms so the overlay's fade-out window at progress 0.86 still covers the handoff to the real route"
    requirement: QUICK-SPLASH-DURATION-SYNC
    verification:
      - kind: automated_ui
        ref: "mobile/test/features/splash/splash_screen_test.dart#animation runs once and flips the gate exactly once"
        status: pass
      - kind: integration
        ref: "mobile/test/features/splash/splash_redirect_gate_test.dart"
        status: pass
    human_judgment: false

duration: 17min
completed: 2026-08-07
status: complete
---

# Quick Task 260807-qhg: Consolidate Splash Lockup Summary

**Shared `AnimatedSafePathMark` widget (traced ring + staggered per-letter wordmark + 0.42-turn halo) replaces the two duplicated glow/sheen implementations in `SplashScreen` and `StartupSplashOverlay`, both now synced to an 1800ms window.**

## Performance

- **Duration:** ~17 min
- **Started:** 2026-08-07T19:13:53+03:00
- **Completed:** 2026-08-07T19:30:43+03:00
- **Tasks:** 3 (plus 1 deviation fix)
- **Files modified:** 3 (1 created, 2 modified)

## Accomplishments
- Ported `design_handoff_safepath_ai/lib/animated_safepath_mark.dart` into `mobile/lib/shared_widgets/animated_safepath_mark.dart`, wiring it directly to the existing `SafePathLogo` widget (no placeholder indirection), with a `ringKey` test handle for the private ring painter
- Collapsed `SplashScreen` and `StartupSplashOverlay`'s duplicate `_AnimatedLogoMark`/`_SheenSweep` code onto the shared widget; both now render the identical lockup
- Synced both surfaces' durations to 1800ms so the overlay's fade-out window (progress > 0.86) still covers the handoff to the real `/splash` route
- Fixed a real testability defect discovered along the way: `StartupSplashOverlay` computed progress from a real `Stopwatch`, which is not driven by `flutter_test`'s FakeAsync clock — replaced with tick-count accumulation on the same `Timer.periodic`
- Updated `splash_screen_test.dart` to assert the per-letter wordmark via a concatenation helper, raised the gate-flip pump to 1850ms, and added ring-present/ring-absent coverage for both surfaces plus a new `StartupSplashOverlay` reduced-motion test group

## Task Commits

Each task was committed atomically:

1. **Task 1: Add the shared AnimatedSafePathMark widget** - `d6f667e` (feat)
2. **Task 2: Rewire both splash surfaces onto the shared widget and sync durations to 1800ms** - `2bb751f` (feat)
3. **Deviation (Rule 3): make StartupSplashOverlay progress testable** - `c7be6c5` (fix)
4. **Task 3: Update splash tests for the per-letter wordmark and the 1800ms window** - `1821d39` (test)

## Files Created/Modified
- `mobile/lib/shared_widgets/animated_safepath_mark.dart` - New shared `AnimatedWidget`: ring painter (`2*pi*progress` sweep), halo rotation, sheen sweep, staggered per-letter wordmark wrapped in merged `Semantics` + `FittedBox`
- `mobile/lib/features/splash/presentation/splash_screen.dart` - Both `_buildLockup()` and `_StartupSplashSurface` now build `AnimatedSafePathMark`; deleted `_AnimatedLogoMark`/`_SheenSweep`; both `_defaultDuration`s now 1800ms; `_StartupSplashOverlayState` progress now tick-accumulated instead of `Stopwatch`-read
- `mobile/test/features/splash/splash_screen_test.dart` - Added `_lockupWordmark()` helper, updated existing assertions for the per-letter wordmark and 1800ms window, added ring-present/ring-absent tests and a new `StartupSplashOverlay` reduced-motion group

## Decisions Made
- `AppSpacing.lg` (24) used instead of the handoff's hardcoded `18` for mark-to-wordmark spacing — not on the project's fixed 4pt scale; 24 matches what the current splash already ships and what `01-UI-SPEC.md` specifies.
- Added a merged `Semantics(label: 'SafePath AI', container: true)` wrapper around the per-letter `Row`, since splitting into 11 `Text` widgets would otherwise make a screen reader announce the wordmark letter by letter.
- Added a `FittedBox(fit: BoxFit.scaleDown)` guard around the same `Row`, since (unlike the single `Text` it replaces) a `Row` cannot soft-wrap and would trip a `RenderFlex` overflow at a large system text scale or on a narrow device.
- Replaced `StartupSplashOverlay`'s `Stopwatch`-based progress read with `Timer.periodic` tick-count accumulation — see Deviations below.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] StartupSplashOverlay's Stopwatch-based progress was untestable under flutter_test's FakeAsync clock**
- **Found during:** Task 3 (writing the new `StartupSplashOverlay` reduced-motion test)
- **Issue:** `_StartupSplashOverlayState._startClock()` computed `nextProgress` from `_stopwatch.elapsedMilliseconds` inside a `Timer.periodic` callback. `Stopwatch` reads genuine wall-clock time and is not driven by `flutter_test`'s FakeAsync zone. `tester.pump(duration)` elapses only the fake zone clock (which does fire the `Timer.periodic` callback correctly), but the `Stopwatch` read inside that callback stayed pinned near zero regardless of how much fake time was pumped — confirmed empirically: a test pumping 150ms of fake time observed `progress ≈ 0.027` (≈7ms of genuine wall-clock overhead), not the expected ~0.58 (150/260 under reduced motion). This made the overlay's clock-driven visibility toggle permanently untestable via the standard widget-test harness, blocking completion of Task 3's action item 7.
- **Fix:** Replaced the `Stopwatch` field with an `int _elapsedMs` accumulator incremented by the fixed `_frameInterval` (16ms) on every periodic tick, and computed `nextProgress` from that accumulator instead. This is deterministic under FakeAsync (each elapsed `_frameInterval` reliably fires exactly one tick) and has no material behavior change on a real device, where `Timer.periodic` already fires close to every `_frameInterval` with no catch-up bursts on a late tick.
- **Files modified:** `mobile/lib/features/splash/presentation/splash_screen.dart`
- **Verification:** New `StartupSplashOverlay reduced motion` test group passes; full `flutter analyze` clean; full splash test file green.
- **Committed in:** `c7be6c5` (standalone fix commit, ahead of the Task 3 test commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Necessary to make the plan's own required test coverage (Task 3 action item 7) actually pass; no scope creep — durations, curves, and visible motion are unchanged, only the internal time-source changed.

## Issues Encountered
None beyond the deviation above.

## Known Stubs
None.

## Threat Flags
None — this task's threat model already anticipated and mitigated the only new surface (the per-frame rebuild, the `FittedBox` overflow guard, and the merged `Semantics` label); see `260807-qhg-PLAN.md`'s `<threat_model>`. No new surface was introduced beyond what that register already covers.

## Deferred Items
- Pre-existing unrelated test failure in `mobile/test/shared_widgets/member_map_pin_semantics_test.dart` (`A SemanticsHandle was active at the end of the test.` in both `announces the label and current-location status as one node` and `announces the label and stale status as one node`), found during Task 3's full-suite verification run. Confirmed unrelated: fails identically in isolation with zero involvement of any file this task touched, last modified in an earlier unrelated commit (`7246356`, quick task 260720-3u4). See `.planning/quick/260807-qhg-apply-splash-screen-enhancement-instruct/deferred-items.md`. Not fixed — out of scope.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `AnimatedSafePathMark` is now the single source of truth for the launch lockup and available for reuse by any future screen wanting the same ring/wordmark motion.
- The pre-existing `member_map_pin_semantics_test.dart` failure remains open for a future session (see Deferred Items).
- No blockers for continuing Phase 03 (sos-fast-path) work.

---
*Quick task: 260807-qhg*
*Completed: 2026-08-07*

## Self-Check: PASSED

- FOUND: mobile/lib/shared_widgets/animated_safepath_mark.dart
- FOUND: mobile/lib/features/splash/presentation/splash_screen.dart
- FOUND: mobile/test/features/splash/splash_screen_test.dart
- FOUND: .planning/quick/260807-qhg-apply-splash-screen-enhancement-instruct/deferred-items.md
- FOUND: d6f667e (Task 1 commit)
- FOUND: 2bb751f (Task 2 commit)
- FOUND: c7be6c5 (deviation fix commit)
- FOUND: 1821d39 (Task 3 commit)
