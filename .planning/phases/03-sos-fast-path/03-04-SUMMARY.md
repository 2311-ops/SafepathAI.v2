---
phase: 03-sos-fast-path
plan: 04
subsystem: ui
tags: [flutter, riverpod, signalr, go_router, sos, delivery-status]

# Dependency graph
requires:
  - phase: 03-sos-fast-path
    provides: "03-02 -- SosController/SosSessionState/SosApi/sos_models.dart, sender_emergency_session_screen.dart scaffold"
  - phase: 03-sos-fast-path
    provides: "03-03 -- AlertHub (/hubs/alert), IAlertClient (SosTriggered/DeliveryStatusChanged/SosCanceled/LiveLocationWindowUpdate), AcknowledgeSosCommand, CancelSosCommand"
provides:
  - "SosHubClient/SignalRSosHubClient/sosHubClientProvider -- authenticated /hubs/alert client with generation-guard reconnect safety and defensive per-event JSON parsing"
  - "SosResponderController/sosResponderControllerProvider -- owns the alert-hub connection lifecycle, confirms receipt once per distinct incoming session, ignores the sender's own outgoing SOS, force-navigates via an injected callback"
  - "ResponderAlertScreen at route '/sos/responder/:sessionId' (name sos-responder) -- full-screen guardian experience with exactly Acknowledge and Call sender"
  - "DeliveryStatusChip/RecipientDeliveryRow -- locked four-state delivery vocabulary (icon+colour+text, never colour alone)"
  - "SosApi.acknowledge/cancel; SosController now folds live deliveryStatusChanges/sosCanceled events into the sender's session"
affects: [03-05, 03-06, 03-07, 03-08, 03-09]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SosResponderController is the sole owner of sosHubClientProvider's connect()/disconnect() lifecycle (mirrors LocationController's role for the location hub); SosController only ever listens to the already-connected client's streams -- one HubConnection per app session, never two competing connect() calls"
    - "Hub-client defensive parsing tested via a fake's raw-JSON push method (FakeSosHubClient.pushRawSosTriggered) that runs the same fromJson-inside-try/catch pipeline the real SignalR client applies, so the parse-valid/swallow-malformed contract is unit-testable without a live SignalR connection"

key-files:
  created:
    - mobile/lib/features/sos/data/sos_hub_client.dart
    - mobile/lib/features/sos/application/sos_responder_controller.dart
    - mobile/lib/features/sos/presentation/responder_alert_screen.dart
    - mobile/lib/features/sos/presentation/delivery_status_chip.dart
    - mobile/test/helpers/fake_sos_hub_client.dart
    - mobile/test/features/sos/sos_delivery_status_test.dart
    - mobile/test/features/sos/responder_alert_screen_test.dart
  modified:
    - mobile/lib/features/sos/data/sos_api.dart
    - mobile/lib/features/sos/data/sos_models.dart
    - mobile/lib/features/sos/presentation/sender_emergency_session_screen.dart
    - mobile/lib/features/sos/application/sos_controller.dart
    - mobile/lib/core/router/app_router.dart
    - mobile/test/helpers/fake_sos_api.dart

key-decisions:
  - "SosResponderController owns sosHubClientProvider's connect/disconnect lifecycle exclusively; SosController (sender-side) never calls connect() itself, only subscribes to the shared client's deliveryStatusChanges/sosCanceled streams -- avoids two competing connections to the same /hubs/alert."
  - "Fixed a real auth-guard bug in app_router.dart: the authenticated-only-route check compared parameterized routes against state.matchedLocation (the resolved path, e.g. /sos/responder/abc-123), which can never equal a route pattern like '/sos/responder/:sessionId' -- the guard would never have fired for this (or any future parameterized) route. Switched the check to state.fullPath (the route pattern), which is a no-op change for the existing static routes in the set."
  - "Corrected the exhausted-retry-budget error copy on the sender screen to the UI-SPEC's exact locked text ('...to anyone yet...' was missing 'to anyone')."
  - "'Call sender' opens a blank tel: dialler rather than a pre-filled number -- no phone-number field exists anywhere on the wire for family members (only EmergencyContact carries one, a separate sender-side fallback feature). Documented as a Known Stub below; a future phase must add a phone field to the family-member contract before this can pre-fill."

