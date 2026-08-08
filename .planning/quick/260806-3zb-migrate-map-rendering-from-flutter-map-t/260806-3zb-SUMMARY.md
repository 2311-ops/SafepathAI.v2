---
phase: quick/260806-3zb-migrate-map-rendering-from-flutter-map-t
plan: 260806-3zb
subsystem: mobile-location
tags: [maplibre_gl, openfreemap, vector-tiles, flutter, live-map, route-history]

requires:
  - phase: 02-real-time-location-history-privacy
    provides: FlutterMap/OSM raster-tile Live Map and route-history sheet (superseded by this migration)
provides:
  - VectorMap widget (mobile/lib/features/location/presentation/vector_map.dart) as the single maplibre_gl import point
  - map_geometry.dart (MapPoint, geodesicRing) for metre-accurate accuracy circles
  - Both LiveMapScreen and RouteStatsSheet rendering OpenFreeMap Liberty vector tiles
affects: [mobile-map-rendering, 02-real-time-location-history-privacy]

tech-stack:
  added: [maplibre_gl ^0.26.2]
  patterns:
    - Single-file plugin ownership (VectorMap) with grep-gate enforcement
    - Screen-space widget overlay pins reprojected via toScreenLocationBatch, native annotations for geometry-only shapes (circle fill/outline, polyline)
    - Camera-command sink (VectorMapController) replacing a test-owned native map controller

key-files:
  created:
    - mobile/lib/features/location/application/map_geometry.dart
    - mobile/lib/features/location/presentation/vector_map.dart
    - mobile/test/features/location/map_geometry_test.dart
    - mobile/test/features/location/vector_map_test.dart
  modified:
    - mobile/lib/features/location/presentation/live_map_screen.dart
    - mobile/lib/features/location/presentation/route_stats_sheet.dart
    - mobile/test/features/location/live_map_screen_test.dart
    - mobile/test/features/location/route_stats_sheet_test.dart
    - mobile/pubspec.yaml
    - .claude/CLAUDE.md

key-decisions:
  - "JVM target bump to 21 and NDK version pin were NOT needed - maplibre_gl 0.26.2 linked cleanly against the existing JavaVersion.VERSION_17 / Kotlin JVM_17 app module on the first flutter build apk --debug attempt (research assumption A1 settled: no bump required)."
  - "latlong2 is kept as a direct pubspec dependency per research recommendation even though no file under mobile/lib or mobile/test imports it anymore post-migration - documented as an intentional discrepancy, not silently removed."
  - "Rail-card tap now animates (~300ms) via VectorMapController.animateTo instead of the previous instant jump - D-03 discretion, a strict superset of prior behavior."
  - "Route polyline end caps are squared off, not rounded - LineOptions exposes no cap property on maplibre_gl 0.26.2 - accepted cosmetic parity gap under D-03, not worked around via raw GeoJSON layers."
  - "Attribution moved entirely from a hand-written Flutter Text widget to the renderer's native bottom-right attribution control fed by OpenFreeMap's TileJSON - the two deleted textContaining('OpenStreetMap') test assertions are replaced by Task 3 step 10's manual on-device check, not left uncovered."
  - "[Rule 1 bug fix #1, post-Task-3-attempt] MapLibreMap.useHybridComposition must be explicitly set to true in VectorMap.initState() - the plugin's own doc comment claims true is the default but the underlying static field actually defaults to false, silently rendering via legacy Virtual-Display mode on Android. This was real and necessary (confirmed via logcat moving from virtual-display to real view-hierarchy hosting) but turned out NOT to be sufficient on its own to fix pin visibility - see the second fix below. The plan's own threat register (T-3ZB-03) already assumed hybrid composition would be active; the flag was simply never flipped in the original Task 2 implementation. Found via the coordinator's own on-device Task 3 verification (emulator-5554, Pixel 6 API 36) - see Deviations section."
  - "[Rule 1 bug fix #2, post-Task-3-re-attempt] toScreenLocationBatch/toScreenLocation return PHYSICAL pixel coordinates from the native Android side, but Positioned/Offset in the Flutter widget layer operate in LOGICAL pixels - confirmed by the coordinator's own device instrumentation (a marker at the exact camera-centre coordinate projected to Point(540.75, 1200.9375), exactly half of the device's 1080x2400 PHYSICAL screen size at devicePixelRatio 2.625, not the ~206/~457 logical centre). Fixed by dividing every returned point by MediaQuery.devicePixelRatioOf(context), captured synchronously before the toScreenLocationBatch await. Extracted as a small @visibleForTesting pure function (physicalToLogicalOffset) with a dedicated unit-test file (vector_map_test.dart) so this exact regression is locked down without needing a full on-device pass to catch it again."
  - "[Rule 1 bug fix #3, found by automated code review --full mode after Task 3 closed] _VectorMapState.dispose() only removed widget.controller's listener (_onCameraCommand), never the native MapLibreMapController's listener (_onControllerNotified) added in _onMapCreated - asymmetric with every other listener in the class. A camera-changed notification firing after dispose() but before the platform view itself tears down (a real race popping the screen or switching tabs mid-pan) would still run _onControllerNotified -> _reprojectMarkers(), which read MediaQuery.devicePixelRatioOf(context) before its only await with the `mounted` guard only checked after - a null-check crash in both debug and release. Fixed with two changes: dispose() now also calls _mapController?.removeListener(_onControllerNotified); and the `mounted` check in _reprojectMarkers() moved to its very first line, before context or _mapController are touched. No regression test added (see Deviations) - the existing test seam never populates _mapController in any current test, so simulating this race would require constructing a real plugin-internal MapLibreMapController; documented via code comments at both fix sites per the reviewer's own explicit fallback guidance. This is a dispose-path-only change with no rendering-path impact, so it did not require another on-device pass."

