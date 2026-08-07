---
phase: 03-sos-fast-path
plan: 09
subsystem: sos
tags: [flutter, riverpod, quick_actions, geolocator, signalr, dart]

# Dependency graph
requires:
  - phase: 03-sos-fast-path
    provides: "03-02 -- SosArmButton/SosArmRingPainter gesture+haptic+reduced-motion pattern, SosController.arm()"
  - phase: 03-sos-fast-path
    provides: "03-03 -- POST /sos/{id}/cancel (CancelSosCommand, self-cancel-only, non-destructive) and the SosCanceled hub event contract"
  - phase: 03-sos-fast-path
    provides: "03-04 -- responder_alert_screen.dart, SosResponderController's sosCanceled stream stub"
  - phase: 03-sos-fast-path
    provides: "03-06/03-07 -- DeepLinkService/push_service pending-invite/cold-start-replay convention reused for the shortcut's pre-auth invocation"
  - phase: 03-sos-fast-path
    provides: "03-08 -- SosLiveLocationService, live-location streaming that cancellation must stop"
provides:
  - "SosHoldToCancelButton -- 2000ms white-ring hold-to-cancel control (no confirmation dialog), reusing SosArmRingPainter with a colour override"
  - "SosController.cancel() -- calls POST /sos/{id}/cancel, stops SosLiveLocationService, retries on network failure using the offline-queue backoff shape, never mutates delivery history"
  - "De-escalated SosCanceled rendering on both sender_emergency_session_screen.dart (deep-teal 'Alert canceled', recipient list still visible) and responder_alert_screen.dart (deep-teal 'Canceled by {name} at {time}', Close-only, never auto-navigates)"
  - "QuickActionsService/quickActionsServiceProvider -- registers a single 'Emergency SOS' quick_actions shortcut only while authenticated, clears it on sign-out, defers/replays exactly one pre-auth invocation, guards against re-arming an active session"
  - "SosLiveLocationService one-shot GPS fix on start() (bugfix found during manual verification) -- a stationary sender now reports an immediate position instead of waiting for 5m of movement"
affects: [06]

tech-stack:
  added: []
  patterns:
    - "Hold-to-cancel reuses SosArmRingPainter with a colour override rather than forking a second ring painter -- same gesture/haptic/reduced-motion shape as the 3s arm button, at 2000ms and white-on-transparent instead of mint-to-red"
    - "QuickActionsService follows DeepLinkService/PushService's external-entry-point shape: constructor-injected plugin instance + navigation callback for pure-Dart testability, pendingInviteProvider-style defer/replay-once for pre-auth invocation"
    - "The shortcut's SOS invocation calls the identical SosController.arm() entry point the press-and-hold button calls -- no second arming implementation exists anywhere in the codebase"

key-files:
  created:
    - mobile/lib/features/sos/presentation/sos_hold_to_cancel_button.dart
    - mobile/lib/core/os_shortcuts/quick_actions_service.dart
    - mobile/test/features/sos/sos_cancel_test.dart
    - mobile/test/features/sos/quick_actions_service_test.dart
  modified:
    - mobile/lib/features/sos/application/sos_controller.dart
    - mobile/lib/features/sos/application/sos_responder_controller.dart
    - mobile/lib/features/sos/presentation/sender_emergency_session_screen.dart
    - mobile/lib/features/sos/presentation/responder_alert_screen.dart
    - mobile/lib/features/sos/presentation/sos_arm_ring_painter.dart
    - mobile/lib/features/sos/application/sos_live_location_service.dart
    - mobile/lib/main.dart
    - mobile/test/features/sos/responder_alert_screen_test.dart
    - mobile/test/features/sos/sos_live_window_test.dart

key-decisions:
  - "Hold-to-cancel duration locked at 2000ms (not the arm button's 3000ms) -- short enough that correcting a false alarm feels responsive, long enough that an accidental brush cannot silently retract a real emergency."
  - "No confirmation dialog on either the cancel path or the shortcut-fire path -- a modal would reinsert exactly the decision gate the parallel-cancel design and the backup-trigger's D-27 'no second gesture' decision both exist to avoid."
  - "Cancellation is additive-only: it writes a status/audit stamp and stops live-location streaming, but never clears or rolls back SosDeliveryAttempt rows -- the guardian's delivery history stays visible on both the sender's and the responder's screens after a cancel."
  - "QuickActionsService registers the shortcut only while authenticated and clears it on sign-out, so a signed-out device never advertises an action that would fail silently."
  - "Found during Task 3's manual verification: SosLiveLocationService sourced position purely from a distanceFilter:5 Geolocator stream, so a stationary sender (the common real-emergency case) never produced a first live-location report. Fixed with a best-effort one-shot GPS fix on start() that falls through to the ongoing stream on denial/timeout, never blocking start() (Rule 1 -- bug)."