requirements-completed: [SOS-02, NOTIF-03, SOS-05]

coverage:
  - id: D1
    description: "SignalRSosHubClient connects to /hubs/alert with the same generation-guard reconnect-race protection and per-event try/catch defensive parsing as location_hub_client.dart, covering SosTriggered/DeliveryStatusChanged/SosCanceled/LiveLocationWindowUpdate"
    requirement: "SOS-02"
    verification:
      - kind: unit
        ref: "mobile/test/features/sos/sos_delivery_status_test.dart#parses a well-formed SosTriggered payload into a SosSession, swallows a malformed payload without closing the stream"
        status: pass
    human_judgment: false
  - id: D2
    description: "SosResponderController confirms receipt exactly once per distinct incoming session id, ignores the sender's own outgoing SOS, and force-navigates to the responder route via an injected callback"
    requirement: "SOS-02"
    verification:
      - kind: unit
        ref: "mobile/test/features/sos/sos_delivery_status_test.dart#confirms receipt after a SosTriggered arrives, exactly once per distinct session id"
        status: pass
    human_judgment: false
  - id: D3
    description: "ResponderAlertScreen renders the sender's name, a red header strip, and exactly Acknowledge + Call sender (no mark-resolved); acknowledging calls the API once and persists a visible acknowledged state with timestamp"
    requirement: "SOS-05"
    verification:
      - kind: unit
        ref: "mobile/test/features/sos/responder_alert_screen_test.dart -- 7/7 tests pass"
        status: pass
    human_judgment: false
  - id: D4
    description: "DeliveryStatusChip/RecipientDeliveryRow render the locked four-state vocabulary (icon+colour+text pairing, never colour alone) and update live from a hub DeliveryStatusChanged event; the sender screen never shows a single aggregate checkmark"
    requirement: "NOTIF-03"
    verification:
      - kind: unit
        ref: "mobile/test/features/sos/sos_delivery_status_test.dart -- DeliveryStatusChip/RecipientDeliveryRow/SenderEmergencySessionScreen groups, 6/6 tests pass"
        status: pass
    human_judgment: false
  - id: D5
    description: "Manual two-device smoke: trigger SOS on device A while device B has the app open on the Live Map; device B lands on the responder screen without an intermediate card, and device A's session shows device B's row flip to Delivered then Seen after Acknowledge"
    requirement: "SOS-02"
    verification: []
    human_judgment: true
    rationale: "No physical/emulator two-device setup was available in this execution environment; this is the plan's own explicitly-called-out manual verification step, not something the automated widget/unit test suite can substitute for."

duration: ~72min
completed: 2026-08-02
status: complete
---

# Phase 03 Plan 04: Alert-Hub Client, Responder Screen, and Honest Delivery Status Summary

**A `signalr_netcore` client for `/hubs/alert` that force-navigates a guardian to a full-screen Acknowledge/Call-sender responder screen on an incoming SOS, plus a locked four-state delivery-status vocabulary (icon+colour+text, never a single checkmark) that updates live on the sender's own session.**

## Performance

- **Duration:** ~72 min
- **Started:** 2026-08-02T11:15:00+03:00 (approx.)
- **Completed:** 2026-08-02T12:40:35+03:00
- **Tasks:** 3
- **Files modified:** 13 (7 created, 6 modified)

## Accomplishments

