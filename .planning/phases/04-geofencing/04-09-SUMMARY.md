---
phase: 04-geofencing
plan: 09
subsystem: api
tags: [dotnet, ef-core, geofencing, notifications, quiet-hours, iana-timezone]
requires:
  - phase: 04-geofencing
    provides: durable recipient-owned feed rows and routine-push jobs
provides:
  - Recipient-scoped durable routine notification feed with owner-only idempotent read state
  - Authenticated recipient-owned quiet-hours settings and UTC defer decisions for routine jobs
affects: [04-14-geofence-activity-ui, routine-notification-worker]
actuals:
  tokens: 7480
  tasks: 2
  commits: 4
tech-stack:
  added: []
  patterns: [current-user-scoped feed queries, pure quiet-hours UTC decision, routine-job-only defer scheduling]
key-files:
  created:
    - backend/src/SafePath.Application/Geofencing/GetRoutineNotificationsQuery.cs
    - backend/src/SafePath.Application/Geofencing/MarkRoutineNotificationReadCommand.cs
    - backend/src/SafePath.Application/Geofencing/QuietHoursCommands.cs
    - backend/src/SafePath.Application/Geofencing/RoutineNotificationDispatcher.cs
    - backend/src/SafePath.Api/Controllers/NotificationsController.cs
    - backend/tests/SafePath.Application.Tests/Geofencing/QuietHoursTests.cs
    - backend/tests/SafePath.Api.IntegrationTests/NotificationsControllerTests.cs
  modified:
    - backend/src/SafePath.Application/DependencyInjection.cs
key-decisions:
  - "Notification feed queries and read mutations use only the authenticated recipient id; no request can supply an owner id."
  - "Quiet-hours scheduling is a pure IANA-local-to-UTC decision that only changes routine-job state and next attempt time."
  - "Invalid persisted zones fail closed as pending work for retry; SOS and push-send dependencies are intentionally absent."
patterns-established:
  - "Routine feed payloads expose transition metadata only and never coordinates or delivery-confidence fields."
  - "Timezone ends that fall in a DST-invalid local minute advance to the next valid local instant."
requirements-completed: [NOTIF-02]
coverage:
  - id: D1
    description: Recipient-owned routine feed rows can be listed and marked read without exposing coordinates, delivery status, or another recipient's row.
    requirement: NOTIF-02
    verification:
      - kind: integration
        ref: F:\\DevTools\\dotnet\\dotnet.exe test backend\\tests\\SafePath.Api.IntegrationTests --filter "FullyQualifiedName~NotificationsControllerTests" --no-restore
        status: pass
    human_judgment: false
  - id: D2
    description: Recipient-owned quiet hours defer routine work across overnight and DST windows while disabled settings send now and invalid zones remain pending.
    requirement: NOTIF-02
    verification:
      - kind: unit
        ref: F:\\DevTools\\dotnet\\dotnet.exe test backend\\tests\\SafePath.Application.Tests --filter "FullyQualifiedName~QuietHoursTests" --no-restore
        status: pass
      - kind: integration
        ref: F:\\DevTools\\dotnet\\dotnet.exe test backend\\SafePath.sln --no-restore
        status: pass
    human_judgment: false
duration: 20min
completed: 2026-08-14
status: complete
---

# Phase 04 Plan 09: Routine Notifications and Quiet Hours Summary

**Recipient-scoped durable geofence feed APIs and server-authoritative IANA quiet-hours scheduling for routine jobs, fully isolated from SOS delivery.**

## Performance

- **Duration:** 20 min
- **Started:** 2026-08-14T01:18:59Z
- **Completed:** 2026-08-14T01:38:59Z
- **Tasks:** 2/2
- **Files modified:** 8

## Accomplishments

- Added `GET /notifications` and owner-only, idempotent `POST /notifications/{id}/read` endpoints over durable recipient feed rows.
- Added authenticated `GET`/`PUT /notifications/quiet-hours` settings that cannot target another recipient.
- Added routine-job quiet-hours reevaluation with disabled, overnight, DST, and invalid-zone outcomes; it has no SOS or direct push-sender dependency.

## Task Commits

1. **Task 1: Expose recipient-owned feed and read state** - `ccbc20e` (TDD RED), `fb09ae3` (feat GREEN)
2. **Task 2: Implement PR-03 settings and deterministic defer decisions** - `2d019a1` (TDD RED), `e233296` (feat GREEN)

## Verification

- Passed: focused `QuietHoursTests` - 4/4 tests.
- Passed: focused `NotificationsControllerTests` - 1/1 test.
- Passed: `F:\DevTools\dotnet\dotnet.exe test backend\SafePath.sln --no-restore` - 224 application and 24 API integration tests.

## Decisions Made

- Feed reads and mutations derive identity solely from `ICurrentUserService`, keeping IDOR predicates server-side.
- Quiet-hours decisions conservatively defer invalid time zones as pending retry work and advance DST-invalid end times to the next valid local instant.
- The dispatcher schedules only `GeofenceRoutineJob` state and timing, preserving the SOS fast path and leaving actual push dispatch separate.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected EF Core ordering before DTO projection**
- **Found during:** Task 1
- **Issue:** SQLite could not translate ordering by a property of a record DTO constructed inside the join query.
- **Fix:** Ordered the translated feed/activity join before projecting `RoutineNotificationDto`.
- **Files modified:** `backend/src/SafePath.Application/Geofencing/GetRoutineNotificationsQuery.cs`
- **Verification:** Focused notification integration test and full backend suite pass.
- **Committed in:** `fb09ae3`

**Total deviations:** 1 auto-fixed (Rule 1 bug)
**Impact on plan:** Required for reliable feed reads; no scope expansion.

## User Setup Required

None - no external service configuration is required.

## Next Phase Readiness

- UI and worker work can consume the durable feed API and re-evaluate routine jobs immediately before a delivery attempt.
- 04-05 remains incomplete by explicit override and is not represented by this summary.

---
*Phase: 04-geofencing*
*Completed: 2026-08-14*

## Self-Check: PASSED

- Verified all eight planned implementation/test files and this summary exist.
- Verified TDD RED/GREEN commits `ccbc20e`, `fb09ae3`, `2d019a1`, and `e233296` exist.
