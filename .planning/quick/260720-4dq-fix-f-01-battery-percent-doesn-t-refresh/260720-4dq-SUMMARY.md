---
phase: quick-260720-4dq
plan: 01
subsystem: location
tags: [flutter, riverpod, timer, battery, live-map, testing, fake_async]

# Dependency graph
requires:
  - phase: quick-260717-oq0
    provides: "LiveLocation.batteryPercent surfaced on the Live Map pin and member detail sheet"
provides:
  - "LocationController periodically re-reads and re-reports battery percent while connected, independent of GPS movement"
affects: []

# Tech tracking
tech-stack:
  added: [fake_async (dev dependency, for deterministic Timer.periodic testing)]
  patterns:
    - "Reuse an existing per-event report flow (_reportPosition) as the periodic-timer callback body, rather than duplicating the battery-read/report logic, so a movement-independent refresh flows through the same already-wired broadcast pipeline"
    - "Timer cancellation registered both synchronously in the async teardown method's pre-await prefix AND as a dedicated, purely-synchronous ref.onDispose callback, so cleanup is guaranteed regardless of how disposal is triggered (fire-and-forget async teardown vs. widget/container disposal)"

key-files:
  created: []
  modified:
    - mobile/lib/features/location/application/location_controller.dart
    - mobile/test/features/location/location_controller_test.dart
    - mobile/test/features/location/location_permission_gate_test.dart
    - mobile/pubspec.yaml
    - mobile/pubspec.lock

key-decisions:
  - "Timer interval fixed at 5 minutes as a static const, not injectable — fake_async's Timer faking works regardless of duration, so no test-only constructor parameter was needed"
  - "_lastKnownPosition is set at the very top of _reportPosition (before any guard), since _reportPosition already fires on every position-stream event — avoided duplicating position-tracking logic in the stream listener itself"
  - "Battery-refresh timer cancellation duplicated into a dedicated ref.onDispose callback (in addition to _stop()'s synchronous prefix) after discovering flutter_test's pending-timer invariant check can run before the async _stop() chain's remaining awaits resolve in certain disposal paths"

patterns-established: []

requirements-completed: ["QUICK-260720-4dq"]

coverage:
  - id: D1
    description: "Periodic Timer re-reads batteryLevelProvider and re-reports the last known position via the existing hub pipeline without requiring a new GPS fix"
    requirement: "QUICK-260720-4dq"
    verification:
      - kind: unit
        ref: "mobile/test/features/location/location_controller_test.dart#periodically refreshes battery and re-reports the last known position without a new GPS fix (F-01)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Timer callback is a no-op before any position has ever been reported (no last-known position to resend)"
    requirement: "QUICK-260720-4dq"
    verification:
      - kind: unit
        ref: "mobile/test/features/location/location_controller_test.dart#does not fire a battery refresh before any position has ever been reported (F-01)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Periodic battery-refresh timer is cancelled on disconnect/dispose with no lingering callback"
    requirement: "QUICK-260720-4dq"
    verification:
      - kind: unit
        ref: "mobile/test/features/location/location_controller_test.dart#cancels the periodic battery-refresh timer on disconnect (no lingering callback after teardown) (F-01)"
        status: pass
      - kind: integration
        ref: "mobile/test/features/location/location_permission_gate_test.dart#cold signed-in /home with granted permission renders MainShell"
        status: pass
    human_judgment: false

duration: 45min
completed: 2026-07-20
status: complete
---

# Quick Task 260720-4dq: Fix F-01 — battery percent doesn't refresh independent of GPS movement Summary

**`LocationController` now runs a `Timer.periodic(Duration(minutes: 5))` while connected that re-invokes the existing `_reportPosition` flow against the last known GPS fix, so the battery percent on the Live Map pin/member sheet keeps refreshing on a stationary device instead of freezing at whatever it read on the last movement-triggered report.**

## Performance

- **Duration:** 45 min
- **Completed:** 2026-07-20
- **Tasks:** 2 (implementation + tests, one commit)
- **Files modified:** 5

## Accomplishments
- Added `_lastKnownPosition` (set on every `_reportPosition` call, i.e. every position-stream event) and `_batteryRefreshTimer` (`Timer.periodic`, 5 min) fields to `LocationController`
- Timer starts in `_bootstrap()` right after the other subscriptions (`_positionSubscription`, `_lowBatterySubscription`, etc.) are wired up on successful connect, and its callback simply calls the existing `_reportPosition(_lastKnownPosition!)` — no new backend endpoint, no new payload shape, reusing the already-wired `batteryLevelProvider` re-read + `hubClient.reportLocation` + broadcast path verbatim
- Timer cancellation is defense-in-depth: cancelled synchronously in `_stop()`'s pre-`await` prefix, and separately via a dedicated, purely-synchronous `ref.onDispose` callback — this was necessary (not just belt-and-braces) because it fixed a real regression, see Deviations below
- `distanceFilter: 10` and the position-triggered `_reportPosition` call path are untouched; no backend/hub contract changes
- Added `fake_async` dev dependency and 3 new tests in `location_controller_test.dart` covering: timer-driven re-report without a new GPS fix, no-op before any position is known, and cancellation on disconnect

## Task Commits

Both implementation and tests landed in a single atomic commit (small, tightly-coupled fix):

1. **fix(location): refresh battery percent independent of GPS movement (F-01)** - `8f2731c` (fix)