- Built `SignalRSosHubClient` by mirroring `location_hub_client.dart`'s entire connection-lifecycle structure verbatim: the `_generation` counter re-checked after every await (stale-reconnect-race guard, T-03-17), a try/catch inside every `connection.on(...)` handler (malformed-payload guard, T-03-16), and the same `Provider<T>` + `ref.onDispose` factory convention. Registered all four `IAlertClient` events; `LiveLocationWindowUpdate` is wired now so plan 03-08 only has to add rendering.
- Built `SosResponderController`, the sole owner of the shared alert-hub connection's lifecycle (bootstraps once authenticated + a family is active, mirroring `LocationController`). On an incoming `SosTriggered` it drops the sender's own self-event (T-03-18), confirms receipt exactly once per distinct session id, and force-navigates via an injected, router-agnostic callback -- SOS is never a dismissible card (D-20) regardless of what the guardian is doing in the app.
- Built `ResponderAlertScreen` (route `/sos/responder/:sessionId`, name `sos-responder`): red header strip naming the sender (resolved via `FamilyController`'s member list), exactly the two Phase 3 actions (Acknowledge, Call sender -- D-22, no mark-resolved/dismiss control, D-23), and a persistent "You acknowledged this alert at {time}" caption once acted on.
- Built `DeliveryStatusChip`/`RecipientDeliveryRow`: the locked four-state vocabulary (not-attempted/queued/delivered/acknowledged, each an icon+colour+text triple, never colour alone) rendered per (recipient, channel) -- failed/queued both use amber, never a second red. Wired into the sender's `SosDelivering` state as a scrollable per-recipient list, replacing the previous elapsed-timer-only body, plus the locked "No one to alert yet." empty state for a zero-recipient session.
- `SosController` now subscribes to the shared hub client's `deliveryStatusChanges`/`sosCanceled` streams, folding each event into the matching recipient+channel entry and transitioning `SosSubmitted` -> `SosDelivering` on the first live signal -- the screen never infers Delivered/Sent from the trigger response alone (D-10).

## Task Commits

Each task was committed atomically:

1. **Task 1: Build the alert-hub client and the responder controller that force-navigates on an incoming SOS** - `eb378a7` (feat)
2. **Task 2: Build the full-screen guardian responder screen with Acknowledge and Call sender** - `b0ce7f3` (feat)
3. **Task 3: Render honest per-recipient, per-channel delivery status on the sender's session** - `880244c` (feat)

**Plan metadata:** commit pending (this SUMMARY + STATE/ROADMAP update)

_Note: All three tasks were TDD-flavored (`tdd="true"`) but executed as single feat commits per task rather than separate RED/GREEN commits -- tests and implementation were iterated together, matching 03-02/03-03's own precedent for this plan family._

## Files Created/Modified

- `mobile/lib/features/sos/data/sos_hub_client.dart` - `SosHubClient`/`SignalRSosHubClient`/`sosHubClientProvider`, generation-guard + defensive-parsing pattern copied from `location_hub_client.dart`
- `mobile/lib/features/sos/application/sos_responder_controller.dart` - `SosResponderController`, owns the hub connection, confirm-receipt dedup, force-navigation callback
- `mobile/lib/features/sos/presentation/responder_alert_screen.dart` - Full-screen responder route, red header strip, Acknowledge/Call sender, acknowledged-caption
- `mobile/lib/features/sos/presentation/delivery_status_chip.dart` - `DeliveryStatusChip`/`RecipientDeliveryRow`, locked icon/colour/copy mapping
- `mobile/lib/features/sos/data/sos_api.dart` - Added `acknowledge()`/`cancel()`
- `mobile/lib/features/sos/data/sos_models.dart` - Added `SosDeliveryStatusChange`/`SosCancellation`/`SosLocationUpdate` event DTOs
- `mobile/lib/features/sos/presentation/sender_emergency_session_screen.dart` - `SosDelivering` branch now renders `RecipientDeliveryRow`s + empty state; corrected exhausted-retry copy
- `mobile/lib/features/sos/application/sos_controller.dart` - Subscribes to `deliveryStatusChanges`/`sosCanceled`, folds updates into session state
- `mobile/lib/core/router/app_router.dart` - `/sos/responder/:sessionId` route (name `sos-responder`); fixed the authenticated-only-route guard to check `fullPath` instead of `matchedLocation`
- `mobile/test/helpers/fake_sos_hub_client.dart` - Hand-written `SosHubClient` fake, incl. `pushRawSosTriggered` for defensive-parsing tests
- `mobile/test/helpers/fake_sos_api.dart` - Added `acknowledge`/`cancel` tracking
- `mobile/test/features/sos/sos_delivery_status_test.dart` - 9 tests (hub-client parsing, receipt-confirmation, chip/row rendering, live update)
- `mobile/test/features/sos/responder_alert_screen_test.dart` - 7 tests (headline, actions, no-resolve, acknowledge flow, red header)

## Decisions Made

- `SosResponderController` is the exclusive owner of `sosHubClientProvider`'s connect/disconnect lifecycle; `SosController` only listens to its streams -- one `HubConnection` per app session.
- Fixed a real bug in `app_router.dart`'s authenticated-only-route guard (compared parameterized routes against the wrong `GoRouterState` field -- see Deviations).
- Corrected the sender screen's exhausted-retry-budget copy to the UI-SPEC's exact locked wording.
- "Call sender" opens a blank OS dialler (no phone number to pre-fill exists on the wire yet) -- documented as a Known Stub.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Updated `FakeSosApi` (test helper) with `acknowledge`/`cancel`**
- **Found during:** Task 1, extending `SosApi` with `acknowledge()`/`cancel()`
- **Issue:** `mobile/test/helpers/fake_sos_api.dart` (not in this plan's file list) implements `SosApi` and would fail to compile the moment the interface gained two new abstract methods -- this breaks the entire test suite, not just this plan's new tests.
- **Fix:** Added `acknowledge`/`cancel` implementations plus call-tracking (`acknowledgeCalls`/`cancelCalls`) matching the existing `triggerCalls`/`getSessionCallCount` convention.
- **Files modified:** `mobile/test/helpers/fake_sos_api.dart`
- **Verification:** `flutter analyze`/`flutter test` both clean.
- **Committed in:** `eb378a7` (Task 1 commit)

**2. [Rule 1 - Bug] Fixed the authenticated-only-route guard for parameterized routes**
- **Found during:** Task 2, adding `/sos/responder/:sessionId` to `_authenticatedOnlyRoutes`
- **Issue:** `GoRouterState.matchedLocation` is the *resolved* path (e.g. `/sos/responder/abc-123`), never the route pattern (`/sos/responder/:sessionId`) -- `_authenticatedOnlyRoutes.contains(state.matchedLocation)` would never match this (or any future parameterized) route, silently disabling the auth redirect for a stale/unauthenticated deep link.
- **Fix:** Switched the check to `state.fullPath` (go_router's field for the route's pattern, e.g. `/family/:fid`), which equals the literal path for every existing static route in the set -- a no-op change for everything except the new parameterized route, which now actually works.
- **Files modified:** `mobile/lib/core/router/app_router.dart`
- **Verification:** `grep -c "'/sos/responder/:sessionId'"` returns 2 (route + guard entry); `flutter analyze` clean.
- **Committed in:** `b0ce7f3` (Task 2 commit)

**3. [Rule 1 - Bug] Corrected the exhausted-retry-budget error copy**
- **Found during:** Task 3, adding the locked error-state copy per the action text
- **Issue:** The existing error-state text read "We couldn't confirm delivery yet." -- missing "to anyone" against the UI-SPEC's exact locked copy ("We couldn't confirm delivery to anyone yet. Keep trying...").
- **Fix:** Corrected the string literal.
- **Files modified:** `mobile/lib/features/sos/presentation/sender_emergency_session_screen.dart`
- **Verification:** Visual diff against 03-UI-SPEC.md's Copywriting Contract table.
- **Committed in:** `880244c` (Task 3 commit)

---

**Total deviations:** 3 auto-fixed (1 Rule 3 blocking compilation fix, 2 Rule 1 bugs -- one pre-existing routing gap, one copy-fidelity correction)
**Impact on plan:** All three were necessary for correctness (compilation, a real auth-guard gap, and locked-copy fidelity); no scope creep beyond what each task already required.

## Issues Encountered

- The plan's Task 1 `<verify>` step names `sos_delivery_status_test.dart` before Task 3 (which owns most of that file's content) has run -- resolved by authoring the file incrementally: Task 1's commit includes the file with its 3 hub-client/responder-controller tests only; Task 3's commit extends the same file with its 6 delivery-status/chip/row tests, reaching the "9 passing tests" the plan's Task 3 acceptance criteria call for.
- `flutter test` (full suite) surfaces the same pre-existing, unrelated `SemanticsHandle` teardown failure in `mobile/test/shared_widgets/member_map_pin_semantics_test.dart` first logged in `03-02-SUMMARY.md`/`deferred-items.md` -- confirmed still present, still out of scope for this plan (touches no file this plan modified), not re-fixed here per the scope-boundary rule.
- `dotnet test backend/SafePath.sln` was not re-run: `git status` confirms zero backend files were touched by this plan (matches its own `<verification>` claim), so there is no backend regression risk to verify.

## Known Stubs

- **"Call sender" opens a blank OS dialler, not the sender's actual number.** `mobile/lib/features/sos/presentation/responder_alert_screen.dart`, `_IncomingBody._callSender()`. No phone-number field exists anywhere on the wire for family members -- `SosSessionDto`/`SosRecipientStatusDto` never carry one (by design, threat T-03-03), and `FamilyMemberView` has no phone field either (only the separate `EmergencyContact` entity does, which is the sender's own local-fallback feature in plan 03-07, not this screen). A future phase must add a phone field to the family-member contract (a schema/DTO change, Rule 4 architectural scope, out of bounds for this mobile-only plan) before this button can pre-fill a real number.

