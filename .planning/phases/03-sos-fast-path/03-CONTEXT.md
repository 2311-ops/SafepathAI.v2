# Phase 03: SOS Fast Path (Core Value) - Context

**Gathered:** 2026-07-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 03 proves SafePath AI's non-negotiable Core Value end to end: a visible, structurally isolated SOS fast path that alerts Guardians and configured emergency contacts with live location within seconds, bypassing routine location batching, geofencing, AI, analytics, and any other non-emergency pipeline.

This phase owns the plain SOS path only: trigger, delivery, offline retry, responder screen, live location sharing window, self-cancel follow-up state, and a basic OS home-screen quick action backup trigger. Silent/Duress implementation remains Phase 6.

</domain>

<decisions>
## Implementation Decisions

### Trigger UX
- **D-01:** The raised center SOS button MUST follow `DESIGN-02` verbatim: 3-second press-and-hold, circular progress ring, release before 3 seconds cancels.
- **D-02:** Once the 3-second hold completes, SOS sends immediately. Do not add a second confirmation, countdown, or cancel-before-send gate.
- **D-03:** After send, route the sender into a full-screen emergency session, not a banner or bottom sheet.
- **D-04:** The sender's emergency session must show delivery confidence/status, live-location sharing status, and guardian notification state.
- **D-05:** Self-cancel is a parallel follow-up action. It never delays the original alert and never silently retracts it. Guardians see that SOS was triggered and then canceled by the sender.

### Delivery Channels
- **D-06:** Phase 03 planning should target all three channels from day one: dedicated `AlertHub`/SignalR for active in-app Guardians, FCM push for durable app/background delivery, and SMS fallback for configured emergency contacts.
- **D-07:** Prefer free/no-cost options first. Anything paid must be marked as later unless the phase cannot satisfy a locked requirement without it.
- **D-08:** SMS provider is not locked. Research should quickly compare free/dev-friendly options first, then evaluate Twilio or equivalent for production SMS fallback, including .NET SDK maturity, delivery webhook support, cost, and trial availability.
- **D-09:** The delivery UI must show per-recipient/per-channel state. Do not collapse delivery into one vague checkmark.
- **D-10:** Do not show confident "Sent" merely because the API call returned, the server accepted a request, or a message was queued.
- **D-11:** Initial recipients are active Guardians plus configured emergency contacts. Do not notify all active family members by default.

### Offline Retry
- **D-12:** If the phone is offline when SOS is triggered, enter the same full-screen emergency session immediately with a clear not-sent-yet/retrying state.
- **D-13:** Generate a client-side `sosSessionId` immediately when the 3-second hold completes, before any network call.
- **D-14:** Persist the `sosSessionId` locally so app kill/restart resumes the same queued SOS session.
- **D-15:** Server submissions with the same `sosSessionId` must be idempotent: repeat submissions are no-op/status-check behavior, not duplicate emergencies.
- **D-16:** Direct device-SMS fallback is deferred to fast-follow/later. iOS cannot silently send SMS, and Android-only automatic SMS would create asymmetric guarantees.
- **D-17:** Offline sender UI should show "Not sent yet, retrying", last retry time, and local fallback actions such as calling an emergency contact and copying location when available.

### Responder Experience
- **D-18:** Guardian SOS arrival is a full-screen responder experience.
- **D-19:** FCM notifications deep-link directly into the dedicated SOS responder screen.
- **D-20:** If a Guardian is actively using the app in the foreground, force-navigate to the same responder screen. Avoid dismissible cards for SOS.
- **D-21:** The responder screen shows the sender's live location stream for a fixed window with an explicit end time/countdown.
- **D-22:** Phase 03 responder actions are Acknowledge and Call sender.
- **D-23:** Do not build Guardian "mark resolved" in Phase 03. That is incident-lifecycle scope and belongs later.
- **D-24:** If the sender self-cancels, keep the SOS visible with an explicit canceled state such as "Canceled by {name} at {time}". Do not move it immediately to history or hide it.

### Backup Trigger / OS Shortcut
- **D-25:** Build the first backup trigger using Flutter's official `quick_actions` plugin, because one API covers Android App Shortcuts and iOS Home Screen Quick Actions.
- **D-26:** Android Quick Settings tile and iOS Widget/App Intent entry points are fast-follow/later, not the first Phase 03 backup trigger.
- **D-27:** The backup shortcut fires SOS immediately when invoked. Do not require the 3-second arming hold after the OS-level shortcut.
- **D-28:** Silent/Duress is explicitly out of Phase 03 scope and remains Phase 6. Phase 03 may design the backend pipeline so a later `kind = visible | duress` field can reuse it, but must not implement decoy UI, duress secret storage, or covert behavior now.

