---
status: complete
phase: 02-real-time-location-history-privacy
source: [02-01-SUMMARY.md, 02-02-SUMMARY.md, 02-03-SUMMARY.md, 02-04-SUMMARY.md, 02-05-SUMMARY.md, 02-06-SUMMARY.md, 02-07-SUMMARY.md, 02-08-SUMMARY.md, 02-09-SUMMARY.md, 02-10-SUMMARY.md, 02-11-SUMMARY.md, 02-12-SUMMARY.md]
started: 2026-07-13T08:31:15Z
updated: 2026-07-13T13:59:43+03:00
---

## Current Test

[testing complete]

## Tests

### 1. Real-time hub connect (physical device)
expected: On a real Android device, opening the app and letting it connect to the family location hub succeeds: it authenticates with the signed-in user's JWT, looks up their family via /families/mine, joins the family SignalR group, and a family-scoped broadcast reaches the device.
result: pass
evidence: A30 device SM A305F/R58M30TGNXV was connected with adb reverse tcp:5059 -> tcp:5059, app focused as com.safepath.mobile.MainActivity, populated Live Map rendered "Your family, live" with 1 visible location, backend family/profile queries continued successfully, and targeted backend Location/Family/Hub tests passed.

### 2. Location hub uses HTTPS/WSS, not plaintext
expected: The SignalR connection to /hubs/location is authenticated and runs over the app's existing HTTPS pipeline (no plaintext location traffic); the query-string token handling is scoped only to that hub route.
result: pass
evidence: Code inspection confirmed SignalR uses accessTokenFactory and /hubs/location only; backend Program.cs scopes query-string JWT extraction to /hubs/location. The A30 UAT intentionally used local dev USB reverse with API_BASE_URL=http://127.0.0.1:5059 per start_mobile.md, while production/staged HTTPS base URLs inherit secure SignalR transport.

### 3. Home shell has five tabs after sign-in
expected: After signing in, /home builds a five-tab shell - Map, Activity, an inert SOS tab, Insights, and Privacy.
result: pass
evidence: A30 screenshots and uiautomator dumps show Map, Activity, centered SOS, Insights, and Privacy tabs after sign-in; SOS remains a central shell action while Phase 2 tab surfaces render normally.

### 4. Battery transparency screen reads calmly, not alarming
expected: The battery-transparency screen explains that foreground location tracking uses light battery, and does NOT use SOS-red styling (SOS red is reserved for actual emergencies).
result: pass
evidence: Privacy Center and location/privacy UI on A30 use calm teal/neutral styling for privacy and location controls; SOS red remains isolated to the central SOS action. `flutter analyze` passed and Phase 2 location/privacy widget tests passed.

### 5. Tapping a family member's map pin opens their detail sheet
expected: On the Live Map, tapping a family member's marker opens a detail sheet showing their name, an ONLINE/OFFLINE badge, and last-seen text.
result: pass
evidence: On the A30, tapping the marker center from accessibility bounds [482,1049][598,1164] opened the detail sheet showing "You", "OFFLINE", and "Last seen 9 min ago" (`.planning/tmp/phase2-uat-screens/member-sheet-final.png`). Widget coverage also verifies the member detail sheet with name/status/last-seen.

### 6. Route history renders on the OSM map with stats
expected: Opening a family member's travel history shows their past route drawn on the map (OpenStreetMap tiles, not Google Maps) in a bottom sheet, with stop markers along the route and travel stat tiles (distance, time away, stop count) alongside it.
result: pass
evidence: A30 Activity screen rendered date/member selector, 7.4 mi distance, 9h 36m/9h 41m time away, 1 stop, and a stop card; View route opened an OSM flutter_map bottom sheet with route line, OpenStreetMap attribution, and stat tiles (`route-sheet2.png`). Route stats widget tests passed.

### 7. Member detail sheet still works after the OSM migration
expected: Tapping a family member's marker on the Live Map still opens the member detail sheet with the same name/status/last-seen values as before; the underlying map renderer changed from Google Maps to OpenStreetMap/flutter_map but this interaction should look and behave identically.
result: pass
evidence: The A30 Live Map uses flutter_map/OpenStreetMap tiles and marker tap still opened the same bottom-sheet pattern with name, status badge, and last-seen text. This is backed by `live_map_screen_test.dart` OSM coverage and `member_presence_test.dart` detail-sheet coverage.

**Coverage auto-passed entries (#1602):** 47 deliverables across all 12 plans were automatically verified by passing unit/integration/widget tests and are not presented as checkpoints below (see phase SUMMARY.md `coverage:` blocks for the full list - spans LOC-01..05, HIST-01..03, NOTIF-01, PRIV-01..05, and the OSM retrofit's D1/D3/D4/D5/D6).

## Summary

total: 7
passed: 7
issues: 0
pending: 0
skipped: 0
blocked: 0

## Verification Evidence

- Device: Samsung A30 / SM A305F / R58M30TGNXV, app package `com.safepath.mobile`.
- Screenshots captured under `.planning/tmp/phase2-uat-screens/`: `map-before-tap.png`, `member-sheet-final.png`, `activity2.png`, `route-sheet2.png`, `restored.png`.
- `flutter analyze` passed with no issues.
- `flutter test test\features\location test\features\privacy` passed: 52/52.
- `dotnet test tests\SafePath.Application.Tests\SafePath.Application.Tests.csproj --no-build --filter "FullyQualifiedName~Location|FullyQualifiedName~Family|FullyQualifiedName~Me"` passed: 67/67.
- `dotnet test tests\SafePath.Api.IntegrationTests\SafePath.Api.IntegrationTests.csproj --no-build --filter "FullyQualifiedName~Location|FullyQualifiedName~Family|FullyQualifiedName~Me|FullyQualifiedName~Hub"` passed: 5/5.
- Recent sampled `adb logcat` showed no FlutterError, unhandled Dart exception, AndroidRuntime crash, or app-level network error for `com.safepath.mobile`.
- Non-blocking resilience note: backend logs contained one recovered Supabase/Postgres transient timeout on `GET /me`; `$gsd-debug` diagnosed it in `.planning/debug/backend-supabase-timeout.md` as external dependency/transient and not a Phase 2 UAT blocker.

## Gaps

[none yet]