requirements-completed: [SOS-05, SOS-06]

coverage:
  - id: D1
    description: "A two-second hold cancels a false SOS alarm; a tap or a hold shorter than two seconds does nothing, and no confirmation dialog is ever shown"
    requirement: "SOS-05"
    verification:
      - kind: unit
        ref: "mobile/test/features/sos/sos_cancel_test.dart (8 tests)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Cancelling de-escalates both the sender's and the guardian's screens to deep-teal, explicit canceled copy, without deleting or hiding any delivery history, and the guardian's screen never auto-navigates away"
    requirement: "SOS-05"
    verification:
      - kind: unit
        ref: "mobile/test/features/sos/sos_cancel_test.dart, mobile/test/features/sos/responder_alert_screen_test.dart (17 tests)"
        status: pass
    human_judgment: false
  - id: D3
    description: "The home-screen quick_actions shortcut registers only while signed in, fires the SOS immediately with no arming hold on invocation, defers a pre-auth invocation and replays it once, and cannot create a duplicate session"
    requirement: "SOS-06"
    verification:
      - kind: unit
        ref: "mobile/test/features/sos/quick_actions_service_test.dart (7 tests)"
        status: pass
    human_judgment: false
  - id: D4
    description: "On a real device, long-pressing the app icon offers Emergency SOS, invoking it fires the alert immediately with no hold/confirmation and lands the user in the live session, a second device receives exactly one alert, the shortcut disappears after sign-out, hold-to-cancel behaves identically on-device to the widget-test coverage with the guardian's screen visibly de-escalating in place, and the full offline-trigger/force-kill/resume/auto-send path completes with exactly one alert received"
    requirement: "SOS-06"
    verification:
      - kind: manual_procedural
        ref: "03-09-PLAN.md Task 3, eleven-step two-device procedure -- approved 2026-08-08"
        status: pass
    human_judgment: true
    rationale: "Native OS home-screen/app-shortcut invocation, real push delivery across two physical devices, and airplane-mode/force-kill device state cannot be reproduced inside a headless flutter test harness."

# Metrics
duration: multi-session (Tasks 1-2 committed 2026-08-07; Task 3 manual verification + bugfix committed 2026-08-07/08; closeout 2026-08-08)
completed: 2026-08-08
status: complete
---

# Phase 3 Plan 9: Hold-to-Cancel and OS Backup Trigger Summary

**Two-second hold-to-cancel with de-escalated deep-teal states on both screens, plus a `quick_actions` home-screen SOS shortcut that fires immediately through the same `SosController.arm()` path as the in-app button — closing the SOS Fast Path phase.**

## Performance

- **Duration:** multi-session (implementation + manual device verification)
- **Completed:** 2026-08-08T00:00:00Z (closeout)
- **Tasks:** 3 (2 automated + 1 blocking human-verify checkpoint)
- **Files modified:** 12 (9 mobile source/test files across Tasks 1-2, plus 1 source + 2 test files for the Task 3 bugfix)

## Accomplishments

