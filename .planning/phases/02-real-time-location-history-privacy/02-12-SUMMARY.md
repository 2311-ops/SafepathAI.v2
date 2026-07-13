---
phase: 02-real-time-location-history-privacy
plan: 12
subsystem: ui
tags: [flutter_map, latlong2, openstreetmap, flutter, mobile, map-rendering]

# Dependency graph
requires:
  - phase: 02-real-time-location-history-privacy (plans 02-06/02-08)
    provides: The original google_maps_flutter-based live_map_screen.dart and route_stats_sheet.dart this plan retrofits
provides:
  - "mobile/lib/features/location/presentation/live_map_screen.dart on flutter_map (FlutterMap + TileLayer + CircleLayer + MarkerLayer + SimpleAttributionWidget)"
  - "mobile/lib/features/location/presentation/route_stats_sheet.dart on flutter_map (FlutterMap + TileLayer + PolylineLayer + MarkerLayer + SimpleAttributionWidget)"
  - "No API key / no billing OSM tile rendering for the whole mobile app"
  - "A flutter_map renderer Phase 4 geofencing can draw safe-zone circles on without a Maps SDK key"
affects: [phase-04-geofencing, mobile-location-feature]

# Tech tracking
tech-stack:
  added: ["flutter_map ^8.0.0 (resolved 8.3.1)", "latlong2 ^0.9.0 (resolved 0.9.1)"]
  patterns:
    - "TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.safepath.mobile') repeated identically on every map surface"
    - "SimpleAttributionWidget(source: Text('OpenStreetMap contributors')) as the last child in every FlutterMap.children list (OSM ToS requirement)"
    - "Marker.child wraps identity/tap/opacity behavior since flutter_map Markers carry no alpha/onTap of their own (private _LiveMemberMarker / _StopMarker widgets)"
    - "CircleMarker(useRadiusInMeter: true) for geographic (meter-scaled) accuracy circles instead of pixel-radius circles"
    - "Widget tests pump(Duration) instead of pumpAndSettle() around FlutterMap to avoid hanging on unresolved network tile requests in the test harness"

key-files:
  created:
    - mobile/test/features/location/route_stats_sheet_test.dart
  modified:
    - mobile/pubspec.yaml
    - mobile/pubspec.lock
    - mobile/lib/features/location/presentation/live_map_screen.dart
    - mobile/lib/features/location/presentation/route_stats_sheet.dart
    - mobile/android/app/src/main/AndroidManifest.xml
    - mobile/android/app/build.gradle.kts
    - mobile/ios/Runner/AppDelegate.swift
    - mobile/ios/Runner/Info.plist
    - mobile/test/features/location/live_map_screen_test.dart
    - .planning/phases/02-real-time-location-history-privacy/02-01-USER-SETUP.md

key-decisions:
  - "flutter_map ^8.0.0 + latlong2 ^0.9.0 are the sole OSM stack (per .claude/CLAUDE.md and 02-OSM-MIGRATION-IMPACT.md); no other map/tile package was added"
  - "SimpleAttributionWidget chosen over RichAttributionWidget because Rich collapses to an 'i' icon and does not reliably keep 'OpenStreetMap' text on screen"
  - "Numbered azure _StopMarker pin replaces the old tap-to-reveal InfoWindow('Stop N') with an always-visible equivalent, since flutter_map Markers have no info-window concept"

patterns-established:
  - "OSM TileLayer + attribution block is now the canonical map-surface pattern for any future map screen (e.g. Phase 4 geofence circles)"

requirements-completed: [LOC-01, LOC-02, LOC-04, HIST-02]

