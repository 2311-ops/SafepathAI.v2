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
| TBD | TBD | TBD | SOS-01 (backend) | — | `TriggerSosCommandHandler` never invokes `ReportLocationCommandHandler` or any AI-scoring path | unit | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Sos.TriggerSosCommandHandlerTests` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | SOS-01 (mobile) / DESIGN-02 | — | 3s press-and-hold fires trigger; release before 3s cancels, no network call | widget | `flutter test test/features/home/sos_button_press_hold_test.dart` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | SOS-02 (backend) / NOTIF-03 (backend) | — | One `SosDeliveryAttempt` row per (recipient, channel); fan-out dispatched to SignalR + FCM + SMS | unit | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Sos.AlertFanOutTests` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | SOS-02 (integration) | — | `POST /sos/trigger` exposes per-recipient/per-channel delivery state (D-09), never a collapsed "sent" flag | integration | `dotnet test backend/tests/SafePath.Api.IntegrationTests --filter FullyQualifiedName~SosControllerTests` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | SOS-03 (backend) | — | Repeat trigger with same `sosSessionId` is idempotent (D-15) — no duplicate session/fan-out | unit | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Sos.TriggerSosCommandHandlerTests.Idempotent` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | SOS-03 (mobile) | — | Offline trigger enters emergency session in "not sent yet/retrying"; resumes after app-kill via persisted `sosSessionId` (D-12/D-14/D-17) | unit | `flutter test test/features/sos/sos_controller_test.dart` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | SOS-04 (backend) | — | `AlertHub` streams live location to subscribed Guardians for the fixed window, stops after end time | integration (hub smoke) | `dotnet test backend/tests/SafePath.Api.IntegrationTests --filter FullyQualifiedName~AlertHubSmokeTests` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | SOS-04 (mobile) | — | Responder screen shows live-location stream + countdown, stops updating after expiry (D-21) | widget | `flutter test test/features/sos/responder_alert_screen_test.dart` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | SOS-05 (backend) | — | `CancelSosCommand` never blocks/delays the original trigger result; both alert and canceled state visible (D-05/D-24) | unit | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Sos.CancelSosCommandTests` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | SOS-06 | — | `quick_actions` shortcut fires SOS immediately, skipping 3s hold (D-27) | manual-only | N/A — native OS shortcut invocation; exercise on emulator/device per `/gsd-verify-work` | ❌ manual-only, justified | ⬜ pending |
| TBD | TBD | TBD | NOTIF-03 (manual) | — | Real FCM push, when tapped, deep-links into SOS responder screen (D-19) | manual-only | N/A — requires real FCM delivery + OS notification tap | ❌ manual-only, justified | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*
*Task ID / Plan / Wave columns are populated by the planner once PLAN.md files exist — this table is pre-populated from research's Phase Requirements → Test Map.*

---

## Wave 0 Requirements

- [ ] `backend/tests/SafePath.Application.Tests/Sos/TriggerSosCommandHandlerTests.cs` — covers SOS-01 (backend), SOS-03 (backend, idempotency)
- [ ] `backend/tests/SafePath.Application.Tests/Sos/AlertFanOutTests.cs` — covers SOS-02 (backend), NOTIF-03 (backend)
- [ ] `backend/tests/SafePath.Application.Tests/Sos/CancelSosCommandTests.cs` — covers SOS-05
- [ ] `backend/tests/SafePath.Api.IntegrationTests/SosControllerTests.cs` — covers SOS-02 (integration), mirrors existing `MeEndpointTests.cs`/`RemoveMemberCommandTests.cs`
- [ ] `backend/tests/SafePath.Api.IntegrationTests/AlertHubSmokeTests.cs` — covers SOS-04 (backend), mirrors existing `LocationHubSmokeTests.cs`
- [ ] `mobile/test/features/sos/sos_controller_test.dart` — covers SOS-03 (mobile), SOS-05 (mobile follow-up UI)
- [ ] `mobile/test/features/home/sos_button_press_hold_test.dart` — covers SOS-01 (mobile), DESIGN-02
- [ ] `mobile/test/features/sos/responder_alert_screen_test.dart` — covers SOS-04 (mobile)
- [ ] `mobile/test/helpers/fake_sos_api.dart` and `mobile/test/helpers/fake_sos_hub_client.dart` — shared fakes mirroring `fake_location_api.dart`/`fake_location_hub_client.dart`
- [ ] Framework install: none — xUnit/Moq/EF Core Sqlite (backend) and `flutter_test` (mobile) already present

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `quick_actions`-invoked shortcut fires SOS immediately, skipping the 3-second arming hold | SOS-06 | Native OS home-screen/app-shortcut invocation cannot be triggered from a headless `flutter test` harness | Long-press app icon on Android/iOS home screen, invoke the SOS quick action, confirm immediate trigger with no hold gate |
| Real FCM push notification, when tapped, deep-links into the dedicated SOS responder screen | NOTIF-03 | Requires actual FCM delivery + OS notification tap; not reproducible inside Flutter test harness or ASP.NET Core integration test | Trigger SOS from a second test device/account acting as sender; on the Guardian device, background the app, wait for the push, tap it, confirm it opens directly on the SOS responder screen |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