### the agent's Discretion
Planner/researcher may choose implementation details that preserve the decisions above, existing Clean Architecture boundaries, existing Riverpod/go_router mobile patterns, and the cost preference for free/no-cost options first.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase Scope And Requirements
- `.planning/ROADMAP.md` - Phase 03 goal, success criteria, requirements list, and explicit Phase 6 separation for Signature Safety Features.
- `.planning/REQUIREMENTS.md` - SOS-01 through SOS-06, NOTIF-03, DESIGN-02, and DURESS requirements scoped outside Phase 03.
- `.planning/PROJECT.md` - Core Value, privacy/no-data-resale posture, key decisions, and cost/scope constraints.
- `.planning/STATE.md` - Current project position, blockers, unresolved SMS provider decision, and recent Phase 02/quick-task context.

### Research And Risk Guidance
- `.planning/research/SUMMARY.md` - SOS fast-path architecture, multi-channel delivery/ack tracking discipline, and Phase 03 SMS-provider research flag.
- `.planning/research/FEATURES.md` - Offline/no-connectivity SOS fallback, no countdown gate before guardian alert, self-cancel as parallel follow-up, competitor context, and direct user-value prioritization.
- `.planning/research/PITFALLS.md` - Pitfall 2: hidden single point of failure in SOS delivery; client/server ack requirements; no false "Sent" state; reconnect/gap-fill guidance; Pitfall 6 for later Duress boundaries.

### Existing Design And UI Contracts
- `SYSTEM_DESIGN (1).md` - SOS flow screens and SOS-red/emergency styling rules.
- `SafePath AI - Standalone (1).html` - Reference UI/state flow for SOS trigger, sent/session state, resilience, and duress references.
- `.planning/phases/01-backend-auth-foundation/01-UI-SPEC.md` - Historical design decision preserving SOS red exclusively for emergency/SOS use.
- `.planning/phases/01-backend-auth-foundation/01-PATTERNS.md` - Mobile design tokens and SafePath UI conventions.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `mobile/lib/features/home/presentation/main_shell.dart` - Existing bottom navigation already has a raised center SOS placeholder. Phase 03 should replace the placeholder behavior with the locked press-and-hold SOS trigger and emergency session flow.
- `mobile/lib/core/theme/app_colors.dart` - `AppColors.sosRed` and `sosRedDeep` exist; red is reserved for SOS/emergency states.
- `mobile/lib/features/location/application/location_controller.dart` - Existing live location bootstrap, self/family state, and hub subscription patterns can inform SOS live-location window behavior, but SOS must not be routed through routine location batching.
- `backend/src/SafePath.Infrastructure/RealTime/LocationHub.cs` - Existing authenticated SignalR hub membership/user identity pattern can inform a dedicated `AlertHub`.
- `backend/src/SafePath.Infrastructure/RealTime/LocationBroadcastService.cs` - Existing user-targeted SignalR fan-out pattern can inform alert delivery, while keeping alert delivery in a dedicated service/pipeline.

### Established Patterns
- Backend follows Clean Architecture: Application owns commands/queries/contracts; Infrastructure owns external providers and SignalR implementations; API maps endpoints/hubs.
- Mobile uses Flutter + Riverpod + go_router, with authenticated-only routes and route guards in `mobile/lib/core/router/app_router.dart`.
- Family-scoped backend reads/writes must use existing membership/role authorization patterns from Phase 1 and Phase 2.
- Privacy/location sharing gates protect routine live-location surfaces, but SOS is a separate emergency bypass path. The bypass must be explicit, auditable, and limited to SOS requirements.

### Integration Points
- Add dedicated backend SOS application commands/entities/services rather than reusing routine location update handlers.
- Add dedicated `AlertHub`/client streams for alert events and responder updates.
- Add mobile sender emergency session and responder emergency screen routes.
- Add FCM integration behind an abstraction so development can use fakes/logging and paid/production pieces can be marked later when appropriate.
- Add `quick_actions` setup in mobile startup/route handling for the first OS-level backup trigger.

</code_context>

<specifics>
## Specific Ideas

- Sender emergency session should be one shell with different states: retrying/not sent, server received, per-recipient/per-channel delivery, canceled, and live-location sharing active.
- Delivery status should be honest and granular: server accepted, SignalR delivered/acknowledged, FCM queued/acknowledged where available, SMS queued/delivered where provider support exists.
- Free/no-cost preference applies across Phase 03. Paid SMS should be abstracted and marked later if no free/testable route exists for the graduation/demo context.
- Local offline fallback actions should include call emergency contact and copy location when available.

</specifics>

<deferred>
## Deferred Ideas

- Automatic direct device-SMS fallback: fast-follow/later because iOS cannot silently send SMS and Android-only behavior would create asymmetric guarantees.
- Android Quick Settings tile: fast-follow/later native Android enhancement.
- iOS Widget/App Intent SOS entry point: fast-follow/later native iOS enhancement.
- Guardian "mark resolved": later incident-lifecycle feature.
- Full incident lifecycle/resolution workflow: later feature after Phase 03 proves the Core Value.
- Silent/Duress implementation: Phase 6 Signature Safety Features, not Phase 03.

</deferred>

---

*Phase: 03-SOS Fast Path*
*Context gathered: 2026-07-24*
