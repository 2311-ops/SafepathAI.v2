---
phase: 02-real-time-location-history-privacy
plan: 10
subsystem: mobile-location-permission-privacy
tags: [flutter, riverpod, go-router, geolocator, privacy, tdd]

requires:
  - phase: 02-real-time-location-history-privacy
    provides: PermissionPrimingScreen, PermissionController, MainShell, LocationController, foreground Geolocator stream provider
provides:
  - LocationPermissionGate wrapping /home before MainShell can render
  - Router refresh wiring for permission-state changes
  - Controller-level guard preventing live-location fetch, SignalR connect, and Geolocator subscription before granted permission
  - Route/controller tests proving cold signed-in /home reaches permission priming before map streaming
affects: [03-sos-fast-path, location, privacy, mobile-router]

tech-stack:
  added: []
  patterns:
    - "Permission-sensitive mobile routes use a small ConsumerWidget gate plus controller-level enforcement at the platform/API boundary."
    - "LocationController treats permissionControllerProvider.isGranted as a hard precondition before live APIs, SignalR, or position streams."

key-files:
  created:
    - mobile/lib/features/location/presentation/location_permission_gate.dart
    - mobile/test/features/location/location_permission_gate_test.dart
  modified:
    - mobile/lib/core/router/app_router.dart
    - mobile/lib/features/location/application/location_controller.dart
    - mobile/test/features/location/location_controller_test.dart

key-decisions:
  - "LOC-05 is enforced twice: /home is gated before MainShell renders, and LocationController independently refuses to fetch/connect/stream until permission is granted."
  - "The gate navigates denied, deniedForever, and unknown states to /permission-priming while rendering a neutral loading scaffold for the current frame."
  - "Permission state is added to the router refresh listenable so granted permission after the priming CTA releases the existing /home route flow without recreating the router."

patterns-established:
  - "Cold-route permission regressions should be tested through routerProvider with MaterialApp.router, not helper-only logic."
  - "Foreground position stream tests override positionStreamProvider and assert hub/API call counts before emitting fake positions."

requirements-completed: [LOC-05]

coverage:
  - id: D1
    description: "Cold signed-in /home with unknown, denied, or deniedForever permission reaches PermissionPrimingScreen before MainShell or LiveMapScreen renders."
    requirement: LOC-05
    verification:
      - kind: automated_ui
        ref: "mobile/test/features/location/location_permission_gate_test.dart#cold signed-in /home with unknown permission reaches priming before MainShell"
        status: pass
      - kind: automated_ui
        ref: "mobile/test/features/location/location_permission_gate_test.dart#cold signed-in /home with denied permission reaches priming before MainShell"
        status: pass
      - kind: automated_ui
        ref: "mobile/test/features/location/location_permission_gate_test.dart#cold signed-in /home with deniedForever permission reaches priming before MainShell"
        status: pass
    human_judgment: false
  - id: D2
    description: "Granted permission users still render MainShell from /home."
    requirement: LOC-05
    verification:
      - kind: automated_ui
        ref: "mobile/test/features/location/location_permission_gate_test.dart#cold signed-in /home with granted permission renders MainShell"
        status: pass
    human_judgment: false
  - id: D3
    description: "LocationController does not fetch live locations, connect the hub, subscribe to positions, or report fixes until permission becomes granted."
    requirement: LOC-05
    verification:
      - kind: unit
        ref: "mobile/test/features/location/location_controller_test.dart#does not connect, fetch live locations, or stream positions before permission is granted"
        status: pass
      - kind: other
        ref: "Select-String mobile/lib/features/location/application/location_controller.dart -Pattern getPositionStream"
        status: pass
    human_judgment: false
  - id: D4
    description: "PermissionPrimingScreen remains the only UI invocation path for requestPermission, and cold route gating does not request OS permission."
    requirement: LOC-05
    verification:
      - kind: automated_ui
        ref: "mobile/test/features/location/permission_priming_screen_test.dart#does not request OS permission until the location-sharing CTA is tapped"
        status: pass
      - kind: other
        ref: "Select-String mobile/lib/features/location/**/*.dart -Pattern requestPermission"
        status: pass
    human_judgment: false

duration: 17min
completed: 2026-07-13
status: complete
---

# Phase 02 Plan 10: LOC-05 Permission Gate Summary

