# Phase 03: SOS Fast Path (Core Value) - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md - this log preserves the alternatives considered.

**Date:** 2026-07-24
**Phase:** 03-SOS Fast Path (Core Value)
**Areas discussed:** Trigger UX, Delivery Channels, Offline Retry, Responder Experience, Backup Trigger / OS Shortcut

---

## Trigger UX

| Option | Description | Selected |
|--------|-------------|----------|
| Exact DESIGN-02 hold | 3-second press-and-hold, circular progress ring, release-before-3s cancels | yes |
| Add final confirmation window | Add a second "sending now" or cancel gate after hold completes | no |
| Full-screen emergency session | Dedicated post-send sender screen with delivery/status visibility | yes |
| Banner/bottom sheet | Smaller overlay over current screen | no |
| Cancel as transparent follow-up | User can cancel anytime; guardians see canceled-by-user state | yes |

**User's choice:** Exact DESIGN-02 hold; send immediately after hold; full-screen emergency session; cancel as transparent follow-up.
**Notes:** User cited `.planning/ROADMAP.md`, `.planning/research/FEATURES.md`, and `.planning/research/PITFALLS.md`. The second confirmation gate was rejected because it would delay guardian notification.

---

## Delivery Channels

| Option | Description | Selected |
|--------|-------------|----------|
| All three channels | AlertHub/SignalR + FCM + SMS fallback | yes |
| Single/dual channel only | Reduce delivery paths for simplicity | no |
| Lock Twilio now | Choose Twilio before research | no |
| Research SMS provider first | Prefer free/dev-friendly options, evaluate Twilio/equivalent for production | yes |
| Per-recipient/per-channel status | Show granular delivery/ack state | yes |
| One generic sent checkmark | Collapse delivery state into one status | no |
| Guardians + emergency contacts | Notify active Guardians and configured emergency contacts | yes |
| All family members | Notify every active member except sender | no |

**User's choice:** All three channels; research SMS provider first with free/no-cost preference; per-recipient/per-channel acknowledgments; Guardians plus emergency contacts.
**Notes:** User explicitly set a planning preference: always prefer free options; mark paid pieces as later unless required.

---

## Offline Retry

| Option | Description | Selected |
|--------|-------------|----------|
| Immediate full-screen retrying state | Enter emergency session even when offline | yes |
| Silent waiting | Wait for network without clear UI | no |
| Client-generated session id | Generate/persist idempotent `sosSessionId` on device | yes |
| No idempotency id | Retry may create duplicate server sessions | no |
| Direct device SMS now | Attempt phone-radio SMS from app in initial Phase 03 | no |
| Defer direct device SMS | Keep queue/retry as Phase 03 requirement; mark direct SMS later | yes |
| Retry UI + local actions | Show not-sent-yet, last retry, call/copy-location actions | yes |

**User's choice:** Immediate full-screen retrying state; persisted client-generated `sosSessionId`; defer direct device SMS; show retry status plus local fallback actions.
**Notes:** User highlighted iOS limitations around silent SMS and the need to avoid duplicate emergency sessions.

---

## Responder Experience

| Option | Description | Selected |
|--------|-------------|----------|
| Full-screen responder takeover | Notification/foreground alert lands in dedicated responder screen | yes |
| Dismissible in-app card | Temporary overlay on current screen | no |
| Live-location window with end time | Show fixed stream window and countdown/end time | yes |
| Acknowledge only | Minimal responder action | no |
| Acknowledge + call sender | Scope Phase 03 to immediate response actions | yes |
| Add mark resolved | Full incident lifecycle action | no |
| Canceled badge remains visible | Sender cancellation is explicit on responder screen | yes |

**User's choice:** Full-screen responder screen; explicit live-location window end time; Acknowledge + Call sender only; canceled state remains visible.
**Notes:** Mark-resolved was rejected as incident-lifecycle scope and deferred.

---

## Backup Trigger / OS Shortcut

| Option | Description | Selected |
|--------|-------------|----------|
| `quick_actions` shortcut | Flutter plugin for Android App Shortcuts and iOS Home Screen Quick Actions | yes |
| Android Quick Settings tile | Native Android-only TileService path | later |
| iOS Widget/App Intent | Native iOS-only extension path | later |
| Fire immediately | OS shortcut invocation sends SOS without second hold | yes |
| Repeat 3-second hold | Re-arm after shortcut opens app | no |
| Include Silent/Duress | Build covert/decoy behavior in Phase 03 | no |
| Defer Silent/Duress to Phase 6 | Keep Phase 03 to plain SOS pipeline | yes |

**User's choice:** Use `quick_actions`; fire immediately; keep Silent/Duress in Phase 6.
**Notes:** User cited `quick_actions` as official/maintained under Flutter packages and noted Phase 03 should stay plain/undisguised.

---

## the agent's Discretion

- Implementation details are open as long as they preserve the locked decisions, existing architecture boundaries, and free/no-cost preference.

## Deferred Ideas

- Automatic direct device-SMS fallback.
- Android Quick Settings tile.
- iOS Widget/App Intent SOS entry point.
- Guardian mark-resolved action.
- Full incident lifecycle/resolution workflow.
- Silent/Duress implementation (Phase 6).