- `SosHoldToCancelButton`: a 2000ms white-ring hold-to-cancel control reusing `SosArmRingPainter` with a colour override, `HapticFeedback.mediumImpact()`, and no confirmation dialog — a tap or a sub-2s hold does nothing.
- `SosController.cancel()`: calls `POST /sos/{id}/cancel`, stops `SosLiveLocationService`, retries on network failure using the existing offline-queue backoff shape, and never touches accumulated delivery state.
- Sender screen (`SosCanceled` branch): deep-teal chrome, "Alert canceled" headline, "You canceled this alert at {time}..." body, with the recipient delivery list still visible beneath it.
- Responder screen (`SosCanceled` branch): shifts from red to deep teal, renders "Canceled by {sender name} at {time}", replaces Acknowledge with Close, and stays mounted — never auto-navigates or auto-dismisses.
- `QuickActionsService`: registers a single "Emergency SOS" `quick_actions` shortcut item only while authenticated, clears it on sign-out, invokes the identical `SosController.arm()` entry point the press-and-hold button uses (no second arming implementation, no hold, no countdown, no confirmation), defers and replays exactly one pre-auth invocation, and routes to the existing session instead of creating a duplicate when one is already active.
- Wired `QuickActionsService` into `main.dart`'s startup bootstrap alongside the existing `DeepLinkService`/push-service wiring.
- Task 3's eleven-step, two-device manual verification (backup-trigger steps 1-5, self-cancel steps 6-10, whole-path offline-resume sanity step 11) was run and **approved** — this was also the SOS Fast Path phase's closing end-to-end gate.
- Found and fixed during that manual verification: a stationary sender's live-location card never received a first GPS fix because `SosLiveLocationService` only sourced position from a `distanceFilter: 5` stream. Added a best-effort one-shot fix on `start()` so live location no longer waits on movement (see Deviations).

## Task Commits

Each task was committed atomically:

1. **Task 1: Hold-to-cancel and de-escalated canceled state on both screens** - `d2968de` (feat)
2. **Task 2: Register the OS home-screen SOS shortcut and fire it immediately** - `e05ed6d` (feat)
3. **Task 3: Verify the OS backup trigger and self-cancel on real devices (SOS-06 manual gate)** - `checkpoint:human-verify`, no source commit; approved 2026-08-08 after all eleven steps confirmed on two devices. A related bug found during this verification was fixed and committed separately: `af9fde8` (fix)

**Plan metadata:** this commit (docs: complete plan)

## Files Created/Modified

- `mobile/lib/features/sos/presentation/sos_hold_to_cancel_button.dart` - the 2000ms white-ring hold-to-cancel control
- `mobile/lib/core/os_shortcuts/quick_actions_service.dart` - `quick_actions` registration + immediate-fire invocation handling
- `mobile/lib/features/sos/application/sos_controller.dart` - `cancel()` entry point (stops live location, retries on failure, moves to `SosCanceled`)
- `mobile/lib/features/sos/application/sos_responder_controller.dart` - folds the hub's `sosCanceled` event into responder state in place
- `mobile/lib/features/sos/presentation/sender_emergency_session_screen.dart` - `SosCanceled` deep-teal treatment, delivery list stays visible
- `mobile/lib/features/sos/presentation/responder_alert_screen.dart` - sender-canceled deep-teal treatment, Close-only, no auto-navigation
- `mobile/lib/features/sos/presentation/sos_arm_ring_painter.dart` - colour-override support reused by the cancel button
- `mobile/lib/features/sos/application/sos_live_location_service.dart` - one-shot GPS fix on `start()` (bugfix)
- `mobile/lib/main.dart` - `QuickActionsService` startup wiring
- `mobile/test/features/sos/sos_cancel_test.dart` - 8 tests, hold-to-cancel + both canceled states
- `mobile/test/features/sos/quick_actions_service_test.dart` - 7 tests, shortcut registration/invocation/defer/re-arm-guard
- `mobile/test/features/sos/responder_alert_screen_test.dart` - 3 tests added for the sender-canceled responder branch
- `mobile/test/features/sos/sos_live_window_test.dart` - regression coverage for the one-shot GPS fix

## Decisions Made

