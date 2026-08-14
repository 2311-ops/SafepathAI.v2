---
phase: 04-geofencing
plan: 16
subsystem: mobile-push
tags: [flutter, firebase-messaging, flutter-local-notifications, go-router, geofencing, sos]
requires:
  - phase: 04-geofencing
    provides: normal-priority identifier-only routine pushes and the zone-activity route
provides:
  - Routine foreground presentation on a normal Android notification channel
  - Explicit-tap-only authenticated replay into selected safe-zone activity
  - SOS regression coverage isolating emergency routing from routine payloads
affects: [routine-notification-delivery, geofencing-uat, sos-push]
actuals:
  tokens: 8637
  tasks: 2
  commits: 4
tech-stack:
  added: []
  patterns: [separate routine local notification channel, in-memory pending tap replay, UUID-only external route validation]
key-files:
  created:
    - mobile/lib/core/push/routine_push_service.dart
    - mobile/test/features/geofencing/routine_notification_route_test.dart
  modified:
    - mobile/lib/core/router/app_router.dart
    - mobile/test/features/sos/push_service_test.dart
key-decisions:
  - "Routine push routing owns a separate service and normal local channel, while app-router composition preserves the existing SOS PushService semantics."
  - "Routine FCM and local payloads validate UUID activity/zone identifiers and retain a pending explicit tap only in memory until authenticated."
patterns-established:
  - "External route payloads extract only the declared marker and identifiers; coordinates are never consumed by mobile routine routing."
  - "Emergency regression tests pin negative routing boundaries as well as SOS positive behavior."
requirements-completed: [NOTIF-02]
coverage:
  - id: D1
    description: "Routine foreground, background, cold-start, and local-tap flows present normally and navigate only after an explicit authenticated tap."
    requirement: NOTIF-02
    verification:
      - kind: unit
        ref: "mobile/test/features/geofencing/routine_notification_route_test.dart"
        status: pass
    human_judgment: false
  - id: D2
    description: "SOS retains its critical route and ignores routine geofence payloads."
    requirement: NOTIF-02
    verification:
      - kind: unit
        ref: "mobile/test/features/sos/push_service_test.dart"
        status: pass
    human_judgment: false
duration: 7min
completed: 2026-08-14
status: complete
---

# Phase 04 Plan 16: Routine Push Routing Summary

**Routine safe-zone pushes now use a normal local channel and explicit-tap-only authenticated navigation, with SOS kept on its existing critical path.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-08-14T05:03:30+03:00
- **Completed:** 2026-08-14T05:10:20+03:00
- **Tasks:** 2/2
- **Files modified:** 4

## Accomplishments

- Added `RoutinePushService` with a dedicated `safepath_routine` default-importance Android channel and normal iOS presentation.
- Validates only the `geofence` marker and UUID activity/zone identifiers, ignores malformed or SOS payloads, and never reads coordinate values.
- Replays only an explicit FCM/local tap after authentication then routes to the chosen zone activity; no access token or pending route is persisted.
- Added a regression fence proving the existing SOS high channel, receipt behavior, and responder navigation do not handle routine pushes.

## Task Commits

1. **Task 1: Present routine messages and route only on explicit tap** - `026b0c4` (TDD RED), `db7156c` (GREEN), `00c40ed` (analyzer correction)
2. **Task 2: Prove existing SOS push behavior is unchanged** - `aa8c4b4` (regression test)

## Files Created/Modified

- `mobile/lib/core/push/routine_push_service.dart` - Isolated routine FCM/local-notification lifecycle, strict identifier validation, and in-memory tap replay.
- `mobile/lib/core/router/app_router.dart` - Composes the routine service with the authenticated `zone-activity` route.
- `mobile/test/features/geofencing/routine_notification_route_test.dart` - Covers foreground no-auto-navigation, three tap lifecycles, and malformed/SOS rejection.
- `mobile/test/features/sos/push_service_test.dart` - Pins the SOS/routine channel and marker separation.

## Decisions Made

- Routine service composition lives beside the shared app router so it can use the existing authenticated activity route without modifying `PushService` production semantics.
- Local notification payloads contain only validated activity and zone IDs; the pending tap is process-memory state, not persisted credentials or payload data.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Restored the mobile analyzer baseline for the routine service constructor**
- **Found during:** Task 1
- **Issue:** The routine service's public named-parameter/private-field composition triggered three new `prefer_initializing_formals` infos.
- **Fix:** Applied the established `PushService` file-level lint convention that preserves public constructor labels while assigning private fields.
- **Files modified:** `mobile/lib/core/push/routine_push_service.dart`
- **Verification:** `flutter analyze` returned only the three pre-existing infos in `geofence_candidate_uploader.dart`.
- **Committed in:** `00c40ed`

---

**Total deviations:** 1 auto-fixed (Rule 1)
**Impact on plan:** Required to preserve the documented analyzer baseline without changing routine or SOS behavior.

## Issues Encountered

- The first sandboxed focused Flutter run timed out while its compiler bundle started; the elevated rerun produced the expected RED failure and subsequent GREEN pass.
- `flutter test` ran 421 tests but four unrelated `privacy_center_screen_test.dart` tests fail. They are documented in `deferred-items.md`; focused routine/SOS tests pass.

## User Setup Required

None - the routine service uses the existing Firebase setup and safely leaves its channel inactive when Firebase is not configured.

## Next Phase Readiness

- NOTIF-02 mobile delivery and explicit activity routing are ready for UAT without altering D-11 SOS behavior.
- Resolve the pre-existing privacy-center test failures before relying on a completely green full-mobile-suite gate.

---
*Phase: 04-geofencing*
*Completed: 2026-08-14*

## Self-Check: PASSED

- Verified all four planned mobile implementation/test files and this summary exist.
- Verified TDD RED/GREEN, SOS regression, and analyzer-baseline commits `026b0c4`, `db7156c`, `aa8c4b4`, and `00c40ed` exist.
