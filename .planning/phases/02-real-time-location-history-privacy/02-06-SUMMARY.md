---
phase: 02-real-time-location-history-privacy
plan: 06
subsystem: mobile-location-shell
tags: [flutter, riverpod, geolocator, google-maps, battery-plus, signalr]

# Dependency graph
requires:
  - phase: 02-real-time-location-history-privacy
    provides: SignalR LocationHubClient, authenticated /hubs/location transport, LocationHub.ReportLocation, GET /families/{id}/live-locations
provides:
  - Five-tab authenticated mobile shell with visually complete but inert SOS center tab
  - Foreground-only Android/iOS location permission and Google Maps key wiring
  - Value-first permission priming flow with CTA-gated Geolocator.requestPermission
  - Battery transparency screen using caution/neutral colors only
  - LocationApi, foreground LocationController, LiveMapScreen, and MemberMapPin
  - Controller tests proving foreground fix reporting, self/member pin state, and auth/family reactive connect/disconnect
affects: [02-07, 02-08, 02-09, 03-sos-fast-path]

# Tech tracking
tech-stack:
  added:
    - google_maps_flutter 2.17.1
    - geolocator 14.0.3
    - battery_plus 7.1.0
  patterns:
    - "Mobile location features use injectable Riverpod seams for OS permission, position streams, and battery level so tests never call platform APIs."
    - "LocationController opens the hub only after AuthAuthenticated plus a loaded family, and tears down on sign-out."
    - "Foreground-only location streaming uses Geolocator.getPositionStream with LocationSettings(accuracy: high, distanceFilter: 10)."

key-files:
  created:
    - mobile/lib/features/home/presentation/main_shell.dart
    - mobile/lib/features/location/application/permission_controller.dart
    - mobile/lib/features/location/application/location_controller.dart
    - mobile/lib/features/location/data/location_api.dart
    - mobile/lib/features/location/presentation/permission_priming_screen.dart
    - mobile/lib/features/location/presentation/battery_transparency_screen.dart
    - mobile/lib/features/location/presentation/live_map_screen.dart
    - mobile/lib/shared_widgets/member_map_pin.dart
    - mobile/test/features/location/permission_priming_screen_test.dart
    - mobile/test/features/location/location_controller_test.dart
    - mobile/test/helpers/fake_location_api.dart
  modified:
    - mobile/pubspec.yaml
    - mobile/pubspec.lock
    - mobile/android/app/build.gradle.kts
    - mobile/android/app/src/main/AndroidManifest.xml
    - mobile/ios/Runner/AppDelegate.swift
    - mobile/ios/Runner/Info.plist
    - mobile/lib/core/router/app_router.dart
    - mobile/lib/core/theme/app_colors.dart
    - mobile/lib/features/location/data/location_hub_client.dart
    - mobile/lib/features/location/data/location_models.dart
    - mobile/test/helpers/fake_location_hub_client.dart

key-decisions:
  - "Google Maps API keys are wired through build-time placeholders rather than hardcoded secrets because no MAPS_API_KEY_* environment variables were available in the executor shell."
  - "Location permission prompting is split into an injectable permission service and a Notifier so initial render can safely call checkPermission without ever triggering requestPermission."
  - "LocationHubClient now exposes reportLocation because the existing P01 client only subscribed to hub events and P06 requires mobile GPS fixes to reach LocationHub.ReportLocation."
  - "Activity, Privacy, and Insights remain explicit placeholders in the shell; Map is live in this plan, while those tabs are owned by later phase plans."

patterns-established:
  - "Use hand-written fakes and ProviderContainer overrides for mobile location controller tests."
  - "Do not request Always/background location in manifests or install background location packages for Phase 2."
  - "Keep SOS visual chrome present in the shell but functionally inert until Phase 3."

requirements-completed: [LOC-01, LOC-04, LOC-05]