requirements-completed: [QUICK-MAP-VECTOR-RENDERER, QUICK-MAP-OPENFREEMAP-LIBERTY, QUICK-MAP-FLAT-NO-TILT, QUICK-MAP-PARITY-FLAGGED]

coverage:
  - id: D1
    description: "geodesicRing()/MapPoint produce a closed, metre-accurate ring (not screen-pixel) so the accuracy indicator keeps a constant real-world footprint at every zoom"
    requirement: "QUICK-MAP-VECTOR-RENDERER"
    verification:
      - kind: unit
        ref: "mobile/test/features/location/map_geometry_test.dart#geodesicRing (11 cases: closure, lat/lng span, doubling, segments, non-positive/NaN/infinite/near-polar guards)"
        status: pass
    human_judgment: false
  - id: D2
    description: "VectorMap is the single file under mobile/lib importing maplibre_gl; both screens describe markers/circles/lines without touching a plugin type"
    requirement: "QUICK-MAP-VECTOR-RENDERER"
    verification:
      - kind: unit
        ref: "grep -rln 'package:maplibre_gl' lib | grep -v vector_map.dart (empty)"
        status: pass
      - kind: unit
        ref: "flutter analyze --no-pub (0 issues)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Family pins remain the exact LiveMemberMarker widget (avatar, name pill, ONLINE/OFFLINE badge, battery, staleness opacity, tap-to-detail), are actually reprojected to real on-screen coordinates, and become visible on a real device - not just structurally present in a widget-test tree with an injected platform-view stand-in"
    requirement: "QUICK-MAP-VECTOR-RENDERER"
    verification:
      - kind: unit
        ref: "mobile/test/features/location/live_member_marker_test.dart (7/7, file untouched)"
        status: pass
      - kind: unit
        ref: "mobile/test/features/location/live_map_screen_test.dart#populated live locations render on a VectorMap with online/offline status"
        status: pass
      - kind: unit
        ref: "mobile/test/features/location/vector_map_test.dart#physicalToLogicalOffset (3 cases: exact regression values, devicePixelRatio-1.0 no-op, integer Point coordinates)"
        status: pass
      - kind: manual_procedural
        ref: "Task 3 third on-device pass (emulator-5554, Pixel 6 API 36) against b5aa00b: avatar/name pill/ONLINE badge/100% battery all visible; accessibility dump confirms the marker's semantics node with correct bounds and clickable=true; tap opens the member detail sheet with correct name/status/last-seen/battery; pin correctly tracked and re-settled after a significant pan"
        status: pass
    human_judgment: true
    rationale: "The widget-test suite injects a SizedBox.expand() platform-view stand-in and never exercises the real toScreenLocationBatch/native-projection path, so it could not (and did not) catch either of the two on-device-only bugs found across two earlier Task 3 attempts: (1) Virtual-Display screen-projection (fixed in 015bc72) and (2) physical-vs-logical pixel mismatch (fixed in b5aa00b). Both are now confirmed on a real device per the coordinator's third pass. One narrower gap remains undemonstrated: staleness-opacity fading specifically was not visually confirmed, since the only available test account has a single (self) member and isSelf always renders at full opacity regardless of staleness per the widget's own logic - the fading behavior itself is unit-tested (live_member_marker_test.dart's 'family member marker still fades when its ping is stale'), just not exercised end-to-end against a real stale multi-member family circle on device. See 'Known Gaps' in the SUMMARY body."
  - id: D4
    description: "Rail-card tap writes the correct camera-command intent (lat/lng/zoom 17) through VectorMapController without opening the member detail sheet"
    requirement: "QUICK-MAP-VECTOR-RENDERER"
    verification:
      - kind: unit
        ref: "mobile/test/features/location/live_map_screen_test.dart#tapping a rail card recenters the map on that member and does not open the detail sheet"
        status: pass
    human_judgment: false
  - id: D5
    description: "Route sheet renders its teal polyline and numbered stop pins through VectorMap with stat tiles intact"
    requirement: "QUICK-MAP-VECTOR-RENDERER"
    verification:
      - kind: unit
        ref: "mobile/test/features/location/route_stats_sheet_test.dart#route history renders on a VectorMap with stat tiles"
        status: pass
      - kind: unit
        ref: "mobile/test/features/location/vector_map_test.dart#physicalToLogicalOffset (same conversion function route-sheet stop pins depend on, via the shared VectorMap/_reprojectMarkers mechanism)"
        status: pass
    human_judgment: true
    rationale: "Route-stop OverlayMarkers share the exact same VectorMap/_reprojectMarkers/physicalToLogicalOffset mechanism as the now-on-device-confirmed member pins (D3), and the underlying conversion function is directly unit-tested, but the coordinator could not visually confirm the route sheet itself on-device - the only account on the test emulator has no location history yet ('No history yet' in the Activity tab), so RouteStatsSheet was never opened during any Task 3 pass. Documented as an honest, narrow gap rather than claimed as fully proven; high confidence given the shared mechanism, but not eyeball-confirmed. See 'Known Gaps' in the SUMMARY body."
  - id: D6
    description: "Both map surfaces actually render OpenFreeMap Liberty vector tiles (street lines, labels, buildings) on a real Android device or emulator"
    requirement: "QUICK-MAP-OPENFREEMAP-LIBERTY"
    verification:
      - kind: manual_procedural
        ref: "Task 3 first on-device pass (emulator-5554, Pixel 6 API 36): Liberty vector basemap confirmed rendering correctly - streets, labels, buildings, land/water"
        status: pass
    human_judgment: true
    rationale: "Native MapLibre platform-view rendering cannot be exercised in the Flutter widget-test harness (no platform-views channel implementation); confirmed via the Task 3 on-device checklist step 2 and unaffected by either subsequent fix (basemap rendering was correct on every attempt, including before both fixes)."
  - id: D7
    description: "Family pins stay glued to the basemap through pan/zoom and settle exactly on their coordinate; accuracy circle visibly grows/shrinks with zoom rather than staying pixel-fixed"
    requirement: "QUICK-MAP-VECTOR-RENDERER"
    verification:
      - kind: manual_procedural
        ref: "Task 3 first pass: accuracy circle confirmed scaling correctly with zoom (real-world footprint, not pixel-fixed). Task 3 third pass (against b5aa00b): panned significantly (Yoshka's area toward Shoreline Amphitheatre) - pin correctly tracked and re-settled at the new on-screen position matching its real-world location, no lag/drift after settling"
        status: pass
    human_judgment: true
    rationale: "toScreenLocationBatch reprojection timing and visual settle behavior against a live native camera can only be observed on-device, not in a widget test with an injected stand-in; confirmed via Task 3 steps 3 and 7 across the first and third on-device passes."
  - id: D8
    description: "The map cannot be tilted or rotated by any gesture (D-01) - stays flat and top-down even against Liberty's building-extrusion layer"
    requirement: "QUICK-MAP-FLAT-NO-TILT"
    verification:
      - kind: unit
        ref: "grep -c 'tiltGesturesEnabled: false' vector_map.dart == 1; rotateGesturesEnabled: false also present"
        status: pass
      - kind: manual_procedural
        ref: "Task 3 first on-device pass: single-finger drag pans only, no pitch/tilt, no rotation, north stays up. Confirmed unaffected by both later fixes (fixes touch only screen-projection code, not gesture configuration)"
        status: pass
    human_judgment: true
    rationale: "Static config flags are grep-verified, and a real two-finger pitch gesture against the native renderer was confirmed on-device (Task 3 step 9) - the gesture is genuinely rejected, not merely configured."
  - id: D9
    description: "Attribution covering OpenFreeMap/OpenMapTiles/OpenStreetMap is visible, reachable, and legally correct via the native attribution control"
    requirement: "QUICK-MAP-VECTOR-RENDERER"
    verification:
      - kind: manual_procedural
        ref: "Task 3 third on-device pass: attribution icon located via accessibility dump ([1004,2324]-[1059,2379]), tapped, opened a dialog titled 'MapLibre Android' with three links - OPENFREEMAP, OPENMAPTILES, OPENSTREETMAP"
        status: pass
    human_judgment: true
    rationale: "The hand-written Flutter Text attribution assertions were deleted by design (attribution is now a native control, not a Text widget); Task 3 step 10 required a real on-device tap to confirm the dialog contents, now done - fully satisfied, closing out the plan's threat register item T-3ZB-04."
  - id: D10
    description: "The SOS button remains instantly responsive with no perceptible delay while the native map platform view is live and location is streaming"
    requirement: "QUICK-MAP-VECTOR-RENDERER"
    verification: []
    human_judgment: true
    rationale: "This is the project's core non-negotiable (SOS must never be slowed by anything) and the plan's own threat register (T-3ZB-03, severity high) designates Task 3 step 12 as the sole verification. The coordinator is deferring this specific check to the user directly (avoiding a third real SOS alert dispatch in one day) rather than skipping it - it remains genuinely unverified as of this SUMMARY, worth extra scrutiny given the hybrid-composition rendering-mode change in fix #1 adds per-frame compositing cost. See 'Known Gaps' in the SUMMARY body; must not be treated as passed until the user confirms it."
  - id: D11
    description: "Every parity gap that could not be preserved 1:1 (squared line caps, attribution off the widget tree, animated rail-card move, JVM-target outcome) is documented rather than silently dropped (D-03)"
    requirement: "QUICK-MAP-PARITY-FLAGGED"
    verification:
      - kind: other
        ref: "This SUMMARY's key-decisions and Deviations sections"
        status: pass
    human_judgment: false
  - id: D12
    description: "VectorMap's dispose() symmetrically removes every listener it adds, including the native MapLibreMapController's, so a camera-changed notification arriving during the dispose/teardown race can never touch a disposed widget's context or the native platform channel"
    verification:
      - kind: unit
        ref: "flutter analyze --no-pub (0 issues), flutter test (311/313, same 2 pre-existing unrelated failures - no regression from this change)"
        status: pass
    human_judgment: true
    rationale: "No dedicated regression test exists for the specific race (arrival of a native camera-changed notification between dispose() and the platform view's actual teardown) - the existing widget-test seam always injects a platformViewBuilder stand-in, so _onMapCreated (and therefore controller.addListener(_onControllerNotified)) never fires in any current test, leaving no way to simulate the race without constructing a real plugin-internal MapLibreMapController. The fix (symmetric listener removal in dispose() plus moving the `mounted` guard to the first line of _reprojectMarkers()) was reviewed and required by an automated --full code-review pass on the diff, and is defensive/structurally sound by inspection, but is not independently proven by a test - documented per the fail-safe coverage default rather than claimed as auto-passing."

