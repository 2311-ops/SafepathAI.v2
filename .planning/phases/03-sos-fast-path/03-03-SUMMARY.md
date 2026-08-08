---
phase: 03-sos-fast-path
plan: 03
subsystem: api
tags: [signalr, aspnetcore, clean-architecture, sos, real-time, ef-core]

# Dependency graph
requires:
  - phase: 03-01
    provides: SosSession/SosDeliveryAttempt schema, idempotent TriggerSosCommand, GetSosSessionQuery, SosSessionProjection, SosController skeleton
provides:
  - AlertHub (route /hubs/alert, own alert:family:{id} group namespace, ConfirmReceipt receipt-confirmation method)
  - IAlertClient (SosTriggered, DeliveryStatusChanged, SosCanceled, LiveLocationWindowUpdate)
  - IAlertBroadcastService / AlertBroadcastService
  - ISosAlertDispatcher / SosAlertDispatcher (SignalR fan-out live; Fcm/Sms extension arms stubbed for 03-06/03-05)
  - AcknowledgeSosCommand, CancelSosCommand
  - POST /sos/{id}/acknowledge, POST /sos/{id}/cancel endpoints
affects: [03-04, 03-05, 03-06, 03-07, 03-08, 03-09]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Background fire-and-forget work resolves its own DI scope (IServiceScopeFactory.CreateScope) rather than reusing the request-scoped DbContext, matching SharingPreferenceSweepService's existing convention"
    - "SOS-only dedicated hub/group namespace, structurally isolated from LocationHub, so no future non-emergency feature can share or slow the emergency path"
    - "Per-channel delivery status is only ever advanced by an explicit downstream signal (ConfirmReceipt, AcknowledgeSosCommand) — the dispatcher itself is structurally incapable of writing Delivered/Acknowledged"

key-files:
  created:
    - backend/src/SafePath.Infrastructure/RealTime/AlertHub.cs
    - backend/src/SafePath.Infrastructure/RealTime/IAlertClient.cs
    - backend/src/SafePath.Infrastructure/RealTime/AlertBroadcastService.cs
    - backend/src/SafePath.Application/Common/Interfaces/IAlertBroadcastService.cs
    - backend/src/SafePath.Application/Common/Interfaces/ISosAlertDispatcher.cs
    - backend/src/SafePath.Application/Sos/SosAlertDispatcher.cs
    - backend/src/SafePath.Application/Sos/AcknowledgeSosCommand.cs
    - backend/src/SafePath.Application/Sos/CancelSosCommand.cs
    - backend/tests/SafePath.Application.Tests/Sos/AlertFanOutTests.cs
    - backend/tests/SafePath.Application.Tests/Sos/CancelSosCommandTests.cs
    - backend/tests/SafePath.Api.IntegrationTests/AlertHubSmokeTests.cs
  modified:
    - backend/src/SafePath.Application/Sos/SosDtos.cs
    - backend/src/SafePath.Application/Sos/SosSessionProjection.cs
    - backend/src/SafePath.Application/Sos/TriggerSosCommand.cs
    - backend/src/SafePath.Application/DependencyInjection.cs
    - backend/src/SafePath.Infrastructure/DependencyInjection.cs
    - backend/src/SafePath.Api/Program.cs
    - backend/src/SafePath.Api/Controllers/SosController.cs

key-decisions:
  - "TriggerSosCommandHandler's fire-and-forget dispatch resolves its own IServiceScopeFactory-created DI scope instead of reusing the request's scoped DbContext, since the request scope (and _db with it) is disposed as soon as the handler's Task returns, racing/crashing against a still-running background dispatch."
  - "AcknowledgeSosCommand and AlertHub.ConfirmReceipt both explicitly add the triggering user into the DeliveryStatusChanged broadcast recipient set so the sender's own session reflects live delivery/acknowledgement changes, matching this plan's must_haves truth."
  - "CancelSosCommand is self-cancel only (session.TriggeredByUserId), idempotent on replay, and never mutates/deletes SosDeliveryAttempt rows — cancellation is a parallel notice, never a retraction."