coverage:
  - id: D1
    description: "Authenticated /home route now builds a five-tab MainShell with Map, Activity, inert SOS, Insights, and Privacy tabs."
    requirement: LOC-01
    verification:
      - kind: integration
        ref: "flutter analyze"
        status: pass
    human_judgment: true
    rationale: "Visual fidelity of the bottom navigation and raised SOS button still needs human/device review."
  - id: D2
    description: "Foreground-only platform location permissions and Maps key wiring are present without background/Always permission strings."
    requirement: LOC-05
    verification:
      - kind: other
        ref: "Select-String AndroidManifest.xml/Info.plist for foreground permissions and absence of ACCESS_BACKGROUND_LOCATION / NSLocationAlwaysAndWhenInUseUsageDescription"
        status: pass
      - kind: integration
        ref: "flutter analyze"
        status: pass
    human_judgment: false
  - id: D3
    description: "Permission priming screen gates Geolocator.requestPermission behind the 'Turn on location sharing' CTA."
    requirement: LOC-05
    verification:
      - kind: automated_ui
        ref: "mobile/test/features/location/permission_priming_screen_test.dart#does not request OS permission until the location-sharing CTA is tapped"
        status: pass
    human_judgment: false
  - id: D4
    description: "Battery transparency screen explains foreground tracking's light battery usage and avoids SOS-red styling."
    requirement: LOC-04
    verification:
      - kind: integration
        ref: "flutter analyze"
        status: pass
      - kind: other
        ref: "Select-String battery_transparency_screen.dart -Pattern sosRed"
        status: pass
    human_judgment: true
    rationale: "Copy tone and visual balance should be reviewed on-device even though static checks pass."
  - id: D5
    description: "LocationController streams foreground Geolocator fixes, attaches battery level, reports through LocationHub.ReportLocation, updates the self pin, handles hub LocationUpdated events, and disconnects on sign-out."
    requirement: LOC-01
    verification:
      - kind: unit
        ref: "mobile/test/features/location/location_controller_test.dart"
        status: pass
      - kind: integration
        ref: "flutter test test/features/location"
        status: pass
    human_judgment: false

duration: 18min
completed: 2026-07-12
status: complete
---

# Phase 02 Plan 06: Mobile Shell + Permission Priming + Live Map Summary

**Flutter location gateway with a five-tab shell, CTA-gated location permission, battery transparency, and foreground self-location map reporting through SignalR.**

## Performance

- **Duration:** 18 min
- **Started:** 2026-07-12T20:20:35Z
- **Completed:** 2026-07-12T20:38:52Z
- **Tasks:** 3 completed
- **Files modified:** 22 plan files plus this summary

## Accomplishments

- Replaced the authenticated landing stub with a five-tab `MainShell`; the center SOS tab is visually complete and inert, while Map hosts the real live map.
- Added `google_maps_flutter`, `geolocator`, and `battery_plus`, plus foreground-only Android/iOS permission and Maps key wiring.
- Added value-first permission priming with a widget test proving the OS request path is CTA-gated.
- Added battery transparency UI using caution/neutral styling only.
- Added mobile live-location data/API/controller/map plumbing so foreground fixes report through the existing SignalR hub and update self/member pin state.

## Task Commits

Each implementation task was committed atomically:

1. **Task 1: Add map/location deps + foreground-only manifests + 5-tab shell** - `d062edb` (feat)
2. **Task 2: Permission-priming + battery-transparency screens** - `92e793e` (feat)
3. **Task 3 RED: Location controller behavior tests** - `176f258` (test)
4. **Task 3 GREEN: Foreground streaming + Live Map self-pin** - `e97b072` (feat)

**Plan metadata:** pending close-out commit

## Files Created/Modified

