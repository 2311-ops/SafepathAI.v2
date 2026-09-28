---
phase: 04-geofencing
plan: 13
subsystem: mobile-ui
tags: [flutter, riverpod, go-router, geofencing, accessibility]
requires:
  - phase: 04-geofencing
    provides: map-first safe-zone editor and typed mobile safe-zone draft contracts
provides:
  - Safe Zones list and detail screens with truthful activation states and confirmed delete
  - Guardian-only Live Map entry and authenticated routes for safe-zone management
affects: [04-14-geofence-activity-ui, mobile-safe-zone-management]
actuals:
  tokens: 12340
  tasks: 2
  commits: 3
tech-stack:
  added: []
  patterns: [route-level management seam, reusable guardian CTA, typed safe-zone list state]
key-files:
  created:
    - mobile/lib/features/geofencing/presentation/safe_zones_screen.dart
    - mobile/lib/features/geofencing/presentation/safe_zone_detail_screen.dart
    - mobile/test/features/geofencing/safe_zone_flow_test.dart
  modified:
    - mobile/lib/features/geofencing/application/geofence_controller.dart
    - mobile/lib/features/geofencing/data/geofence_api.dart
    - mobile/lib/features/geofencing/data/geofence_models.dart
    - mobile/lib/features/geofencing/data/native_geofence_gateway.dart
    - mobile/lib/features/location/presentation/live_map_screen.dart
    - mobile/lib/core/router/app_router.dart
    - mobile/test/features/geofencing/geofence_controller_test.dart
    - mobile/test/features/geofencing/native_geofence_gateway_test.dart
key-decisions:
  - "The Live Map exposes a 48px Manage safe zones action only when the loaded profile role is Guardian."
  - "Safe-zone list/detail routes preserve the existing shell and SOS behavior; backend auth remains the real security boundary."
  - "The mobile geofence API was extended with list/get/delete because the 04-13 UI cannot truthfully manage real zones with create/update only."
requirements-completed: [GEO-01]
coverage:
  - id: D1
    description: Safe-zone list/detail screens render empty/error/populated states, activation status, activity action, settings prompt, and confirmed delete.
    requirement: GEO-01
    verification:
      - kind: automated_ui
        ref: C:\Flutter\flutter\bin\flutter.bat test test/features/geofencing/safe_zone_flow_test.dart
        status: pass
    human_judgment: false
  - id: D2
    description: Guardian safe-zone management is reachable from Live Map through a 48px action and authenticated routes.
    requirement: GEO-01
    verification:
      - kind: automated_ui
        ref: C:\Flutter\flutter\bin\flutter.bat test test/features/geofencing/safe_zone_flow_test.dart
        status: pass
      - kind: static
        ref: C:\Flutter\flutter\bin\flutter.bat analyze
        status: unknown
    human_judgment: true
    rationale: "Analyze exits non-zero only for three pre-existing infos in geofence_candidate_uploader.dart; no 04-13 errors remain, but the command status is still non-zero until those legacy infos are cleaned."
duration: 36min
completed: 2026-08-14
status: complete
---

# Phase 04 Plan 13: Safe-Zone List, Detail, and Navigation Summary

**Safe-zone management is now reachable from the Live Map for Guardians, with real list/detail screens that show activation status, route to management, and require confirmation before delete.**

## Performance

- **Duration:** 36 min
- **Completed:** 2026-08-14
- **Tasks:** 2/2
- **Files modified:** 11

## Accomplishments

- Added Safe Zones list states for empty, error, and populated data, including member/radius/category/status cards and activity actions.
- Added Safe Zone detail with map summary, permission-needed Open Settings copy, edit/activity actions, and confirmed delete.
- Added mobile list/get/delete API seams and a list controller so the UI can load real server zones rather than fake local data.
- Added Guardian-only Live Map entry and safe-zone routes without altering tab count, shell behavior, or SOS controls.

## Task Commits

1. **Task 1: Build Guardian list/detail and truthful activation states** - `e81a40b` (TDD RED), `a31bdfb` (feat GREEN)
2. **Task 2: Add Guardian-only routes and Live Map entry without shell changes** - `4bef3d9` (feat/test)

## Verification

- Passed: `C:\Flutter\flutter\bin\flutter.bat test test\features\geofencing\safe_zone_flow_test.dart` - 3/3 tests.
- Passed: `C:\Flutter\flutter\bin\flutter.bat test test\features\geofencing\geofence_controller_test.dart test\features\geofencing\safe_zone_editor_test.dart test\features\geofencing\safe_zone_flow_test.dart test\features\geofencing\native_geofence_gateway_test.dart` - 13/13 tests.
- Partial: `C:\Flutter\flutter\bin\flutter.bat analyze` reports only three pre-existing `prefer_initializing_formals` infos in `lib/features/geofencing/data/geofence_candidate_uploader.dart`.

## Decisions Made

- The Safe Zones list does not render a duplicate floating add button in empty/error/loading states; the visible empty-state CTA remains the primary action.
- The detail screen keeps edit/delete actions in the bottom safe area so confirmation is reachable on small devices.
- The profile role gates the Live Map entry as a convenience/defense-in-depth only; backend Guardian authorization remains authoritative.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added mobile list/get/delete seams**

- **Found during:** Task 2
- **Issue:** The 04-13 plan requires a real list/detail/delete flow, but the existing mobile geofence API from 04-12 only exposed create/update.
- **Fix:** Added typed list/get/delete methods, JSON hydration, and a list controller while preserving the existing editor/save contracts.
- **Files modified:** `mobile/lib/features/geofencing/data/geofence_api.dart`, `mobile/lib/features/geofencing/data/geofence_models.dart`, `mobile/lib/features/geofencing/application/geofence_controller.dart`
- **Verification:** Focused geofencing Flutter tests passed 13/13.
- **Committed in:** `4bef3d9`

---

**Total deviations:** 1 Rule-2 correctness seam.

## Issues Encountered

- The disconnected executor left only the RED flow test; root continued 04-13 inline under the user's elevated-tool approval.
- Initial widget tests exposed duplicate empty-state add labels, hidden bottom actions, and fragile semantics lookup. The UI/test were adjusted to make actions visible and deterministic.

## User Setup Required

None - no external service configuration is required.

## Next Phase Readiness

- 04-14 can layer activity views onto the list/detail route structure.
- The mobile API/controller can now hydrate and mutate real server safe zones.

## Self-Check: PASSED

- Verified 04-13 focused tests and broader geofencing Flutter tests pass.
- Verified no 04-05 evidence was fabricated and no `04-05-SUMMARY.md` exists.

---
*Phase: 04-geofencing*
*Completed: 2026-08-14*