**Permission-first /home routing with a controller guard that prevents live-map API, SignalR, and Geolocator streaming before consent.**

## Performance

- **Duration:** 17 min
- **Started:** 2026-07-12T22:30:00Z
- **Completed:** 2026-07-12T22:47:46Z
- **Tasks:** 2 completed
- **Files modified:** 5

## Accomplishments

- Added `LocationPermissionGate` and wrapped `/home`, so signed-in users with unknown, denied, or deniedForever location permission see permission priming before `MainShell` or `LiveMapScreen`.
- Added permission-state refresh wiring to the router so a granted result from the priming CTA releases the user back to `/home`.
- Added a controller-level permission guard so `LocationController` does not call `LocationApi.getLiveLocations`, `LocationHubClient.connect`, or subscribe to `positionStreamProvider` until permission is granted.
- Added route and controller tests that reproduce the LOC-05 verifier failure and prove the fixed behavior.

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: Add failing LOC-05 gate tests for cold signed-in /home and controller streaming** - `174dd59` (test)
2. **Task 2 GREEN: Gate /home and LocationController on granted permission** - `e2f0a9e` (feat)

**Plan metadata:** pending close-out commit

## Files Created/Modified

- `mobile/lib/features/location/presentation/location_permission_gate.dart` - Consumer gate that renders a neutral loading scaffold and routes non-granted permission states to `/permission-priming`.
- `mobile/lib/core/router/app_router.dart` - Wraps `/home` with `LocationPermissionGate` and refreshes routing on permission state changes.
- `mobile/lib/features/location/application/location_controller.dart` - Enforces granted permission before live-location fetch, hub connect, or position stream subscription.
- `mobile/test/features/location/location_permission_gate_test.dart` - Real-router coverage for unknown, denied, deniedForever, and granted `/home` paths.
- `mobile/test/features/location/location_controller_test.dart` - Permission-denied controller boundary test plus granted-permission defaults for existing happy paths.

## Decisions Made

- LOC-05 is enforced at both the route and controller layers because route state is convenience only; the controller owns the platform/API trust boundary.
- `LocationPermissionGate` uses a neutral loading scaffold during permission checks and same-frame navigation scheduling for non-granted states to avoid rendering the map before redirect.
- No new background location behavior, packages, or permissions were added; this remains foreground-only per Phase 2 D-01.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The RED suite failed for the intended reasons before implementation: `/home` did not show priming for unknown/denied permission, and `LocationController` connected while permission was denied.
- `REQUIREMENTS.md` already had `LOC-05` marked complete and contained unrelated pre-existing dirty changes, so this plan did not modify or stage that file.

## User Setup Required

None - no external service configuration required.

## Known Stubs

None in files created or modified by this plan.

## Threat Flags

None - the plan closed an existing trust-boundary gap and added no new network endpoints, auth paths, file access patterns, or schema changes.

## Verification

- `cd mobile && flutter test test/features/location/location_permission_gate_test.dart test/features/location/location_controller_test.dart test/features/location/permission_priming_screen_test.dart` - passed, 9 tests.
- `cd mobile && flutter analyze lib/core/router lib/features/location` - passed, no issues.
- `Select-String -Path mobile/lib/features/location/application/location_controller.dart -Pattern getPositionStream` - passed, only the provider definition path matched.
- `Select-String -Path mobile/lib/features/location/**/*.dart -Pattern requestPermission\(` - passed, only service/controller definitions plus the priming-screen CTA invocation matched.

## TDD Gate Compliance

- RED commit present: `174dd59`
- GREEN commit present after RED: `e2f0a9e`
- No refactor commit was needed.

## Next Phase Readiness

The LOC-05 verifier gap is closed for Phase 2. Phase 3 can rely on the foreground location pipeline only starting after user-visible permission priming, while SOS-specific routing and fast-path behavior remain separate Phase 3 work.

## Self-Check: PASSED

- Summary file created at `.planning/phases/02-real-time-location-history-privacy/02-10-SUMMARY.md`.
- Created file exists: `mobile/lib/features/location/presentation/location_permission_gate.dart`.
- Task commits `174dd59` and `e2f0a9e` are present in git log.
- Final verification commands listed above passed after the GREEN implementation.

---
*Phase: 02-real-time-location-history-privacy*
*Completed: 2026-07-13*