## Files Created/Modified
- `mobile/lib/features/location/application/location_controller.dart` - `_lastKnownPosition`/`_batteryRefreshTimer` fields, `_batteryRefreshInterval` const, timer start in `_bootstrap()`, timer cancel in `_stop()` prefix + dedicated `ref.onDispose`, `_refreshBatteryOnly()` helper reusing `_reportPosition`
- `mobile/test/features/location/location_controller_test.dart` - 3 new `fakeAsync`-based regression tests for F-01
- `mobile/test/features/location/location_permission_gate_test.dart` - "granted permission" test now explicitly disposes its `ProviderContainer` inside the test body (idempotent `dispose()` guard added) so the new timer doesn't trip `flutter_test`'s pending-timer invariant check
- `mobile/pubspec.yaml` / `mobile/pubspec.lock` - added `fake_async` as a direct dev dependency (was previously only a transitive dependency)

## Decisions Made
- Reused `_reportPosition` as the timer callback body rather than writing a parallel "battery-only" report path — it already does exactly what's needed (invalidate + re-read `batteryLevelProvider`, build the payload, call `hubClient.reportLocation`, apply the resulting `LiveLocation` to state), so reuse was both the minimal change and the correct one per the task's explicit "reuse the existing pipeline, no new payload shape" constraint
- Set `_lastKnownPosition` inside `_reportPosition` (fires on every stream event) instead of in the stream-listener lambda, keeping position-tracking in one place
- Kept the 5-minute interval as a `static const` rather than making it constructor-injectable for tests — `fake_async`'s `elapse()` doesn't care about wall-clock duration, so no test-seam was needed

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Timer not reliably cancelled through `_stop()`'s fire-and-forget invocation path**
- **Found during:** Task 2 (writing/running the F-01 regression tests) — surfaced as a *different* test's failure, not one of the new tests
- **Issue:** `ref.onDispose(() { unawaited(_stop(clearState: false)); });` only guarantees the code *before* `_stop()`'s first `await` runs synchronously when the provider is disposed. Initially the `_batteryRefreshTimer?.cancel()` call was placed after several `await _xSubscription?.cancel()` lines in `_stop()`, so it wasn't guaranteed to execute synchronously at dispose time.
- **Fix:** Moved the timer cancellation to `_stop()`'s synchronous prefix (before any `await`), AND added a second, dedicated `ref.onDispose` callback containing only `_batteryRefreshTimer?.cancel(); _batteryRefreshTimer = null;` so cancellation is guaranteed synchronous regardless of `_stop()`'s internal ordering.
- **Files modified:** `mobile/lib/features/location/application/location_controller.dart`
- **Verification:** `flutter test test/features/location/location_controller_test.dart` — new "cancels the periodic battery-refresh timer on disconnect" test passes
- **Committed in:** `8f2731c` (single task commit)

**2. [Rule 1 - Bug] Pre-existing `location_permission_gate_test.dart` "granted permission" test broke under the new timer**
- **Found during:** Task 2 (running the full mobile test suite after implementation)
- **Issue:** `flutter_test`'s `AutomatedTestWidgetsFlutterBinding._verifyInvariants()` (which asserts no `Timer` is left pending) runs *before* `addTearDown` callbacks execute. This test's `ProviderContainer` is only disposed via `addTearDown(harness.dispose)`, so with the new `LocationController`-owned `Timer.periodic` still live at that checkpoint, the assertion failed — a regression directly caused by this fix's own timer, not a pre-existing bug. (Widget-owned `State` timers, like the existing splash-screen timer, don't hit this because `runApp(Container())`'s widget-tree unmount — which triggers `State.dispose()` — happens earlier in the same binding method, before the invariant check; a `ProviderContainer`-owned timer under `UncontrolledProviderScope` has no such automatic unmount hook.)
- **Fix:** Made `_RouterHarness.dispose()` idempotent (guarded with a `_disposed` flag) and added an explicit `harness.dispose()` call at the end of the "granted permission" test body, so the container — and its timer — is torn down inside the test body itself, ahead of the invariant check, while `addTearDown` remains a safe no-op fallback for the other three (permission-denied) tests that never reach a connected state.
- **Files modified:** `mobile/test/features/location/location_permission_gate_test.dart`
- **Verification:** `flutter test test/features/location/location_permission_gate_test.dart` passes; full `flutter test` (228 tests) passes with no regressions
- **Committed in:** `8f2731c` (single task commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 — bugs introduced by this fix's own timer, corrected within the same task before commit)
**Impact on plan:** Both fixes were necessary for the feature to actually be leak-free and non-regressing; no scope creep beyond making the new timer correctly lifecycle-managed.

## Issues Encountered
Two iterations were needed to get timer cancellation fully synchronous-safe (see Deviations #1) before the pre-existing widget test surfaced a second, harness-level issue (Deviations #2). Both are now covered by passing tests so they won't silently regress again.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- F-01 is closed: Live Map pin and member detail sheet battery percent now refreshes every 5 minutes even when the device is stationary
- No further location-controller work identified from this finding

---
*Quick task: 260720-4dq*
*Completed: 2026-07-20*

## Self-Check: PASSED
- FOUND: mobile/lib/features/location/application/location_controller.dart
- FOUND: mobile/test/features/location/location_controller_test.dart
- FOUND: mobile/test/features/location/location_permission_gate_test.dart
- FOUND: 8f2731c