- `mobile/lib/features/home/presentation/main_shell.dart` - Five-tab shell and inert SOS center tab.
- `mobile/lib/core/router/app_router.dart` - `/home` now builds `MainShell`; adds `/permission-priming` and `/battery-info`.
- `mobile/lib/core/theme/app_colors.dart` - Phase 2 color tokens for safe backgrounds, hairlines, toggle-off, and member identity colors.
- `mobile/android/app/src/main/AndroidManifest.xml` - FINE/COARSE foreground permissions and Maps metadata.
- `mobile/android/app/build.gradle.kts` - Build-time `MAPS_API_KEY_ANDROID` manifest placeholder.
- `mobile/ios/Runner/Info.plist` / `AppDelegate.swift` - WhenInUse permission copy and `MAPS_API_KEY_IOS` handoff to Google Maps.
- `mobile/lib/features/location/application/permission_controller.dart` - Injectable Geolocator permission flow.
- `mobile/lib/features/location/presentation/permission_priming_screen.dart` - Value-first permission CTA and denial states.
- `mobile/lib/features/location/presentation/battery_transparency_screen.dart` - Battery transparency explainer.
- `mobile/lib/features/location/data/location_api.dart` - Dio REST client for live locations.
- `mobile/lib/features/location/application/location_controller.dart` - Auth/family-reactive foreground location controller.
- `mobile/lib/features/location/presentation/live_map_screen.dart` - Google Map with self/member markers and empty/error states.
- `mobile/lib/shared_widgets/member_map_pin.dart` - Reusable member pin/avatar dot.
- `mobile/lib/features/location/data/location_hub_client.dart` / `location_models.dart` - Added `ReportLocation` client call and payload model.
- `mobile/test/features/location/*.dart` and `mobile/test/helpers/fake_location_api.dart` - Location widget/controller coverage and fakes.

## Decisions Made

- Maps keys are placeholders (`MAPS_API_KEY_ANDROID`, `MAPS_API_KEY_IOS`) instead of hardcoded values because the executor environment did not expose provisioned key variables.
- `LocationController` mirrors `FamilyController`'s auth-reactive pattern but also listens for family bootstrap completion before opening the hub.
- Battery level is read through a `FutureProvider<int?>` seam so controller tests stay platform-free.
- The Phase 2 shell intentionally keeps Activity, Privacy, and Insights as placeholders; later plans own those tabs.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added compile-safe Task 2 screen shells during Task 1**
- **Found during:** Task 1 router wiring
- **Issue:** Task 1 required routes to `/permission-priming` and `/battery-info`, but Task 2 owned the actual screen implementations. The router could not analyze against missing imports.
- **Fix:** Added temporary compile-safe screen shells in Task 1, then replaced them with final implementations in Task 2.
- **Files modified:** `permission_priming_screen.dart`, `battery_transparency_screen.dart`
- **Verification:** `flutter analyze lib/features/home lib/core/router lib/core/theme`; later `flutter test test/features/location/permission_priming_screen_test.dart`
- **Committed in:** `d062edb`, finalized in `92e793e`

**2. [Rule 2 - Missing Critical] Added build-time Maps key plumbing beyond the manifest**
- **Found during:** Task 1 platform setup
- **Issue:** A literal Android manifest placeholder needs Gradle wiring, and iOS `google_maps_flutter` needs `GMSServices.provideAPIKey`; Info.plist alone would not initialize Maps.
- **Fix:** Added `manifestPlaceholders["MAPS_API_KEY_ANDROID"]` and AppDelegate reads `MAPS_API_KEY_IOS` from Info.plist before providing it to Google Maps.
- **Files modified:** `mobile/android/app/build.gradle.kts`, `mobile/ios/Runner/AppDelegate.swift`, `mobile/ios/Runner/Info.plist`
- **Verification:** `flutter analyze`; platform grep for key entries and no background/Always permissions.
- **Committed in:** `d062edb`

**3. [Rule 2 - Missing Critical] Added LocationHubClient.reportLocation**
- **Found during:** Task 3 implementation
- **Issue:** The existing P01 mobile hub client subscribed to updates but had no method for sending GPS fixes to `LocationHub.ReportLocation`, which P06 needs for LOC-01.
- **Fix:** Added `ReportLocationPayload`, `LocationHubClient.reportLocation`, SignalR invoke wiring, and fake assertions.
- **Files modified:** `location_hub_client.dart`, `location_models.dart`, `fake_location_hub_client.dart`
- **Verification:** `flutter test test/features/location/location_controller_test.dart`
- **Committed in:** `e97b072`

