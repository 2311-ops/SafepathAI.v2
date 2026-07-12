---
phase: 02-real-time-location-history-privacy
verified: 2026-07-12T21:59:24Z
status: gaps_found
score: 12/14 must-haves verified
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "User sees an in-app permission-priming screen before the OS location-permission dialog appears (LOC-05)."
    status: failed
    reason: "The priming screen exists, but /home routes directly to MainShell/LiveMapScreen and LiveMapScreen watches LocationController, whose build path starts the foreground Geolocator stream. No router/controller gate sends a signed-in user to /permission-priming before map location streaming begins."
    artifacts:
      - path: "mobile/lib/core/router/app_router.dart"
        issue: "/home builds MainShell directly; /permission-priming is only a standalone authenticated route."
      - path: "mobile/lib/features/home/presentation/main_shell.dart"
        issue: "The first tab is LiveMapScreen."
      - path: "mobile/lib/features/location/application/location_controller.dart"
        issue: "positionStreamProvider creates Geolocator.getPositionStream and LocationController bootstraps from LiveMapScreen."
      - path: "mobile/test/features/location/permission_priming_screen_test.dart"
        issue: "Test proves requestPermission is CTA-gated inside the screen, but does not prove users are routed to that screen before location streaming."
    missing:
      - "Add an app/router/controller gate that sends users without granted location permission to /permission-priming before LiveMapScreen starts location streaming."
      - "Prevent LocationController from starting Geolocator.getPositionStream until permission is granted through the priming flow."
      - "Add a route/controller test covering the cold signed-in /home path with denied/unknown permission."
  - truth: "A user can start a temporary, time-boxed share with the advertised 1h/4h/8h/Custom controls and choose who receives it (PRIV-03)."
    status: partial
    reason: "Backend expiry and preset duration flow exist, but the mobile Privacy Center hardcodes temporary sharing to recipients.first and the Custom chip starts a fixed 1-hour share rather than collecting a custom duration."
    artifacts:
      - path: "mobile/lib/features/privacy/presentation/privacy_center_screen.dart"
        issue: "Temporary share uses recipients.first.memberId and Custom calls onPresetSelected(Duration(hours: 1))."
      - path: "mobile/test/features/privacy/privacy_center_screen_test.dart"
        issue: "Tests cover the 4-hour preset only; no test covers custom duration or choosing a recipient."
    missing:
      - "Add a recipient selection path for temporary sharing or attach temporary controls to each recipient row."
      - "Implement a real custom duration input instead of mapping Custom to 1 hour."
      - "Add widget/controller tests for custom duration and non-first-recipient temporary sharing."
---

# Phase 2: Real-Time Location, History & Privacy Verification Report