coverage:
  - id: D1
    description: "Live map renders self + family markers, each faded by staleness, with a geographic accuracy-radius circle per member, on flutter_map/OSM"
    requirement: "LOC-01"
    verification:
      - kind: unit
        ref: "mobile/test/features/location/live_map_screen_test.dart#populated live locations render on a FlutterMap with OSM attribution"
        status: pass
    human_judgment: false
  - id: D2
    description: "Tapping a member marker opens the member detail sheet with the same name/status/last-seen values as before the migration"
    requirement: "LOC-02"
    verification:
      - kind: unit
        ref: "mobile/lib/features/location/presentation/live_map_screen.dart (_LiveMemberMarker GestureDetector -> showMemberDetailSheet, unchanged MemberDetail fields)"
        status: pass
    human_judgment: true
    rationale: "The existing test suite verifies the marker/tap wiring compiles and the sheet function is called with correct arguments in isolation (member_presence_test.dart), but no automated test drives an actual marker tap through the live FlutterMap widget tree to confirm the sheet visually opens — reserved for human UAT."
  - id: D3
    description: "Accuracy circle keeps meter semantics (scales with zoom) via CircleMarker(useRadiusInMeter: true)"
    requirement: "LOC-04"
    verification:
      - kind: unit
        ref: "grep -c 'useRadiusInMeter' mobile/lib/features/location/presentation/live_map_screen.dart -> 1"
        status: pass
    human_judgment: false
  - id: D4
    description: "Route history renders a polyline of past travel plus stop markers, with distance/time-away/stops stat tiles unchanged, on flutter_map/OSM"
    requirement: "HIST-02"
    verification:
      - kind: unit
        ref: "mobile/test/features/location/route_stats_sheet_test.dart#route history renders on a FlutterMap with OSM attribution and stat tiles"
        status: pass
    human_judgment: false
  - id: D5
    description: "Visible OpenStreetMap attribution present on both the live map and route-history map"
    verification:
      - kind: unit
        ref: "mobile/test/features/location/live_map_screen_test.dart and mobile/test/features/location/route_stats_sheet_test.dart both assert find.textContaining('OpenStreetMap')"
        status: pass
    human_judgment: false
  - id: D6
    description: "No google_maps_flutter reference remains in mobile/lib, pubspec.yaml, or Android/iOS native config; flutter analyze on location is clean; full mobile test suite passes"
    verification:
      - kind: unit
        ref: "flutter analyze lib/features/location -> No issues found!; flutter test -> 164 passed"
        status: pass
    human_judgment: false

duration: 20min
completed: 2026-07-13
status: complete
---

# Phase 2 Plan 12: OSM Map-Rendering Migration Summary

**Retrofitted `live_map_screen.dart` and `route_stats_sheet.dart` from `google_maps_flutter` to `flutter_map` + `latlong2`, removing the Google Cloud Maps SDK billing/API-key dependency across pubspec, Android manifest/gradle, and iOS AppDelegate/Info.plist.**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-07-13 (context load) — first commit 2026-07-13T10:55:59+03:00
- **Completed:** 2026-07-13T11:05:22+03:00
- **Tasks:** 3 completed (Task 2 and Task 3 each RED/GREEN TDD pairs)
- **Files modified:** 10 (9 modified, 1 created)

## Accomplishments
- `pubspec.yaml` on `flutter_map ^8.0.0` + `latlong2 ^0.9.0`, zero `google_maps_flutter` anywhere in `mobile/lib`, `pubspec.yaml`, `pubspec.lock`, or Android/iOS native config
- `live_map_screen.dart` rewritten onto `FlutterMap` + `TileLayer(OSM)` + `CircleLayer` (meter-scaled accuracy circles via `useRadiusInMeter`) + `MarkerLayer` (staleness-faded, tap-to-detail-sheet markers via new `_LiveMemberMarker`) + `SimpleAttributionWidget`
- `route_stats_sheet.dart` rewritten onto `FlutterMap` + `TileLayer(OSM)` + `PolylineLayer` (route path) + `MarkerLayer` (numbered stop pins via new `_StopMarker`) + `SimpleAttributionWidget`; distance/time-away/stops `StatTile` row unchanged
- All native Google Maps key wiring removed: Android manifest `com.google.android.geo.API_KEY` meta-data, `build.gradle.kts` `MAPS_API_KEY_ANDROID` placeholder, iOS `AppDelegate.swift` `import GoogleMaps`/`GMSServices.provideAPIKey`, `Info.plist` `MAPS_API_KEY_IOS` key
- `02-01-USER-SETUP.md` updated with a dated SUPERSEDED banner on the Google Maps sections plus an active "OpenStreetMap setup (active)" section covering the no-API-key path, attribution requirement, and the pre-production tile-provider caveat
- New `route_stats_sheet_test.dart` and extended `live_map_screen_test.dart` both assert `find.byType(FlutterMap)` + visible `OpenStreetMap` attribution against populated state
- `flutter analyze lib/features/location` reports "No issues found!"; full `flutter test` suite (164 tests) passes

## Task Commits

Each task was committed atomically, with Tasks 2 and 3 following the RED/GREEN TDD gate:

1. **Task 1: Swap the map dependency and strip all Google Maps native wiring + setup docs** - `799cf94` (feat)
2. **Task 2: Rewrite live_map_screen.dart onto flutter_map and extend its widget test**
   - `2e96428` (test — RED: new populated-map assertion fails to compile without flutter_map)
   - `8ad8ee3` (feat — GREEN: live_map_screen.dart rewritten, all 6 tests pass)