requirements-completed: [SOS-02, SOS-05, NOTIF-03]

coverage:
  - id: D1
    description: "A guardian connected to /hubs/alert receives SosTriggered; a non-member of the requested family is disconnected; the hub occupies its own group namespace distinct from LocationHub"
    requirement: "SOS-02"
    verification:
      - kind: integration
        ref: "backend/tests/SafePath.Api.IntegrationTests/AlertHubSmokeTests.cs#AlertHub_RejectsUserOutsideRequestedFamily, AlertHub_RejectsUnauthenticatedConnection, AlertHub_AcceptsFamilyMemberAndJoinsAlertGroup, AlertHub_UsesGroupNameDistinctFromLocationHub"
        status: pass
    human_judgment: false
  - id: D2
    description: "Dispatching to a channel marks it Queued, never Delivered; a throwing channel is marked Failed and does not abort the remaining channels; the sender's trigger response is never gated on dispatch completion; a replayed session id dispatches zero additional times"
    requirement: "SOS-02"
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Sos/AlertFanOutTests.cs#Dispatch_MarksSignalRAttemptsQueuedNotDelivered, Dispatch_BroadcastsSosTriggeredToEveryResolvedRecipient, Dispatch_ExcludesTheTriggeringUser, Dispatch_ContinuesWhenOneChannelThrows, Trigger_ReturnsBeforeDispatchCompletes, Dispatch_IsSkippedForAnIdempotentReplay"
        status: pass
    human_judgment: false
  - id: D3
    description: "A guardian can acknowledge an SOS (only their own delivery rows change); a non-member is rejected; the sender can self-cancel (idempotent, deletes nothing, broadcasts SosCanceled to the same recipient set); a non-triggering user cannot cancel"
    requirement: "SOS-05"
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Sos/CancelSosCommandTests.cs#Cancel_SetsCanceledStatusAndAudit, Cancel_LeavesOriginalDeliveryRowsIntact, Cancel_BroadcastsSosCanceledToTheSameRecipients, Cancel_IsIdempotent, Cancel_RejectsANonTriggeringUser, Acknowledge_SetsAcknowledgedOnlyForTheCallersOwnRow, Acknowledge_RejectsAUserOutsideTheFamily"
        status: pass
    human_judgment: false
  - id: D4
    description: "Full backend solution builds and all suites (Application, Api.IntegrationTests) are green, including 03-01's pre-existing Sos suites, after this plan's changes"
    requirement: "NOTIF-03"
    verification:
      - kind: other
        ref: "dotnet build backend/SafePath.sln; dotnet test backend/SafePath.sln — 130 Application.Tests + 13 Api.IntegrationTests passing"
        status: pass
    human_judgment: false

duration: ~35min (across original + continuation sessions)
completed: 2026-08-02
status: complete
---

# Phase 03 Plan 03: Alert Hub, SOS-Only Fan-Out Dispatcher, Acknowledge/Cancel Summary

**Dedicated authenticated `AlertHub` (own group namespace, receipt confirmation), an `ISosAlertDispatcher` that fans out SOS-triggered events per recipient/channel while writing only `Queued` (never `Delivered`/`Acknowledged`) and isolating per-channel failures, plus self-cancel and per-recipient acknowledge commands — completing the real-time half of the emergency pipeline without ever gating the sender's confirmation.**

## Performance

- **Duration:** ~35 min total (Tasks 1-2 completed in a prior session; this continuation session completed Task 3 plus a concurrency-bug fix discovered while verifying the full solution)
- **Tasks:** 3 (all complete)
- **Files:** 11 created, 7 modified

## Accomplishments