**Phase Goal:** Family members can see each other's live and past location, with full control over what's shared and with whom.
**Verified:** 2026-07-12T21:59:24Z
**Status:** gaps_found
**Re-verification:** No - initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | Live location updates on a shared map with last-seen and online/offline status (LOC-01, LOC-02) | VERIFIED | `LocationHub.ReportLocation` derives caller id from `Context.UserIdentifier`, `ReportLocationCommandHandler` persists then broadcasts through `ILocationBroadcastService`, `GetLiveLocationsQueryHandler` returns latest pings and dual-signal online state, and `LiveMapScreen` renders Google Map markers plus detail sheets. Focused backend and Flutter tests passed. |
| 2 | Stale-location indicator with accuracy radius is visible (LOC-03) | VERIFIED | `stalenessFor` and `accuracyCircleRadius` are implemented and used by `LiveMapScreen` marker alpha/circles and `MemberMapPin`; `mobile/test/features/location/staleness_test.dart` covers opacity bands and 24px minimum radius. |
| 3 | Battery transparency screen exists (LOC-04) | VERIFIED | `BatteryTransparencyScreen` explains foreground-only tracking and uses caution/neutral styling; router exposes `/battery-info`; no background/Always permission strings were found. |
| 4 | In-app permission priming appears before OS location prompt (LOC-05) | FAILED | `PermissionPrimingScreen` is implemented and CTA-gates `requestPermission`, but `/home` builds `MainShell` directly and the map tab watches `LocationController`, which starts `Geolocator.getPositionStream`. No route/gate forces the priming screen first. |
| 5 | Historical timeline of stops/movements is available (HIST-01) | VERIFIED | `GetLocationHistoryQueryHandler` gates membership plus `SharedDataType.History`, reads bounded pings, and returns polyline points plus `StopDetection.DetectStops`; mobile `HistoryTimelineScreen` renders timeline nodes. |
| 6 | Route visualization of past travel is available (HIST-02) | VERIFIED | Backend returns ordered route points; mobile `route_stats_sheet.dart` renders `google_maps_flutter` `Polyline` plus markers. |
| 7 | Travel statistics are available (HIST-03) | VERIFIED | `GetTravelStatsQueryHandler` computes distance, timeAway, and stopCount; mobile displays stat tiles in Activity and route sheet. |
| 8 | Low-battery alert surfaces for self/family (NOTIF-01) | VERIFIED | `LowBatteryEvaluator` implements falling-edge hysteresis, `ReportLocationCommandHandler` broadcasts `LowBattery`, mobile hub client exposes `lowBatteryAlerts`, and `LowBatteryBanner` is shown/dismissed from live map state. |
| 9 | Sensitive communication is encrypted per project transport posture (PRIV-01) | VERIFIED | SignalR JWT tokens are scoped to `/hubs/location`; backend uses HTTPS redirection, JWT `RequireHttpsMetadata`, and WSS/HTTPS transport. No app-layer E2EE is present; this report treats the phase plans' HTTPS/WSS interpretation as the implemented contract. |
| 10 | Sharing can be toggled per data type and recipient (PRIV-02) | VERIFIED | `SharingPreference`, `ISharingAuthorizationService`, `PrivacyController`, mobile `PrivacyController`, and `ToggleRow` matrix are present and server-backed. Broadcast and read paths call sharing gates. |
| 11 | Temporary sharing auto-stops on expiry (PRIV-03 backend) | VERIFIED | `SharingPreferenceSweepService.SweepExpired` disables expired rows and authorization denies expired rows immediately; tests cover sweep behavior. |
| 12 | Temporary sharing UI supports advertised custom/recipient control (PRIV-03 UI) | FAILED | Privacy Center hardcodes temporary shares to `recipients.first.memberId`; `Custom` maps to `Duration(hours: 1)` instead of a user-entered duration. |
| 13 | User can export/delete their data from Privacy Center (PRIV-04) | VERIFIED | Backend export returns caller-owned pings and sharing preferences; delete hard-deletes caller-owned `LocationPings`; mobile calls export/delete and confirmation-gates delete. Focused export/delete tests passed. |
| 14 | No-data-resale policy is documented and surfaced (PRIV-05) | VERIFIED | `GET privacy/policy` returns no-data-resale/export/delete text; mobile policy screen fetches and renders it from Privacy Center. |

**Score:** 12/14 truths verified.

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `backend/src/SafePath.Infrastructure/RealTime/LocationHub.cs` | Authenticated family SignalR hub | VERIFIED | `[Authorize]`, query `familyId`, membership check, group join, presence events, and `ReportLocation` command dispatch are implemented. |
| `backend/src/SafePath.Application/Location/*` | Live/history/stats/low-battery application logic | VERIFIED | Report, live, history, stats, staleness math, low-battery evaluator, and DTOs are substantive and registered. |
| `backend/src/SafePath.Application/Privacy/*` | Sharing/export/delete logic | VERIFIED | Sharing matrix/update, export, delete, and privacy DTOs are implemented and controller-wired. |
| `mobile/lib/features/location/*` | Map, permission, battery, history, location controllers | PARTIAL | Substantive and tested, but permission priming is not wired as a first-use gate before map streaming. |
| `mobile/lib/features/privacy/*` | Privacy Center, sharing matrix, temporary sharing, export/delete/policy | PARTIAL | Substantive and server-backed, but temporary share custom duration/recipient choice is incomplete. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `Program.cs` | `LocationHub` | `OnMessageReceived` + `MapHub("/hubs/location")` | WIRED | Query `access_token` only applies to `/hubs/location`. |
| `LocationHub.ReportLocation` | `ReportLocationCommandHandler` | Injected command handler | WIRED | User id comes from `Context.UserIdentifier`; request has no user id. |
| `ReportLocationCommandHandler` | Realtime clients | `BroadcastLocation` / `BroadcastLowBattery` | WIRED | Persist-then-broadcast, recipient-filtered by sharing preferences. |
| `PrivacyCenterScreen` | Backend privacy API | `PrivacyController` -> `PrivacyApi` PATCH/export/delete/policy | WIRED | Toggles/export/delete/policy are backend-backed. |
| `/home` route | Permission priming | Missing route/controller gate | NOT_WIRED | `/home` goes directly to `MainShell`; priming is a standalone route only. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|---|---|---|---|---|
| `LiveMapScreen` | `LocationState.members/selfPosition` | `LocationController` -> `LocationApi.getLiveLocations`, SignalR streams, Geolocator stream | Yes | VERIFIED |
| `HistoryTimelineScreen` | `HistoryState.history/stats` | `HistoryController` -> `LocationApi.getHistory/getTravelStats` | Yes | VERIFIED |
| `PrivacyCenterScreen` | `PrivacyState.matrix` | `PrivacyController` -> `PrivacyApi.getSharingMatrix/updateSharingPreference` | Yes | VERIFIED |
| `PrivacyCenterScreen` temporary sharing | recipient/duration | UI uses first recipient and preset callback | Partial | HOLLOW PARTIAL - custom/recipient choice not real. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Report/live/export backend paths | `dotnet test backend\tests\SafePath.Application.Tests --filter "FullyQualifiedName~Location.ReportLocationCommandHandlerTests\|FullyQualifiedName~Location.GetLiveLocationsQueryTests\|FullyQualifiedName~Privacy.ExportDeleteTests"` | 14 passed | PASS |
| SignalR smoke integration guard | `dotnet test backend\tests\SafePath.Api.IntegrationTests --filter FullyQualifiedName~LocationHubSmokeTests` | 1 passed | PASS |
| Permission/location/privacy mobile controllers | `cd mobile; flutter test test/features/location/permission_priming_screen_test.dart test/features/location/location_controller_test.dart test/features/privacy/privacy_controller_test.dart` | 9 passed | PASS |
| Permission-first user flow | grep/code trace | No gate from `/home` to `/permission-priming`; no test covers cold `/home` denied-permission routing | FAIL |