**4. [Rule 1 - Bug] Fixed async teardown after Riverpod dispose**
- **Found during:** Task 3 GREEN test run
- **Issue:** `_stop()` read providers during `onDispose`, which Riverpod rejects after a provider is disposed.
- **Fix:** Cached the hub client while mounted and used the cached instance during teardown; updated the fake to tolerate late disconnect state emissions.
- **Files modified:** `location_controller.dart`, `fake_location_hub_client.dart`
- **Verification:** `flutter test test/features/location/location_controller_test.dart`
- **Committed in:** `e97b072`

---

**Total deviations:** 4 auto-fixed (2 Rule 2 missing critical, 1 Rule 3 blocking, 1 Rule 1 bug)
**Impact on plan:** All deviations were required to make the planned routes, Maps setup, and live reporting work without widening the feature scope.

## Issues Encountered

- No `MAPS_API_KEY_ANDROID` / `MAPS_API_KEY_IOS` environment variables were visible to the executor. The app is wired for placeholders, but actual map tiles still require key values during local/device builds.
- `ctx7` was not installed, so package API details were verified from installed package source after `flutter pub add` and pub.dev pages were consulted.

## User Setup Required

External service configuration is still required before map tiles render on device:

- Provide `MAPS_API_KEY_ANDROID` as a Gradle property for Android builds.
- Provide `MAPS_API_KEY_IOS` through the iOS build settings / generated Info.plist value.
- Ensure the keys are restricted in Google Cloud Console to the Android package/signature and iOS bundle ID.

## Known Stubs

| File | Line | Stub | Reason |
|------|------|------|--------|
| `mobile/lib/features/home/presentation/main_shell.dart` | 49 | "Location history is coming soon." | Activity tab is owned by Phase 02 plans 04/08. |
| `mobile/lib/features/home/presentation/main_shell.dart` | 54 | "Emergency tools are coming soon." | SOS behavior is intentionally deferred to Phase 03; this plan only renders inert chrome. |
| `mobile/lib/features/home/presentation/main_shell.dart` | 59 | "Insights are coming soon" | Insights are Phase 05 scope. |
| `mobile/lib/features/home/presentation/main_shell.dart` | 64 | "Privacy controls are coming soon." | Privacy Center mobile UI is Phase 02 plan 09 scope. |
| `mobile/android/app/build.gradle.kts` | 18, 32 | Flutter scaffold TODOs | Pre-existing Flutter project TODOs for application ID/signing; unrelated to this plan. |

## Verification

- `flutter test test/features/location` - passed, 4 tests.
- `flutter analyze` - passed.
- `flutter analyze lib/features/home lib/core/router lib/core/theme` - passed during Task 1.
- `flutter test test/features/location/permission_priming_screen_test.dart` - passed during Task 2.
- `flutter test test/features/location/location_controller_test.dart` - passed during Task 3 GREEN.
- Platform grep confirmed no `ACCESS_BACKGROUND_LOCATION` and no `NSLocationAlwaysAndWhenInUseUsageDescription`.
- `Select-String location_controller.dart` confirmed `Geolocator.getPositionStream` with `LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10)`.

## TDD Gate Compliance

- RED commit present: `176f258`
- GREEN commit present after RED: `e97b072`
- No refactor commit was needed.

## Next Phase Readiness

- Plan 02-07 can expand the `LocationState` and `LiveMapScreen` with staleness, accuracy radius, online/offline, and low-battery presentation.
- Plan 02-08 can replace the Activity placeholder with history timeline/route/stat screens.
- Plan 02-09 can replace the Privacy placeholder with the mobile Privacy Center.
- Phase 03 can replace the inert SOS SnackBar with the real press-and-hold emergency flow.

---
*Phase: 02-real-time-location-history-privacy*
*Completed: 2026-07-12*

## Self-Check: PASSED

Created/modified plan artifacts exist on disk (`main_shell.dart`, `permission_controller.dart`, `location_controller.dart`, `location_api.dart`, `live_map_screen.dart`, `02-06-SUMMARY.md`); task commits `d062edb`, `92e793e`, `176f258`, and `e97b072` are present in git log; final verification commands listed above passed.