## Threat Flags

None beyond what `03-04-PLAN.md`'s own `<threat_model>` already registers (T-03-16, T-03-17, T-03-03, T-03-04, T-03-18) -- no new network endpoint, auth path, or trust-boundary surface was introduced beyond that register.

## User Setup Required

None - no external service configuration required this plan.

## Next Phase Readiness

- 03-05 (SMS/Twilio) and 03-06 (FCM) can render their channel's status through the same `DeliveryStatusChip`/`RecipientDeliveryRow` widgets without touching this file again.
- 03-06's FCM deep-link path resolves to the same `sos-responder` named route this plan registered.
- 03-08 (live-location countdown) fills the `// Owned by plan 03-08` seam already left in both `sender_emergency_session_screen.dart`'s `SosDelivering`/`SosLiveActive` handling and `responder_alert_screen.dart`'s `_IncomingBody`.
- 03-09 (hold-to-cancel + canceled chrome) fills the `_CanceledPlaceholderBody` seam in `responder_alert_screen.dart` and the `SosCanceled` branch already wired in `sender_emergency_session_screen.dart`/`sos_controller.dart`.
- Manual two-device smoke verification (trigger on A, confirm B force-navigates and A's Delivered/Seen states update) was not performed in this execution environment (no second device/emulator available) -- flagged as human-judgment coverage (D5) above.
- The "Call sender" phone-number gap (Known Stubs) should be resolved by whichever future phase adds a phone field to the family-member contract.

---
*Phase: 03-sos-fast-path*
*Completed: 2026-08-02*

## Self-Check: PASSED

All 7 created/tracked files verified present on disk; all 3 task commits (`eb378a7`, `b0ce7f3`, `880244c`) verified present in git log.