3. **Task 3: Rewrite route_stats_sheet.dart onto flutter_map, add its render test, and run full regression**
   - `e230249` (test — RED: new route_stats_sheet_test.dart fails to compile)
   - `567c38f` (feat — GREEN: route_stats_sheet.dart rewritten, analyze clean, full suite green)

**Plan metadata:** (this commit)

## Files Created/Modified
- `mobile/pubspec.yaml` - `google_maps_flutter` removed; `flutter_map ^8.0.0` + `latlong2 ^0.9.0` added
- `mobile/pubspec.lock` - regenerated via `flutter pub get`
- `mobile/lib/features/location/presentation/live_map_screen.dart` - GoogleMap/Marker/Circle/BitmapDescriptor replaced with FlutterMap/TileLayer/CircleLayer/MarkerLayer; new `_LiveMemberMarker` private widget carries staleness opacity + tap
- `mobile/lib/features/location/presentation/route_stats_sheet.dart` - GoogleMap/Polyline/Marker/BitmapDescriptor/InfoWindow replaced with FlutterMap/TileLayer/PolylineLayer/MarkerLayer; new `_StopMarker` private widget renders a numbered pin
- `mobile/android/app/src/main/AndroidManifest.xml` - `com.google.android.geo.API_KEY` meta-data element removed
- `mobile/android/app/build.gradle.kts` - `manifestPlaceholders["MAPS_API_KEY_ANDROID"]` statement removed
- `mobile/ios/Runner/AppDelegate.swift` - `import GoogleMaps` and `GMSServices.provideAPIKey` block removed
- `mobile/ios/Runner/Info.plist` - `MAPS_API_KEY_IOS` key/value pair removed
- `mobile/test/features/location/live_map_screen_test.dart` - added populated-map render test (`FlutterMap` + OSM attribution assertions)
- `mobile/test/features/location/route_stats_sheet_test.dart` - new file; route map render test (`FlutterMap` + OSM attribution + stat tile assertions)
- `.planning/phases/02-real-time-location-history-privacy/02-01-USER-SETUP.md` - Google Maps sections marked superseded; active OSM setup section added

## Decisions Made
- `flutter_map ^8.0.0` + `latlong2 ^0.9.0` are the sole OSM stack (resolved to 8.3.1 / 0.9.1) — no `flutter_map_marker_cluster` or alternative tile package added, matching the plan's threat-model constraint (T-02-SC)
- `SimpleAttributionWidget` (not `RichAttributionWidget`) used on both map surfaces because Rich collapses to an "i" icon that would not reliably keep "OpenStreetMap" text visible, and the plan's must-have truth requires *visible* attribution
- `_StopMarker`'s always-visible numbered pin is treated as the equivalent successor to the old tap-to-reveal `InfoWindow('Stop N')`, since flutter_map has no info-window primitive

## Deviations from Plan

None — plan executed exactly as written. Task 1's mandated `grep -rln "GoogleMaps\|MAPS_API_KEY\|com.google.android.geo"` sweep confirmed the actual surface matched the plan's stated list exactly (only a build-cache binary file matched, not source).

One micro-correction caught during Task 3's acceptance-criteria verification: an initial doc comment on `_StopMarker` said `InfoWindow('Stop N')`, which itself matched the negative grep `BitmapDescriptor\|InfoWindow\|PolylineId\|CameraPosition\|GoogleMap` the plan uses to prove the old API surface is gone. Reworded the comment to describe the behavior without naming the removed symbol before committing — not logged as a numbered deviation since it was corrected pre-commit and never landed in the committed code.

## Issues Encountered
None.

## User Setup Required
None — this plan removes the external-service requirement rather than adding one. `02-01-USER-SETUP.md` now documents the no-API-key OSM path; see [02-01-USER-SETUP.md](./02-01-USER-SETUP.md).

## Next Phase Readiness
- Phase 4 (Geofencing) can now draw safe-zone circles via the same `CircleLayer`/`CircleMarker` pattern established here, with no Maps SDK key dependency.
- Deferred verification: iOS `pod install`/`xcodebuild` after the GoogleMaps pod drops out cannot run on this Windows dev box — source-level acceptance (no `GoogleMaps`/`GMSServices`/`MAPS_API_KEY_IOS` references in `AppDelegate.swift`/`Info.plist`) is confirmed here; the actual iOS compile must be validated on a macOS/CI runner before an iOS build is attempted.
- Before production traffic, a dedicated tile-hosting provider (MapTiler/Stadia Maps/Thunderforest) must replace the raw `tile.openstreetmap.org` URL per OSM's tile usage policy — documented in `02-01-USER-SETUP.md`.

---
*Phase: 02-real-time-location-history-privacy*
*Completed: 2026-07-13*
