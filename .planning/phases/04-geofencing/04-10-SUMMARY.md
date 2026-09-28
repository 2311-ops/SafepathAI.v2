---
phase: 04-geofencing
plan: 10
subsystem: infra
tags: [dotnet, firebase-admin, fcm, apns, geofencing, background-service]
requires:
  - phase: 04-geofencing
    provides: durable recipient-owned routine feed rows, quiet-hours re-evaluation, and retry-ready jobs
provides:
  - Normal-priority routine push sender isolated from SOS transport
  - Bounded, durable routine job worker with per-recipient retry isolation
affects: [04-15-geofence-notifications-ui, routine-notification-delivery]
actuals:
  tokens: 7473
  tasks: 2
  commits: 4
tech-stack:
  added: []
  patterns: [separate emergency/routine push seams, identifier-only routine payloads, fresh DI scope per durable job]
key-files:
  created:
    - backend/src/SafePath.Application/Common/Interfaces/IRoutinePushSender.cs
    - backend/src/SafePath.Infrastructure/Push/FirebaseRoutinePushSender.cs
    - backend/src/SafePath.Infrastructure/Push/LoggingRoutinePushSender.cs
    - backend/src/SafePath.Infrastructure/Geofencing/RoutinePushWorker.cs
    - backend/tests/SafePath.Application.Tests/Geofencing/RoutineNotificationDispatcherTests.cs
  modified:
    - backend/src/SafePath.Infrastructure/DependencyInjection.cs
    - backend/tests/SafePath.Application.Tests/Sos/PushFanOutTests.cs
key-decisions:
  - "Routine notifications use a separate IRoutinePushSender and named Firebase app, so normal-priority transport cannot change SOS's high-priority sender settings."
  - "Routine jobs are re-evaluated for quiet hours immediately before delivery and retry with bounded exponential backoff after isolated provider failures."
patterns-established:
  - "Routine push payloads carry only type, activityId, and zoneId; coordinates never leave the backend through this channel."
  - "Hosted durable workers discover a bounded batch then open a fresh DI scope per job, isolating DbContext state and provider failures."
requirements-completed: [NOTIF-02, GEO-02]
coverage:
  - id: D1
    description: "Routine pushes use normal transport priority and an identifier-only payload through a sender seam separate from SOS."
    requirement: NOTIF-02
    verification:
      - kind: unit
        ref: "F:\\DevTools\\dotnet\\dotnet.exe test backend\\tests\\SafePath.Application.Tests --filter \"FullyQualifiedName~RoutineNotificationDispatcherTests|FullyQualifiedName~PushFanOutTests\" --no-restore"
        status: pass
    human_judgment: false
  - id: D2
    description: "Eligible routine jobs complete once while a failing recipient retains bounded retry state without blocking a sibling."
    requirement: GEO-02
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Geofencing/RoutineNotificationDispatcherTests.cs#DrainDueJobs_KeepsFailingSiblingScheduledWhileCompletingEligibleSibling"
        status: pass
      - kind: integration
        ref: "F:\\DevTools\\dotnet\\dotnet.exe test backend\\SafePath.sln --no-restore"
        status: pass
    human_judgment: false
duration: 7min
completed: 2026-08-14
status: complete
---

# Phase 04 Plan 10: Routine Push Delivery Summary

**Isolated normal-priority FCM/APNs routine delivery with identifier-only payloads, quiet-hours rechecks, and bounded per-recipient retries.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-08-14T01:33:47Z
- **Completed:** 2026-08-14T01:40:27Z
- **Tasks:** 2/2
- **Files modified:** 7

## Accomplishments

- Added a routine-only push sender seam with Firebase normal-priority (`safepath_routine`, APNs priority 5) and no-Firebase logging implementations.
- Preserved SOS high-priority transport through its existing isolated `IPushSender` path, with a structural regression test pinning its channel and priorities.
- Added a hosted durable worker that rechecks quiet hours, emits no coordinates, uses per-job scopes, and retries provider failures without blocking sibling jobs.

## Task Commits

1. **Task 1: Send normal-priority routine payloads and fence SOS** - `8e44408` (TDD RED), `2f06551` (feat GREEN)
2. **Task 2: Drain jobs with bounded per-recipient retry** - `ae08369` (TDD RED), `7ca5afd` (feat GREEN)

## Files Created/Modified

- `backend/src/SafePath.Application/Common/Interfaces/IRoutinePushSender.cs` - Routine-only provider contract.
- `backend/src/SafePath.Infrastructure/Push/FirebaseRoutinePushSender.cs` - Normal-priority FCM/APNs sender.
- `backend/src/SafePath.Infrastructure/Push/LoggingRoutinePushSender.cs` - Zero-cost local routine sender.
- `backend/src/SafePath.Infrastructure/Geofencing/RoutinePushWorker.cs` - Bounded per-job durable delivery worker.
- `backend/src/SafePath.Infrastructure/DependencyInjection.cs` - Registers both isolated sender seams and the hosted worker.
- `backend/tests/SafePath.Application.Tests/Geofencing/RoutineNotificationDispatcherTests.cs` - Identifier-only payload and retry-isolation coverage.
- `backend/tests/SafePath.Application.Tests/Sos/PushFanOutTests.cs` - SOS high-priority transport regression coverage.

## Decisions Made

- The routine sender uses a distinct interface and named Firebase application instead of reusing the SOS sender instance, preserving the emergency transport's high/critical path.
- Provider acceptance completes a routine job; provider failures retain durable state with capped exponential retry timing, while quiet-hours deferrals remain separate from failures.

## Verification

- Passed: focused routine/SOS tests — 13/13.
- Passed: `F:\DevTools\dotnet\dotnet.exe test backend\SafePath.sln --no-restore` — 228 application and 24 API integration tests.

## Deviations from Plan

None - plan executed exactly as written.

## User Setup Required

None - existing Firebase configuration enables routine delivery automatically; absent credentials continue to use the logging sender.

## Next Phase Readiness

- The notification UI can consume durable routine feed data knowing delivery work is isolated from SOS.
- No plan-specific blocker remains.

---
*Phase: 04-geofencing*
*Completed: 2026-08-14*

## Self-Check: PASSED

- Verified all seven planned implementation/test files and this summary exist.
- Verified TDD RED/GREEN commits `8e44408`, `2f06551`, `ae08369`, and `7ca5afd` exist.
