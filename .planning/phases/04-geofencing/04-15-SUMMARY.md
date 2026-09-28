---
phase: 04-geofencing
plan: 15
subsystem: mobile-ui
tags: [flutter, riverpod, dio, go-router, geofencing, notifications, quiet-hours]
requires:
  - phase: 04-geofencing
    provides: durable recipient feed rows, caller-owned quiet-hours endpoints, and authorized zone-activity queries
provides:
  - Durable routine notification feed with idempotent read state and zone-activity routing
  - Recipient-owned quiet-hours editor with IANA validation
  - Minimal feed contract fields for member names and safe-zone filters
affects: [geofencing-uat, routine-notification-delivery]
actuals:
  tokens: 7988
  tasks: 2
  commits: 6
tech-stack:
  added: []
  patterns: [caller-owned notification endpoints, normal navigation for routine alerts, family-scoped activity reload]
key-files:
  created:
    - mobile/lib/features/geofencing/application/routine_notifications_controller.dart
    - mobile/lib/features/geofencing/presentation/notifications_screen.dart
    - mobile/lib/features/geofencing/presentation/quiet_hours_screen.dart
  modified:
    - mobile/lib/core/router/app_router.dart
    - mobile/lib/features/location/presentation/live_map_screen.dart
    - backend/src/SafePath.Application/Geofencing/GetRoutineNotificationsQuery.cs
key-decisions:
  - "Routine feed rows update local read state before the idempotent caller-owned read request, so normal navigation is never blocked by delivery status."
  - "The feed contract now supplies memberDisplayName and safeZoneId, allowing the client to render truthful rows and request a family-scoped zone filter without exposing coordinates."
requirements-completed: [NOTIF-02, GEO-03]
coverage:
  - id: D1
    description: "Routine feed renders unread transition rows, supports normal activity navigation, and preserves the non-SOS route."
    requirement: NOTIF-02
    verification:
      - kind: automated_ui
        ref: "flutter test test/features/geofencing/notifications_screen_test.dart"
        status: pass
      - kind: integration
        ref: "F:/DevTools/dotnet/dotnet.exe test backend/tests/SafePath.Api.IntegrationTests --filter FullyQualifiedName~NotificationsControllerTests --no-restore"
        status: pass
    human_judgment: false
  - id: D2
    description: "Recipients can edit their own quiet-hours policy with actionable time-zone validation and explicit routine/SOS copy."
    requirement: GEO-03
    verification:
      - kind: automated_ui
        ref: "flutter test test/features/geofencing/quiet_hours_screen_test.dart"
        status: pass
      - kind: other
        ref: "flutter analyze"
        status: pass
    human_judgment: false
duration: 18min
completed: 2026-08-14
status: complete
---

# Phase 04 Plan 15: Routine Notifications UI Summary

**Durable Flutter notification feed, recipient-owned quiet-hours controls, and authorized zone-activity routing kept separate from SOS behavior.**

## Performance

- **Duration:** 18 min
- **Started:** 2026-08-14T01:35:58Z
- **Completed:** 2026-08-14T01:53:12Z
- **Tasks:** 2/2
- **Files modified:** 9

## Accomplishments

- Added a 48px Live Map Notifications action and normal-push route with durable New/read feed rows, full local timestamps, and no delivery-status claim.
- Added caller-owned quiet-hours settings with disabled default, local start/end controls, IANA zone validation, and explicit immediate feed/activity plus SOS-bypass copy.
- Extended the minimal feed response with member display name and safe-zone id, then loads the existing authorized activity endpoint filtered to the tapped zone.

## Task Commits

1. **Task 1: Build routine Notifications feed and activity routing** - `cc4fce8` (TDD RED), `741f8b1` (GREEN), `30ab92a` (contract RED), `475db81` (correctness fix)
2. **Task 2: Expose PR-03 recipient quiet-hours settings** - `bec0b5d` (TDD RED), `012bed6` (GREEN)

## Files Created/Modified

- `mobile/lib/features/geofencing/application/routine_notifications_controller.dart` - API models, caller-owned feed/read/quiet-hours requests, and Riverpod coordination.
- `mobile/lib/features/geofencing/presentation/notifications_screen.dart` - Routine feed states and family-scoped activity loader.
- `mobile/lib/features/geofencing/presentation/quiet_hours_screen.dart` - Recipient-only quiet-hours editor.
- `mobile/lib/features/location/presentation/live_map_screen.dart` - 48px Notifications entry action.
- `mobile/lib/core/router/app_router.dart` - Notifications, quiet-hours, and filtered activity routes.
- `backend/src/SafePath.Application/Geofencing/GetRoutineNotificationsQuery.cs` - Feed member-name and safe-zone fields.
- `backend/tests/SafePath.Api.IntegrationTests/NotificationsControllerTests.cs` - Response-contract regression coverage.

## Decisions Made

- Routine notification navigation remains ordinary app navigation; it never uses SOS chrome or force-navigation.
- The API continues to authorize activity server-side; the mobile route only supplies the active family and tapped safe-zone filter.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added feed fields required for truthful row rendering and filtered activity routing**
- **Found during:** Task 1
- **Issue:** `GET /notifications` lacked both `memberDisplayName` and `safeZoneId`; the client could neither render the named/avatar row nor select the clicked zone's authorized activity.
- **Fix:** Joined the existing user row into the feed projection and returned the activity's safe-zone id; the mobile route consumes only those identifiers.
- **Files modified:** `backend/src/SafePath.Application/Geofencing/GetRoutineNotificationsQuery.cs`, `backend/tests/SafePath.Api.IntegrationTests/NotificationsControllerTests.cs`, and Task 1 mobile routing files.
- **Verification:** Focused NotificationsController integration test, focused Flutter feed test, and Flutter analysis passed.
- **Committed in:** `30ab92a`, `475db81`

---

**Total deviations:** 1 auto-fixed (Rule 2)
**Impact on plan:** Required for correct, truthful, and authorization-preserving feed behavior; no new endpoint, schema, or dependency was added.

## Issues Encountered

- The first broad Flutter test invocation exceeded its timeout while compiler workers were still starting; the rerun with the local package configuration completed normally and produced the expected RED failure.
- `flutter analyze` reports only the three pre-existing informational diagnostics in `geofence_candidate_uploader.dart`; no diagnostics originate from this plan.

## User Setup Required

None - the UI uses existing authenticated endpoints and stores the recipient's IANA time-zone value through their own settings endpoint.

## Next Phase Readiness

- Routine feed, quiet-hours editing, and activity navigation are ready for Phase 04 UAT.
- No plan-specific blocker remains.

---
*Phase: 04-geofencing*
*Completed: 2026-08-14*

## Self-Check: PASSED

- Verified all nine implementation/test files and this summary exist.
- Verified TDD RED/GREEN and feed-contract commits `cc4fce8`, `741f8b1`, `bec0b5d`, `012bed6`, `30ab92a`, and `475db81` exist.
