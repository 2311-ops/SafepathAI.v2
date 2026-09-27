---
phase: 04-geofencing
plan: 17
status: blocked-human-physical-acceptance
created: 2026-08-14
updated: 2026-09-27
timezone: Africa/Cairo
requirements: [GEO-01, GEO-02, GEO-03, NOTIF-02]
---

# Phase 04 Device Verification

04-17 Task 1 automated gates were refreshed and passed on 2026-09-27. Task 2 and the earlier 04-05 tracer checkpoint remain open: required Android and iOS physical acceptance evidence has not been produced.

Per PR-04, Phase 4 is not approved/closed until signed physical iPhone + APNs evidence exists alongside Android physical movement/recovery evidence. No 04-05 evidence was fabricated or retroactively claimed.

## Current Verification: 2026-09-27

| Gate | Command / evidence | Result |
|---|---|---|
| Backend full suite | `dotnet test backend/SafePath.sln --no-restore --configuration Release --verbosity quiet` | PASS: 228 application tests, 25 API integration tests; command exit 0 |
| Flutter full suite | `flutter test --no-pub --reporter expanded --timeout 60s` | PASS: 461 tests |
| Flutter analysis | `flutter analyze --no-pub` | PASS: no issues |
| Native Android worker test | `gradlew.bat :app:testDebugUnitTest --console=plain` | PASS: BUILD SUCCESSFUL; JUnit XML records 1 test, 0 failures/errors |
| Model drift | `dotnet ef migrations has-pending-model-changes --no-build --configuration Release --project backend/src/SafePath.Infrastructure --startup-project backend/src/SafePath.Api` | PASS: no pending model changes |
| Database migration state | Same EF projects/configuration with `migrations list` | PASS: all 12 migrations applied, through `20260811173100_AddGeofencing` |
| Android build and launch | `flutter run --no-pub -d R58M30TGNXV --no-resident --dart-define-from-file=env.json --dart-define=API_BASE_URL=https://exclude-driving-maternal.ngrok-free.dev` | PASS: debug APK built, installed, and launched |
| Remote API | Tunnel `/openapi/v1.json`, with ngrok bypass header | HTTP 200 |
| Signed-in API | Connected phone session calling `/me` and `/families/mine` | HTTP 200; Google sign-in succeeded |
| SOS dependency isolation | Scoped source scan of geofence backend, Dart, Kotlin, and Swift code | No AlertHub/SosAlertDispatcher/SosController/foreground-service dependencies found |
| Routine payload | `RoutinePushWorker` payload inspected | Only type, activityId, zoneId; no coordinates |
| Presentation isolation | Scoped geofence presentation scan | No SOS/error red references found |
| Map SDK boundary | Dart import scan | Only `vector_map.dart` imports MapLibre |

Environment: Windows, .NET SDK 9.0.205, EF CLI 9.0.3/runtime 9.0.9, Flutter 3.44.5, Dart 3.12.2, Samsung SM A305F/Android 11/API 30. EF's tool-version warning and Gradle deprecation warnings did not fail the checks.

The first Debug backend test build hit Windows DLL locks from the live API. The successful Release run used separate build output without stopping the API. An earlier interrupted Flutter run was not counted as evidence. Logs under `.planning/tmp/phase04-*` are local, ignored artifacts. The native XML result, not PowerShell's stderr pipeline status, establishes the worker test result.

### Repairs

Commit `76694fa` restores the existing `BatteryIndicator` to `LiveMemberMarker`, expands its projected bounds to 86 x 96, checks the marker in those bounds, and scrolls the splash navigation test's login link into view. The initial Flutter run had 459 passes and 2 failures; the full rerun passed all 461.

### Current Device Setup

- Supabase project is now `dvhxboclavtudtwzifst`; the August accounts and test-zone IDs below are historical, not current fixtures.
- Created `Phase 04 Test Circle`, family ID `40bdffff-c601-47a1-9a8b-7394813dde56`, using the signed-in account's production API.
- The connected account is the test Guardian. Fine/coarse/background location are granted on its Samsung phone.
- The user selected their friend's remote Android phone for the monitored Member and boundary test.
- A 24-hour, single-use Member invitation was generated and given to the user privately. Its code/token is intentionally omitted from this committed document.
- At the last check the family contained only the Guardian and had zero zones. Await the friend's join before selecting their account and a current location for a 100 m zone.
- No current-project registration acknowledgement, real boundary candidate, headless upload, offline replay, push delivery, or SOS concurrency is claimed.
- Signed iPhone/macOS/Xcode/APNs acceptance remains unverified and required by PR-04.

Next: follow `04-REMOTE-ANDROID-VERIFICATION.md` after the friend joins. Do not create 04-05 or 04-17 completion summaries until their physical gates pass.

## Historical Environment Evidence: 2026-08-14

