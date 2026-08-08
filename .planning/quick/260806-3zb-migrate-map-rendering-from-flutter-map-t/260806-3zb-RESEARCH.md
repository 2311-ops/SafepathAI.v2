# Quick Task 260806-3zb: flutter_map → maplibre_gl (OpenFreeMap Liberty) — Research

**Researched:** 2026-08-06
**Domain:** Flutter map rendering — raster tile layer → vector-tile native renderer
**Confidence:** HIGH (package/API/native-config verified against source; parity risks verified against project code)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Map Style**
- Use the **Liberty** style (flat, top-down), served from OpenFreeMap's style JSON endpoint (e.g. `https://tiles.openfreemap.org/styles/liberty`).
- Explicitly rejected: "Fiord 3D" (terrain-relief style) — flagged as a legibility risk for a live safety-tracking map (tilted/elevation rendering can occlude pins, adds render cost during continuous location streaming). User chose flat Liberty specifically to keep SOS/staleness pins and route lines fully legible.

**Tile Hosting**
- Use OpenFreeMap's free public hosted instance (no API key, no usage limits) as the tile source. Same trust model as the current `tile.openstreetmap.org` source. Self-hosting is an accepted future hardening step, not required now — no follow-up todo needed per user's explicit choice ("Accept it for now").

### Claude's Discretion
- Exact `maplibre_gl` pub.dev version, Android/iOS native setup steps (build.gradle, Info.plist), and the annotation API used to replace `flutter_map`'s `Marker`/`Polyline` widgets (symbols/circles for member pins preserving staleness-opacity, line layers for route polylines) — to be nailed down by the research phase and executed per its findings.
- Camera/zoom/follow-user interaction parity with the current `flutter_map` implementation should be preserved as closely as `maplibre_gl`'s API allows; any behavior that cannot be preserved 1:1 must be flagged explicitly in the plan/summary rather than silently dropped.

### Deferred Ideas (OUT OF SCOPE)
- Self-hosting OpenFreeMap tiles (explicitly accepted as-is for now, no follow-up todo).
</user_constraints>

## Summary