- Hold-to-cancel duration is 2000ms, distinct from the arm button's 3000ms, and uses white-on-transparent ring colour rather than the arm button's mint-to-red interpolation — deliberately avoiding any visual language that would suggest arming rather than de-escalating.
- No confirmation dialog exists anywhere in the cancel or shortcut-fire paths; the hold itself (cancel) and the deliberate long-press-then-tap (shortcut) are each treated as sufficient intent.
- Cancellation is structurally non-destructive: it never mutates or deletes `SosDeliveryAttempt` rows, matching the backend's `CancelSosCommand` contract from 03-03.
- The shortcut is registered only while authenticated and cleared on sign-out; a pre-auth invocation is deferred and replayed exactly once, following the same `pendingInviteProvider` convention used for deep links (03-06/03-07 lineage).
- `SosLiveLocationService.start()` now attempts a best-effort one-shot `getCurrentPosition()` before falling back to the ongoing `distanceFilter: 5` stream — a denied or timed-out one-shot fix never blocks or fails `start()`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Stationary sender never produced a first live-location report**
- **Found during:** Task 3 manual device verification (step covering the live-location card on the responder screen)
- **Issue:** `SosLiveLocationService` sourced the sender's live position purely from `Geolocator.getPositionStream(distanceFilter: 5)`, which only emits once the device moves 5m. A stationary sender — the most common real emergency case (injured, hiding, unconscious) — never produced a first report, leaving the responder's live-location card stuck on "Waiting for a live position..." indefinitely.
- **Fix:** Added a best-effort one-shot `getCurrentPosition()`-style fix reported immediately on `start()`, falling through to the ongoing movement-gated stream on denial/timeout without blocking or failing `start()`.
- **Files modified:** `mobile/lib/features/sos/application/sos_live_location_service.dart`, `mobile/test/features/sos/sos_cancel_test.dart`, `mobile/test/features/sos/sos_live_window_test.dart`
- **Verification:** Full mobile suite green; re-verified live on a stationary physical device as part of the same manual checkpoint.
- **Committed in:** `af9fde8`

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Necessary correctness fix for the live-location window (SOS-04, delivered in 03-08) surfaced only by real-device testing; no scope creep — same structurally-isolated `SosLiveLocationService` code path, no changes to routine location tracking.

## Issues Encountered

None beyond the auto-fixed live-location bug above, which is documented in Deviations.

## User Setup Required

None - no external service configuration required.

## Manual Verification (Task 3 / SOS-06 gate)

All eleven steps of `03-09-PLAN.md` Task 3's `<how-to-verify>` procedure were run across two devices and approved by the human:

- **Backup trigger (SOS-06, D-25/D-27), steps 1-5:** the "Emergency SOS" home-screen shortcut appears on long-press, tapping it opens directly into the full-screen emergency session already sending (no hold, no confirmation, no intermediate screen), the second device received exactly one alert, and the shortcut disappeared after sign-out.
- **Self-cancel (SOS-05, D-05/D-24), steps 6-10:** a sub-two-second hold does not cancel; the full two-second hold switches the sender to the deep-teal "Alert canceled" screen with the recipient list still visible; the responder screen shifted to deep teal, read "Canceled by {name} at {time}", offered only Close, and did not disappear or auto-navigate.
- **Whole-path sanity, step 11:** airplane-mode trigger showed "Not sent yet" immediately; force-kill and reopen resumed the same queued session; re-enabling networking sent it automatically with exactly one alert received on the second device.

This was also the SOS Fast Path phase's closing end-to-end gate. `.planning/phases/03-sos-fast-path/03-VALIDATION.md`'s SOS-06 manual row is updated to exercised/passed.

## Next Phase Readiness

- All of Phase 3's requirements (SOS-01 through SOS-06, NOTIF-03, DESIGN-02) are now implemented, automated-tested, and manually verified end-to-end.
- `SosHoldToCancelButton`'s hold-gesture pattern and `QuickActionsService`'s registration shape are both flagged as reusable groundwork for Phase 6's Silent/Duress trigger (a duress shortcut type would extend `QuickActionsService`'s registration; the duress path reuses the hold-gesture pattern, not the `SosHoldToCancelButton` widget itself).
- No blockers for Phase 4 (Geofencing), which depends only on Phase 2.
- Outstanding, unrelated-to-this-plan items already tracked in STATE.md (Twilio SMS provisioning, iOS/APNs FCM path, a few investigation todos) remain open and are explicitly out of this plan's scope.

---
*Phase: 03-sos-fast-path*
*Completed: 2026-08-08*

## Self-Check: PASSED

- FOUND: `.planning/phases/03-sos-fast-path/03-09-SUMMARY.md`
- FOUND: `mobile/lib/features/sos/presentation/sos_hold_to_cancel_button.dart`
- FOUND: `mobile/lib/core/os_shortcuts/quick_actions_service.dart`
- FOUND commit: `d2968de` (Task 1)
- FOUND commit: `e05ed6d` (Task 2)
- FOUND commit: `af9fde8` (Task 3 manual-verification bugfix)
