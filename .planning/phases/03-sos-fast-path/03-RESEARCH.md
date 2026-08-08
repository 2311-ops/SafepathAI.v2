# Phase 3: SOS Fast Path (Core Value) - Research

**Researched:** 2026-08-01
**Domain:** Emergency-alert fast path — multi-channel delivery (SignalR + FCM + SMS), offline queue/retry, live-location streaming window, OS-level backup triggers
**Confidence:** MEDIUM (architecture: HIGH, verified directly against this codebase; external providers/plugins: LOW, single-pass WebSearch/WebFetch only — no context7/firecrawl available this session)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Trigger UX**
- D-01: The raised center SOS button MUST follow `DESIGN-02` verbatim: 3-second press-and-hold, circular progress ring, release before 3 seconds cancels.
- D-02: Once the 3-second hold completes, SOS sends immediately. Do not add a second confirmation, countdown, or cancel-before-send gate.
- D-03: After send, route the sender into a full-screen emergency session, not a banner or bottom sheet.
- D-04: The sender's emergency session must show delivery confidence/status, live-location sharing status, and guardian notification state.
- D-05: Self-cancel is a parallel follow-up action. It never delays the original alert and never silently retracts it. Guardians see that SOS was triggered and then canceled by the sender.

**Delivery Channels**
- D-06: Target all three channels from day one: dedicated `AlertHub`/SignalR for active in-app Guardians, FCM push for durable app/background delivery, SMS fallback for configured emergency contacts.
- D-07: Prefer free/no-cost options first. Anything paid must be marked as later unless the phase cannot satisfy a locked requirement without it.
- D-08: SMS provider is not locked. Compare free/dev-friendly options first, then evaluate Twilio or equivalent for production, including .NET SDK maturity, delivery webhook support, cost, and trial availability.
- D-09: The delivery UI must show per-recipient/per-channel state. Do not collapse delivery into one vague checkmark.
- D-10: Do not show confident "Sent" merely because the API call returned, the server accepted a request, or a message was queued.
- D-11: Initial recipients are active Guardians plus configured emergency contacts. Do not notify all active family members by default.

**Offline Retry**
- D-12: If offline at trigger time, enter the same full-screen emergency session immediately with a clear not-sent-yet/retrying state.
- D-13: Generate a client-side `sosSessionId` immediately when the 3-second hold completes, before any network call.
- D-14: Persist the `sosSessionId` locally so app kill/restart resumes the same queued SOS session.
- D-15: Server submissions with the same `sosSessionId` must be idempotent: repeat submissions are no-op/status-check behavior, not duplicate emergencies.
- D-16: Direct device-SMS fallback is deferred to fast-follow/later.
- D-17: Offline sender UI should show "Not sent yet, retrying", last retry time, and local fallback actions (call emergency contact, copy location).

**Responder Experience**
- D-18: Guardian SOS arrival is a full-screen responder experience.
- D-19: FCM notifications deep-link directly into the dedicated SOS responder screen.
- D-20: If a Guardian is actively using the app in the foreground, force-navigate to the same responder screen. Avoid dismissible cards for SOS.
- D-21: The responder screen shows the sender's live location stream for a fixed window with an explicit end time/countdown.
- D-22: Phase 03 responder actions are Acknowledge and Call sender.
- D-23: Do not build Guardian "mark resolved" in Phase 03.
- D-24: If the sender self-cancels, keep the SOS visible with an explicit canceled state. Do not move it immediately to history or hide it.

**Backup Trigger / OS Shortcut**
- D-25: Build the first backup trigger using Flutter's official `quick_actions` plugin.
- D-26: Android Quick Settings tile and iOS Widget/App Intent entry points are fast-follow/later.
- D-27: The backup shortcut fires SOS immediately when invoked. Do not require the 3-second arming hold.
- D-28: Silent/Duress is explicitly out of Phase 03 scope and remains Phase 6.
- D-29: The Phase 03 SOS entity/schema includes a `kind = visible | duress` field from the start (defaulting to/only ever set to `visible` this phase) — schema forward-compat only, authorizes zero duress logic/UI now.

### Claude's Discretion
Implementation details are open as long as they preserve the decisions above, existing Clean Architecture boundaries, existing Riverpod/go_router mobile patterns, and the cost preference for free/no-cost options first.

### Deferred Ideas (OUT OF SCOPE)
- Automatic direct device-SMS fallback.
- Android Quick Settings tile.
- iOS Widget/App Intent SOS entry point.
- Guardian mark-resolved action.
- Full incident lifecycle/resolution workflow.
- Silent/Duress implementation (Phase 6).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SOS-01 | One-tap (press-and-hold) SOS button, bypasses routine/AI pipeline | See Architecture Patterns — dedicated `SosController`/`TriggerSosCommand` path, bypassing `ReportLocationCommand`-style routine handling entirely; confirmed no shared middleware/pipeline exists to bypass in the first place (see Backend Pipeline Isolation finding) |
| SOS-02 | Multi-channel delivery (SignalR + FCM + SMS) with server-side delivery-ack tracking | See Standard Stack, Delivery Acknowledgment Model, SMS Provider Comparison |
| SOS-03 | Offline queue/retry with "not sent yet" state | See Offline Queue & Retry Architecture |
| SOS-04 | Live location streaming to responders for a fixed window | See Live-Location Streaming Window (dedicated `AlertHub`, separate from `LocationHub`) |
| SOS-05 | Parallel, non-blocking self-cancel | See Architecture Patterns — Self-Cancel Pipeline |
| SOS-06 | OS-level backup trigger | See `quick_actions` findings, Common Pitfalls (Android/iOS shortcut landscape) |
| NOTIF-03 | In-app SOS notification | Covered by AlertHub push to Guardian clients + FCM data message |
| DESIGN-02 | SOS button exact spec | Already fully specified in `03-UI-SPEC.md` — this document does not re-derive it, only the trigger-to-backend wiring |
</phase_requirements>

## Summary

Phase 3 is almost entirely new backend/mobile surface area: **no SMS provider, no FCM wiring, no phone-number field anywhere in the schema, no `flutter_foreground_task`/`quick_actions`/`firebase_messaging`/`connectivity_plus` packages are in `pubspec.yaml` yet**, and there is no `EmergencyContact` concept in the domain model at all (verified by reading `backend/src/SafePath.Domain/Entities/`). This is a green-field build inside an otherwise-mature Clean Architecture backend and a mature Riverpod/go_router mobile app — the phase should extend the existing patterns (hand-rolled `ICommandHandler<TCommand,TResult>`, `IHubContext`-based broadcast services, `AsyncNotifier` + hub-client stream subscriptions) rather than introduce new architectural machinery (no MediatR, no BLoC, no state-machine library).

The backend has **no cross-cutting request pipeline at all** — no MediatR, no FluentValidation actually wired up (the package is referenced but unused; validation is inline in handlers), no global logging/behavior decorators. This means "bypass every routine and AI pipeline" is largely already satisfied by the codebase's existing minimalism: a new `TriggerSosCommand`/`SosController` simply needs to avoid calling into `ReportLocationCommandHandler` or any Phase 5 AI-scoring code path, not fight through generic middleware. The one thing to actively avoid is accidentally reusing `ReportLocationCommand`'s low-battery-alert / sharing-preference filtering logic for the SOS path — SOS recipients are Guardians + emergency contacts (D-11), a different (and currently non-existent) recipient set from location-sharing-eligible recipients.