duration: 85min
completed: 2026-08-06
status: complete
---

# Quick Task 260806-3zb: Migrate map rendering from flutter_map to maplibre_gl Summary

**Both SafePath map surfaces now render OpenFreeMap's flat Liberty vector-tile style through native MapLibre (`maplibre_gl` 0.26.2), with family/stop pins kept as reprojected Flutter widgets (now confirmed visible and correctly tracking on a real device) and the accuracy circle re-expressed as a metre-accurate geodesic fill — shipped after finding and fixing two distinct, real bugs (Virtual-Display rendering-mode default, then a physical-vs-logical pixel mismatch) across three rounds of the coordinator's own on-device Task 3 verification, plus a third real bug (a dispose-path listener-removal asymmetry that could crash on a post-dispose camera notification) found by an automated `--full` code-review pass afterward and fixed before close-out; two narrow, explicitly-documented on-device gaps (route-sheet stop pins, staleness-opacity fading) remain, and SOS-responsiveness (step 12) is deferred to the user directly rather than a third live alert dispatch.**

## Performance

- **Duration:** 85 min (code tasks + three root-cause bug fixes + coordinator's three on-device verification passes + one automated code-review pass)
- **Started:** 2026-08-06T00:21:09Z
- **Code tasks completed:** 2026-08-06T00:39:30Z
- **Fix #1 committed (hybrid composition):** 2026-08-06T00:59:00Z (approx.)
- **Fix #2 committed (physical-to-logical pixel conversion):** 2026-08-06T01:16:00Z (approx.)
- **Task 3 closed (coordinator's third on-device pass, confirmed against `b5aa00b`):** 2026-08-06T01:31:00Z (approx.)
- **Fix #3 committed (dispose-path listener-removal race, found by automated code review):** 2026-08-06T01:46:00Z (approx.)
- **Tasks:** 3 of 3 complete (Task 3's blocking human-verify checkpoint closed on the third on-device pass; a fourth real bug was then found and fixed by an automated code-review pass, requiring no further on-device pass per the reviewer's own note)
- **Files modified:** 11 (4 created, 7 modified across all commits; `vector_map.dart` touched by Task 2 and all three fix commits)

## Accomplishments

- Added `maplibre_gl ^0.26.2` and proved the native Android build links cleanly with **no** Gradle changes needed (Task 1) — `flutter build apk --debug` succeeded on the first attempt.
- Built `map_geometry.dart` (`MapPoint`, `geodesicRing`) test-first (TDD RED confirmed failing before implementation existed, then GREEN), giving the accuracy circle a real-world-metre footprint instead of a fixed screen-pixel radius.
- Built `vector_map.dart` — the single file under `mobile/lib` permitted to import `maplibre_gl` (enforced by a grep gate) — exposing `VectorMap`, `VectorMapController` (camera-command sink replacing the old test-owned map controller), and `OverlayMarker`/`MapCircle`/`MapLine` specs.
- Migrated `live_map_screen.dart` and `route_stats_sheet.dart` onto `VectorMap`: family pins and numbered stop pins stay the exact pre-existing Flutter widgets (`LiveMemberMarker`, `_StopMarker`), now reprojected via a single batched `toScreenLocationBatch` call per camera event instead of a native symbol annotation per pin.
- Restored both previously-broken widget tests using an injected `platformViewBuilder` stand-in so no test mounts a real native platform view; `live_member_marker_test.dart` passes unmodified (7/7).
- Removed `flutter_map` from `pubspec.yaml`; kept `latlong2` per research recommendation despite it no longer being imported anywhere under `lib`/`test`.
- Updated `.claude/CLAUDE.md`'s three stack references (Constraints tech-stack line, the Flutter supporting-libraries table row, the Version Compatibility clustering row) to describe `maplibre_gl`/OpenFreeMap instead of the retired `flutter_map`/OSM stack.
- Confirmed exact `maplibre_gl` 0.26.2 API identifiers (enum casing, method names, option-object fields) against the resolved package source under `.dart_tool/package_config.json` before writing any code against them, per the plan's explicit warning that this fork's naming has drifted from generic docs.
- **Found and fixed two real, distinct pin-visibility regressions** across two rounds of the coordinator's on-device Task 3 verification: family/stop pins never appeared even though every other surface (basemap, accuracy circle scaling, flatness, rail-card animation) worked correctly on both attempts.
  - **Bug #1:** `maplibre_gl` silently defaulted to legacy Virtual-Display rendering instead of Hybrid Composition (a plugin doc-vs-code mismatch) - fixed by forcing `MapLibreMap.useHybridComposition = true`. Necessary, confirmed via logcat, but not sufficient on its own.
  - **Bug #2:** even under Hybrid Composition, `toScreenLocationBatch` returns coordinates in native **physical** pixels while Flutter's `Positioned`/`Offset` expect **logical** pixels - fixed by dividing every returned point by `MediaQuery.devicePixelRatioOf(context)`, extracted into a unit-tested pure function (`physicalToLogicalOffset`).
  - Also added explicit try/catch + logging around the projection call so a future platform-channel failure is never silent again.
- **Found and fixed a fourth real bug via automated code review after Task 3 closed:** `_VectorMapState.dispose()` removed `widget.controller`'s listener but never the native `MapLibreMapController`'s listener added in `_onMapCreated` - a real dispose-path race (camera notification arriving between `dispose()` and platform-view teardown) that could crash with a null-check error in both debug and release. Fixed with symmetric listener removal plus moving the `mounted` guard to the very first line of `_reprojectMarkers()`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add maplibre_gl and prove the native Android build gate** - `4152e22` (feat)
2. **Task 2: Build the shared VectorMap layer, migrate both screens, restore both widget tests** - `5be73c6` (feat)
3. **Fix #1 (Rule 1 - found during first Task 3 attempt): force hybrid composition** - `015bc72` (fix)
4. **Fix #2 (Rule 1 - found during second Task 3 attempt): convert physical to logical pixels** - `b5aa00b` (fix)
5. **Task 3: Checkpoint - human on-device verification** - **CLOSED** on the coordinator's third on-device pass against commit `b5aa00b` (blocking checkpoint; see 'Task 3 Verification Result' below)
6. **Fix #3 (Rule 1 - found by automated `--full` code review after Task 3 closed): remove dispose-path listener-removal race** - `8c8e68a` (fix)

**Plan metadata:** not yet committed (deferred to the orchestrator; docs artifacts intentionally excluded from these task commits per this execution's constraints).

_Note: Task 2's `<behavior>` block for `map_geometry.dart` followed a genuine RED→GREEN cycle: the test file was written first and confirmed to fail (file/constructor/function did not exist) before `map_geometry.dart` was implemented._

## Files Created/Modified

- `mobile/lib/features/location/application/map_geometry.dart` - `MapPoint` value type + `geodesicRing()` metre-to-degree ring generator (new)
- `mobile/lib/features/location/presentation/vector_map.dart` - `VectorMap` widget, `VectorMapController`, marker/circle/line spec classes, Liberty style constant, `hexColor` helper (new in Task 2; modified in fix #1 to force `MapLibreMap.useHybridComposition = true` and add try/catch logging around `toScreenLocationBatch`; modified in fix #2 to add `physicalToLogicalOffset` and apply it before storing `_screenPositions`; modified in fix #3 to remove the native controller's listener symmetrically in `dispose()` and move the `mounted` guard to the top of `_reprojectMarkers()`)
- `mobile/test/features/location/vector_map_test.dart` - 3 unit tests for `physicalToLogicalOffset` locking down the exact physical-to-logical pixel regression (new, fix #2)
- `mobile/lib/features/location/presentation/live_map_screen.dart` - migrated off `flutter_map`/`latlong2` onto `VectorMap`; added `mapPlatformViewBuilder` test seam; rail-card tap now calls `VectorMapController.animateTo`
- `mobile/lib/features/location/presentation/route_stats_sheet.dart` - migrated off `flutter_map`/`latlong2` onto `VectorMap`; added `mapPlatformViewBuilder` test seam
- `mobile/test/features/location/map_geometry_test.dart` - 12 unit tests covering every case in the plan's `<behavior>` block (new)
- `mobile/test/features/location/live_map_screen_test.dart` - retargeted to `VectorMap`, injected platform-view stand-in, deleted the OSM-attribution `Text` assertion, rewrote the rail-card test against `VectorMapController.lastCommand`
- `mobile/test/features/location/route_stats_sheet_test.dart` - retargeted to `VectorMap`, injected platform-view stand-in, deleted the OSM-attribution `Text` assertion
- `mobile/pubspec.yaml` / `mobile/pubspec.lock` - added `maplibre_gl ^0.26.2`, removed `flutter_map`, kept `latlong2`
- `.claude/CLAUDE.md` - three scoped stack-reference updates (Constraints line, Flutter supporting-libraries row, Version Compatibility clustering row)

## Decisions Made

See `key-decisions` in the frontmatter above. Summary:

- No Android Gradle changes were needed (JVM target stayed at 17, no NDK pin) — settles research assumption A1.
- `latlong2` retained per research despite no remaining import, documented rather than silently dropped.
- Rail-card tap is now a ~300ms animation (D-03 discretion, superset of prior instant-jump behavior).
- Route line end caps are squared, not rounded (`LineOptions` has no cap property) — accepted cosmetic gap, not worked around.
- Attribution is now entirely native-control-driven; the two deleted `textContaining('OpenStreetMap')` test assertions are explicitly replaced by Task 3 step 10, not left uncovered.

## Deviations from Plan

Tasks 1 and 2 as originally written and committed had no deviations. Task 3's conditional Step 4 Gradle fixes (JVM-target bump, NDK pin) were correctly *not* applied, because Step 3's build gate succeeded without either failure symptom occurring — this is the plan's own documented "only if step 3 fails" branch, not a deviation.

**Two deviations were required after the fact:** two distinct, real bugs found across two rounds of the coordinator's own on-device Task 3 verification. Neither was catchable by the automated widget-test suite, since those tests inject a `SizedBox.expand()` platform-view stand-in and never exercise the real `toScreenLocationBatch`/native-projection path.

### Auto-fixed Issues

**1. [Rule 1 - Bug] Family/route-stop pins never became visible on a real device (Virtual-Display screen-projection mismatch)**

- **Found during:** Task 3, first on-device attempt (the coordinator's own verification pass, emulator-5554, Pixel 6 API 36).
- **Issue:** `maplibre_gl 0.26.2`'s `MapLibreMap.useHybridComposition` doc comment claims a `true` default, but the underlying static field (`MapLibreMethodChannel.useHybridComposition`) actually defaults to `false` — a doc/code mismatch in the plugin itself. `VectorMap` never explicitly set this flag, so it silently rendered via legacy Virtual-Display mode on Android, confirmed by the coordinator's own logcat: `"Using legacy platform view rendering strategy"` / `"Hosting view in a virtual display for platform view: 0"`. Under Virtual Display, the native `getProjection().toScreenLocation()` calls behind `toScreenLocationBatch` return coordinates relative to the *offscreen virtual-display surface*, not this widget's real on-screen position — so every `OverlayMarker` got a wrong/degenerate screen offset that fell outside the `Stack`'s default hard-edge clip and was never drawn, with no exception anywhere (the native call succeeds and returns a valid-but-wrong coordinate, not a failure).
- **Fix:** Set `MapLibreMap.useHybridComposition = true` explicitly in `VectorMap`'s `initState()` — this was already assumed by the plan's own threat register (T-3ZB-03: *"hybrid composition adds per-frame compositing cost... Pinned to plugin 0.26.2, the first release line to fix hybrid-composition and texture-mode crashes on older Android hardware"*), so the intended rendering mode was hybrid composition all along; the flag was simply never flipped in the original Task 2 implementation. Also added an explicit `try/catch` + `debugPrint` around the `toScreenLocationBatch` call (the coordinator's own suggestion) so any future platform-channel failure surfaces immediately instead of silently vanishing as an unhandled Future error on this fire-and-forget call site.
- **Files modified:** `mobile/lib/features/location/presentation/vector_map.dart` only.
- **Verification:** `flutter build apk --debug` succeeds; `flutter analyze --no-pub` 0 issues; `flutter test` 308/310 (same 2 pre-existing unrelated failures); all grep/boundary gates pass. Confirmed real and necessary by the coordinator's own re-run (logcat moved from virtual-display to real view-hierarchy hosting) — but **not sufficient on its own**; the pin was still invisible, leading directly to bug #2.
- **Committed in:** `015bc72`

**2. [Rule 1 - Bug] Pins still invisible after fix #1 - native screen-projection returns physical pixels, Flutter's Positioned expects logical pixels**

- **Found during:** Task 3, second on-device attempt (the coordinator's own device instrumentation: a temporary debugPrint dumping raw `toScreenLocationBatch` output plus a temporary hardcoded `Positioned`/`ColoredBox` control to rule out a Stack-sizing/compositing theory - both added, tested, then fully reverted before handing this back, confirmed via a clean `git diff` on `vector_map.dart`).
- **Issue:** `toScreenLocationBatch`/`toScreenLocation` return coordinates in the native side's **physical** pixel space (raw View/Projection pixels), not the **logical** pixel space that Flutter's `Positioned`/`Offset` operate in. Proven conclusively: a marker at the exact camera-centre coordinate consistently projected to `Point(540.75, 1200.9375)` - exactly half of the device's 1080x2400 **physical** screen size (devicePixelRatio 2.625, confirmed via `adb shell wm density` = 420dpi) - not the ~206/~457 **logical** centre a correctly-converted value would show. The projection itself was proven live and correct (it tracked real pan gestures in lockstep), and the hardcoded-Positioned control proved the Stack/compositing/z-order mechanism itself was fine - isolating the bug specifically to the missing physical→logical conversion. Left unconverted, every marker landed ~2.625x further right/down than correct, outside the `Stack`'s default hard-edge clip.
- **Fix:** Divide each returned point by `MediaQuery.devicePixelRatioOf(context)` before storing into `_screenPositions`, with the ratio captured synchronously right before the `toScreenLocationBatch` await (the only point in this fire-and-forget async method where `context` is guaranteed valid). Extracted the conversion into a small `@visibleForTesting` pure function, `physicalToLogicalOffset`, and added a dedicated unit-test file (`vector_map_test.dart`, 3 cases: the exact regression values, a `devicePixelRatio: 1.0` no-op, and integer-valued `Point` coordinates) so this specific class of bug is locked down without needing a full on-device pass to catch a regression of it.
- **Files modified:** `mobile/lib/features/location/presentation/vector_map.dart`, `mobile/test/features/location/vector_map_test.dart` (new).
- **Verification:** `flutter build apk --debug` succeeds; `flutter analyze --no-pub` 0 issues; `flutter test` 311/313 (same 2 pre-existing unrelated failures, +3 new passing regression tests); all grep/boundary gates pass. Confirmed real and sufficient by the coordinator's third on-device pass (see "Task 3 Verification Result" below) — the member pin now renders correctly, with avatar/name/badge/battery visible and tap-to-detail and pan-tracking both working.
- **Committed in:** `b5aa00b`

Both fixes are centralized in the single file that owns all plugin interaction (`vector_map.dart`), so `route_stats_sheet.dart`'s numbered stop pins (sharing the exact same `VectorMap`/`OverlayMarker`/`_reprojectMarkers` mechanism) are covered by both changes with no per-screen duplication.

**3. [Rule 1 - Bug] Dispose-path listener-removal asymmetry could crash on a post-dispose native camera notification**

- **Found during:** an automated code review (`--full` mode) run on the diff after Task 3 had already closed, not during any on-device pass - a static-analysis-catchable class of bug distinct from the two on-device-only bugs above.
- **Issue:** `_onMapCreated` calls `controller.addListener(_onControllerNotified)` on the native `MapLibreMapController`, but `dispose()` only removed `widget.controller`'s listener (`_onCameraCommand`) - never the native controller's. Every other listener in this class is added/removed symmetrically; this one wasn't. Concretely: if the native controller fires a camera-changed notification after `_VectorMapState.dispose()` runs but before the platform view itself fully tears down (a real race popping the screen or switching tabs mid-pan/mid-camera-settle), `_onControllerNotified` -> `_reprojectMarkers()` would still run. That method read `MediaQuery.devicePixelRatioOf(context)` before its only `await`, with the `mounted` guard only checked *after* the await - so a disposed widget's `context` could be touched, a null-check-operator crash in both debug and release builds (the assert-wrapped diagnostic is stripped in release, the underlying null-check is not).
- **Fix:** Two parts. (1) `dispose()` now also calls `_mapController?.removeListener(_onControllerNotified)`, symmetric with every other listener. (2) The `mounted` check in `_reprojectMarkers()` moved to the very first line, before `_mapController` or `context` are touched at all - belt-and-braces so a stray notification arriving between listener-removal and actual disposal still can't crash it.
- **Files modified:** `mobile/lib/features/location/presentation/vector_map.dart` only.
- **Regression test:** Not added. The existing widget-test seam always injects a `platformViewBuilder` stand-in, so `_onMapCreated` (and therefore `controller.addListener(_onControllerNotified)`) never fires in any current test - `_mapController` stays null throughout every existing test. Simulating this race would require constructing a real `MapLibreMapController` (a concrete plugin-internal class with a non-trivial constructor graph), effectively reimplementing plugin test scaffolding for a defensive dispose-path fix. Documented via detailed code comments at both fix sites instead, per the reviewer's own explicit fallback guidance ("a clear code comment explaining the fix is an acceptable fallback given the existing test suite already can't mount a real platform view").
- **Verification:** `flutter analyze --no-pub` 0 issues; `flutter test` 311/313 (same 2 pre-existing unrelated failures, no regression from this change). Per the reviewer's own note, this is a dispose-path-only change with no rendering-path impact, so no further on-device verification pass was required.
- **Committed in:** `8c8e68a`

---

**Total deviations:** 3 auto-fixed (3 Rule 1 bug fixes: 2 found via on-device Task 3 verification, 1 found via automated code review afterward)
**Impact on plan:** All three necessary for correctness — the plan's own success criteria explicitly require family pins to be visible and interactive (fixes #1/#2), and a dispose-path crash risk is a correctness/stability defect regardless of how it was found (fix #3). Without fixes #1/#2 the migration would have shipped with the primary visual payoff (member pins on the map) silently broken on real hardware, exactly the kind of regression the plan's Task 3 on-device checklist exists to catch (and did catch, twice); without fix #3 the migration would have shipped a latent crash-on-navigate defect that no on-device checklist step happened to trigger. No scope creep — all three fixes touch only the single file the plan already designated as sole plugin owner, plus one new unit-test file.

### Code review findings (automated `--full` pass on the diff, after Task 3 closed)

One BLOCKER (fixed above as deviation #3, commit `8c8e68a`) and four advisory WARNINGs the coordinator explicitly asked to be recorded rather than acted on. Documented here for the STATE.md/future-reader record, not fixed in this task:

- **WR-01 (UX polish, not a bug):** `didUpdateWidget`'s circles/lines "changed" check is dead logic - `MapCircle`/`MapLine` have no `==` override, so the "deep equality" half of the condition (`oldWidget.circles != widget.circles`) reduces to the same `identical()` check already being performed. Since `LiveMapScreen` builds a fresh `circleMarkers` list on every location tick, `_drawAnnotations()` ends up redrawing unconditionally on every tick, causing a visible flicker on the accuracy circle. Real, but cosmetic - candidate for a future quick task (add `==`/`hashCode` to `MapCircle`/`MapLine`, or compare field-by-field).
- **WR-02:** No in-flight guard on `_drawAnnotations()` - overlapping calls (plausible given WR-01's frequency) could interleave `clearFills()`/`addFill()` calls across two invocations. Would benefit from the same kind of guard pattern already used elsewhere, or from fixing WR-01 first (which would reduce the call frequency that makes this reachable).
- **WR-03:** `_drawAnnotations()` has no `try/catch`, unlike `_reprojectMarkers()`'s explicit one (added in fix #1) - a transient platform-channel failure here fails silently. Same fix pattern as `_reprojectMarkers()`'s existing `try/catch` + `debugPrint` would apply directly.
- **WR-04:** The `VectorMap` class doc comment claims a "grep gate enforces" single-file plugin-import ownership, but that grep only ran once during plan execution (`Task 2`'s verify step and this SUMMARY's own re-runs), not as a standing CI/pre-commit check - the comment overstates what's actually enforced going forward. Would need an actual CI step or pre-commit hook (e.g. `grep -rln 'package:maplibre_gl' lib | grep -v vector_map.dart`, non-zero exit fails the build) to match the doc comment's claim.

None of these four block this task's completion; all are candidates for a future quick task if picked up.

### Out-of-scope issue observed (not fixed, per scope boundary rule)

**Pre-existing failure in `mobile/test/shared_widgets/member_map_pin_semantics_test.dart`** (2 tests: "announces the label and current-location status as one node", "announces the label and stale status as one node") — both fail with `A SemanticsHandle was active at the end of the test`. Confirmed via `git stash` that this failure exists identically on the pre-migration code (before `maplibre_gl` was even added), so it is unrelated to this migration and out of this task's scope per the Scope Boundary rule (only auto-fix issues directly caused by the current task's changes). Not fixed. Flagging here for the user/next agent rather than silently ignoring it — likely a Flutter SDK behavior change unrelated to `member_map_pin.dart` itself. All 308 other tests in the full suite pass.

## Issues Encountered

**The pin-visibility bug documented above under Deviations** — in two distinct layers — was the substantive issue across this task's Task 3 attempts: family pins and route-stop pins never rendered on a real device despite the widget-test suite passing in full. The widget tests structurally verify the marker is present in the tree via an injected platform-view stand-in, but cannot exercise the real native screen-projection path, so this whole class of bug (rendering-mode selection, physical-vs-logical pixel space) is only catchable on-device. This is precisely why the plan designates Task 3 as a blocking (not optional) checkpoint, and precisely why it caught two separate real bugs rather than zero. Both root-caused and fixed per the Deviations entries above; the coordinator's own diagnostic evidence (logcat, uiautomator dump, screenshots for bug #1; targeted temporary debugPrint instrumentation plus a hardcoded-Positioned control experiment, cleanly reverted, for bug #2) was sufficient to pinpoint both exact causes without needing to attach a device from this environment for either.

The native Android build gate (Task 1, Step 3) completed successfully in ~188s on a cold Gradle cache with only a non-blocking Kotlin Gradle Plugin (KGP) migration warning (`flutter_foreground_task`, `maplibre_gl` apply KGP — a Flutter-tooling forward-compat warning, not a build failure) and pre-existing Java-8-source-value-obsolete warnings unrelated to this change. Both fix commits' own `flutter build apk --debug` re-runs also succeeded cleanly on a warm cache (~72s, then ~38s).

## User Setup Required

None — no external service configuration required. OpenFreeMap's public instance needs no API key (D-02).

## Task 3 Verification Result: CLOSED (third on-device pass, against `b5aa00b`)

All code changes (five commits: `4152e22`, `5be73c6`, `015bc72`, `b5aa00b`) are verified by the full automated suite (`flutter analyze --no-pub`: 0 issues; `flutter test`: 311/313 passing, the 2 failures pre-existing and unrelated; every grep verification gate passing; the SOS/home/backend directory boundary untouched; `flutter build apk --debug` succeeds) **and** by three rounds of the coordinator's own on-device verification (emulator-5554, Pixel 6 API 36), which found and forced the fix of two real, distinct bugs before closing clean.

**Confirmed passing across the three passes:**

1. **Basemap.** Liberty vector tiles render correctly - streets, labels, buildings, land/water.
2. **Pins (member pin).** Avatar photo, "You" name pill, ONLINE badge, and battery indicator all visible and matching `LiveMemberMarker`'s design; accessibility dump confirms a correctly-bounded, clickable semantics node; tapping opens the member detail sheet with correct name/status/last-seen/battery; the pin tracked and re-settled correctly after a significant pan (Yoshka's area toward Shoreline Amphitheatre), no lag/drift after settling.
3. **Geometry.** The accuracy circle grows/shrinks correctly with zoom (real-world footprint, confirmed not pixel-fixed).
4. **Flatness (D-01, locked decision).** Two-finger drag does not pitch or rotate either map; single-finger drag pans only; north stays up.
5. **Attribution.** Icon located and tapped (bounds `[1004,2324]-[1059,2379]`); opened a dialog titled "MapLibre Android" with three links - OPENFREEMAP, OPENMAPTILES, OPENSTREETMAP. Fully satisfies the plan's threat register item T-3ZB-04.
6. **Interaction parity.** Rail-card tap animates the camera to the tapped member without opening the detail sheet (confirmed in the first pass, unaffected by both later fixes since they touch only screen-projection code).

## Known Gaps (documented honestly, not silently claimed as covered)

Three items could not be independently confirmed by a human on a real device during this task's execution. None block closing this task, but a future reader should not assume they were proven:

1. **Route sheet's numbered stop pins were never visually confirmed.** The only account on the coordinator's test emulator has no location history ("No history yet" in the Activity tab), so `RouteStatsSheet` was never opened during any Task 3 pass. `route_stats_sheet.dart`'s `OverlayMarker`s share the exact same `VectorMap`/`_reprojectMarkers`/`physicalToLogicalOffset` mechanism as the now-confirmed-working member pins, and the underlying pixel-conversion function is directly unit-tested (`vector_map_test.dart`), so confidence is high - but this is inference from a shared mechanism, not an eyeball confirmation. Worth a quick manual check the next time a test account has seeded route history.
2. **Staleness-opacity fading was never visually confirmed end-to-end.** The only member available on the test account is the self member, and `LiveMemberMarker` always renders `isSelf` at full opacity (`opacity = isSelf ? 1.0 : stalenessFor(...)`) regardless of staleness, so this path was never reachable with a self-only family circle. The fading behavior itself is unit-tested and passing (`live_member_marker_test.dart#family member marker still fades when its ping is stale`), so the underlying widget logic is proven - only the "real multi-member family circle with an actually-stale ping, rendered live via VectorMap" end-to-end path lacks a device confirmation. Lower risk than the two bugs already found and fixed, since this logic is untouched by the migration itself (same `LiveMemberMarker`/`stalenessFor` code as before).
3. **SOS responsiveness (Task 3 step 12, the plan's core non-negotiable) has not yet been independently confirmed by anyone in this task's own execution.** The coordinator explicitly deferred this specific check to the user directly, to avoid a third real SOS alert dispatch in one day - this is a deliberate handoff, not a skip, but it means step 12 remains genuinely open as of this SUMMARY. Given fix #1 (forcing hybrid composition) explicitly trades in "adds per-frame compositing cost" per the plugin's own doc comment and the plan's threat register (T-3ZB-03, severity high), this is the single highest-value remaining check and should not be treated as passed until the user confirms it.

**Note (post-close):** commit `8c8e68a` (fix #3, the dispose-path listener-removal race found by automated code review) landed *after* Task 3's on-device checkpoint above was already confirmed closed. Per the reviewer's own explicit note, this is a dispose-path-only change with no rendering-path impact, so it did not require - and did not receive - a fourth on-device pass; it is verified by `flutter analyze --no-pub` + `flutter test` only, consistent with the reviewer's guidance.

---
*Quick task: 260806-3zb-migrate-map-rendering-from-flutter-map-t*
*Completed: 2026-08-06 - all three tasks closed, including Task 3's on-device verification, after two rounds of on-device-found bug fixes plus one automated-code-review-found bug fix; three documented gaps (route-sheet pins, staleness fading, SOS responsiveness) and four advisory code-review findings (WR-01 through WR-04, UX/robustness polish) remain for future confirmation/pickup as noted above*

## Self-Check: PASSED

All 11 created/modified files under this task confirmed present on disk; all commit hashes (`4152e22`, `5be73c6`, `015bc72`, `b5aa00b`, `8c8e68a`) confirmed present in `git log`; post-fix `flutter build apk --debug` and `flutter test` re-runs confirmed green throughout (final state: 311/313, same 2 pre-existing unrelated failures, +3 new passing regression tests); Task 3's blocking checkpoint confirmed closed via the coordinator's own third on-device verification pass, reported directly in this conversation; the subsequent dispose-path fix (commit `8c8e68a`) re-verified via `flutter analyze`/`flutter test` per the reviewer's own no-further-on-device-pass-needed guidance.