- `AlertHub` (`/hubs/alert`) is structurally isolated from `LocationHub`: its own `alert:family:{id}` group namespace, no `PresenceTracker`, no location-related method — only delivery fan-out and (from 03-08) live-location window streaming.
- `IAlertClient`'s four events (`SosTriggered`, `DeliveryStatusChanged`, `SosCanceled`, `LiveLocationWindowUpdate`) and `AlertHub.ConfirmReceipt` give "Delivered" a real, client-asserted signal instead of inferring it from a send call returning.
- `SosAlertDispatcher` fans out to every resolved guardian, writes `Queued` (never `Delivered`/`Acknowledged` — enforced by negative greps in the plan's own acceptance criteria), isolates a throwing channel to `Failed` without aborting the rest, and is skipped entirely on an idempotent replay.
- `TriggerSosCommandHandler` starts dispatch without awaiting it inline, so a slow/failing channel can never delay the sender's confirmation.
- `AcknowledgeSosCommand` updates only the caller's own delivery rows; `CancelSosCommand` is self-cancel-only, idempotent, and never deletes or downgrades delivery history — cancellation is a parallel notice, never a retraction.
- Fixed a real concurrency bug (see Deviations) in the fire-and-forget dispatch path that could race or crash against the request's disposed DbContext scope.

## Task Commits

1. **Task 1: Dedicated AlertHub, typed client contract, broadcast service** - `5e44e8e` (completed in prior session)
2. **Task 2: SOS-only fan-out dispatcher wired into the trigger path** - `caa52cc` (completed in prior session)
3. **Task 3: Acknowledge, parallel self-cancel, session-status endpoints (+ concurrency fix)** - `151256f` (this continuation session)

## Files Created/Modified

- `backend/src/SafePath.Infrastructure/RealTime/AlertHub.cs` - Dedicated `[Authorize] Hub<IAlertClient>`; `ConfirmReceipt` flips the caller's own row to `Delivered` and re-broadcasts, including the triggering user in the recipient set so the sender's own session updates live
- `backend/src/SafePath.Infrastructure/RealTime/IAlertClient.cs` - Four typed client methods incl. `LiveLocationWindowUpdate` declared now for 03-08
- `backend/src/SafePath.Infrastructure/RealTime/AlertBroadcastService.cs` - `IHubContext<AlertHub, IAlertClient>`-backed implementation, one dedicated service (no shared "generic notification" surface)
- `backend/src/SafePath.Application/Common/Interfaces/IAlertBroadcastService.cs` - Application-layer interface, zero SignalR types referenced
- `backend/src/SafePath.Application/Common/Interfaces/ISosAlertDispatcher.cs` - Single `DispatchAsync(sosSessionId, ct)` method
- `backend/src/SafePath.Application/Sos/SosAlertDispatcher.cs` - Per-channel try/catch fan-out; `Fcm`/`Sms` no-op arms for 03-06/03-05
- `backend/src/SafePath.Application/Sos/AcknowledgeSosCommand.cs` - Per-recipient acknowledge, broadcasts `DeliveryStatusChanged` including the sender
- `backend/src/SafePath.Application/Sos/CancelSosCommand.cs` - Self-cancel-only, idempotent, never mutates delivery rows
- `backend/src/SafePath.Application/Sos/SosSessionProjection.cs` - Added shared `ResolveRecipientUserIds` helper used by Cancel/Acknowledge
- `backend/src/SafePath.Application/Sos/TriggerSosCommand.cs` - Wired `ISosAlertDispatcher`; fixed to dispatch inside its own DI scope (see Deviations)
- `backend/src/SafePath.Application/DependencyInjection.cs` - Registered `ISosAlertDispatcher`, `AcknowledgeSosCommandHandler`, `CancelSosCommandHandler`
- `backend/src/SafePath.Infrastructure/DependencyInjection.cs` - Registered `IAlertBroadcastService`
- `backend/src/SafePath.Api/Program.cs` - `app.MapHub<AlertHub>("/hubs/alert")` + query-token JWT allowance extended to the new hub path
- `backend/src/SafePath.Api/Controllers/SosController.cs` - Added `POST /sos/{id}/acknowledge`, `POST /sos/{id}/cancel`; no rate-limit attribute on either
- `backend/tests/SafePath.Application.Tests/Sos/AlertFanOutTests.cs` - 6 unit tests (dispatcher + trigger wiring)
- `backend/tests/SafePath.Application.Tests/Sos/CancelSosCommandTests.cs` - 7 unit tests (cancel + acknowledge)
- `backend/tests/SafePath.Api.IntegrationTests/AlertHubSmokeTests.cs` - 4 integration tests (auth, family-scoping, group namespace)

## Decisions Made

- `TriggerSosCommandHandler`'s fire-and-forget dispatch resolves its own `IServiceScopeFactory`-created scope rather than reusing the request-scoped `_db`, matching the existing `SharingPreferenceSweepService` background-scope convention in this codebase.
- `AcknowledgeSosCommand` and `AlertHub.ConfirmReceipt` both explicitly add the triggering user to the broadcast recipient set so the sender's own session reflects live delivery/acknowledgement changes without a separate polling mechanism.
- `CancelSosCommand` rejects any caller other than `session.TriggeredByUserId`, is idempotent (repeat calls leave the first `CanceledAtUtc` untouched and broadcast at most once more), and never deletes, downgrades, or marks `Failed` any `SosDeliveryAttempt` row.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed a request-scope/DbContext concurrency race in the fire-and-forget SOS dispatch**
- **Found during:** Task 3's full-solution verification pass (`dotnet test backend/SafePath.sln`)
- **Issue:** `TriggerSosCommandHandler` (Task 2, prior session) started `_dispatcher.DispatchAsync(...)` without awaiting it, but the dispatcher was constructed from the same request-scoped `IApplicationDbContext` the handler itself still used to build the response DTO immediately afterward. EF Core's `DbContext` is not safe for concurrent use by two overlapping operations, and the HTTP request's DI scope (with `_db`) is disposed the instant the handler's returned `Task` completes — before a backgrounded dispatch necessarily finishes. This surfaced as a flaky integration test (`SosControllerTests.Trigger_ReturnsPerChannelDeliveryState` intermittently observed `Queued` instead of `NotAttempted` in the trigger response, because the background dispatch raced ahead and mutated the same `DbContext` the response was being projected from) and represented a genuine risk of `ObjectDisposedException`/`InvalidOperationException` in production once dispatch takes any nontrivial time past the response.
- **Fix:** Added an optional `IServiceScopeFactory` constructor parameter to `TriggerSosCommandHandler` (defaults to `null`, so the existing `AlertFanOutTests` constructor calls and mocked-dispatcher assertions are unaffected). When a scope factory is available (always true under real DI), the handler creates a fresh scope, resolves `ISosAlertDispatcher` from it, and disposes the scope once dispatch completes — giving the background dispatch its own independent `DbContext`, isolated from the request's. This mirrors `SharingPreferenceSweepService`'s existing `IServiceScopeFactory`-based background-scope pattern in this codebase.
- **Files modified:** `backend/src/SafePath.Application/Sos/TriggerSosCommand.cs`
- **Verification:** Full solution (`dotnet build` + `dotnet test SafePath.sln`) green; re-ran the previously-flaky `SosControllerTests` filter three consecutive times with no failures.
- **Committed in:** `151256f` (Task 3 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — a genuine concurrency bug introduced by this same plan's Task 2, caught by Task 3's own full-solution acceptance criterion)
**Impact on plan:** No scope creep; the fix is additive (an optional constructor parameter), does not alter any existing test's assertions or the plan's file list, and restores the exact `NotAttempted` trigger-response behavior 03-01's test suite already expected.

## Issues Encountered

None beyond the concurrency bug documented above.

## User Setup Required

None.

## Next Phase Readiness

- 03-04 (Dart hub client) can now connect to `/hubs/alert` and consume `IAlertClient`'s four typed events.
- 03-05 (SMS/Twilio) and 03-06 (FCM) each have a single, documented extension point inside `SosAlertDispatcher`'s channel switch.
- 03-07/03-09 can call `AcknowledgeSosCommand`/`CancelSosCommand` against real, tested endpoints.
- No blockers identified.

---
*Phase: 03-sos-fast-path*
*Completed: 2026-08-02*

## Self-Check: PASSED

All files listed above verified present on disk; commits `5e44e8e`, `caa52cc`, `151256f` verified present in `git log --oneline`.