The riskiest unknowns are external, not architectural: (1) there is no fully "free" SMS-to-real-phone provider — Twilio's trial credit (~$15-20, restricted to ≤5 verified numbers) is the most practical zero-dollar-to-start option for a graduation-project demo where guardian/emergency-contact numbers are known in advance; (2) Android side-button/power-button sequence detection and iOS Back Tap have **no first-party Flutter plugin and no true programmatic hook for a third-party app** — `quick_actions` (already locked, D-25) is correctly scoped as the only Phase 3 OS-shortcut mechanism, and any power-button/Back-Tap path would be Phase-later native work with real Play Store/App Store policy risk; (3) FCM and SignalR both only confirm "accepted for delivery," never true on-device receipt, without an explicit client callback — this directly shapes the per-channel/per-recipient status model already locked in `03-UI-SPEC.md`.

**Primary recommendation:** Build a new `Sos` bounded context (`SosSession`, `SosDeliveryAttempt` entities; `TriggerSosCommand`, `CancelSosCommand`, `AcknowledgeSosCommand`, `GetSosSessionQuery` handlers; dedicated `AlertHub`) that is structurally isolated from `LocationHub`/`ReportLocationCommand`, add a minimal `EmergencyContact` entity + phone-number field (this does not exist yet and blocks SOS-02/SOS-03's "call/SMS" paths entirely), wire `firebase_messaging` + `quick_actions` + `connectivity_plus` on mobile (none currently installed), and gate SMS behind an `ISmsGateway` abstraction with a free `LoggingSmsGateway` for dev and a Twilio-backed implementation (trial-credit, verified-numbers) for the demo — satisfying D-07/D-08 without introducing a real recurring cost.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| SOS trigger arm/hold UI, `sosSessionId` generation, local persistence | Browser/Client (Flutter) | — | Must work fully offline (D-12, D-13, D-14); client owns the idempotency key before any network call exists |
| SOS command handling, recipient resolution, delivery orchestration | API/Backend (ASP.NET Core) | — | Single source of truth for who gets alerted and via which channels; must be reachable via a plain authenticated REST call (works even if the SignalR socket is down) |
| In-app real-time alert delivery + live-location streaming | API/Backend (SignalR `AlertHub`) | Browser/Client (subscriber) | Lowest-latency channel for already-connected Guardians; server is authoritative for the streaming window's start/end time |
| Durable background/app-closed delivery | API/Backend (FCM send) | Browser/Client (FCM receive + deep-link) | FCM is Google's infrastructure for reaching a backgrounded/closed app; server only gets "accepted," client must report receipt back |
| SMS fallback to non-app emergency contacts | API/Backend (SMS gateway abstraction) | — | Emergency contacts are not assumed to have the app installed; only the backend can reach an arbitrary phone number |
| Delivery/ack state persistence (per-recipient, per-channel) | Database/Storage (Postgres) | API/Backend (read model) | D-09 requires this to be queryable, not held only in memory/SignalR group state |
| Offline queue & retry | Browser/Client (Flutter local persistence + retry loop) | — | The whole point of SOS-03 is that the client must function with zero connectivity; server has nothing to do until connectivity resumes |
| OS-level backup trigger (`quick_actions`) | Browser/Client (native shortcut registration) | — | Home-screen/app-shortcut registration is inherently an OS/client-level integration; it re-enters the same client trigger path as the in-app button (D-27, skipping the arm hold) |

## Standard Stack

### Core

| Library | Version (verified) | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `firebase_core` + `firebase_messaging` | `firebase_messaging: 16.4.3` (pub.dev, published 18 days ago) [ASSUMED — WebFetch, LOW confidence per this session's provider tier; matches CLAUDE.md's 16.4.x pin] | FCM push delivery to Guardians (durable, app-backgrounded/closed) | Official Firebase Flutter plugin; already specified in CLAUDE.md's fixed stack; **not currently in `pubspec.yaml`** — must be added this phase |
| `quick_actions` | `1.1.0` (pub.dev, published ~19 months ago) [ASSUMED — WebFetch, LOW confidence] | OS-level backup SOS trigger (D-25) — Android App Shortcuts + iOS Home Screen Quick Actions, one Dart API | Already the user's locked D-25 decision; official `flutter.dev`-published package (part of the `flutter/packages` monorepo) — infrequent releases reflect a stable/finished API surface, not abandonment |
| `connectivity_plus` | `7.3.1` (pub.dev, published 8 days ago) [ASSUMED — WebFetch, LOW confidence] | Detects "no network interface" state to drive the offline/queued UI branch (D-12) | De-facto standard Flutter connectivity plugin (`fluttercommunity.dev` publisher); **not currently in `pubspec.yaml`** |
| Twilio (`Twilio` NuGet) | `7.14.9` (NuGet, published 2026-05-07, 131.8M total downloads) [ASSUMED — WebFetch, LOW confidence] | SMS fallback delivery to emergency contacts (D-08) | Most mature .NET SDK + delivery-status-webhook (`SmsStatusCallbackRequest`) support among the three compared providers; free trial credit (~$15-20) is usable at zero cost for the graduation-demo scope once recipient numbers are pre-verified |
| Existing `signalr_netcore` (already in `pubspec.yaml`) | `1.4.4` (already approved/retained per `STATE.md` [Phase 02-01] package-legitimacy review) [VERIFIED: codebase / prior phase decision] | Client for the new `AlertHub` (reuse the existing hub-client pattern from `location_hub_client.dart`) | Already vetted in Phase 2; do not introduce a second SignalR client package |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `shared_preferences` (already in `mobile/pubspec.lock`, transitively available) [VERIFIED: codebase] | current locked | Persist `sosSessionId` + last-known offline SOS payload locally (D-14) | Simplest option already present in the dependency tree — no new package needed for this specific persistence need (a single string + small JSON blob), avoiding `hive`/`sqflite`/`isar` overhead for a single-key value |
| `flutter_local_notifications` (per CLAUDE.md fixed stack; not yet in `pubspec.yaml` — verify before assuming) | current stable | Local-notification fallback so a Guardian sees an SOS alert even if FCM delivery is delayed | Pair with FCM per CLAUDE.md's belt-and-braces guidance; needed for NOTIF-03's in-app notification path when the app is backgrounded |
| `flutter_foreground_task` | `10.0.0` (pub.dev, published 17 days ago — **ahead of CLAUDE.md's cited 9.2.x**) [ASSUMED — WebFetch, LOW confidence] | NOT required to trigger SOS itself, but relevant if the live-location streaming window (SOS-04) needs to keep sending position updates while the app is backgrounded during the streaming window | Only add if the live-location window must survive app backgrounding; if the SOS session is expected to be a foreground, full-screen experience for the sender throughout the window (per D-03/D-04), this may not be needed for Phase 3 — flag as an open question below |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Twilio (SMS) | Vonage | Cheaper free credit (€2 vs ~$15-20) [ASSUMED, LOW confidence] and free delivery receipts, but less .NET/ASP.NET Core-specific documentation was found in this session's research — higher integration-time risk for a solo-dev timeline |
| Twilio (SMS) | Azure Communication Services | Would consolidate billing under the project's existing Azure hosting account, but no comparably generous free-trial credit was found, and requires toll-free/10DLC number registration overhead in the US market — worse fit for a fast MVP demo |
| Hand-rolled `ICommandHandler<T,R>` (existing pattern) | MediatR | Already explicitly rejected in Phase 1 (see `ICommandHandler.cs` doc comment: avoids MediatR v13+'s commercial license-key requirement) — Phase 3 must continue the existing pattern, not introduce MediatR |
| New `AlertHub` (dedicated) | Extend `LocationHub` with alert methods | Rejected — mixing SOS and routine-location hub traffic on one hub contradicts the "isolated fast path" non-negotiable and makes SOS message delivery dependent on the same connection-group logic as routine location broadcast |

**Installation:**
```bash
# Mobile (Flutter)
flutter pub add firebase_core firebase_messaging quick_actions connectivity_plus flutter_local_notifications

# Backend (.NET) — actual installed TargetFramework is net9.0, NOT net10.0 (see Project Constraints)
dotnet add backend/src/SafePath.Infrastructure package Twilio
```

**Version verification:** Versions above were checked via direct `WebFetch` of pub.dev/NuGet package pages on 2026-08-01 (this session). No `context7`/`firecrawl` MCP provider was available this session (both disabled in `.planning/config.json`), so all external package facts in this document carry the seam's `LOW` confidence tier (`websearch`/`webfetch` both classify as LOW per `gsd-tools query classify-confidence`) — re-verify exact versions at install time with `flutter pub outdated` / `dotnet list package --outdated` rather than trusting these pinned numbers blindly.

## Package Legitimacy Audit

> The automated `gsd-tools query package-legitimacy check` seam only supports `npm|pypi|crates` ecosystems. This phase's new packages are `pub.dev` (Flutter/Dart) and `NuGet` (.NET) — **outside the seam's coverage**. The table below is a manual audit using pub.dev/NuGet page metadata gathered this session; treat all rows as `[ASSUMED]`, not seam-`[OK]`-verified, and the planner should still gate first-install of each with a `checkpoint:human-verify` task per the package-legitimacy protocol's spirit.

| Package | Registry | Age / Publish Date | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| `firebase_messaging` | pub.dev | 16.4.3, 18 days old | high (official Firebase Flutter plugin, millions of likes/pub-points historically) | `github.com/firebase/flutterfire` | OK (manual) | Approved |
| `quick_actions` | pub.dev | 1.1.0, ~19 months old | official `flutter.dev` publisher | `github.com/flutter/packages` | OK (manual) | Approved |
| `connectivity_plus` | pub.dev | 7.3.1, 8 days old | official `fluttercommunity.dev` publisher, widely used | `github.com/fluttercommunity/plus_plugins` | OK (manual) | Approved |
| `flutter_local_notifications` | pub.dev | not version-checked this session — verify before install | de-facto standard, long-established | `github.com/MaikuB/flutter_local_notifications` | Not checked | Verify at plan time |
| `flutter_foreground_task` | pub.dev | 10.0.0, 17 days old | widely used in Flutter background-location community, already named in CLAUDE.md's fixed stack | not confirmed this session | Not checked (only needed if backgrounded live-location streaming is required — see Open Questions) | Verify at plan time if adopted |
| `Twilio` (NuGet) | NuGet | 7.14.9, published 2026-05-07 | 131.8M total downloads (very high) | `github.com/twilio/twilio-csharp` | OK (manual) | Approved |

**Packages removed due to [SLOP] verdict:** none — no hallucinated/fabricated package names were found; all names above match this project's own CLAUDE.md stack doc or the user's own locked decisions (D-25 names `quick_actions` explicitly).
**Packages flagged as suspicious [SUS]:** none via manual review, but because the automated seam cannot cover `pub.dev`/`NuGet`, the planner should still insert one `checkpoint:human-verify` before the first `flutter pub add` / `dotnet add package` batch as a defense-in-depth step, per this project's general caution around unverified-ecosystem installs.

## Architecture Patterns

### System Architecture Diagram

```
                      ┌─────────────────────────────────────────────┐
                      │              Flutter Mobile App               │
                      │                                                │
  Home-screen shortcut│  ┌──────────┐   3s hold    ┌────────────────┐ │
  (quick_actions) ───►│  │SOS Button│─────────────►│ generate         │ │
  (D-25, D-27,        │  │(main_    │  release<3s  │ sosSessionId     │ │
  skips hold)         │  │ shell)   │  = cancel     │ (client-side,    │ │
                      │  └──────────┘               │ before network) │ │
                      │                              └────────┬───────┘ │
                      │                                        ▼        │
                      │                          ┌──────────────────────┴┐
                      │                          │ Persist sosSessionId  │
                      │                          │ locally (shared_prefs)│
                      │                          │ (D-14 — survives kill)│
                      │                          └──────────┬─────────────┘
                      │                                     ▼
                      │                     ┌───────────────────────────────┐
                      │       online? ──no──►│ Offline queue + retry loop    │
                      │          │            │ (connectivity_plus signal +  │
                      │          yes           │ actual-call-failure driven) │
                      │          ▼             └───────────────┬───────────┘
                      │  ┌───────────────┐                     │ (network resumes)
                      │  │ POST /sos/     │◄────────────────────┘
                      │  │ trigger        │  idempotent on sosSessionId (D-15)
                      │  │ {sosSessionId} │
                      │  └───────┬────────┘
                      │          │  AlertHub client subscribes for
                      │          │  live delivery/ack + location-window events
                      └──────────┼────────────────────────────────────────────┘
                                 ▼
      ┌───────────────────────────────────────────────────────────────────────┐
      │                      ASP.NET Core Backend (net9.0)                      │
      │                                                                          │
      │  SosController.Trigger ──► TriggerSosCommandHandler (ICommandHandler)   │
      │      │                          │                                        │
      │      │                          ├─► Idempotency check (sosSessionId)     │
      │      │                          ├─► Resolve recipients: active Guardians │
      │      │                          │      + EmergencyContact rows (D-11)    │
      │      │                          ├─► Persist SosSession + one             │
      │      │                          │      SosDeliveryAttempt row per        │
      │      │                          │      (recipient, channel) pair         │
      │      │                          │                                        │
      │      │                          ▼                                        │
      │      │              ┌───────────────────────────────┐                   │
      │      │              │  Fan out in parallel:          │                   │
      │      │              │  1. AlertHub → in-app Guardians │                   │
      │      │              │  2. FCM send → all Guardians'   │                   │
      │      │              │     device tokens (durable)     │                   │
      │      │              │  3. ISmsGateway → EmergencyContact│                  │
      │      │              │     phone numbers (Twilio)       │                   │
      │      │              └───────────────┬───────────────┘                   │
      │      │                              ▼                                    │
      │      │              Each channel updates its own                        │
      │      │              SosDeliveryAttempt row's status                     │
      │      │              (queued → delivered → acknowledged)                 │
      │      │                                                                   │
      │      └─► never calls ReportLocationCommandHandler / any AI scoring path  │
      │           (structural isolation from the routine pipeline)               │
      └───────────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼ AlertHub push (deep-link on FCM tap)
      ┌───────────────────────────────────────────────────────────────────────┐
      │                Guardian's Flutter App — Responder Screen                │
      │  force-navigated regardless of foreground state (D-20)                  │
      │  Acknowledge ──► POST /sos/{id}/acknowledge ──► SosDeliveryAttempt row   │
      │  Call sender  ──► native tel: intent (client-only, no server round trip)│
      └───────────────────────────────────────────────────────────────────────┘
```

### Recommended Project Structure

**Backend (mirrors existing `Location`/`Families` module layout):**
```
backend/src/SafePath.Domain/Entities/
├── SosSession.cs              # sosSessionId (client-issued Guid), kind=visible|duress (D-29), status, timestamps
├── SosDeliveryAttempt.cs      # one row per (SosSessionId, RecipientUserId|EmergencyContactId, Channel)
└── EmergencyContact.cs        # NEW entity — does not exist yet; Name, PhoneNumber, OwnerUserId/FamilyId

backend/src/SafePath.Application/Sos/
├── TriggerSosCommand.cs       # idempotent on sosSessionId, resolves recipients, persists, fans out
├── CancelSosCommand.cs        # parallel, non-blocking (D-05) — never awaited by the trigger path
├── AcknowledgeSosCommand.cs   # Guardian-only, sets SosDeliveryAttempt.Acknowledged
├── GetSosSessionQuery.cs      # polling/status-check fallback for offline-resume idempotency (D-15)
└── SosDtos.cs

backend/src/SafePath.Infrastructure/RealTime/
├── AlertHub.cs                 # NEW — dedicated hub, separate from LocationHub
├── IAlertClient.cs             # strongly-typed hub interface (SosTriggered, DeliveryStatusChanged, SosCanceled)
└── AlertBroadcastService.cs    # NEW — mirrors LocationBroadcastService's IHubContext pattern

backend/src/SafePath.Infrastructure/Sms/
├── ISmsGateway.cs               # Application-layer interface
├── TwilioSmsGateway.cs          # production implementation
└── LoggingSmsGateway.cs         # free, no-op dev implementation (D-07)

backend/src/SafePath.Api/Controllers/
└── SosController.cs             # POST /sos/trigger, POST /sos/{id}/cancel, POST /sos/{id}/acknowledge, GET /sos/{id}
```

**Mobile (mirrors existing `location`/`family` feature layout):**
```
mobile/lib/features/sos/
├── application/
│   ├── sos_controller.dart          # AsyncNotifier — arm state, session state machine, AlertHub subscription
│   └── sos_session_state.dart       # sealed union: offlineQueued | submitted | delivering | liveActive | canceled
├── data/
│   ├── sos_api.dart                  # POST /sos/trigger (Dio), idempotent retry wrapper
│   ├── sos_hub_client.dart           # signalr_netcore client for AlertHub (mirrors location_hub_client.dart)
│   └── sos_local_store.dart          # shared_preferences-backed sosSessionId persistence (D-14)
└── presentation/
    ├── sender_emergency_session_screen.dart
    └── responder_alert_screen.dart

mobile/lib/core/os_shortcuts/
└── quick_actions_service.dart        # registers the SOS quick action at app startup, wires invocation to sos_controller
```

### Pattern 1: Backend Pipeline Isolation (satisfies "bypass every routine/AI pipeline")
**What:** `Program.cs` has no MediatR pipeline, no global validation/logging behaviors — only standard ASP.NET Core middleware (HTTPS redirect, rate limiter, CORS, auth). [VERIFIED: codebase, `backend/src/SafePath.Api/Program.cs`]
**When to use:** Confirms the SOS non-negotiable is structurally satisfied by *not adding* any new global middleware/decorator that would apply to `SosController` — do not wrap `TriggerSosCommand` in a generic "all commands get validated/logged the same way" behavior pipeline, even if one is later introduced for other Phase 4/5 commands.
**Example:**
```csharp
// Source: backend/src/SafePath.Api/Controllers/LocationController.cs (existing pattern to mirror)
[ApiController]
[Authorize]
public class SosController : ControllerBase
{
    private readonly ICommandHandler<TriggerSosCommand, TriggerSosResult> _trigger;
    // ... same constructor-injection + try/catch FamilyAuthorizationDeniedException pattern
}
```
**Anti-pattern to avoid:** Do NOT add rate limiting to the SOS trigger endpoint using the existing `invite-redeem` fixed-window policy (10/min per IP) — an SOS retry loop (D-17) legitimately needs to retry more aggressively than that, and a false-alarm-prone rate limit on the one endpoint that must "always work" is a direct contradiction of the Core Value. If any rate limiting is added at all, it must be scoped per-`sosSessionId`/per-authenticated-user, generous, and fail-open (never silently drop a genuine retry).

### Pattern 2: Idempotent Command via Client-Generated ID
**What:** The client generates `sosSessionId` (a GUID) before any network call (D-13); the server's `TriggerSosCommandHandler` treats repeat submissions of the same ID as a no-op/status-check, not a new emergency (D-15).
**When to use:** Standard pattern for offline-tolerant mutation commands — check-then-act inside a single transaction (`SELECT ... FOR UPDATE`-equivalent via EF Core's tracked-entity semantics, or a unique constraint on `SosSession.Id` with a catch-and-return-existing-row on conflict).
**Example:**
```csharp
public async Task<TriggerSosResult> Handle(TriggerSosCommand command, CancellationToken ct)
{
    var existing = await _db.SosSessions.FindAsync(new object[] { command.SosSessionId }, ct);
    if (existing is not null)
    {
        // Idempotent replay: do not re-resolve recipients or re-fan-out; return current status.
        return TriggerSosResult.FromExisting(existing);
    }
    // ... create new SosSession + fan out
}
```

### Pattern 3: Per-Recipient/Per-Channel Delivery State (satisfies D-09, D-10)
**What:** One `SosDeliveryAttempt` row per (recipient, channel) pair, with a small fixed status enum (`NotAttempted`, `Queued`, `Delivered`, `Acknowledged`, `Failed`) — matching the 4-state vocabulary already locked in `03-UI-SPEC.md`.
**When to use:** Whenever a channel's send is attempted; never collapse multiple channels into one boolean "sent" flag on `SosSession` itself.
**Example:**
```csharp
public class SosDeliveryAttempt
{
    public Guid Id { get; set; }
    public Guid SosSessionId { get; set; }
    public Guid? RecipientUserId { get; set; }        // null for pure-SMS-only emergency contacts
    public Guid? EmergencyContactId { get; set; }      // null for in-app Guardians
    public AlertChannel Channel { get; set; }           // SignalR | Fcm | Sms
    public DeliveryStatus Status { get; set; }
    public DateTime? DeliveredAtUtc { get; set; }
    public DateTime? AcknowledgedAtUtc { get; set; }
}
```
**Never infer "Sent" from a bare API-accepted response** — this applies to all three channels: SignalR's `SendAsync` returning does not mean the client received it; FCM's send API only confirms FCM accepted the message (see Common Pitfalls); Twilio's send call only confirms Twilio queued it (the delivery webhook is the actual confirmation).

### Anti-Patterns to Avoid
- **Reusing `ReportLocationCommandHandler`'s sharing/recipient-filtering logic for SOS:** SOS recipients are Guardians + emergency contacts (D-11), a fundamentally different and currently-nonexistent recipient resolution query — do not filter SOS recipients through `ISharingAuthorizationService`'s `SharedDataType.LiveLocation` privacy gate, which exists to *restrict* routine location visibility, not to gate an emergency alert.
- **Building a "generic notification service" that both SOS and NOTIF-01/02/04 share as one code path:** the SOS bypass requirement means SOS's fan-out logic should be its own dedicated service (`AlertBroadcastService`), even if it superficially resembles `LocationBroadcastService` — a shared abstraction here risks a future NOTIF-04 (inactivity alert) change accidentally slowing down or gating the SOS path.
- **Treating `connectivity_plus`'s connectivity signal as ground truth for "can reach the server":** it only reports network-interface state, not actual reachability (see Standard Stack note) — drive the offline/retrying UI state primarily off the actual HTTP call's success/failure/timeout, using `connectivity_plus` only as a secondary hint for retry backoff timing.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SMS delivery to phone numbers | A raw SMTP-to-SMS-gateway hack or carrier-specific email-to-SMS bridge | Twilio (via `ISmsGateway` abstraction) | Carrier email-to-SMS gateways are unreliable, undocumented per-carrier, and have no delivery acknowledgment — directly violates D-09/D-10's per-channel status requirement |
| Home-screen/App-shortcut OS integration | Custom native Android `ShortcutManager`/iOS `UIApplicationShortcutItem` code per-platform | `quick_actions` (already locked, D-25) | One Dart API instead of two native implementations; already the user's decision |
| Phone number validation/formatting for SMS + `EmergencyContact` entry | A hand-rolled regex for "is this a phone number" | A vetted phone-number library (e.g. `libphonenumber`-based package on both the Flutter and .NET sides — verify exact package name/version at plan time, not assumed here) | International phone number formats are a well-known "deceptively simple" problem (country codes, extensions, formatting) — a naive regex will reject or mis-store valid numbers, silently breaking SMS delivery for some emergency contacts |
| Push-notification delivery confirmation | Trusting FCM's send-response as "delivered" | An explicit client → server "I received this SOS push" callback, recorded against the matching `SosDeliveryAttempt` row | FCM's API contract only ever confirms server-side acceptance, never device receipt (see Common Pitfalls) — building a false "delivered" state around FCM's response is the exact anti-pattern D-10 forbids |
| Offline retry scheduling | A bespoke exponential-backoff timer implemented from scratch inside `SosController`/mobile app lifecycle callbacks | A small, explicit `Timer.periodic`-driven retry loop scoped to the SOS session's own state (client) + idempotent retries hitting the same endpoint (server) — this is simple enough that no external library is needed, but the *idempotency* (D-15), not the retry loop itself, is the part that must not be improvised ad hoc per call site | The risk is not "retry logic is hard," it's "an accidentally-non-idempotent retry creates a duplicate emergency" — keep the idempotency check in one place (`TriggerSosCommandHandler`), not duplicated across every retry call site |

**Key insight:** Every "don't hand-roll" item above maps to a place where a shortcut would silently violate one of the phase's locked D-09/D-10/D-15 decisions, not just introduce generic technical debt — the review focus for this phase should specifically probe "can this show a false positive delivery/ack state?" and "can this create a duplicate SOS session?"

## Runtime State Inventory

Not applicable — Phase 3 is new-feature construction (green-field `Sos`/`EmergencyContact`/`AlertHub` surface), not a rename/refactor/migration phase. No existing runtime state, stored data, live service config, secrets, or build artifacts reference the strings/entities this phase introduces.

## Common Pitfalls

### Pitfall 1: Treating FCM/SignalR "send succeeded" as "alert delivered"
**What goes wrong:** The UI shows "Delivered" or even "Sent" the moment the backend's outbound call to FCM/the SignalR hub returns without error.
**Why it happens:** Both APIs are designed to confirm *acceptance*, not *device receipt* — FCM returns a message ID meaning "FCM has queued this," and `IHubContext.Clients.User(...).SendAsync(...)` returning does not mean the specific client actually processed the message (the user might be disconnected and the send silently no-ops, or the connection might drop mid-send).
**How to avoid:** Model "Delivered" only from an explicit signal: for SignalR, treat delivery as confirmed only once the client hub method fires back (or, at minimum, once `PresenceTracker`/connection-group membership confirms the target was actually connected at send time); for FCM, require a client → server receipt callback before marking `Delivered`, matching the D-09/D-10 vocabulary already locked in `03-UI-SPEC.md` (Not yet attempted / Queued / Delivered / Acknowledged).
**Warning signs:** Any code path that sets `DeliveryStatus.Delivered` synchronously inside the same handler that called `SendAsync`/FCM's send API, with no callback or client-confirmation step in between.

### Pitfall 2: No `EmergencyContact`/phone-number data model exists yet
**What goes wrong:** Planning assumes "SMS fallback to emergency contacts" is just a wiring task, when in fact there is currently nowhere in the schema to even store a phone number — not on `User`, not on `FamilyMember`, nowhere. [VERIFIED: codebase — `backend/src/SafePath.Domain/Entities/User.cs` and `FamilyMember.cs` read in full this session, no phone field exists anywhere]
**Why it happens:** Phase 1/2 never needed phone numbers (auth is Supabase email/OAuth-based); the SOS phase is the first to need this data.
**How to avoid:** Add a minimal `EmergencyContact` entity (Name, PhoneNumber, OwnerUserId or FamilyId, IsActive) plus a small management surface — see Open Questions below for the UI-SPEC scope gap this creates. Do not silently assume Guardian users have phone numbers; if SMS should also reach Guardians directly (not just non-app emergency contacts), a phone-number field needs to be added to the `User`/`FamilyMember` model too, which is a bigger schema change than just adding a new `EmergencyContact` table.
**Warning signs:** Any plan task that says "send SMS to Guardian" without first confirming where that Guardian's phone number is stored.

### Pitfall 3: Android/iOS OS-level backup triggers beyond `quick_actions` have no clean path
**What goes wrong:** A future phase (or an over-eager Phase 3 task) attempts to implement "side-button sequence" or "Back Tap" as if a mature cross-platform plugin exists for either.
**Why it happens:** These *sound* like they should be simple OS features, but: Android routes hardware key events only to the foreground Activity (background apps cannot intercept the power button at all on modern Android; AccessibilityService can, but is a Play Store policy-risk path per Google's Oct 2021 accessibility-misuse policy — general automation/shortcut use is explicitly disallowed); iOS Back Tap has **no third-party-app-facing programmatic API whatsoever** — it is configured entirely through iOS Settings + the user manually assigning a Siri Shortcut, which the app cannot silently pre-wire. [ASSUMED, LOW confidence — WebSearch only this session; re-verify against current Apple/Google developer docs before any Phase-later implementation]
**How to avoid:** Phase 3 correctly scopes to `quick_actions` only (D-25) and defers everything else (D-26); do not let scope creep pull side-button/Back-Tap detection into this phase even as a "quick add" — both would require substantial native (Kotlin/Swift) code and carry real app-store-policy risk that needs its own dedicated research/review pass.
**Warning signs:** Any task description mentioning "power button" or "Back Tap" detection inside Phase 3's plan files.

### Pitfall 4: Applying an existing restrictive rate-limit policy to the SOS endpoint
**What goes wrong:** A well-intentioned "consistency" pass applies the existing `invite-redeem` rate-limit policy (10 requests/min per IP, `RejectionStatusCode = 429`) to `SosController`, since it is the only precedent for rate limiting in this codebase. [VERIFIED: codebase, `backend/src/SafePath.Api/Program.cs`]
**Why it happens:** Copy-paste consistency with existing patterns without considering that SOS retry traffic (D-17: aggressive retry while offline/unconfirmed) is a fundamentally different traffic shape than invite-code brute-force prevention.
**How to avoid:** If any rate limiting is added to the SOS endpoints at all, it must be scoped per-authenticated-user/per-`sosSessionId`, generous enough to never block a legitimate retry storm, and must fail open (reject-with-429 is never acceptable behavior for the one endpoint that must "always work").
**Warning signs:** `[EnableRateLimiting("invite-redeem")]` or any shared rate-limit policy attribute appearing on `SosController`.

### Pitfall 5: `.NET 10` assumed by CLAUDE.md's stack doc vs. `.NET 9.0` actually running
**What goes wrong:** A plan or task assumes .NET 10/EF Core 10-only APIs are available, based on CLAUDE.md's "Recommended Stack" table.
**Why it happens:** CLAUDE.md's stack table is aspirational/project-wide guidance written independently of what was actually scaffolded; the actual solution (`backend/src/*/*.csproj`) targets `net9.0` throughout, with `Microsoft.EntityFrameworkCore 9.0.9` and `Npgsql.EntityFrameworkCore.PostgreSQL 9.0.4`. [VERIFIED: codebase, all four `.csproj` files under `backend/src/` read this session]
**How to avoid:** Phase 3 must target `net9.0` to match the existing, already-building solution — do not introduce `net10.0`-only SignalR/EF Core APIs (e.g., anything documented as ".NET 10 only" in the SignalR stateful-reconnect docs) without a separate, explicit upgrade decision outside this phase's scope.
**Warning signs:** Any new `.csproj` or code referencing a .NET 10-specific API without first confirming it also exists in .NET 9.

## Code Examples

### Idempotent SOS trigger (backend)
```csharp
// Source: pattern adapted from backend/src/SafePath.Application/Location/ReportLocationCommand.cs
// (existing ICommandHandler + inline validation convention — no FluentValidation is actually wired up
// in this codebase despite the package reference existing in SafePath.Application.csproj)
public record TriggerSosCommand(Guid SosSessionId, Guid CallerUserId, Guid FamilyId, double Latitude, double Longitude, DateTime TriggeredAtUtc);

public class TriggerSosCommandHandler : ICommandHandler<TriggerSosCommand, TriggerSosResult>
{
    public async Task<TriggerSosResult> Handle(TriggerSosCommand command, CancellationToken ct = default)
    {
        var existing = await _db.SosSessions.FindAsync(new object[] { command.SosSessionId }, ct);
        if (existing is not null)
        {
            return TriggerSosResult.FromExisting(existing); // D-15: idempotent replay, not a new emergency
        }

        await _authorization.RequireMembership(command.CallerUserId, command.FamilyId, ct);

        var session = new SosSession
        {
            Id = command.SosSessionId, // client-generated (D-13)
            FamilyId = command.FamilyId,
            TriggeredByUserId = command.CallerUserId,
            Kind = SosKind.Visible, // D-29 — schema field exists, only ever "visible" this phase
            TriggeredAtUtc = command.TriggeredAtUtc,
        };
        _db.SosSessions.Add(session);

        var recipients = await ResolveSosRecipients(command.FamilyId, command.CallerUserId, ct); // Guardians + EmergencyContacts (D-11)
        foreach (var recipient in recipients)
        {
            _db.SosDeliveryAttempts.AddRange(BuildAttemptsForRecipient(session.Id, recipient));
        }
        await _db.SaveChangesAsync(ct);

        // Fan out AFTER persisting — never let a slow SMS/FCM call delay the DB commit that the
        // idempotency check depends on.
        _ = _alertFanOut.DispatchAsync(session.Id, recipients, ct); // fire-and-forget-with-tracking, not awaited inline

        return TriggerSosResult.FromNew(session);
    }
}
```

### Strongly-typed `AlertHub` client interface (mirrors existing `ILocationClient`)
```csharp
// Source: pattern from backend/src/SafePath.Infrastructure/RealTime/ILocationClient.cs (existing file, read this session for shape reference)
public interface IAlertClient
{
    Task SosTriggered(SosTriggeredDto dto);
    Task DeliveryStatusChanged(SosDeliveryStatusDto dto);
    Task SosCanceled(SosCanceledDto dto);
    Task LiveLocationWindowUpdate(SosLocationUpdateDto dto);
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|---------------|--------|
| Assuming FCM/APNs delivery = confirmed | Explicit client-side receipt callback required for true delivery confirmation | Ongoing industry practice, not a recent change — flagged here because it's easy to miss, not because it's new | Directly shapes the `SosDeliveryAttempt` status model (D-09/D-10) |
| Foreground-service polling for background work on Android | Native OS APIs (Geofencing API, `AccessibilityService` restrictions tightened) | Google Play policy update, April 15, 2026 (per CLAUDE.md, already documented for Phase 4 geofencing) [CITED: CLAUDE.md's own Sources section] | Reinforces why an `AccessibilityService`-based SOS shortcut (side-button detection) is policy-risky, not just technically hard — same regulatory direction applies |

**Deprecated/outdated:** None specific to this phase's exact stack — the packages/patterns above are current as of this session's checks (2026-08-01), all flagged `[ASSUMED]`/LOW confidence per the provider tier available this session.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `firebase_messaging` latest is 16.4.3, `quick_actions` latest is 1.1.0, `connectivity_plus` latest is 7.3.1, `flutter_foreground_task` latest is 10.0.0 | Standard Stack | Low-medium — pin exact versions via `flutter pub add` at plan/execute time rather than hardcoding these numbers into a plan file; a stale version pin causes a build-time error, not a silent bug |
| A2 | Twilio NuGet `7.14.9` is current, and Twilio's free trial credit (~$15-20, ≤5 verified numbers) remains the practical zero-cost SMS option vs. Vonage/Azure Communication Services | Standard Stack, Alternatives Considered | Medium — if Twilio's trial terms have changed or a cheaper/more-.NET-friendly alternative has since emerged, this recommendation should be re-confirmed before committing to the provider; the D-08 decision explicitly asks for this comparison, so treat this as the input to a plan-time decision, not a locked choice |
| A3 | Android power-button/side-button sequences and iOS Back Tap have no mature third-party-app-facing API/Flutter plugin | Common Pitfalls, Don't Hand-Roll | Medium — if a plugin or new platform API has shipped since this session's WebSearch, the "defer to Phase-later" recommendation could be revisited; low risk of harm either way since D-26 already defers these regardless |
| A4 | `flutter_foreground_task` is not strictly required for Phase 3's live-location streaming window (SOS-04) if the sender stays in the full-screen emergency session throughout | Standard Stack (Supporting) | Medium — if the phase later requires the streaming window to survive the sender backgrounding the app, this package becomes required; flagged explicitly as an Open Question below rather than silently assumed either way |
| A5 | ASP.NET Core SignalR has no application-level per-message ACK primitive beyond "stateful reconnect" (transport-level, .NET 8+) | Architecture Patterns, Common Pitfalls | Low — this shapes the recommendation to build an explicit `SosDeliveryAttempt` ack model rather than relying on a SignalR built-in; even if a newer SignalR version added more, the explicit-ack-row pattern remains correct and is not harmed by being "extra safe" |

**If this table is empty:** N/A — see rows above; all external-provider/plugin claims in this document are `[ASSUMED]` per this session's LOW-confidence provider tier (no `context7`/`firecrawl` access). Architecture claims about *this specific codebase* (backend pipeline shape, missing `EmergencyContact` entity, actual `.NET 9.0` target, existing package versions in `pubspec.yaml`/`pubspec.lock`) are `[VERIFIED: codebase]`, not assumed — those were confirmed by directly reading the relevant files this session.

## Open Questions

1. **Where does emergency-contact/phone-number data get entered? (`EmergencyContact` UI is not in `03-UI-SPEC.md`'s scope)**
   - What we know: `03-UI-SPEC.md` explicitly scopes to "the always-visible bottom-nav SOS button... the sender's full-screen Emergency Session... the Guardian's full-screen Responder Alert screen... and the `quick_actions` OS-level backup trigger's UI implications" — no "manage emergency contacts" or "add phone number" screen is described, and no phone-number field exists anywhere in the current schema (`User`, `FamilyMember`) [VERIFIED: codebase].
   - What's unclear: SOS-02/D-11 require SMS delivery to "configured emergency contacts," which is impossible without at least one minimal data-entry surface (even a single-field form) for a name + phone number.
   - Recommendation: The planner should add a minimal `EmergencyContact` CRUD surface (likely under the existing `profile` or `family` feature module, following the existing `ProfileController`/`PrivacyController` pattern) as an in-scope Phase 3 task — this is infrastructure the phase cannot function without, even though the UI-SPEC's screen list doesn't enumerate it. Flag this back to the UI-SPEC owner if a dedicated visual spec is wanted before building it; otherwise treat it as a plain, unstyled-beyond-existing-theme settings form.

2. **Does the live-location streaming window (SOS-04) need to survive the sender backgrounding the app?**
   - What we know: D-03/D-04 keep the sender inside a full-screen emergency session; the existing `geolocator`-based position stream (used for routine tracking) is a foreground-oriented API, and `flutter_foreground_task` exists in CLAUDE.md's stack specifically for background-survival scenarios but is not yet installed.
   - What's unclear: Whether the phase's success criteria require location streaming to continue if the sender's phone screen locks or another app briefly takes focus during the fixed window.
   - Recommendation: Default to requiring the sender to stay in-app for the streaming window in Phase 3 (simpler, avoids adding `flutter_foreground_task` to this already-large phase); if the discuss-phase/planning step decides background survival is required, add `flutter_foreground_task` as an explicit dependency at that point rather than assuming it silently.

3. **What identifies a Guardian's device(s) for FCM targeting?**
   - What we know: `firebase_messaging` is not yet integrated anywhere in this codebase — there is no FCM device-token registration/storage mechanism today.
   - What's unclear: Whether Phase 3 needs to add a `DeviceToken` entity (per-user, per-device) or whether a single-token-per-user model is acceptable for the MVP scope.
   - Recommendation: Add a minimal `UserDeviceToken` table (UserId, Token, Platform, UpdatedAtUtc) with upsert-on-app-start registration — the multi-device case (a Guardian with both a phone and tablet) is a real scenario for a family-safety app and should not be designed away at this stage, but a single-row-per-token upsert keeps the initial implementation simple.

## Validation Architecture

### Test Framework

**Backend (.NET)**

| Property | Value |
|----------|-------|
| Framework | xUnit 2.9.2 + `xunit.runner.visualstudio` 2.8.2 + Moq 4.20.72 [VERIFIED: codebase, `backend/tests/SafePath.Application.Tests/SafePath.Application.Tests.csproj`] |
| Config file | none — no `xunit.runner.json`; project-level config only via each `.csproj` (`SafePath.Domain.Tests`, `SafePath.Application.Tests`, `SafePath.Api.IntegrationTests`), all targeting `net9.0` |
| Quick run command | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Sos` |
| Full suite command | `dotnet test backend/SafePath.sln` |

**Mobile (Flutter)**

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (bundled with Flutter SDK, declared in `mobile/pubspec.yaml` dev_dependencies) [VERIFIED: codebase, `mobile/pubspec.yaml`] |
| Config file | none — no `dart_test.yaml`; existing convention is one `*_test.dart` file per feature/widget under `mobile/test/features/**`, with shared fakes under `mobile/test/helpers/` (e.g. `fake_location_api.dart`, `fake_location_hub_client.dart`) |
| Quick run command | `flutter test test/features/sos` (run from `mobile/`) |
| Full suite command | `flutter test` (run from `mobile/`) |

Both stacks already have working test infrastructure — no new test framework needs to be installed for Phase 3. The `Sos`/`AlertHub` test surface is entirely new (no existing files), following the same conventions already used for `Location`/`Families` (backend) and `location`/`family` (mobile).

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SOS-01 (backend) | `TriggerSosCommandHandler` never invokes `ReportLocationCommandHandler` or any AI-scoring path; command succeeds independent of the routine pipeline | unit | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Sos.TriggerSosCommandHandlerTests` | ❌ Wave 0 |
| SOS-01 (mobile) | 3-second press-and-hold on the SOS button fires the trigger; release before 3s cancels, no network call made | widget | `flutter test test/features/home/sos_button_press_hold_test.dart` | ❌ Wave 0 |
| SOS-02 (backend) | `TriggerSosCommandHandler` creates one `SosDeliveryAttempt` row per (recipient, channel) pair and dispatches fan-out for SignalR + FCM + SMS | unit | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Sos.AlertFanOutTests` | ❌ Wave 0 |
| SOS-02 (integration) | `POST /sos/trigger` response exposes per-recipient/per-channel delivery state, never a single collapsed "sent" flag (D-09) | integration | `dotnet test backend/tests/SafePath.Api.IntegrationTests --filter FullyQualifiedName~SosControllerTests` | ❌ Wave 0 |
| SOS-03 (backend) | Repeat `TriggerSosCommand` submissions with the same `sosSessionId` are idempotent — no duplicate `SosSession` row, no duplicate fan-out (D-15) | unit | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Sos.TriggerSosCommandHandlerTests.Idempotent` | ❌ Wave 0 |
| SOS-03 (mobile) | Offline trigger enters the full-screen emergency session in "not sent yet/retrying" state; queued session resumes after simulated app-kill/restart via persisted `sosSessionId` (D-12, D-14, D-17) | unit (controller) | `flutter test test/features/sos/sos_controller_test.dart` | ❌ Wave 0 |
| SOS-04 (backend) | `AlertHub` streams live-location updates to subscribed Guardians for the session's fixed window and stops emitting after the window's end time | integration (hub smoke, mirrors `LocationHubSmokeTests.cs`) | `dotnet test backend/tests/SafePath.Api.IntegrationTests --filter FullyQualifiedName~AlertHubSmokeTests` | ❌ Wave 0 |
| SOS-04 (mobile) | Responder screen renders the live-location stream with an explicit end-time/countdown and stops updating after expiry (D-21) | widget | `flutter test test/features/sos/responder_alert_screen_test.dart` | ❌ Wave 0 |
| SOS-05 (backend) | `CancelSosCommand` never blocks or delays the original `TriggerSosCommand` result; `SosSession` shows both the original alert and a `Canceled` state (D-05, D-24) | unit | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Sos.CancelSosCommandTests` | ❌ Wave 0 |
| SOS-06 | `quick_actions`-invoked shortcut fires SOS immediately, skipping the 3-second arming hold (D-27) | manual-only | — native OS home-screen/app-shortcut invocation cannot be triggered from a headless `flutter test` harness; requires manual exercise on an emulator/device per `/gsd-verify-work` | ❌ manual-only, justified |
| NOTIF-03 (backend) | On trigger, `AlertHub` push and FCM send are both invoked for every resolved recipient (Guardians + emergency contacts per D-11) | unit | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Sos.AlertFanOutTests` | ❌ Wave 0 (same file as SOS-02 backend row) |
| NOTIF-03 (manual) | A real FCM push notification, when tapped, deep-links into the dedicated SOS responder screen (D-19) | manual-only | — requires actual FCM delivery + OS notification tap; not reproducible inside the Flutter test harness or an ASP.NET Core integration test | ❌ manual-only, justified |
| DESIGN-02 | SOS button matches spec exactly: always-visible, raised center of bottom nav, 64px circle, 3-second press-and-hold with circular progress ring, release-to-cancel | widget | `flutter test test/features/home/sos_button_press_hold_test.dart` | ❌ Wave 0 (same file as SOS-01 mobile row) |

### Sampling Rate
- **Per task commit:** Backend — `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Sos` (plus `SafePath.Api.IntegrationTests --filter FullyQualifiedName~Sos|FullyQualifiedName~AlertHub` once those files exist); Mobile — `flutter test test/features/sos test/features/home/sos_button_press_hold_test.dart`
- **Per wave merge:** Backend — `dotnet test backend/SafePath.sln`; Mobile — `flutter test` (run from `mobile/`)
- **Phase gate:** Both full suites green, plus the two manual-only items (SOS-06 quick-action invocation, NOTIF-03 real FCM tap deep-link) exercised and confirmed before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `backend/tests/SafePath.Application.Tests/Sos/TriggerSosCommandHandlerTests.cs` — covers SOS-01 (backend), SOS-03 (backend, idempotency)
- [ ] `backend/tests/SafePath.Application.Tests/Sos/AlertFanOutTests.cs` — covers SOS-02 (backend), NOTIF-03 (backend)
- [ ] `backend/tests/SafePath.Application.Tests/Sos/CancelSosCommandTests.cs` — covers SOS-05
- [ ] `backend/tests/SafePath.Api.IntegrationTests/SosControllerTests.cs` — covers SOS-02 (integration), mirrors existing `MeEndpointTests.cs`/`RemoveMemberCommandTests.cs` pattern
- [ ] `backend/tests/SafePath.Api.IntegrationTests/AlertHubSmokeTests.cs` — covers SOS-04 (backend), mirrors existing `LocationHubSmokeTests.cs` pattern (auth rejection, group membership)
- [ ] `mobile/test/features/sos/sos_controller_test.dart` — covers SOS-03 (mobile), SOS-05 (mobile follow-up UI state)
- [ ] `mobile/test/features/home/sos_button_press_hold_test.dart` — covers SOS-01 (mobile), DESIGN-02
- [ ] `mobile/test/features/sos/responder_alert_screen_test.dart` — covers SOS-04 (mobile)
- [ ] `mobile/test/helpers/fake_sos_api.dart` and `mobile/test/helpers/fake_sos_hub_client.dart` — shared fakes for controller/widget tests, mirroring existing `fake_location_api.dart`/`fake_location_hub_client.dart`
- [ ] Framework install: none — xUnit/Moq/`Microsoft.EntityFrameworkCore.Sqlite` (backend) and `flutter_test` (mobile) are already present in both test projects; no new test-framework dependency is required for Phase 3

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-------------------|
| V2 Authentication | yes | Reuse existing Supabase-JWT `[Authorize]` pattern already on `LocationHub`/`LocationController` — `SosController`/`AlertHub` must not introduce a parallel auth mechanism |
| V3 Session Management | yes | `AlertHub` connection lifecycle follows the same `SupabaseUserIdProvider`/JWT-`sub`-claim identity pattern as `LocationHub` (already vetted in Phase 2) |
| V4 Access Control | yes | `IFamilyAuthorizationService.RequireMembership` must gate `TriggerSosCommand`/`AcknowledgeSosCommand` exactly as it gates `ReportLocationCommand` — an SOS trigger for a family the caller doesn't belong to must be rejected (IDOR prevention, matching existing `FamilyAuthorizationDeniedException` → `Forbid()` convention) |
| V5 Input Validation | yes | Inline guard-clause validation in the command handler (existing convention — `ReportLocationCommandHandler.Validate`), not FluentValidation (unused in this codebase despite the package reference) |
| V6 Cryptography | no | No new cryptographic material introduced this phase (D-28/D-29 explicitly exclude duress-secret storage from Phase 3 scope — that is Phase 6's `DURESS-03` concern) |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|----------------------|
| Forged/duplicate SOS trigger from a stolen `sosSessionId` | Spoofing/Tampering | `sosSessionId` alone is not an authorization credential — `TriggerSosCommand` still requires a valid authenticated JWT + `RequireMembership` check; the ID only provides idempotency, not authentication |
| A non-Guardian family member (e.g. a `Member`-role user) triggering/reading another family's SOS session | Elevation of Privilege | Apply the same `RequireMembership`/role checks used elsewhere (`IFamilyAuthorizationService`) to every SOS endpoint; do not create a Sos-specific authorization shortcut |
| SMS-fallback phone numbers or FCM device tokens leaking via an over-broad API response | Information Disclosure | `EmergencyContact.PhoneNumber` and `UserDeviceToken.Token` should never be included in any DTO returned to a client other than the owning user's own "my emergency contacts" management view — the SOS session/delivery-status DTOs shown to Guardians should reference recipients by name/role, not by raw phone number or device token |
| Repeated invalid `sosSessionId` submissions used to probe/DoS the trigger endpoint | Denial of Service | Per Pitfall 4 above — any rate limiting here must be generous/fail-open, but basic malformed-input rejection (invalid GUID format, missing auth) still applies before any expensive work runs |

## Sources

### Primary (HIGH confidence)
- None — no `context7`/`firecrawl` MCP provider was available this session (`.planning/config.json` has `brave_search`, `firecrawl`, `exa_search`, `tavily_search` all `false`).

### Secondary (MEDIUM confidence — direct codebase reads, not external)
- `backend/src/SafePath.Api/Program.cs` — confirmed no MediatR/global pipeline, actual middleware order
- `backend/src/SafePath.Application/Common/Interfaces/ICommandHandler.cs` — confirmed hand-rolled command pattern, documented MediatR-avoidance rationale
- `backend/src/SafePath.Application/Location/ReportLocationCommand.cs` — existing handler pattern to mirror for `TriggerSosCommand`
- `backend/src/SafePath.Infrastructure/RealTime/LocationHub.cs`, `LocationBroadcastService.cs` — existing SignalR hub/broadcast pattern to mirror for `AlertHub`
- `backend/src/SafePath.Domain/Entities/User.cs`, `FamilyMember.cs` — confirmed no phone-number field exists anywhere
- `backend/src/*/*.csproj` (all four) — confirmed actual `net9.0` target, EF Core 9.0.9, Npgsql 9.0.4 (vs. CLAUDE.md's aspirational .NET 10 stack doc)
- `mobile/pubspec.yaml`, `mobile/pubspec.lock` — confirmed `firebase_messaging`, `quick_actions`, `connectivity_plus`, `flutter_foreground_task` are NOT currently installed
- `mobile/lib/features/home/presentation/main_shell.dart` — confirmed existing `_SosTabButton` placeholder structure (already noted in `03-UI-SPEC.md`)
- `mobile/lib/features/location/application/location_controller.dart`, `mobile/lib/core/router/app_router.dart` — existing `AsyncNotifier`/hub-client and `GoRoute` patterns to mirror

### Tertiary (LOW confidence — external, WebSearch/WebFetch only, this session)
- Twilio pricing/trial/NuGet package facts — twilio.com, nuget.org (WebFetch)
- Vonage SMS pricing/delivery-receipt facts — vonage.com (WebSearch aggregation)
- Azure Communication Services SMS pricing/delivery-report facts — learn.microsoft.com (WebSearch aggregation)
- `quick_actions`, `flutter_foreground_task`, `firebase_messaging`, `connectivity_plus` version/requirement facts — pub.dev (WebFetch)
- Android power-button/AccessibilityService restrictions — multiple WebSearch results (androidpolice.com, medium.com, community forums)
- iOS Back Tap API landscape — apple.com/support, macrumors.com (WebSearch aggregation)
- ASP.NET Core SignalR ACK/stateful-reconnect facts — learn.microsoft.com, github.com/dotnet/aspnetcore (WebSearch aggregation)
- FCM delivery-confirmation facts — various blog/vendor sources (WebSearch aggregation, no single canonical Firebase doc page fetched directly this session)

## Metadata

**Confidence breakdown:**
- Standard stack (package choices/versions): LOW — no context7/firecrawl this session; re-verify exact versions at plan/execute time
- Architecture (backend/mobile structure, isolation pattern, existing-code reuse): HIGH — directly verified against this repository's actual source this session
- Pitfalls: MEDIUM — the FCM/SignalR delivery-confirmation and missing-EmergencyContact-schema pitfalls are HIGH confidence (codebase-verified or well-established platform behavior); the OS-shortcut-landscape pitfalls are LOW confidence (WebSearch only)

**Research date:** 2026-08-01
**Valid until:** 30 days for architecture guidance (stable); 14 days for external package versions and SMS-provider pricing/trial terms (fast-moving — re-verify before locking the SMS provider decision in planning)