### Probe Execution

No phase-specific `scripts/**/tests/probe-*.sh` probes were declared or found. Step 7c skipped.

### Requirements Coverage

| Requirement | Status | Evidence |
|---|---|---|
| LOC-01 | SATISFIED | Backend report/broadcast + mobile map/controller exist and tests pass. |
| LOC-02 | SATISFIED | Presence tracker, live query, mobile presence/detail sheet implemented. |
| LOC-03 | SATISFIED | Staleness/accuracy radius functions and map rendering exist. |
| LOC-04 | SATISFIED | Battery transparency screen and route exist. |
| LOC-05 | BLOCKED | Priming screen is not wired before map location streaming. |
| HIST-01 | SATISFIED | History query + Activity timeline implemented. |
| HIST-02 | SATISFIED | Route points + Google Maps polyline implemented. |
| HIST-03 | SATISFIED | Travel stats endpoint + stat tiles implemented. |
| NOTIF-01 | SATISFIED | Low-battery evaluator, hub event, mobile banner implemented. |
| PRIV-01 | SATISFIED WITH NOTE | HTTPS/WSS/JWT transport implemented; no app-layer E2EE. |
| PRIV-02 | SATISFIED | Server-backed per-recipient/data-type sharing matrix and gates implemented. |
| PRIV-03 | BLOCKED | Backend expiry works, but mobile temporary share UI lacks custom duration and recipient choice. |
| PRIV-04 | SATISFIED | Export/delete endpoints and Privacy Center actions implemented. |
| PRIV-05 | SATISFIED | Policy endpoint and mobile policy screen render no-data-resale commitment. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---:|---|---|---|
| `mobile/lib/features/home/presentation/main_shell.dart` | 52, 57 | "coming soon" placeholders | INFO | Intentional for inert SOS/Insights outside Phase 2 scope; not a blocker. |
| `mobile/lib/features/privacy/presentation/privacy_center_screen.dart` | 142, 324 | Hardcoded recipient/custom duration | BLOCKER | Prevents exact temporary-share control promised by plan/PRIV-03. |

### Human Verification Required

None added by this verification report. The orchestrator separately reported a physical-device SignalR smoke pass on SM A305F Android 11; this verifier did not re-run physical-device UAT.

### Gaps Summary

Phase 2 is mostly implemented and wired end to end, but the phase goal is not fully achieved. LOC-05 is blocked because the user can land on the map and start the location controller without being forced through the priming screen. PRIV-03 is partially blocked because temporary sharing is not fully controllable: the UI always targets the first recipient and the Custom chip is not custom.

Process note: ROADMAP marks Phase 2 as MVP mode, but the ROADMAP goal is not in the canonical user-story format. `user-story.validate` rejects it. The plans include a derived user story, so this report verified the concrete roadmap success criteria and requirement IDs.

---

_Verified: 2026-07-12T21:59:24Z_
_Verifier: the agent (gsd-verifier)_