| Tool | Evidence |
|---|---|
| .NET SDK | `9.0.316` |
| dotnet-ef | `9.0.9` via `F:\DevTools\dotnet-tools` with `DOTNET_ROOT=F:\DevTools\dotnet` |
| Flutter | `3.44.9` stable; framework revision `6b182d2c7585eba26d4edce0f97630effd256c33` |
| Dart SDK | `3.12.2` |
| Gradle wrapper | `9.1.0-all` |
| Android Java runtime | Android Studio JBR `25.0.2` for debug build; app unit test also ran successfully under configured Java tooling |

## Historical Automated Gate Results: 2026-08-14

| Gate | Command | Result |
|---|---|---|
| Backend full suite | `F:\DevTools\dotnet\dotnet.exe test backend\SafePath.sln --no-restore` | PASS: 228/228 application tests and 24/24 API integration tests |
| EF database update | `dotnet-ef database update --project backend\src\SafePath.Infrastructure --startup-project backend\src\SafePath.Api` | PASS: database already up to date; no migrations applied |
| EF model drift | `dotnet-ef migrations has-pending-model-changes --project backend\src\SafePath.Infrastructure --startup-project backend\src\SafePath.Api` | PASS: no pending model changes |
| Flutter analyze | `flutter analyze` | PASS: no issues found |
| Flutter full suite | `flutter test` | PASS: 427/427 tests |
| Android debug APK | `flutter build apk --debug --dart-define-from-file=env.json` | PASS: built `mobile\build\app\outputs\flutter-apk\app-debug.apk` |
| Android app unit tests | `mobile\android\gradlew.bat :app:testDebugUnitTest` | PASS: `BUILD SUCCESSFUL` |

Notes:

- The Android build command used `env.json`; secret/env values are intentionally not copied into this artifact.
- Android/Gradle emitted non-blocking warnings about deprecated Kotlin Gradle plugin usage, deprecated Gradle features, and Java source/target 8 warnings in plugin code. The build and app unit gate passed.
- A later attempt to rerun only `test\features\geofencing test\features\sos` was blocked by the command approval layer; the full `flutter test` gate above already executed and covered those test directories.

## Structural Isolation Checks

| Check | Result | Evidence |
|---|---|---|
| Geofence code excludes SOS/foreground-service dependencies | PASS | `rg` found no `AlertHub`, `SosAlertDispatcher`, `SosController`, `flutter_foreground_task`, `ForegroundService`, or foreground-service references in scoped geofence backend/mobile/native paths |
| Routine notification payload contains no coordinates | PASS | Coordinate identifier scan over routine push/feed implementation lines found no latitude/longitude/coordinate payload fields |
| Geofence presentation avoids SOS red styling | PASS | `rg` found no `AppColors.sos`, `AppColors.danger`, `AppColors.error`, `Colors.red`, or locked SOS red literals in `mobile/lib/features/geofencing/presentation` |
| Only `VectorMap` imports MapLibre | PASS | `maplibre_gl` import appears only in `mobile/lib/features/location/presentation/vector_map.dart` |

## Additional Fixes Made During 04-17 Automation

| Commit | Reason |
|---|---|
| `36e3a48` | Cleared the final geofence uploader analyzer infos so `flutter analyze` is green |
| `7e1464a` | Restored per-recipient Privacy Center controls so the full Flutter suite is green and the screen again matches its “each family member” privacy promise |

## Historical Physical Acceptance Status: 2026-08-14

| Platform | Status | Evidence / blocker |
|---|---|---|
| Android physical device | BLOCKED | `adb devices -l` returned no attached devices at verification time. No movement, boundary accuracy, process-death, reboot, permission-revoked, quiet-hours, push/feed/activity, or concurrent SOS evidence was captured. |
| iOS physical device | BLOCKED | Current executor is Windows. No supported macOS/Xcode environment, signed physical iPhone, Always-location authorization, APNs credential, Core Location relaunch, or APNs tap-to-activity evidence was supplied. |

## Required Human Acceptance Before Phase Closure

Android must still prove:

- Guardian creates/reviews/saves a 100 m zone on a real Google Play Services device.
- Background permission is granted after Save and native registration reaches Active ack.
- Ambiguous boundary accuracy does not alert.
- Sustained clear crossing yields exactly one activity/feed/push.
- Swipe/process death and reboot recovery do not duplicate events.
- Cold-relaunch fallback drains pending evidence.
- Permission revocation marks zone inactive.
- Quiet hours create feed now but defer routine push.
- Concurrent SOS remains immediate.

iOS must still prove:

- Signed physical iPhone build on supported macOS/Xcode.
- WhenInUse, Always, denied, and recovery flows.
- 20-region cap behavior.
- Terminated Core Location relaunch and authenticated drain.
- APNs routine push and tap-to-activity.
- Quiet-hours behavior.
- Concurrent SOS remains immediate.

## Verdict

Automated verification is green. Device acceptance is blocked. Phase 4 must remain open until the Android and iOS physical acceptance checklist above is completed with evidence.
