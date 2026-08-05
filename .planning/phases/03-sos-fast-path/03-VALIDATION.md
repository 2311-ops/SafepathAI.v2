---
phase: 03
slug: sos-fast-path
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-01
---

# Phase 03 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

**Backend (.NET)**

| Property | Value |
|----------|-------|
| **Framework** | xUnit 2.9.2 + `xunit.runner.visualstudio` 2.8.2 + Moq 4.20.72 |
| **Config file** | none — no `xunit.runner.json`; project-level config via each `.csproj` (`SafePath.Domain.Tests`, `SafePath.Application.Tests`, `SafePath.Api.IntegrationTests`), all targeting `net9.0` |
| **Quick run command** | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Sos` |
| **Full suite command** | `dotnet test backend/SafePath.sln` |
| **Estimated runtime** | ~30-90 seconds (quick) / ~3-5 min (full suite) |

**Mobile (Flutter)**

| Property | Value |
|----------|-------|
| **Framework** | `flutter_test` (bundled with Flutter SDK) |
| **Config file** | none — no `dart_test.yaml`; one `*_test.dart` per feature/widget under `mobile/test/features/**`, shared fakes under `mobile/test/helpers/` |
| **Quick run command** | `flutter test test/features/sos test/features/home/sos_button_press_hold_test.dart` (run from `mobile/`) |
| **Full suite command** | `flutter test` (run from `mobile/`) |
| **Estimated runtime** | ~15-30 seconds (quick) / ~1-2 min (full suite) |

Both stacks already have working test infrastructure — no new test framework needs to be installed for Phase 3. The `Sos`/`AlertHub` test surface is entirely new, following the same conventions already used for `Location`/`Families` (backend) and `location`/`family` (mobile).

---

## Sampling Rate

- **After every task commit:** Backend — `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Sos`; Mobile — `flutter test test/features/sos test/features/home/sos_button_press_hold_test.dart`
- **After every plan wave:** Backend — `dotnet test backend/SafePath.sln`; Mobile — `flutter test` (run from `mobile/`)
- **Before `/gsd-verify-work`:** Both full suites green, plus the two manual-only items (SOS-06 quick-action invocation, NOTIF-03 real FCM tap deep-link) exercised and confirmed
- **Max feedback latency:** ~90 seconds (backend full suite is the slowest path)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| T-03 | 03-01 | 1 | SOS-01 (backend) | T-03-01 | `TriggerSosCommandHandler` never invokes `ReportLocationCommandHandler` or any AI-scoring path | unit | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Sos.TriggerSosCommandHandlerTests` | ❌ created by 03-01 T3 | ⬜ pending |
| T-02 | 03-01 | 1 | SOS-03 (schema) | T-03-02 | Duplicate `SosSession.Id` rejected at the storage layer; multi-token-per-user allowed (D-32) | unit | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Sos.SosSchemaTests` | ❌ created by 03-01 T2 | ⬜ pending |
| T-03 | 03-01 | 1 | SOS-03 (backend) | T-03-02 | Repeat trigger with same `sosSessionId` is idempotent (D-15) — no duplicate session/fan-out | unit | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Sos.TriggerSosCommandHandlerTests.Idempotent` | ❌ created by 03-01 T3 | ⬜ pending |
| T-03 | 03-01 | 1 | SOS-02 (integration) | T-03-01, T-03-03 | `POST /sos/trigger` exposes per-recipient/per-channel delivery state (D-09), never a collapsed "sent" flag | integration | `dotnet test backend/tests/SafePath.Api.IntegrationTests --filter FullyQualifiedName~SosControllerTests` | ❌ created by 03-01 T3 | ⬜ pending |
| T-01 | 03-02 | 2 | SOS-01 (mobile) / DESIGN-02 | T-03-11 | 3s press-and-hold fires trigger; release before 3s cancels, no network call | widget | `flutter test test/features/home/sos_button_press_hold_test.dart` | ❌ created by 03-02 T1 | ⬜ pending |
| T-02 | 03-02 | 2 | SOS-03 (mobile, session id) | T-03-02 | Session id generated and persisted before any network call (D-13/D-14); reused on every resubmission | unit (controller) | `flutter test test/features/sos/sos_controller_test.dart` | ❌ created by 03-02 T2 | ⬜ pending |
| T-01 | 03-03 | 2 | SOS-04 (backend, hub auth) | T-03-07, T-03-04 | `AlertHub` rejects unauthenticated and out-of-family connections; own group namespace | integration (hub smoke) | `dotnet test backend/tests/SafePath.Api.IntegrationTests --filter FullyQualifiedName~AlertHubSmokeTests` | ❌ created by 03-03 T1 | ⬜ pending |
| T-02 | 03-03 | 2 | SOS-02 (backend) / NOTIF-03 (backend) | T-03-14, T-03-15 | One `SosDeliveryAttempt` row per (recipient, channel); dispatch marks Queued, never Delivered | unit | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Sos.AlertFanOutTests` | ❌ created by 03-03 T2 | ⬜ pending |
| T-03 | 03-03 | 2 | SOS-05 (backend) | T-03-12 | `CancelSosCommand` never blocks/delays the original trigger result; both alert and canceled state visible (D-05/D-24); only the sender may cancel | unit | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Sos.CancelSosCommandTests` | ❌ created by 03-03 T3 | ⬜ pending |
| T-02 | 03-04 | 3 | SOS-05 / NOTIF-03 (mobile) | T-03-03 | Responder screen is full-screen, force-navigated, offers only Acknowledge + Call sender (D-22/D-23) | widget | `flutter test test/features/sos/responder_alert_screen_test.dart` | ❌ created by 03-04 T2 | ⬜ pending |
| T-03 | 03-04 | 3 | SOS-02 (mobile) | T-03-15, T-03-16 | Per-recipient/per-channel chips pair icon+text+colour; malformed hub payload never closes the stream | widget | `flutter test test/features/sos/sos_delivery_status_test.dart` | ❌ created by 03-04 T3 | ⬜ pending |
| T-01 | 03-05 | 3 | SOS-02 (contacts) | T-03-03, T-03-20 | Emergency contacts are owner-scoped and E.164-normalised; number readable only by its owner | unit | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Sos.EmergencyContactCommandTests` | ❌ created by 03-05 T1 | ⬜ pending |
| T-02, T-03 | 03-05 | 3 | SOS-02 (SMS) | T-03-19, T-03-21 | Recipients = Guardians + contacts only; SMS Delivered only on a signature-validated provider receipt | unit | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Sos.SmsFanOutTests` | ❌ created by 03-05 T2/T3 | ⬜ pending |
| T-01 | 03-06 | 4 | SOS-02 (FCM) / NOTIF-03 | T-03-23, T-03-15 | Fan-out reaches every registered device of a recipient (D-32); FCM stays Queued until the device reports receipt | unit | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Sos.PushFanOutTests` | ✅ created by 03-06 T1 | ✅ green (9/9, re-run 2026-08-05) |
| T-02 | 03-06 | 4 | NOTIF-03 (mobile) | T-03-23 | Token registered on sign-in, removed on sign-out; tap routed to responder from all three lifecycles | unit | `flutter test test/features/sos/push_service_test.dart` | ✅ created by 03-06 T2 | ✅ green (8/8, re-run 2026-08-05) |
| T-03 | 03-06 | 4 | NOTIF-03 (manual) | — | Real FCM push, when tapped, deep-links into SOS responder screen (D-19) | manual-only | N/A — requires real FCM delivery + OS notification tap; gated by 03-06 Task 3 checkpoint | ✅ manual-only, justified | ✅ exercised, Android-only (2026-08-05: terminated-state push + deep-link confirmed on device, Queued→Delivered→Acknowledged confirmed server-side; see 03-06-SUMMARY.md) — iOS/APNs and D-32 multi-device NOT tested |
| T-01 | 03-07 | 4 | SOS-03 (mobile) | T-03-02, T-03-26 | Offline trigger enters emergency session in "not sent yet/retrying"; resumes after app-kill via persisted `sosSessionId` (D-12/D-14/D-17); one session id across every retry | unit (controller) | `flutter test test/features/sos/sos_offline_retry_test.dart` | ❌ created by 03-07 T1 | ⬜ pending |
| T-02 | 03-07 | 4 | SOS-02 (contacts UI) | T-03-20 | Contacts can be added/edited/removed in-app; server owns number validity (D-30) | widget | `flutter test test/features/sos/emergency_contacts_screen_test.dart` | ❌ created by 03-07 T2 | ⬜ pending |
| T-01 | 03-08 | 5 | SOS-04 (backend) | T-03-09, T-03-27 | Window end stamped from server time; positions refused after expiry/cancellation and from non-triggering users | unit | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Sos.SosLiveWindowTests` | ❌ created by 03-08 T1 | ⬜ pending |
| T-01 | 03-08 | 5 | SOS-04 (backend, hub) | T-03-09 | `AlertHub` delivers `LiveLocationWindowUpdate` to a connected recipient | integration (hub smoke) | `dotnet test backend/tests/SafePath.Api.IntegrationTests --filter FullyQualifiedName~AlertHubSmokeTests` | ❌ extended by 03-08 T1 | ⬜ pending |
| T-02 | 03-08 | 5 | SOS-04 (mobile, streaming) | T-03-29 | Stream survives lock/backgrounding and self-terminates on expiry, cancellation and stop (D-31) | unit | `flutter test test/features/sos/sos_live_window_test.dart` | ❌ created by 03-08 T2 | ⬜ pending |
| T-03 | 03-08 | 5 | SOS-04 (mobile, UI) | T-03-28 | Responder screen shows live-location stream + countdown, stops updating after expiry (D-21); no digit jitter | widget | `flutter test test/features/sos/responder_alert_screen_test.dart` | ❌ extended by 03-08 T3 | ⬜ pending |
| T-01 | 03-09 | 6 | SOS-05 (mobile) | T-03-31, T-03-11 | 2s hold cancels; tap/short hold does not; canceled state stays visible on both sides (D-05/D-24) | widget | `flutter test test/features/sos/sos_cancel_test.dart` | ❌ created by 03-09 T1 | ⬜ pending |
| T-02 | 03-09 | 6 | SOS-06 (mobile) | T-03-32, T-03-02 | Shortcut reuses `arm()` with no hold (D-27); no duplicate session; not registered while signed out | unit | `flutter test test/features/sos/quick_actions_service_test.dart` | ❌ created by 03-09 T2 | ⬜ pending |
| T-03 | 03-09 | 6 | SOS-06 (manual) | T-03-33 | `quick_actions` shortcut fires SOS immediately, skipping 3s hold (D-27) | manual-only | N/A — native OS shortcut invocation; gated by 03-09 Task 3 checkpoint on a real device | ❌ manual-only, justified | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*
*Task ID / Plan / Wave columns populated by the planner on 2026-08-01. Every row from research's Phase Requirements → Test Map is assigned to an owning plan; no mapping was dropped. Both manual-only rows are gated by a blocking `checkpoint:human-verify` task inside their owning plan rather than deferred to `/gsd-verify-work` alone.*

---

## Wave 0 Requirements

Both stacks are compiled/typed, so a standalone "Wave 0 test-only plan" would not compile against symbols that do not yet exist. Instead every Wave 0 file below is created by its owning plan's own task using task-level TDD (`tdd="true"` with an explicit `<behavior>` block written before the implementation). The owning plan and task are named so nothing is orphaned.

- [ ] `backend/tests/SafePath.Application.Tests/Sos/SosSchemaTests.cs` — 03-01 T2 — schema shape, client-issued id, multi-device tokens
- [ ] `backend/tests/SafePath.Application.Tests/Sos/TriggerSosCommandHandlerTests.cs` — 03-01 T3 — covers SOS-01 (backend), SOS-03 (backend, idempotency)
- [ ] `backend/tests/SafePath.Api.IntegrationTests/SosControllerTests.cs` — 03-01 T3 — covers SOS-02 (integration), mirrors existing `MeEndpointTests.cs`/`RemoveMemberCommandTests.cs`
- [ ] `backend/tests/SafePath.Api.IntegrationTests/AlertHubSmokeTests.cs` — 03-03 T1 (extended 03-08 T1) — covers SOS-04 (backend), mirrors existing `LocationHubSmokeTests.cs`
- [ ] `backend/tests/SafePath.Application.Tests/Sos/AlertFanOutTests.cs` — 03-03 T2 — covers SOS-02 (backend), NOTIF-03 (backend)
- [ ] `backend/tests/SafePath.Application.Tests/Sos/CancelSosCommandTests.cs` — 03-03 T3 — covers SOS-05
- [ ] `backend/tests/SafePath.Application.Tests/Sos/EmergencyContactCommandTests.cs` — 03-05 T1 — contact ownership + E.164
- [ ] `backend/tests/SafePath.Application.Tests/Sos/SmsFanOutTests.cs` — 03-05 T2/T3 — recipient set + SMS channel + delivery webhook
- [ ] `backend/tests/SafePath.Application.Tests/Sos/PushFanOutTests.cs` — 03-06 T1 — multi-device FCM fan-out
- [ ] `backend/tests/SafePath.Application.Tests/Sos/SosLiveWindowTests.cs` — 03-08 T1 — server-authoritative window
- [ ] `mobile/test/features/home/sos_button_press_hold_test.dart` — 03-02 T1 — covers SOS-01 (mobile), DESIGN-02
- [ ] `mobile/test/features/sos/sos_controller_test.dart` — 03-02 T2 (extended 03-07 T1) — covers SOS-03 (mobile)
- [ ] `mobile/test/features/sos/responder_alert_screen_test.dart` — 03-04 T2 (extended 03-08 T3, 03-09 T1) — covers SOS-04 (mobile)
- [ ] `mobile/test/features/sos/sos_delivery_status_test.dart` — 03-04 T3 — per-recipient/per-channel status
- [ ] `mobile/test/features/sos/push_service_test.dart` — 03-06 T2 — token lifecycle + tap routing
- [ ] `mobile/test/features/sos/sos_offline_retry_test.dart` — 03-07 T1 — offline queue, retry, app-kill resume
- [ ] `mobile/test/features/sos/emergency_contacts_screen_test.dart` — 03-07 T2 — contact management UI
- [ ] `mobile/test/features/sos/sos_live_window_test.dart` — 03-08 T2 — background streaming lifecycle
- [ ] `mobile/test/features/sos/sos_cancel_test.dart` — 03-09 T1 — hold-to-cancel + canceled states
- [ ] `mobile/test/features/sos/quick_actions_service_test.dart` — 03-09 T2 — OS shortcut behaviour
- [ ] `mobile/test/helpers/fake_sos_api.dart`, `fake_sos_local_store.dart` (03-02 T2), `fake_sos_hub_client.dart` (03-04 T1), `fake_device_token_api.dart` (03-06 T2), `fake_connectivity_service.dart`, `fake_emergency_contact_api.dart` (03-07) — shared fakes mirroring `fake_location_api.dart`/`fake_location_hub_client.dart`
- [ ] Framework install: none — xUnit/Moq/EF Core Sqlite (backend) and `flutter_test` (mobile) already present

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `quick_actions`-invoked shortcut fires SOS immediately, skipping the 3-second arming hold | SOS-06 | Native OS home-screen/app-shortcut invocation cannot be triggered from a headless `flutter test` harness | Long-press app icon on Android/iOS home screen, invoke the SOS quick action, confirm immediate trigger with no hold gate |
| Real FCM push notification, when tapped, deep-links into the dedicated SOS responder screen | NOTIF-03 | Requires actual FCM delivery + OS notification tap; not reproducible inside Flutter test harness or ASP.NET Core integration test | Trigger SOS from a second test device/account acting as sender; on the Guardian device, background the app, wait for the push, tap it, confirm it opens directly on the SOS responder screen |

---

## Manual-Only Gating

Both manual-only rows are enforced by a blocking `checkpoint:human-verify` task inside the plan that builds the feature, rather than being deferred to `/gsd-verify-work` alone:

| Behavior | Requirement | Gate |
|----------|-------------|------|
| Real FCM push tap deep-links into the responder screen | NOTIF-03 | `03-06-PLAN.md` Task 3 — ten-step two-device procedure covering backgrounded and terminated states |
| `quick_actions` shortcut fires SOS immediately with no arming hold | SOS-06 | `03-09-PLAN.md` Task 3 — eleven-step two-device procedure, also the phase's closing end-to-end gate |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or a named owning task that creates the test file first
- [x] Sampling continuity: every plan's tasks carry an `<automated>` command; the only tasks without one are the three blocking human checkpoints
- [x] Wave 0 covers all MISSING references, each assigned to an owning plan + task
- [x] No watch-mode flags
- [x] Feedback latency < 90s (backend quick filter ~30-90s, mobile quick filter ~15-30s)
- [ ] `nyquist_compliant: true` — set this once the first wave's test files actually exist on disk

**Approval:** planner-populated 2026-08-01; pending execution
