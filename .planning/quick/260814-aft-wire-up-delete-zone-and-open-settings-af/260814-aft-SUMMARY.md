---
phase: quick-260814-aft
plan: 01
subsystem: ui
tags: [flutter, riverpod, go_router, geofencing, geolocator]

requires:
  - phase: quick-260814-8r2
    provides: SafeZonesPage/SafeZoneEditorPage/SafeZoneReviewPage/SafeZoneDetailPage Riverpod-connected route wrappers
provides:
  - SafeZoneDetailPage.onDeleteConfirmed wired to GeofenceListController.deleteZone with family-id fallback and error-aware navigation
  - SafeZoneDetailPage.onOpenSettings wired to locationPermissionServiceProvider.openAppSettings
affects: [geofencing]

tech-stack:
  added: []
  patterns:
    - "Route-wrapper delete handlers capture GoRouter/ScaffoldMessenger before the first await, then read controller error state post-await to decide navigate-vs-snackbar (avoids use_build_context_synchronously)."

key-files:
  created: []
  modified:
    - mobile/lib/features/geofencing/presentation/safe_zones_page.dart
    - mobile/test/helpers/fake_location_permission_service.dart
    - mobile/test/features/geofencing/safe_zone_router_flow_test.dart

key-decisions:
  - "Confirmation dialog stays owned by SafeZoneDetailScreen; SafeZoneDetailPage supplies only the post-confirmation handler, avoiding a double-confirm UX."
  - "Family id resolution prefers GeofenceListController's loaded state, falling back to FamilyController and calling load() first for the cold-deep-link case, so deleteZone's own null-family early return can never masquerade as a successful delete."

patterns-established:
  - "Pattern: capture BuildContext-derived objects (GoRouter.of, ScaffoldMessenger.of) into locals before any await in a ConsumerWidget handler method, since ConsumerWidget has no mounted guard."

requirements-completed: [GEO-01, GEO-03]

coverage:
  - id: D1
    description: "Confirming Delete zone on the safe-zone detail screen calls GeofenceListController.deleteZone and returns to /safe-zones with the zone removed."
    requirement: "GEO-03"
    verification:
      - kind: automated_ui
        ref: "mobile/test/features/geofencing/safe_zone_router_flow_test.dart#confirming delete removes the zone through the fake API and returns to /safe-zones"
        status: pass
    human_judgment: false
  - id: D2
    description: "Cancelling the delete confirmation (Keep safe zone) deletes nothing and stays on the detail screen."
    requirement: "GEO-03"
    verification:
      - kind: automated_ui
        ref: "mobile/test/features/geofencing/safe_zone_router_flow_test.dart#cancelling the delete confirmation deletes nothing and stays on the detail screen"
        status: pass
    human_judgment: false
  - id: D3
    description: "Open Settings on the location-permission card opens the OS app settings via locationPermissionServiceProvider."
    requirement: "GEO-01"
    verification:
      - kind: automated_ui
        ref: "mobile/test/features/geofencing/safe_zone_router_flow_test.dart#Open Settings on the permission card reaches the location permission seam"
        status: pass
    human_judgment: false
  - id: D4
    description: "A delete that fails server-side (or has no resolvable family id) surfaces an error via snackbar and does not navigate away."
    verification: []
    human_judgment: true
    rationale: "The error/no-family-id snackbar branches (GeofenceApiException surfaced, null-family-id guard) are implemented per the interface_contracts but have no dedicated automated test in this plan — only the happy-path confirm/cancel/open-settings flows are covered. Human should sanity-check by temporarily forcing FakeGeofenceApi.throwsOnDelete or reviewing the code path in safe_zones_page.dart._handleDelete."

duration: ~15min
completed: 2026-08-14
status: complete
---

# Quick Task 260814-aft: Wire up Delete zone and Open Settings Summary

**Wired `SafeZoneDetailScreen`'s two remaining dead affordances — Delete zone and Open Settings — to real `GeofenceListController.deleteZone` and `locationPermissionServiceProvider.openAppSettings()` calls, with router-level test coverage for confirm, cancel, and open-settings.**

