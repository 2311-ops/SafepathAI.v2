---
phase: 2
slug: real-time-location-history-privacy
status: approved
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-12
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Backend: xUnit 2.9.2 + `SqliteInMemoryDbContextFactory` (EF Core Sqlite in-memory 9.0.9) + hand fakes/Moq — same as Phase 1 `SafePath.Application.Tests`. Mobile: `flutter_test` + hand-written fakes (`FakeLocationApi`/`FakeLocationHubClient`/`FakePrivacyApi`), `ProviderContainer`-driven, no real network/Supabase/GPS — same as Phase 1 `FakeAuthApi`/`FakeFamilyApi`. |
| **Config file** | Backend `backend/tests/SafePath.Application.Tests/SafePath.Application.Tests.csproj` (exists). Mobile: default `flutter test` (no config). |
| **Quick run command** | Backend: `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~<Feature>`. Mobile: `cd mobile && flutter test test/features/<feature>` |
| **Full suite command** | Backend: `dotnet test backend/SafePath.sln`. Mobile: `cd mobile && flutter test` |
| **Estimated runtime** | Backend quick ~5-15s; mobile quick ~5-20s; full suites < ~2 min each |

---

## Sampling Rate

- **After every task commit:** Run the plan's quick command (backend `--filter FullyQualifiedName~<Feature>` or mobile `flutter test test/features/<feature>`)
- **After every plan wave:** Run both full suites (`dotnet test backend/SafePath.sln` + `cd mobile && flutter test`)
- **Before `/gsd-verify-work`:** Both full suites green
- **Max feedback latency:** ~120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | LOC-01/02 | T-02-SC | Human-verify package legitimacy before install | manual (blocking-human) | n/a — checkpoint | n/a | ⬜ pending |
| 02-01-02 | 01 | 1 | LOC-01/02, PRIV-01 | T-02-03/04/01 | Hub group join gated by RequireMembership; JWT query-string auth scoped to hub path | build | `dotnet build backend/SafePath.sln -c Debug` | ✅ | ⬜ pending |
| 02-01-03 | 01 | 1 | LOC-01/02 | T-02-SC | Access token re-read live per connection (not cached) | static | `cd mobile && flutter analyze lib/features/location test/helpers/fake_location_hub_client.dart` | ❌ W0 | ⬜ pending |
| 02-01-04 | 01 | 1 | LOC-01/02 | T-02-03 | Live spike: connect/receive/reconnect + cross-family isolation | manual (blocking) | n/a — checkpoint | n/a | ⬜ pending |
| 02-02-01 | 02 | 2 | LOC-03 | — | GeoMath/entity round-trip; composite index | unit | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Location.GetLiveLocationsQueryTests` | ❌ W0 | ⬜ pending |
| 02-02-02 | 02 | 2 | LOC-01/02 | T-02-04/08 | UserId from Context.UserIdentifier; lat/lng+timestamp validated; persist+broadcast once | unit | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Location.ReportLocationCommandHandlerTests` | ❌ W0 | ⬜ pending |
| 02-02-03 | 02 | 2 | LOC-01/02/03 | T-02-01 | RequireMembership before read; dual-signal presence | unit | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Location.GetLiveLocationsQueryTests` | ❌ W0 | ⬜ pending |
| 02-03-01 | 03 | 3 | PRIV-02/03 | T-02-02 | Server-side FilterRecipients honors default/override/disabled/expired | unit | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Privacy.SharingPreferenceTests` | ❌ W0 | ⬜ pending |
| 02-03-02 | 03 | 3 | PRIV-02 | T-02-02/05/01 | Double-gate on broadcast+read; owner forced to caller | unit | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Privacy.BroadcastGatingTests` | ❌ W0 | ⬜ pending |
| 02-03-03 | 03 | 3 | PRIV-03/01 | T-02-09 | Sweep flips only expired+enabled; idempotent; TLS/WSS | unit | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Privacy.SweepServiceTests` | ❌ W0 | ⬜ pending |
| 02-04-01 | 04 | 4 | HIST-01/03 | — | Dwell-time stop detection correctness | unit | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Location.StopDetectionTests` | ❌ W0 | ⬜ pending |
| 02-04-02 | 04 | 4 | HIST-01/02 | T-02-01/02/10 | Membership + History-share gate; bounded range | unit | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Location.GetLocationHistoryQueryTests` | ❌ W0 | ⬜ pending |
| 02-04-03 | 04 | 4 | HIST-03 | T-02-01/02 | Stats gated; distance within ~1% | unit | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Location.GetTravelStatsQueryTests` | ❌ W0 | ⬜ pending |
| 02-05-01 | 05 | 5 | NOTIF-01 | T-02-11/02 | Falling-edge suppression; family-scoped alert | unit | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Location.LowBatteryAlertTests` | ❌ W0 | ⬜ pending |
| 02-05-02 | 05 | 5 | PRIV-04 | T-02-01 | Owner-scoped export/hard-delete; idempotent delete | unit | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Privacy.ExportDeleteTests` | ❌ W0 | ⬜ pending |
| 02-05-03 | 05 | 5 | PRIV-05 | — | No-data-resale policy endpoint | build | `dotnet build backend/SafePath.sln -c Debug` | ✅ | ⬜ pending |
| 02-06-01 | 06 | 3 | LOC-04/05 | T-02-13 | Foreground-only manifests (no Always/background) | static | `cd mobile && flutter analyze lib/features/home lib/core/router lib/core/theme` | ❌ W0 | ⬜ pending |
| 02-06-02 | 06 | 3 | LOC-05/04 | T-02-14 | requestPermission only after priming CTA | widget | `cd mobile && flutter test test/features/location/permission_priming_screen_test.dart` | ❌ W0 | ⬜ pending |
| 02-06-03 | 06 | 3 | LOC-01 | T-02-04 | Foreground stream; hub reports self fixes | unit | `cd mobile && flutter test test/features/location/location_controller_test.dart` | ❌ W0 | ⬜ pending |
| 02-07-01 | 07 | 4 | LOC-03 | T-02-16 | Staleness bands + 0.3 floor + 24px min radius | unit | `cd mobile && flutter test test/features/location/staleness_test.dart` | ❌ W0 | ⬜ pending |
| 02-07-02 | 07 | 4 | LOC-02 | T-02-03 | Presence + last-seen; dual-signal | widget | `cd mobile && flutter test test/features/location/member_presence_test.dart` | ❌ W0 | ⬜ pending |
| 02-07-03 | 07 | 4 | NOTIF-01 | T-02-11 | Amber banner, no red, dismissible | static | `cd mobile && flutter analyze lib/features/location` | ❌ W0 | ⬜ pending |
| 02-08-01 | 08 | 5 | HIST-01/02/03 | T-02-02 | History/stats fetch; 403 → friendly error | unit | `cd mobile && flutter test test/features/location/history_controller_test.dart` | ❌ W0 | ⬜ pending |
| 02-08-02 | 08 | 5 | HIST-01/03 | — | Stat tiles + timeline nodes + empty state; no red | widget | `cd mobile && flutter test test/features/location/history_timeline_screen_test.dart` | ❌ W0 | ⬜ pending |
| 02-08-03 | 08 | 5 | HIST-02 | — | Native Polyline route; Activity tab wired | static | `cd mobile && flutter analyze lib/features/location lib/features/home` | ❌ W0 | ⬜ pending |
| 02-09-01 | 09 | 6 | PRIV-02/03 | T-02-02 | Toggle PATCHes server; revert+error copy on failure | unit | `cd mobile && flutter test test/features/privacy/privacy_controller_test.dart` | ❌ W0 | ⬜ pending |
| 02-09-02 | 09 | 6 | PRIV-02/03 | T-02-02 | Matrix + duration presets render; no red | widget | `cd mobile && flutter test test/features/privacy/privacy_center_screen_test.dart` | ❌ W0 | ⬜ pending |
| 02-09-03 | 09 | 6 | PRIV-04/05 | T-02-12/01 | Ink delete behind confirm; export; policy | static | `cd mobile && flutter analyze lib/features/privacy lib/features/home lib/core/router` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

All Phase 2 test files are new (❌ in RESEARCH.md Test Map). Rather than a separate Wave 0 plan, each plan's first code-producing task creates its own failing tests first (test-first / `tdd="true"`), reusing existing infrastructure — no framework installs needed.

- [ ] `backend/tests/SafePath.Application.Tests/Location/` — new test dir; mirrors `Families/` conventions (SqliteInMemoryDbContextFactory, Moq/hand fakes for `IFamilyAuthorizationService`/`ILocationBroadcastService`/`IPresenceQuery`/`ISharingAuthorizationService`). Created across P02/P04/P05.
- [ ] `backend/tests/SafePath.Application.Tests/Privacy/` — new test dir for SharingPreference/sweep/broadcast-gating/export-delete tests. Created across P03/P05.
- [ ] `mobile/test/features/location/` — new test dir; reuse `FakeAuthApi`-style fakes (`FakeLocationApi`, `FakeLocationHubClient`). Created across P06/P07/P08.
- [ ] `mobile/test/features/privacy/` — new test dir (`FakePrivacyApi`). Created in P09.
- [ ] `mobile/test/helpers/fake_location_hub_client.dart` (P01), `fake_location_api.dart` (P06), `fake_privacy_api.dart` (P09) — hand-written fakes.
- [ ] No new frameworks: xUnit/Moq/EF Sqlite already in `SafePath.Application.Tests.csproj`; `flutter_test` already the mobile default.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| signalr_netcore package legitimacy | LOC-01/02 (transport) | Supply-chain trust decision on a `[SUS]` pub.dev package; outside the automated legitimacy seam | P01 Task 1 — verify publisher/version/repo/non-typosquat on pub.dev before install |
| Live reconnect spike (connect/receive/reconnect/isolation) | LOC-01/02 | Requires a real device, real Supabase session, a live socket, and a forced network drop — not reproducible in unit tests | P01 Task 4 — run backend over HTTPS, drive the hub client, force airplane-mode drop, confirm group rejoin + cross-family isolation |
| Google Map tiles + pins render on device | LOC-01, HIST-02 | `google_maps_flutter` needs a real Maps API key + platform surface; map rendering is not unit-testable | Phase UAT — cold open → Map tab → self pin renders; Activity → route polyline draws |
| Visual fidelity to UI-SPEC (SOS-red exclusion, staleness fade, no-red Privacy Center) | LOC-03, PRIV-02/04, DESIGN | Color/opacity/layout fidelity is a human visual judgment (grep gates cover the token exclusion, not the look) | Phase UAT — visual sweep of Map/History/Privacy/Battery screens against 02-UI-SPEC.md |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or a documented manual/checkpoint rationale (2 checkpoints in P01 + device-only map/visual behaviors are the only non-automated items; every code-producing task has an automated command)
- [x] Sampling continuity: no 3 consecutive code-producing tasks without automated verify (each plan's implementation tasks carry a quick test/analyze command)
- [x] Wave 0 covers all MISSING references (test dirs/fakes created test-first within each plan)
- [x] No watch-mode flags
- [x] Feedback latency < 120s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-07-12