`maplibre_gl` **0.26.2** is the right and only viable target: it is published by the **verified `maplibre.org` publisher**, ~47 days old, 69.5k weekly downloads, and its own CHANGELOG names **OpenFreeMap Liberty** as a tested non-Mapbox style. It satisfies every SDK/native constraint this project already has: Dart `>=3.7.0 <4.0.0` (project is on Flutter 3.44.5), Android `minSdk 21` (project floor is Flutter's 24), `compileSdk 36` (project resolves `flutter.compileSdkVersion` = 36), iOS deployment target `13.0` (project is exactly 13.0). The Liberty style JSON was fetched and inspected directly: MapLibre style-spec **v8**, 111 layers, self-hosted glyphs + sprites, no Mapbox-proprietary extensions, no `terrain`/`sky`/`projection` keys — it is natively parseable by maplibre-native with zero transformation.

The migration is **not** a 1:1 API swap. `flutter_map` composes markers as arbitrary Flutter widgets in the Dart widget tree; `maplibre_gl` renders a **native platform view** and its annotation API (`addSymbol`/`addCircle`/`addLine`) only accepts bitmap icons + style-spec text. The project's `LiveMemberMarker` is a rich composite widget (CachedNetworkImage avatar, name pill, ONLINE/OFFLINE badge, battery readout, `GestureDetector` → member sheet, `Opacity` from `stalenessFor()`). Rebuilding it as a `Symbol` would destroy that widget, its 7 passing unit tests, and the design-system fidelity CLAUDE.md mandates. The correct approach — and the one MapLibre ships as its **own official `custom_marker.dart` example** — is a **screen-space widget overlay**: keep `LiveMemberMarker` verbatim, `Stack` it above `MapLibreMap`, and reproject each member's `LatLng` to screen pixels via `controller.toScreenLocationBatch()` on every camera notification.

Three parity risks are real and must be handled explicitly, not silently dropped: (1) **accuracy circles** — `CircleOptions.circleRadius` is in *screen pixels*, not meters, so `useRadiusInMeter: true` has no direct equivalent (use `addFill` with a generated geodesic ring polygon); (2) **the `@visibleForTesting mapController` test seam** in `LiveMapScreen` cannot survive — `MapLibreMapController` is only obtainable from the native `onMapCreated` callback and is not constructible in a widget test; (3) **widget tests that pump the map will throw `MissingPluginException` on `flutter/platform_views`**.

**Primary recommendation:** Add `maplibre_gl: ^0.26.2`, set `styleString: 'https://tiles.openfreemap.org/styles/liberty'` with `tiltGesturesEnabled: false`, keep `LiveMemberMarker` and `_StopMarker` as Flutter widgets in a `toScreenLocationBatch()`-driven overlay Stack, use native `addLine` for the route polyline and `addFill` (geodesic ring) for accuracy circles, and refactor the map behind an injectable seam so the two existing map widget tests keep running.

## Project Constraints (from CLAUDE.md)

| Directive | Impact on this task |
|-----------|---------------------|
| SOS red is reserved **exclusively** for emergency/SOS | Route line stays `AppColors.primaryTeal`; no map annotation may use SOS red. Liberty's own palette contains reds in road casings — this is style chrome, not app UI, and does not violate the rule, but do **not** add app-authored red annotations. |
| UI must faithfully recreate the 36-screen design system (Manrope/JetBrains Mono, spacing/radius/shadow specs fixed) | Reinforces the widget-overlay decision — rasterizing markers into bitmap symbols would lose `AppTypography`/`AppColors`/shadow fidelity. |
| SOS pipeline must bypass all routine processing; nothing may slow it down | The map is on the same UI isolate as the SOS button. Native platform views on Android use hybrid composition; verify SOS button responsiveness on-device after migration (see Pitfall 6). |
| Tech-stack table lists `flutter_map` 8.x | Must be updated to `maplibre_gl` 0.26.x as part of this task (CONTEXT canonical_refs explicitly calls this out). |
| GSD workflow enforcement — no direct edits outside a GSD workflow | Already satisfied (this is `/gsd-quick`). |

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Vector tile fetch + render | Native (maplibre-native via platform view) | — | GPU rendering of 111 style layers is not Dart's job |
| Style JSON resolution | CDN / Static (OpenFreeMap) | Native | Style, glyphs, sprites, TileJSON all served by `tiles.openfreemap.org` |
| Member pin visuals + tap | Flutter widget layer (overlay) | — | Preserves design system, `CachedNetworkImage` lifecycle, semantics, existing tests |
| Member pin *positioning* | Native → Dart bridge (`toScreenLocationBatch`) | Flutter | Only the native renderer knows the current projection |
| Accuracy circle geometry | Native annotation (`addFill`) | Dart (ring generation) | Must scale with zoom in real-world meters; Dart generates the ring, native renders it |
| Route polyline | Native annotation (`addLine`) | — | Static geometry, no widget content, no per-frame reprojection needed |
| Camera / follow-user | Native (`animateCamera`/`easeCamera`) | Flutter (trigger) | Camera state lives in the native map |
| Attribution | Native (built-in attribution button, fed by TileJSON) | — | Verified: OpenFreeMap TileJSON already carries the full required attribution string |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `maplibre_gl` | **0.26.2** | Vector-tile map renderer (maplibre-native Android/iOS) | Published by verified publisher **maplibre.org**; BSD-3; 69.5k weekly downloads; 117 likes; 160 pub points. The only maintained Flutter binding to maplibre-native. `[VERIFIED: pub.dev/packages/maplibre_gl]` |
| `latlong2` | ^0.9.0 (**keep**) | Coordinate type used by `LocationHistory`/`polylinePoints` | Still needed by non-map code paths; `maplibre_gl` ships its **own** `LatLng` class — see Pitfall 1. `[VERIFIED: mobile/pubspec.yaml]` |

**Removed:** `flutter_map: ^8.0.0` — no remaining usages once the two screens migrate (verified: only `live_map_screen.dart`, `route_stats_sheet.dart`, and their two test files import it).

### Transitive native dependencies (informational — pulled automatically)

| Dependency | Version | Platform |
|------------|---------|----------|
| `org.maplibre.gl:android-sdk-opengl` | 13.3.0 | Android (OpenGL variant; Vulkan SDK explicitly excluded by the plugin for stability on older devices) |
| `org.maplibre.gl:android-plugin-annotation-v9` | 3.0.2 | Android |
| `MapLibre` (CocoaPods) | 6.27.0 | iOS |
| `maplibre_gl_platform_interface` / `maplibre_gl_web` | ^0.26.2 | shared / web |

`[VERIFIED: github.com/maplibre/flutter-maplibre-gl — maplibre_gl/android/build.gradle, maplibre_gl/ios/maplibre_gl.podspec]`

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `maplibre_gl` 0.26.2 | `maplibre` (the newer josxha rewrite) | Has a first-class widget-based `MarkerLayer` that would make the pin migration trivial. **Rejected** — CONTEXT.md locks `maplibre_gl` by name, and `maplibre` is a younger, lower-adoption package. **Flag for the user only if the overlay pattern proves unworkable on-device.** `[ASSUMED — package identity seen in search results, not independently audited]` |
| Widget overlay for pins | `addSymbol` + rasterized PNG icons | Rejected: loses `LiveMemberMarker`, its 7 unit tests, `CachedNetworkImage` avatar caching, semantics labels, and design-token fidelity. |

**Installation:**
```bash
cd mobile
flutter pub remove flutter_map
flutter pub add maplibre_gl:^0.26.2
flutter pub get
```

## Package Legitimacy Audit

pub.dev is not covered by the npm/PyPI/crates legitimacy seam; verified manually against the official registry and upstream source.

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| `maplibre_gl` 0.26.2 | pub.dev | published ~47 days ago; project began as a fork of `flutter-mapbox-gl` (multi-year lineage) | 69.5k / week | `github.com/maplibre/flutter-maplibre-gl` (353★, 208 forks, 76 open issues, active) | **OK** | Approved |

- Publisher is the **verified `maplibre.org` publisher** on pub.dev — not an unverified individual. `[VERIFIED: pub.dev/packages/maplibre_gl]`
- Discovered from official documentation (maplibre.org) and the OpenFreeMap ecosystem, not from a bare model guess.
- No postinstall-equivalent risk; native deps resolve from `google()`/`mavenCentral()` and CocoaPods trunk only.

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Native Setup Requirements

### Android — compatibility matrix vs. this project

| Requirement (from `maplibre_gl/android/build.gradle`) | Project value (`mobile/android/app/build.gradle.kts`) | Status |
|---|---|---|
| `minSdkVersion 21` | `flutter.minSdkVersion` = **24** | ✅ OK |
| `compileSdk 36` | `flutter.compileSdkVersion` = **36** | ✅ OK (exact match) |
| `targetSdk` — n/a | `flutter.targetSdkVersion` = 36 | ✅ |
| `sourceCompatibility/targetCompatibility VERSION_21`, Kotlin `jvmTarget 21` | App module is **VERSION_17 / JVM_17** | ⚠️ **Needs verification** — see Pitfall 5 |
| `ndkVersion "28.1.13356709"` | `flutter.ndkVersion` = **28.2.13676358** | ⚠️ Version-mismatch warning likely; may require an explicit `ndkVersion` pin |
| Build JDK ≥ 21 (Java 21 bytecode) | Local JDK is **23.0.2** | ✅ OK |
| `multiDexEnabled true` (plugin module) | not set on app | ℹ️ minSdk 24 ⇒ native multidex; no action |
| `kotlin_version 2.4.0`, AGP 8.13.2 (plugin's own buildscript) | resolved by root `android/build.gradle.kts` | ℹ️ Verify root AGP ≥ 8.13 during execution |

`[VERIFIED: flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt — compileSdkVersion=36, minSdkVersion=24, targetSdkVersion=36, ndkVersion="28.2.13676358"]`

**AndroidManifest permissions required by the plugin:** `ACCESS_COARSE_LOCATION` (mandatory) and `ACCESS_FINE_LOCATION`. **Both are already present** — the app ships `geolocator` + `flutter_foreground_task` and has a working location permission gate (`location_permission_gate_test.dart`). No manifest change expected; verify during execution. `[CITED: maplibre.org/flutter-maplibre-gl/getting-started/]`

**No conflict expected with existing plugins.** `firebase_messaging`, `flutter_foreground_task`, `flutter_local_notifications`, and `geolocator` do not contend for anything maplibre_gl touches. The plugin pulls `play-services-base:18.10.0` and `play-services-location:21.3.0` — `geolocator` also pulls `play-services-location`; Gradle resolves to the highest version, which is standard and non-breaking. The recent core-library-desugaring fix (commit `2aee4de`) is unaffected.

### iOS

| Requirement | Project value | Status |
|---|---|---|
| `s.ios.deployment_target = '13.0'` | `IPHONEOS_DEPLOYMENT_TARGET = 13.0` (all 3 configs) | ✅ Exact match |
| `Info.plist` → `NSLocationWhenInUseUsageDescription` | Verify — likely already present for `geolocator` | Check during execution |
| CocoaPods pod `MapLibre 6.27.0` | **No `mobile/ios/Podfile` exists** | ℹ️ iOS has never been built on this machine; `flutter build ios` generates the Podfile. Out of scope to fix here — flag, don't chase. |

**iOS is not verifiable on this Windows dev machine.** Do not add iOS-specific steps to the plan beyond the Info.plist key check; treat iOS build validation as deferred.

## Style JSON Consumption — VERIFIED by direct fetch

`GET https://tiles.openfreemap.org/styles/liberty` → **HTTP 200**, `application/json`, 43,079 bytes.

| Property | Value |
|---|---|
| `version` | **8** (MapLibre / Mapbox style spec v8 — natively parseable) |
| `layers` | 111 — `line`×67, `symbol`×25, `fill`×16, `raster`×1, `background`×1, `fill-extrusion`×1 |
| `sources.openmaptiles` | `{type: "vector", url: "https://tiles.openfreemap.org/planet"}` (TileJSON) |
| `sources.ne2_shaded` | raster hillshade, `maxzoom 6`, PNG tiles |
| `glyphs` | `https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf` (self-hosted) |
| `sprite` | `https://tiles.openfreemap.org/sprites/ofm_f384/ofm` (self-hosted) |
| `terrain` / `sky` / `projection` | **absent** — no globe, no 3D terrain, no GL-JS-only features |
| Default `center`/`zoom`/`pitch`/`bearing` | **absent** — `initialCameraPosition` must be supplied (the app already does) |
| Expressions used | `get`, `case`, `step`, `coalesce`, `let`, `interpolate` — all core style-spec v8, all supported by maplibre-native |
| Font stacks | `Noto Sans Regular` / `Bold` / `Italic` — served by OpenFreeMap's own glyph endpoint |

**No Mapbox-proprietary extensions.** No `mapbox://` URLs, no access-token placeholders. Loads directly:

```dart
MapLibreMap(
  styleString: 'https://tiles.openfreemap.org/styles/liberty',
  ...
)
```

**Corroborating evidence:** maplibre_gl's own 0.26.2 CHANGELOG entry #830 reads *"**iOS**: `setMapLanguage` now correctly changes map labels on non-Mapbox styles (e.g. **OpenFreeMap Liberty**)"* — the maintainers explicitly test against this exact style. `[VERIFIED: github.com/maplibre/flutter-maplibre-gl CHANGELOG.md v0.26.2]`

### Attribution — no manual widget needed

`GET https://tiles.openfreemap.org/planet` (the TileJSON) returns:

```
attribution: <a href="https://openfreemap.org">OpenFreeMap</a> <a href="https://www.openmaptiles.org/">© OpenMapTiles</a> Data from <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>
```

maplibre-native's built-in attribution button reads this from the source and surfaces it. **Remove the two `SimpleAttributionWidget` instances** and rely on the native button, positioned via `attributionButtonPosition` / `attributionButtonMargins` so it doesn't collide with the `_LiveMapOverlay` card or the `_MemberStatusRail`. `[VERIFIED: direct TileJSON fetch]`

⚠️ **Test impact:** both existing map tests assert `find.textContaining('OpenStreetMap')`. The native attribution button is *not* a Flutter `Text` widget — these assertions will fail and must be replaced (see Validation Architecture).

## Architecture Patterns

### Data flow

```
OpenFreeMap CDN                        Flutter (Dart)
──────────────────                     ─────────────────────────────
/styles/liberty (style v8) ──┐
/planet (TileJSON+attrib.) ──┤
/planet/.../{z}/{x}/{y}.pbf ─┼──▶ maplibre-native ──▶ platform view (GPU)
/fonts/{stack}/{range}.pbf ──┤          │
/sprites/ofm_f384/ofm ───────┘          │ onMapCreated
                                        ▼
                             MapLibreMapController (ChangeNotifier)
                                        │
        ┌───────────────────────────────┼──────────────────────────────┐
        │ native annotations            │ notifyListeners()            │ camera cmds
        ▼                               ▼                              ▼
   addLine(route)             toScreenLocationBatch(LatLng[])   animateCamera /
   addFill(accuracy ring)              │                        easeCamera(linear)
                                       ▼
                         Stack overlay of Positioned(LiveMemberMarker)
                                       │
   locationControllerProvider ─────────┘  (lat/lng, staleness, battery, avatar)
```

### Pattern 1: Widget-overlay markers (replaces `MarkerLayer`)

**What:** Keep `LiveMemberMarker` / `_StopMarker` as Flutter widgets. Position them in a `Stack` above `MapLibreMap` using screen coordinates reprojected from the native map.
**When to use:** Every marker in this migration. This is MapLibre's own documented approach for widget markers.
**Why:** `SymbolOptions` only accepts `iconImage` (a registered bitmap name) + style-spec `textField`. It cannot host a Flutter widget tree. Rasterizing would break `LiveMemberMarker`'s 7 unit tests and the design-token fidelity CLAUDE.md requires.

```dart
// Source: github.com/maplibre/flutter-maplibre-gl
//   maplibre_gl_example/lib/examples/annotations/custom_marker.dart
MapLibreMapController? _mapController;

void _onMapCreated(MapLibreMapController controller) {
  setState(() => _mapController = controller);
  // MapLibreMapController extends ChangeNotifier and notifies on every
  // camera move (verified: controller.dart:102, 186-202).
  controller.addListener(() async {
    if (controller.isCameraMoving) await _updateMarkerPosition();
  });
}

Future<void> _onCameraIdleCallback() => _updateMarkerPosition();

Future<void> _updateMarkerPosition() async {
  final coords = [for (final m in _markerStates) m.getCoordinate()];
  final points = await _mapController!.toScreenLocationBatch(coords);
  for (var i = 0; i < _markerStates.length; i++) {
    _markerStates[i].updatePosition(points[i]);
  }
}

// build():
Stack(children: [
  MapLibreMap(
    trackCameraPosition: true,       // REQUIRED for cameraPosition to update
    onMapCreated: _onMapCreated,
    onCameraIdle: _onCameraIdleCallback,
    styleString: 'https://tiles.openfreemap.org/styles/liberty',
    initialCameraPosition: CameraPosition(target: cameraTarget, zoom: 15),
  ),
  Stack(children: _markers),         // each child a Positioned(child: LiveMemberMarker)
])
```

⚠️ The upstream example wraps the overlay in `IgnorePointer(ignoring: true)`. **Do not copy that** — `LiveMemberMarker.onTap` must stay live. A bare `Stack` of `Positioned` children only hit-tests inside each child's box, so taps on empty map area still reach `MapLibreMap`. Verify pan/zoom gestures still work through the gaps during execution.

### Pattern 2: Native line annotation (replaces `PolylineLayer`)

```dart
await controller.addLine(LineOptions(
  geometry: [for (final p in points) LatLng(p.lat, p.lng)], // maplibre_gl LatLng
  lineColor: '#0C3A3F',          // hex string, NOT a Flutter Color
  lineWidth: 5,
  lineJoin: 'round',
  lineOpacity: 1.0,
));
```

`LineOptions` fields (verified from source): `lineJoin`, `lineOpacity`, `lineColor`, `lineWidth`, `lineGapWidth`, `lineOffset`, `lineBlur`, `linePattern`, `geometry`, `draggable`.

⚠️ **No `strokeCap` equivalent.** `flutter_map`'s `strokeCap: StrokeCap.round` has no `LineOptions` counterpart — `line-cap` is a *layout* property that the annotation manager does not expose. Route line ends will be butt-capped. Cosmetic; flag it, don't fight it. (If round caps prove necessary, drop to `addGeoJsonSource` + `addLineLayer` with `lineCap: 'round'`.)

### Pattern 3: Accuracy circle in **meters** (replaces `useRadiusInMeter: true`)

`CircleOptions` fields: `circleRadius`, `circleColor`, `circleBlur`, `circleOpacity`, `circleStrokeWidth`, `circleStrokeColor`, `circleStrokeOpacity`, `geometry`, `draggable`. **`circleRadius` is in screen pixels** (MapLibre style-spec `circle-radius`), so the circle would *not* shrink/grow with zoom — a functional regression for an accuracy indicator.

Use `addFill` with a generated geodesic ring instead:

```dart
List<LatLng> geodesicRing(LatLng center, double radiusMeters, {int segments = 64}) {
  const earthR = 6378137.0;
  final latR = center.latitude * pi / 180;
  final dLat = radiusMeters / earthR * 180 / pi;
  final dLng = radiusMeters / (earthR * cos(latR)) * 180 / pi;
  return [
    for (var i = 0; i <= segments; i++)
      LatLng(
        center.latitude  + dLat * sin(2 * pi * i / segments),
        center.longitude + dLng * cos(2 * pi * i / segments),
      ),
  ];
}

await controller.addFill(FillOptions(
  geometry: [geodesicRing(center, accuracyCircleRadius(loc.accuracyMeters))],
  fillColor: '#7C5CFF',
  fillOpacity: 0.15,
  fillOutlineColor: '#7C5CFF',
));
```

`accuracyCircleRadius()` in `staleness.dart` carries over unchanged. `FillOptions.geometry` is `List<List<LatLng>>` (rings) — verified from source.

⚠️ `FillOptions` has **no `fillOutlineWidth`**. The current 2px border (`borderStrokeWidth: 2`) cannot be reproduced via `addFill`. Either accept a hairline outline, or add a second `addLine` around the same ring with `lineWidth: 2`, `lineOpacity: 0.40`.

### Pattern 4: Staleness-driven opacity — **fully preserved**

Because the pin stays a Flutter widget, `LiveMemberMarker`'s existing `Opacity(opacity: stalenessFor(...).opacity)` works **verbatim, zero changes**, and `live_member_marker_test.dart` keeps passing unmodified.

*(For reference only, if pins ever become native symbols: `SymbolOptions` does expose `iconOpacity` and `textOpacity` as `double?`, so a native path exists — but it is not the recommended path here.)*

### Pattern 5: Camera parity

| flutter_map (current) | maplibre_gl equivalent | Parity |
|---|---|---|
| `MapOptions(initialCenter:, initialZoom: 15)` | `initialCameraPosition: CameraPosition(target:, zoom: 15)` | ✅ exact |
| `_mapController.move(LatLng(...), 17)` (rail-card tap, instant) | `controller.moveCamera(CameraUpdate.newLatLngZoom(target, 17))` | ✅ exact |
| — (nicer UX for the same tap) | `controller.animateCamera(CameraUpdate.newLatLngZoom(target, 17), duration: …)` | ✅ upgrade |
| follow-a-moving-target | `controller.easeCamera(update, interpolation: CameraAnimationInterpolation.linear)` — the CHANGELOG explicitly recommends `linear` *"for smooth continuous tracking (e.g. following a moving GPS target) without velocity discontinuities between successive calls"* | ✅ better than flutter_map |
| n/a | `myLocationEnabled`, `myLocationTrackingMode`, `myLocationRenderMode`, `updateMyLocationTrackingMode()` | ✅ native follow-user available if wanted |

Camera API is a **net gain**, not a regression. `[VERIFIED: pub.dev MapLibreMapController API docs + CHANGELOG v0.26.0 #789]`

### Flat-not-3D enforcement (CONTEXT locked decision)

Liberty contains one `fill-extrusion` layer (`building-3d`, `minzoom 14`). At pitch 0 it renders as flat footprints. To guarantee the user's "flat, top-down" decision holds even under gesture:

```dart
MapLibreMap(
  tiltGesturesEnabled: false,     // user can never pitch the camera
  rotateGesturesEnabled: false,   // optional — keeps north-up like flutter_map
  compassEnabled: false,          // pointless with rotation off; frees screen space
  ...
)
```

The style declares no default `pitch`, so the map starts flat. `[VERIFIED: direct style JSON inspection]`

### Anti-Patterns to Avoid

- **Rasterizing `LiveMemberMarker` to PNG bytes for `addImage`/`addSymbol`.** Destroys the widget, its tests, `CachedNetworkImage` avatar caching, semantics labels, and design-token fidelity. Requires re-rasterizing on every location tick.
- **Using `CircleOptions.circleRadius` for the accuracy circle.** Pixel radius means the circle no longer represents meters at any zoom.
- **Passing Flutter `Color` objects to annotation options.** All maplibre_gl color fields are `String?` CSS/hex.
- **Mixing `latlong2.LatLng` and `maplibre_gl.LatLng`.** See Pitfall 1.
- **Calling style/annotation APIs before `onStyleLoadedCallback`.** 0.26.2 fixed a crash for this on Android, but it is still a race.
- **Keeping `SimpleAttributionWidget`.** Redundant with the native attribution button and it no longer exists once `flutter_map` is removed.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Marker screen positions during pan/zoom | Manual Web-Mercator math from `cameraPosition` | `controller.toScreenLocationBatch()` | The native projection accounts for zoom fraction, padding, device pixel ratio, and (if ever enabled) pitch/bearing |
| Attribution text | A hand-written `Text('OpenStreetMap contributors')` | Native attribution button fed by the TileJSON | The TileJSON already carries the exact legally-required string; hand-written text drifts and under-attributes OpenMapTiles |
| Smooth follow-the-user camera | A `Timer` + repeated `moveCamera` | `easeCamera(..., interpolation: CameraAnimationInterpolation.linear)` | Purpose-built for continuous GPS tracking; avoids velocity discontinuities between successive calls |
| Tile caching / offline | Custom HTTP cache | maplibre-native's ambient cache + `OfflineRegion` API | Already built in |

**Key insight:** the split is *rendering in native, presentation in Flutter*. Push geometry (lines, fills) into native annotations where there is no widget content; keep anything with design-system styling, images, semantics, or tap handlers in the Flutter overlay.

## Common Pitfalls

### Pitfall 1: Two competing `LatLng` classes
**What goes wrong:** `maplibre_gl` exports its own `LatLng`. `import 'package:maplibre_gl/maplibre_gl.dart'` alongside `import 'package:latlong2/latlong.dart'` causes an ambiguous-import compile error. `location_models.dart` and `LocationHistory.polylinePoints` are built on `latlong2`.
**How to avoid:** In the two migrated screens, import maplibre_gl unprefixed and drop the `latlong2` import; convert at the boundary (`ml.LatLng(p.lat, p.lng)`). If `latlong2` is genuinely needed in the same file, alias it: `import 'package:latlong2/latlong.dart' as ll;`.
**Warning sign:** `The name 'LatLng' is defined in the libraries ... and ...`

### Pitfall 2: The `@visibleForTesting mapController` seam cannot survive
**What goes wrong:** `LiveMapScreen` accepts a test-owned `flutter_map.MapController` and `live_map_screen_test.dart:307-339` constructs one, taps a rail card, then asserts `controller.camera.center/.zoom`. `MapLibreMapController` is **only** produced by the native platform view via `onMapCreated` — it cannot be constructed in a widget test.
**How to avoid:** Replace the seam with an injectable **camera-command sink** (e.g. `@visibleForTesting void Function(LatLng target, double zoom)? onCameraCommand`) that production wires to `controller.animateCamera(...)`. The test then asserts the *intent* (30.0500 / 31.2400 / zoom 17) without needing a live map. Same coverage, no platform view.
**Warning sign:** planning a task that says "port the MapController test" without redesigning the seam.

### Pitfall 3: `MissingPluginException` on `flutter/platform_views` in widget tests
**What goes wrong:** Any `testWidgets` that pumps a widget tree containing `MapLibreMap` throws `No implementation found for method create on channel flutter/platform_views`. This hits `live_map_screen_test.dart` (the whole file) and `route_stats_sheet_test.dart`.
**How to avoid (preferred):** extract the map into a small injectable widget builder so tests inject a `SizedBox` stand-in and keep asserting the surrounding chrome (overlay card, rail, stat tiles, empty/error states — which is what most of those tests actually cover). Fallback: register a mock handler on the `flutter/platform_views` channel in `test/helpers/`.
**Warning sign:** a plan task that only swaps `find.byType(FlutterMap)` → `find.byType(MapLibreMap)` without addressing the channel.

### Pitfall 4: Async marker reprojection lags the map by ~1 frame
**What goes wrong:** `toScreenLocationBatch()` is a `Future` over a method channel. During a fast fling, overlay pins visibly trail the basemap.
**How to avoid:** accept it (this is what the official example does), and additionally call `_updateMarkerPosition()` from `onCameraIdle` so pins always settle exactly. Keep the batch call — never call `toScreenLocation()` in a per-marker loop.
**Warning sign:** pins "swimming" during pan — expected during motion, a bug only if they don't settle on idle.

### Pitfall 5: Java/Kotlin target mismatch (21 vs 17) and NDK version skew
**What goes wrong:** the plugin module compiles at Java/Kotlin **21**; the app module is pinned to **17**. The plugin also declares `ndkVersion "28.1.13356709"` while Flutter 3.44 defaults the app to `28.2.13676358`. Symptoms range from a benign NDK warning to a hard `Inconsistent JVM-target compatibility` / `Unsupported class file major version` failure depending on AGP/Gradle version.
**How to avoid:** run `cd mobile && flutter build apk --debug` **as the first task of the plan**, before touching Dart. If it fails, raise the app module to `JavaVersion.VERSION_21` / `JvmTarget.JVM_21` (local JDK is 23.0.2, so this is safe) and/or pin `ndkVersion` explicitly. Do this as a discrete, separately-committed task.
**Warning sign:** `Cannot inline bytecode built with JVM target 21 into bytecode that is being built with JVM target 17`.

### Pitfall 6: Platform-view compositing cost vs. the SOS guarantee
**What goes wrong:** `MapLibreMap` is an Android platform view. Hybrid composition adds per-frame compositing overhead, and there are open Flutter issues reporting Impeller performing worse than Skia with platform views. The live map and the always-visible SOS button share the same UI isolate.
**How to avoid:** after migration, manually verify on a real device that the SOS button responds instantly while the map is streaming location updates. 0.26.1 fixed hybrid-composition/textureMode crashes on older Android hardware, so 0.26.2 is the right floor — do not downgrade.
**Warning sign:** SOS tap latency or dropped frames on the live map screen. `[CITED: flutter/flutter#180831, flutter/flutter#126273]`

### Pitfall 7: Attribution assertions silently drop legal attribution
**What goes wrong:** deleting `SimpleAttributionWidget` and its test assertions without confirming the native button is visible and reachable leaves the app under-attributed for OSM/OpenMapTiles/OpenFreeMap.
**How to avoid:** set `attributionButtonPosition` explicitly (the `_LiveMapOverlay` card occupies the top and the rail sits under it — bottom-right is safest) and add a manual verification step confirming the button is tappable and shows the OpenFreeMap/OpenMapTiles/OSM links.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `flutter_test` (Flutter 3.44.5) |
| Config file | `mobile/analysis_options.yaml`; helpers in `mobile/test/helpers/` |
| Quick run command | `cd mobile && flutter test test/features/location/` |
| Full suite command | `cd mobile && flutter test` |

### Affected tests → required change

| File | Current assertion | Required change |
|------|-------------------|-----------------|
| `test/features/location/live_map_screen_test.dart:253` | `find.byType(FlutterMap)` | Assert the injected map stand-in / `MapLibreMap` type |
| `…live_map_screen_test.dart:307-339` | constructs `MapController`, asserts `camera.center/.zoom` after rail tap | **Redesign** — assert via a camera-command sink (Pitfall 2) |
| `…live_map_screen_test.dart` (whole file) | pumps `LiveMapScreen` | Needs platform-view mock or map injection (Pitfall 3) |
| `test/features/location/route_stats_sheet_test.dart:63` | `find.byType(FlutterMap)` | Same as above |
| `…route_stats_sheet_test.dart:64` | `find.textContaining('OpenStreetMap')` | **Delete** — attribution moves to the native button; replace with a manual verification step |
| `test/features/location/live_member_marker_test.dart` (all 7) | `LiveMemberMarker` in isolation, incl. `Opacity` staleness assertions | ✅ **No change** — this is the payoff of the overlay approach |

### Sampling Rate
- **Per task commit:** `cd mobile && flutter analyze && flutter test test/features/location/`
- **Task 1 gate (before any Dart change):** `cd mobile && flutter build apk --debug` must succeed with `maplibre_gl` added
- **Final gate:** `cd mobile && flutter test` full suite green + on-device manual verification

### Wave 0 Gaps
- [ ] `test/helpers/` — a platform-view channel mock **or** a map-injection seam usable by both map tests
- [ ] No new framework install needed

### Manual verification (cannot be automated)
- [ ] Liberty vector tiles render on a real Android device (labels, roads, buildings)
- [ ] Member pins track the basemap during pan/zoom and settle correctly on idle
- [ ] Pin tap opens the member detail sheet; pan/zoom still works between pins
- [ ] Staleness opacity visibly differs for a >15-min-old member
- [ ] Accuracy circle scales with zoom (i.e. stays the same real-world size)
- [ ] Route polyline renders in `RouteStatsSheet` with numbered stop pins
- [ ] Rail-card tap moves the camera to the member at zoom 17
- [ ] Native attribution button visible, tappable, shows OpenFreeMap/OpenMapTiles/OSM
- [ ] Map cannot be tilted (flat, per locked decision)
- [ ] SOS button remains instantly responsive with the map live (CLAUDE.md core value)

## Security Domain

Low-surface change — no auth, session, access-control, or crypto code is touched.

| ASVS Category | Applies | Standard control |
|---------------|---------|------------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | marginal | Style/tile URLs are hard-coded constants, not user input |
| V6 Cryptography | no | — |
| V9 Communications | yes | All OpenFreeMap endpoints are HTTPS (verified: style, TileJSON, tiles, glyphs, sprites) |

| Pattern | STRIDE | Mitigation |
|---------|--------|------------|
| Third-party tile CDN can observe approximate viewport (privacy-first positioning) | Information disclosure | Same trust posture as the current `tile.openstreetmap.org` source; OpenFreeMap states no registration, no API keys, **no cookies**. Explicitly accepted in CONTEXT.md. |
| Malicious/compromised style JSON altering rendering | Tampering | HTTPS + a pinned, hard-coded style URL. Self-hosting is the documented hardening path (deferred by user decision). |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The Java-21-vs-17 module mismatch will not hard-fail the build (AGP's JVM-target consistency check is intra-module) | Native Setup / Pitfall 5 | Build fails at Task 1 — **mitigated** by making `flutter build apk --debug` the first plan task before any Dart change |
| A2 | `ACCESS_COARSE_LOCATION` and `ACCESS_FINE_LOCATION` are already in AndroidManifest.xml (inferred from `geolocator` + `flutter_foreground_task` + a passing permission-gate test) | Native Setup | Map fails to show user location; trivial one-line manifest fix |
| A3 | `NSLocationWhenInUseUsageDescription` already exists in iOS Info.plist | Native Setup | iOS-only; iOS is unbuildable on this machine anyway |
| A4 | A bare `Stack` overlay (no `IgnorePointer`) lets pan/zoom gestures pass through gaps to `MapLibreMap` | Pattern 1 | Map becomes ungesturable — caught immediately by the first on-device check |
| A5 | The `maplibre` package (josxha rewrite) has a widget `MarkerLayer` making it an easier target | Alternatives | Only matters as a fallback; CONTEXT locks `maplibre_gl` |

## Open Questions

1. **Should rail-card taps animate instead of jump?**
   - Known: `flutter_map`'s `.move()` is instant; `animateCamera` is a strict superset.
   - Unclear: whether "as close to 1:1 as the API allows" means preserving the jump.
   - Recommendation: use `animateCamera` with a short duration (~300ms) — a UX improvement consistent with the design-conscious profile — and call it out in the summary.

2. **Where should the native attribution button sit?**
   - Known: `_LiveMapOverlay` + `_MemberStatusRail` occupy the top; `LowBatteryBanner` may appear below them.
   - Recommendation: bottom-right with a small margin; confirm during on-device verification.

3. **Does the route sheet need marker reprojection at all?**
   - Known: `RouteStatsSheet` markers are static numbered stops in a fixed 360px map.
   - Recommendation: reuse the same overlay mechanism for consistency; the user can still pan/zoom the sheet map, so reprojection is still required.

## Environment Availability

| Dependency | Required by | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Flutter SDK | build | ✅ | 3.44.5 stable (2026-07-06) | — |
| Dart SDK | `maplibre_gl` `>=3.7.0 <4.0.0` | ✅ | bundled (pubspec `^3.12.2`) | — |
| JDK | plugin Java-21 bytecode | ✅ | 23.0.2 | — |
| Android SDK 36 | plugin `compileSdk 36` | ✅ | via `flutter.compileSdkVersion` = 36 | — |
| Android NDK | plugin declares 28.1.13356709 | ⚠️ | Flutter default 28.2.13676358 | explicit `ndkVersion` pin |
| `tiles.openfreemap.org` | style + tiles | ✅ | HTTP 200 verified (style, TileJSON) | — |
| CocoaPods / Xcode | iOS build | ✗ | — | iOS deferred (Windows dev machine, no `mobile/ios/Podfile`) |

**Missing with no fallback:** none blocking Android.
**Missing with fallback:** iOS toolchain — iOS validation deferred, not blocking.

## Runtime State Inventory

Migration-shaped task; all five categories checked explicitly.

| Category | Items found | Action required |
|----------|-------------|-----------------|
| Stored data | **None** — no map library identifier is persisted. Location rows store lat/lng/accuracy only. Verified by grep for `flutter_map`/`latlong2` across `lib/` and `test/`. | none |
| Live service config | **None** — `tile.openstreetmap.org` is hard-coded in the two Dart files; no dashboard, no API key, no registered app. | none |
| OS-registered state | **None** — no OS registration references the map library. `flutter_foreground_task`'s notification channel is unrelated. | none |
| Secrets / env vars | **None** — the current OSM tile URL needs no key, and OpenFreeMap explicitly requires none. `userAgentPackageName: 'com.safepath.mobile'` is a flutter_map-only concept and disappears with it. | none |
| Build artifacts | `mobile/build/`, `mobile/android/build/` (untracked, present per git status), `mobile/pubspec.lock`, Gradle caches. Removing `flutter_map` and adding a plugin with native code invalidates them. | `flutter clean && flutter pub get` before the first build |

## Sources

### Primary (HIGH confidence — verified by direct fetch)
- `https://tiles.openfreemap.org/styles/liberty` — style JSON fetched and parsed (v8, 111 layers, sources/glyphs/sprite, no proprietary extensions, no terrain/sky/projection)
- `https://tiles.openfreemap.org/planet` — TileJSON: attribution string, zoom range, 16 vector layers
- `github.com/maplibre/flutter-maplibre-gl` `maplibre_gl/android/build.gradle` — minSdk 21, compileSdk 36, Java/Kotlin 21, ndk 28.1.13356709, native deps
- `github.com/maplibre/flutter-maplibre-gl` `maplibre_gl/ios/maplibre_gl.podspec` — iOS 13.0, MapLibre pod 6.27.0
- `github.com/maplibre/flutter-maplibre-gl` `maplibre_gl/pubspec.yaml` — v0.26.2, Dart >=3.7.0 <4.0.0, Flutter >=3.29.0
- `github.com/maplibre/flutter-maplibre-gl` `CHANGELOG.md` — OpenFreeMap Liberty tested; `easeCamera` linear-interpolation guidance for GPS tracking; 0.26.1 hybrid-composition fixes
- `github.com/maplibre/flutter-maplibre-gl` `maplibre_gl/lib/src/controller.dart` — `MapLibreMapController extends ChangeNotifier`, camera notify path (lines 93-202, 367-373)
- `maplibre_gl_platform_interface/lib/src/{symbol,circle,line,fill}.dart` — full option field lists
- `maplibre_gl_example/lib/examples/annotations/custom_marker.dart` — canonical widget-overlay pattern
- Flutter SDK `flutter_tools/gradle/.../FlutterExtension.kt` — compileSdk 36, minSdk 24, targetSdk 36, ndk 28.2.13676358
- Local repo: `mobile/pubspec.yaml`, `mobile/android/app/build.gradle.kts`, `mobile/ios/Runner.xcodeproj/project.pbxproj`, the two map screens, `staleness.dart`, and all three location test files

### Secondary (MEDIUM confidence)
- [pub.dev/packages/maplibre_gl](https://pub.dev/packages/maplibre_gl) — version, publisher, downloads, likes, pub points
- [pub.dev MapLibreMapController API](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMapController-class.html) — method signatures
- [pub.dev MapLibreMap API](https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/MapLibreMap-class.html) — constructor parameters
- [maplibre.org/flutter-maplibre-gl/getting-started/](https://maplibre.org/flutter-maplibre-gl/getting-started/) — permissions, Info.plist, usage
- [openfreemap.org](https://openfreemap.org/) — styles, attribution requirement, no-limits/no-keys/no-cookies terms

### Tertiary (LOW confidence — flagged, not relied upon)
- [flutter/flutter#180831](https://github.com/flutter/flutter/issues/180831) — Impeller vs Skia platform-view performance
- [flutter/flutter#126273](https://github.com/flutter/flutter/issues/126273) — hybrid composition raster-thread option
- [flutter-mapbox-gl/maps#1386](https://github.com/flutter-mapbox-gl/maps/issues/1386) — `flutter/platform_views` MissingPluginException in widget tests (upstream fork, same architecture)

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** — version, SDK constraints, and native config read from upstream source, not inferred
- Style compatibility: **HIGH** — style JSON and TileJSON fetched and parsed directly; maintainers name Liberty in the CHANGELOG
- Annotation/camera API: **HIGH** — option classes and controller read from source; overlay pattern is the official example
- Native build config: **MEDIUM-HIGH** — all version numbers verified; the Java-21-vs-17 outcome is unverifiable without an actual build (A1, mitigated by a build-first task)
- Test impact: **HIGH** — every affected assertion located by line number in the repo
- Pitfalls: **MEDIUM-HIGH** — API-derived pitfalls are HIGH; platform-view performance is LOW/anecdotal and marked as such

**Research date:** 2026-08-06
**Valid until:** 2026-09-05 (30 days — `maplibre_gl` ships roughly monthly; re-verify the version if planning slips)