## Performance

- **Duration:** ~15 min
- **Tasks:** 3 (2 code tasks + 1 verification gate)
- **Files modified:** 3

## Accomplishments
- `SafeZoneDetailPage.onDeleteConfirmed` resolves a family id (list state, falling back to `familyControllerProvider` with a `load()` for the cold-deep-link case), calls `GeofenceListController.deleteZone`, and navigates to `/safe-zones` only when no error occurred and a family id was resolved — otherwise shows a snackbar and stays put.
- `SafeZoneDetailPage.onOpenSettings` delegates to `locationPermissionServiceProvider.openAppSettings()`.
- No second confirmation dialog was added — `SafeZoneDetailScreen`'s existing `AlertDialog` gate is untouched and verified by the delete-cancel test.
- `FakeLocationPermissionService` gained an additive `openAppSettingsCalls` counter (existing tests unaffected).
- Three new router-level `testWidgets` cases added to `safe_zone_router_flow_test.dart`, driving the real `routerProvider` through delete-confirm, delete-cancel, and open-settings.

## Task Commits

Each task was committed atomically:

1. **Task 1: Supply the delete and open-settings handlers in SafeZoneDetailPage** - `901b2db` (feat)
2. **Task 2: Cover delete-confirm, delete-cancel, and open-settings at the router level** - `2c13fdf` (test)
3. **Task 3: Full-package analyze and test gate** - verification only, no code changes (clean `flutter analyze` + `flutter test` across the whole mobile package; diff confirmed contained to the three files below)

## Files Created/Modified
- `mobile/lib/features/geofencing/presentation/safe_zones_page.dart` - `SafeZoneDetailPage` now supplies `onOpenSettings` and `onDeleteConfirmed`, plus a private `_handleDelete` method implementing family-id resolution, delete, and error-aware navigation.
- `mobile/test/helpers/fake_location_permission_service.dart` - Added `openAppSettingsCalls` counter, incremented in `openAppSettings()`.
- `mobile/test/features/geofencing/safe_zone_router_flow_test.dart` - `_buildContainer` widened to accept an optional `FakeLocationPermissionService`; three new router-driven test cases added.

## Decisions Made
- Family id resolution order is list-state-first, then family-controller fallback with an explicit `load()` before delete — matches the plan's interface contract and avoids `deleteZone`'s own null-family early return silently no-opping a destructive action.
- Used `find.widgetWithText(TextButton, ...)` vs. `find.widgetWithText(FilledButton, ...)` to disambiguate the bottom-bar delete trigger from the dialog's confirm action, since both share the label "Delete zone".
- Added `tester.ensureVisible(...)` before tapping "Open Settings" in the new test, since the permission card sits below the fold in the scrollable detail body and the default `tap()` offset landed outside the 800x600 test viewport.

## Deviations from Plan

None - plan executed exactly as written. One implementation detail not explicitly specified in the plan (the `ensureVisible` call before tapping Open Settings) was needed purely to make the widget test's tap hit-test succeed against an off-screen widget — no production code or plan behavior was affected.

## Issues Encountered
- Initial run of the "Open Settings" test failed with a hit-test warning (`tap()` derived an offset outside the render tree bounds) because the permission card renders near the bottom of a `SingleChildScrollView` and wasn't scrolled into view by `pumpAndSettle` alone. Fixed by calling `tester.ensureVisible(openSettingsFinder)` before tapping — a routine widget-test fix, not a production bug.

## Next Phase Readiness
- Both previously-dead affordances on `SafeZoneDetailScreen` are now fully wired and covered by router-level tests. No further work identified for this task; the explicitly out-of-scope item (re-syncing `GeofenceRegistrationController` after returning from OS settings) remains a separate future concern per the plan.

---
*Phase: quick-260814-aft*
*Completed: 2026-08-14*

## Self-Check: PASSED

All modified files and both task commits (901b2db, 2c13fdf) verified present.
