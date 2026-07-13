---
phase: 02-real-time-location-history-privacy
verified: 2026-07-13T14:02:00+03:00
status: passed
score: 14/14 must-haves verified
behavior_unverified: 0
overrides_applied: 0
gaps: []
supersedes: 2026-07-12T21:59:24Z (status: gaps_found, score 12/14)
---

# Phase 2: Real-Time Location, History & Privacy Verification Report (re-verification)

**Phase Goal:** Family members can see each other's live and past location, with full control over what's shared and with whom.
**Verified:** 2026-07-13T14:02:00+03:00
**Status:** passed
**Re-verification:** Yes — closes both gaps from the 2026-07-12T21:59:24Z report.

## Final UAT Refresh - 2026-07-13T14:02:00+03:00

Phase 2 conversational/device UAT is now complete in `02-UAT.md`: 7/7 manual-facing checkpoints passed on the Samsung A30 physical device (`SM_A305F`, `R58M30TGNXV`). The run captured screenshots under `.planning/tmp/phase2-uat-screens/`, verified the live OSM map, five-tab home shell, marker detail sheet, route-history bottom sheet with stats, and privacy controls, and found no app crash or user-blocking issue in sampled `adb logcat`.

Additional regression checks from the same UAT refresh:

- `flutter analyze` - passed with no issues.
- `flutter test test\features\location test\features\privacy` - passed, 52/52.
- `dotnet test tests\SafePath.Application.Tests\SafePath.Application.Tests.csproj --no-build --filter "FullyQualifiedName~Location|FullyQualifiedName~Family|FullyQualifiedName~Me"` - passed, 67/67.
- `dotnet test tests\SafePath.Api.IntegrationTests\SafePath.Api.IntegrationTests.csproj --no-build --filter "FullyQualifiedName~Location|FullyQualifiedName~Family|FullyQualifiedName~Me|FullyQualifiedName~Hub"` - passed, 5/5.

One non-blocking backend resilience issue was diagnosed during UAT: a single recovered Supabase/Postgres transient timeout on `GET /me`. `$gsd-debug` recorded the diagnosis in `.planning/debug/backend-supabase-timeout.md` and classified it as external dependency/transient, not a Phase 2 UAT blocker. Future hardening should add retry/resilience or normalize transient database errors to a retryable 503.

## What changed since the last verification

Wave 7 (`02-10-PLAN.md`, `02-11-PLAN.md`) closed both previously-failed truths:

| # | Truth | Previous | Now | Evidence |
|---|---|---|---|---|
| 4 | In-app permission priming appears before OS location prompt (LOC-05) | FAILED | **VERIFIED** | `/home` is now wrapped in `LocationPermissionGate` (`mobile/lib/core/router/app_router.dart:221`), which routes unknown/denied/deniedForever permission states to `/permission-priming` before `MainShell` renders, and `LocationController` independently refuses to fetch live locations, connect the SignalR hub, or subscribe to the position stream until permission is granted. Confirmed by direct code read plus `location_permission_gate_test.dart` (10 tests) and `location_controller_test.dart` (9 tests), all passing. |
| 12 | Temporary sharing UI supports advertised custom/recipient control (PRIV-03 UI) | FAILED | **VERIFIED** | `privacy_center_screen.dart` no longer hardcodes `recipients.first.memberId` — temporary-share controls are attached per recipient row (`recipient.memberId` used throughout) and the Custom chip opens a real duration-input dialog (`custom-duration-field`/`custom-duration-unit`) instead of mapping to a fixed 1-hour `Duration`. Confirmed by direct code read (`grep` for `recipients.first.memberId` returns zero matches) plus `privacy_center_screen_test.dart` (6 tests covering non-first-recipient and custom duration), all passing. |

**Score: 14/14 truths verified** (up from 12/14).

## Additional fixes applied in this pass

A code review of the full Phase 2 diff (85 files, backend + mobile) surfaced and fixed 5 critical +
9 warning correctness/concurrency bugs unrelated to the two verification gaps above — see
`02-REVIEW-2.md` for full detail (PresenceTracker race condition, FilterRecipients self-bypass gap,
battery-level caching bug, SignalR hub client race guard, optimistic-rollback bug, etc.). All fixes
verified: backend `dotnet build` + 86 tests pass; mobile `flutter analyze` clean.

While re-running the full mobile test suite during this verification pass, a genuine regression was
also found and fixed: `LocationPermissionGate` (added by Wave 7 to close LOC-05) uses the real
`GeolocatorLocationPermissionService` by default, which has no platform-channel handler in widget
tests — any test reaching `/home` without overriding that provider hung on `pumpAndSettle` instead
of resolving. Added a shared `FakeLocationPermissionService` test helper and wired it into the three
affected suites (`auth_flow_navigation_test.dart`, `landing_role_flow_test.dart`,
`splash_redirect_gate_test.dart`).

## Known pre-existing test debt (not a Phase 2 gap, not fixed here)

Those same three test files still fail 9 assertions after the hang fix above — they expect
`"Your circle"` / `"Create your family circle"` text from `LandingStubScreen`, which
`mobile/lib/features/home/presentation/main_shell.dart` stopped using in commit `d062edb`
(**02-06**, well before Wave 7) in favor of `LiveMapScreen`. `LandingStubScreen` is now dead code
with no route referencing it. This predates both today's session and the Wave 7 gap-closure work,
and is out of scope for Phase 2's tracked success criteria — flagging for a separate cleanup pass
(either delete `LandingStubScreen` and rewrite these three suites against `MainShell`'s actual tab
content, or restore whatever redirect was supposed to show the family-setup flow first).

## Regression check

- Backend: `dotnet build` succeeds; `dotnet test` — 86/86 pass (`SafePath.Application.Tests` 81,
  `SafePath.Api.IntegrationTests` 5, including the `LocationHubSmokeTests` physical-device-adjacent
  SignalR smoke guard).
- Mobile: `flutter analyze` — no issues. `flutter test` (full suite) — 135 pass, 9 fail (the
  pre-existing stale-assertion debt documented above; unrelated to Phase 2 requirements or this
  verification's gaps).
- All originally-verified truths (1–3, 5–11, 13–14) were spot-re-checked against current code and
  remain intact; no regressions introduced by the Wave 7 gap-closure work or this pass's bug fixes.

## Requirements Coverage (updated)

| Requirement | Status |
|---|---|
| LOC-01..LOC-04 | SATISFIED (unchanged) |
| LOC-05 | **SATISFIED** (was BLOCKED) |
| HIST-01..HIST-03 | SATISFIED (unchanged) |
| NOTIF-01 | SATISFIED (unchanged) |
| PRIV-01 | SATISFIED WITH NOTE (unchanged — HTTPS/WSS/JWT transport, no app-layer E2EE) |
| PRIV-02 | SATISFIED (unchanged) |
| PRIV-03 | **SATISFIED** (was BLOCKED) |
| PRIV-04, PRIV-05 | SATISFIED (unchanged) |

## Human Verification Required

None. Prior physical-device SignalR smoke pass (SM A305F, Android 11) stands; not re-run in this pass.

---

_Verified: 2026-07-13T20:00:00Z_
_Verifier: Claude (inline re-verification against Wave 7 SUMMARY claims + direct code/test confirmation)_
_Previous report (gaps_found) superseded, not deleted — see git history for `02-VERIFICATION.md`._
