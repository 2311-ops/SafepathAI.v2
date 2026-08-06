---
status: verifying
trigger: "Live Map pin jitter during pan /gsd-debug fix this error and also see the maps as it doesnt display my correct location and keep having this in the build: I/SurfaceControl nativeRelease nativeObject churn, W/libEGL EGLNativeWindowType disconnect failed, E/BufferQueueProducer disconnect: not connected (req=1), around FlutterSurfaceView/MainActivity during map interaction, following the 260806-3zb flutter_map -> maplibre_gl/OpenFreeMap migration."
created: 2026-08-06
updated: 2026-08-06 (fix applied, awaiting human verification)
---

## Symptoms

**Expected behavior:** Panning the Live Map should track the basemap smoothly with the family/self avatar pin staying visually locked to its true geographic position, and the pin should reflect the user's actual current GPS location.

**Actual behavior:**
1. Panning left/right makes the family/self pin visibly "roll"/vibrate rather than tracking smoothly (previously logged in `.planning/todos/pending/2026-08-06-live-map-pin-jitter-during-pan.md` with a preliminary hypothesis, not yet independently confirmed on-device).
2. The map does not display the user's correct current location (new report, not yet investigated — pin may be stale, defaulted, or off by a fixed offset).

**Error messages:** No Dart/Flutter exception reported by the user. Android logcat during map interaction shows repeated native surface/EGL churn around `FlutterSurfaceView` on `MainActivity`:
```
I/SurfaceControl: nativeRelease nativeObject s[...]/e[...]  (repeated)
I/SurfaceView: onWindowVisibilityChanged / surfaceDestroyed callback
W/libEGL: EGLNativeWindowType 0x... disconnect failed  (x2)
I/SurfaceControl: assignNativeObject: nativeObject = 0 Surface(name=null)  (via ViewRootImpl.relayoutWindow / Choreographer.doFrame)
E/BufferQueueProducer: [ImageReader-1080x2214f22m7-...] disconnect: not connected (req=1)
```
Status of this log as causal vs. benign is unconfirmed — needs to be evaluated against `maplibre_gl`'s hybrid-composition PlatformView lifecycle (forced via `015bc72 fix(260806-3zb): force hybrid composition so family/stop pins actually render`), which is known to recreate/destroy native Android Surfaces during PlatformView compositing.

**Timeline:** Both symptoms first observed 2026-08-06, after the 260806-3zb migration from `flutter_map`/raster OSM tiles to `maplibre_gl`/OpenFreeMap Liberty vector tiles was rebuilt on-device. Never confirmed working correctly under the new renderer.

**Reproduction:**
1. Open the Live Map screen on Android.
2. Pan the map left/right — family/self pin visibly jitters/rolls instead of smoothly tracking.
3. Observe the pin's position relative to the device's actual current location — reported incorrect (specifics — how far off, static vs. moving — not yet gathered from user).
4. Watch `adb logcat` during step 2/3 for the SurfaceControl/EGL/BufferQueueProducer lines above.

## Suspected Area (carried over from prior investigation, unconfirmed)

`mobile/lib/features/location/presentation/vector_map.dart`:
- `_onControllerNotified` (~L270-276): fires on every native camera-move tick during a pan gesture.
- `_reprojectMarkers` (~L341-): unguarded async method-channel round-trip (`toScreenLocationBatch`) per tick, no generation counter/in-flight guard — overlapping calls can resolve out of order, causing a stale coordinate to briefly overwrite a newer one (matches "roll/vibrate" rather than one-directional lag).
- `_onCameraIdle` (~L285-290): where the pin is expected to settle to a correct final position.
- Related, not-yet-checked: `_drawAnnotations()` was flagged in code review (WR-02, advisory) for the identical missing-in-flight-guard pattern; unclear whether `_reprojectMarkers` shares the same gap in practice.
- Current-location source feeding the pin (device GPS via `geolocator` vs. last broadcast/backend position) not yet located in this file — needs tracing to confirm which is wrong for symptom 2.

## Current Focus

- status: root causes CONFIRMED on-device; entering fix.

reasoning_checkpoint:
  hypothesis: |
    RC-1 (symptom 2, "wrong location") — the self pin and the camera are driven by two
    independent, both-broken paths. (a) The app never performs a one-shot device GPS read, so
    on a stationary device `selfPosition` stays at whatever the server/hub last reported and
    the device's own fix may never be established in a session. (b) The camera is bound to
    `MapLibreMap.initialCameraPosition`, which the plugin reads ONLY at platform-view
    creation, so once the map exists the camera can never follow a corrected `selfPosition`.
    RC-2 (symptom 1, "jitter") — `_reprojectMarkers()` performs an async platform-channel
    round-trip on every native camera tick to obtain a projection whose inputs Dart already
    holds synchronously; the variable per-call latency makes the applied marker offset advance
    in irregular increments, which reads as vibration/roll rather than smooth trailing.
  confirming_evidence:
    - "E-08: live on-device — camera sat on Tanaydah, Egypt with NO pin visible; tapping the 'You' rail card (animateTo the marker's own coordinate) moved the camera thousands of km and the pin rendered perfectly centred. Camera and marker were provably decoupled."
    - "E-07: plugin source — `initialCameraPosition` is referenced only at maplibre_map.dart:336-337 (creationParams) and :393 (controller seed); `didUpdateWidget` diffs only `MapLibreMapOptions`, which carries no camera. A changed initialTarget is therefore a guaranteed no-op."
    - "E-01/E-02: `Geolocator.getPositionStream(distanceFilter: 10)` is the ONLY GPS read in the entire app; no getCurrentPosition/getLastKnownPosition exists."
    - "E-09: the marker was showing Googleplex (emulator-origin data) while the device is physically in Egypt — the device's own GPS had not established a fix this session, exactly as RC-1(a) predicts."
    - "E-10: plugin source controller.dart:190-193 — `_cameraPosition` is assigned synchronously and only THEN is `notifyListeners()` fired, so `_onControllerNotified` already has the fresh camera state in Dart when it chooses to ask native for it over a channel."
  falsification_test: |
    RC-1(b) would be false if tapping the rail card had NOT brought the pin into view (that
    would mean the marker itself was mispositioned rather than the camera being stranded) —
    it did, so RC-1(b) holds. RC-2 would be false if `controller.cameraPosition` were stale or
    unset at notification time (making the native round-trip genuinely necessary) — plugin
    source shows the opposite. RC-2 would also be false if the jitter persisted after the
    round-trip is removed; that is the on-device check for this fix.
  fix_rationale: |
    RC-2 is fixed by deleting the redundant async round-trip entirely and projecting
    synchronously in Dart from `controller.cameraPosition` + the widget's own layout size —
    this removes the variable-latency term that IS the root cause, rather than a generation
    guard, which would only stop stale replies overwriting newer ones and would leave the
    irregular-increment lag (the actual visible defect) fully intact. RC-1(a) is fixed by a
    one-shot `getCurrentPosition()` at bootstrap feeding the existing report/apply path.
    RC-1(b) is fixed by re-centring the camera once, when this device's own GPS fix first
    lands — the one moment where the camera is provably pointing at a coordinate the user did
    not choose and does not want.
  blind_spots: |
    - The synchronous projection assumes MapLibre's core scale convention (worldSize =
      512 * 2^zoom LOGICAL px) and a north-up, unpitched camera. The zoom convention is
      inferred from plugin/native source, not measured; north-up is architecturally enforced
      by D-01 (`rotateGesturesEnabled: false`, `tiltGesturesEnabled: false`) but the math
      would silently break if rotation is ever enabled. Requires on-device confirmation.
    - Jitter magnitude was never directly measured — `adb screencap` latency (~200 ms) exceeds
      the transient, so RC-2 rests on mechanism plus structural confirmation, not a captured
      frame. The post-fix on-device pan is the real test.
    - Whether the Googleplex coordinate reached this device via a stale hub broadcast or via
      the REST bootstrap was not distinguished; it does not change either root cause.

## Evidence

- timestamp: 2026-08-06 (E-01)
  checked: Grepped all of `mobile/` for every geolocator position-read API (`getCurrentPosition|getLastKnownPosition|getPositionStream|distanceFilter`).
  found: Exactly TWO hits, both in `location_controller.dart:72,75` — `Geolocator.getPositionStream(locationSettings: LocationSettings(accuracy: high, distanceFilter: 10))`. There is NO `getCurrentPosition()` and NO `getLastKnownPosition()` anywhere in the app.
  implication: The app has no one-shot "where am I right now" read. The self pin's position on app open comes entirely from the server, and can only ever be corrected by a stream emission — which `distanceFilter: 10` suppresses until the device physically moves 10 m.

- timestamp: 2026-08-06 (E-02)
  checked: `location_controller.dart:164-191` (`_bootstrap`) — how `selfPosition` and `members` are first populated.
  found: `getLiveLocations(familyId)` (REST) seeds `members`, and `selfPosition = initialMembers[currentUserId]` — i.e. the last position the server has on record for this user, of arbitrary age. `_reportPosition` (L305) is the only writer of a fresh GPS fix, and it is driven solely by the `distanceFilter: 10` stream.
  implication: Confirms E-01's consequence. On a cold open while stationary, `selfPosition` is a historical server value, not the current fix. This alone reproduces "the map does not display my correct location."

- timestamp: 2026-08-06 (E-03)
  checked: `live_map_screen.dart:112-113, 184-188` and `vector_map.dart:405-410` — the camera-target path.
  found: `cameraTarget = MapPoint(self.lat, self.lng)` where `self = state?.selfPosition ?? locations.first`, passed as `VectorMap.initialTarget` -> `MapLibreMap.initialCameraPosition`. `initialCameraPosition` is consumed by the plugin only when the platform view is created; `VectorMap` has no `didUpdateWidget` branch for `initialTarget`, so a later, corrected `selfPosition` moves the marker but NEVER moves the camera.
  implication: Second, independent contributor to symptom 2. Worse: if the server has no row for the current user at all, `selfPosition` is null and the camera opens centred on `locations.first` — an arbitrary OTHER family member. The only camera move in the whole screen is a `_MemberStatusRail` card tap; there is no "recentre on me" control.

- timestamp: 2026-08-06 (E-04)
  checked: `AndroidManifest.xml` for location permissions.
  found: `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION` both declared. `permission_controller.dart` maps `always`/`whileInUse` -> granted and gates `_bootstrap`.
  implication: Permission plumbing is NOT the cause of symptom 2 — the pipeline is permitted to run; it simply has no initial-fix source.

- timestamp: 2026-08-06 (E-05)
  checked: `vector_map.dart:341-399` (`_reprojectMarkers`) for an in-flight/generation guard.
  found: Structurally confirmed — no generation counter, no in-flight token, no cancellation. `_onControllerNotified` (L270-277) fires it unthrottled on every native camera tick, and `_onCameraIdle` (L285) and `didUpdateWidget` (L233) fire it too. Every invocation does an `await controller.toScreenLocationBatch(...)` then an unconditional `setState`.
  implication: The prior todo's structural claim is verified. Note the mechanism is broader than "replies invert": even with perfectly ordered replies, each reply lands after a VARIABLE method-channel latency, so the applied marker offset lags the basemap by a varying number of frames. Constant lag reads as smooth trailing; variable lag reads as vibration/roll. This matches the reported symptom without requiring out-of-order delivery.

- timestamp: 2026-08-06 (E-06)
  checked: `maplibre_gl-0.26.2` native sources for the units returned by `map#toScreenLocationBatch`, to audit whether commit b5aa00b's physical->logical conversion is complete and correct.
  found: Android (`MapLibreMapController.java:926-939`) returns `mapLibreMap.getProjection().toScreenLocation(...)` raw, and MapLibre Android's `NativeMapView.pixelForLatLng` multiplies the core result by `pixelRatio` — so Android really does return PHYSICAL px and the conversion is correct there. iOS (`MapLibreMapController.swift:572-592`) returns `mapView.convert(coordinate, toPointTo: mapView)`, a `CGPoint` in UIKit POINTS (already logical). Confirmed device density 420 -> devicePixelRatio exactly 2.625, matching the value recorded in the code comment, so that measurement was taken on this physical Galaxy A30.
  implication: b5aa00b is correct for Android but would be WRONG on iOS — dividing an already-logical point by ~3 would clump every pin toward the top-left. A latent cross-platform defect, not a cause of either reported symptom. Reported, not fixed (out of the reported scope; see final report).

- timestamp: 2026-08-06 (E-07)
  checked: `maplibre_gl-0.26.2/lib/src/maplibre_map.dart` — every reference to `initialCameraPosition`, plus `_MapLibreMapState.didUpdateWidget`.
  found: Only three references — L123 (field), L336-337 (serialized into the platform view's `creationParams`), L393 (seeds the controller's `_cameraPosition` in `onPlatformViewCreated`). `didUpdateWidget` (L370-380) computes `MapLibreMapOptions.fromWidget(widget)` and applies only `updatesMap` diffs; `MapLibreMapOptions` carries no camera position at all.
  implication: PROVES E-03. Once the platform view exists, changing `initialTarget` is a guaranteed no-op. The camera can only be moved by an explicit `animateCamera`/`moveCamera` call, of which the app makes exactly one — a `_MemberStatusRail` card tap.

- timestamp: 2026-08-06 (E-08)
  checked: Live reproduction on the connected physical device (Samsung SM-A305F, Android 11, 1080x2340 @ density 420, app `com.safepath.mobile` already installed).
  found: Map opened centred on **Tanaydah, Egypt** with the rail card reading "You / Online" but **NO pin anywhere on the map**. Ten pan gestures did not reveal it. Tapping the "You" rail card — which calls `animateTo(member.location.lat, member.location.lng, zoom: 17)`, i.e. the marker's OWN coordinate — snapped the camera to a completely different place where the pin and its accuracy circle rendered perfectly, dead-centre.
  implication: DECISIVE confirmation of RC-1(b). The marker data and the marker rendering are both fine; the camera was stranded thousands of km away at the coordinate captured at map-creation time. This is the whole of "the map does not display my correct location" as the user experiences it.

- timestamp: 2026-08-06 (E-09)
  checked: The basemap at the marker's coordinate once tiles finished loading (screenshot `drag2.png`).
  found: The self marker sits at **Googleplex, Mountain View, California** — "Google Main Sand Court", "Yoshka's", "Charlie's Cafe", "Amphitheatre Parkway", "Charleston Road". That is the Android emulator's default fake GPS location, and it matches the emulator screenshots taken during the 260806-3zb verification pass (`verify_v3_02.png`). The device itself is physically in Egypt.
  implication: Confirms RC-1(a) end-to-end: this physical device's own GPS never established a fix during the session, so `selfPosition` remained emulator-origin data carried by the server/hub. With no one-shot read and `distanceFilter: 10` suppressing stream emissions while stationary, there was no mechanism for the device's real position to ever assert itself.

- timestamp: 2026-08-06 (E-10)
  checked: `maplibre_gl-0.26.2/lib/src/controller.dart:187-202` — the ordering between camera-state assignment and listener notification.
  found: `onCameraMovePlatform` handler assigns `_cameraPosition = cameraPosition` FIRST, then calls `notifyListeners()`. `cameraPosition` is a plain synchronous getter (L372-373).
  implication: The fresh camera target/zoom is already in Dart memory at the exact moment `_onControllerNotified` runs. The `toScreenLocationBatch` round-trip asks the native side to recompute a projection from inputs Dart already holds — it is pure redundant latency. This makes a synchronous Dart projection the correct root-cause fix rather than a mitigation.

- timestamp: 2026-08-06 (E-11)
  checked: Whether the SurfaceControl/libEGL/BufferQueueProducer churn is caused by map interaction. Cleared logcat, performed 10 pan gestures on the live map, dumped logcat.
  found: **ZERO** SurfaceControl/libEGL/BufferQueue/surfaceCreated/surfaceDestroyed lines from the app process (pid 2429) across all 10 pans, despite 149 app-process log lines in the window. In the earlier capture, all 17 app-process surface lines clustered at exactly two timestamps — app-to-foreground (18:32:03) and screen-wake/window-resize (18:32:34) — and every stack trace ran through `ViewRootImpl.relayoutWindow` <- `performTraversals` <- `Choreographer.doFrame`. The remaining 113 lines came from `system_server` (pid 4285) and SystemUI (pid 4620), not the app. `FlutterSurfaceView{... 0,0-1080,2214}` matches the `ImageReader-1080x2214` name exactly (2340 physical minus the 126px status bar).
  implication: The log is benign. It is Android's normal SurfaceView relayout on window-visibility change plus Flutter's standard `FlutterSurfaceView` -> `FlutterImageView` swap for platform-view compositing, and it is entirely absent during map interaction. Not causal for either symptom.

## Eliminated

- hypothesis: The SurfaceControl/libEGL/BufferQueueProducer logcat churn indicates a real native view-lifecycle defect introduced by forcing hybrid composition (015bc72), and contributes to the jitter.
  evidence: E-11 — a controlled 10-pan experiment on the physical device produced zero such lines from the app process; every occurrence in the session was tied to window visibility/relayout transitions (foreground, screen wake, 2340<->2214 resize) via `ViewRootImpl.relayoutWindow`, and most lines originated from system_server/SystemUI rather than the app at all.
  timestamp: 2026-08-06

- hypothesis: The jitter is caused by out-of-order resolution of overlapping `toScreenLocationBatch` replies (the prior todo's stated mechanism), and is therefore fixable with a generation counter.
  evidence: Partially superseded rather than simply wrong. The missing in-flight guard is real (E-05), but E-10 shows the deeper defect: the round-trip is redundant because Dart already holds the camera state synchronously. A generation guard would only prevent a stale reply overwriting a newer one; it cannot make the newest available reply any fresher, so the irregular per-frame increments that actually produce the visible vibration would survive it. Ordering was therefore not the operative mechanism, and the guard is not a sufficient fix.
  timestamp: 2026-08-06

- hypothesis: Missing/denied Android location permissions cause the wrong-location symptom.
  evidence: E-04 — both fine and coarse location are declared in the manifest, and `_bootstrap` is hard-gated on `permissionControllerProvider.isGranted`, so the map only renders at all once permission is granted.
  timestamp: 2026-08-06

- hypothesis: A lat/lng swap in serialization causes the wrong-location symptom.
  evidence: Read `location_models.dart` end to end — `LiveLocation.fromJson` reads `json['lat']`/`json['lng']` into `lat`/`lng`, `ReportLocationPayload.toJson` writes `latitude`/`longitude` from `position.latitude`/`position.longitude`, and `live_map_screen.dart` builds `MapPoint(location.lat, location.lng)` and `OverlayMarker(lat: location.lat, lng: location.lng)`. No axis is transposed on any path. A swap would also put the pin in the ocean, not "slightly wrong."
  timestamp: 2026-08-06

- timestamp: 2026-08-06 (E-12)
  checked: Post-fix on-device validation of the synchronous projection, using the natively-drawn accuracy circle (drawn by MapLibre itself in lat/lng space, independent of any Dart math) as ground truth for the Flutter pin's position.
  found: Concentric across the whole viewport. Marker parked in open space: circle centre (585, 1234) displayed, pin anchor (585, 1158) predicted vs (585, 1155) measured — agreement within ~3 px. Marker dragged to the far top-left corner: predicted avatar y 370 vs measured 370, at a lever arm of ~554 displayed px from centre where a wrong tile-size constant (256 vs 512) would have thrown the pin completely off-screen. Re-running the exact held-drag sequence from the pre-fix build reproduced an identical frame with identical pin/circle separation (~4.6 px vs the old build's ~5.6 px — both within the constant offset of my avatar-centre measurement method).
  implication: The `worldSize = 512 * 2^zoom` LOGICAL-pixel convention is correct on real hardware, and steady-state marker accuracy is unchanged from the pre-fix build. The blind spot recorded in the reasoning checkpoint is closed.

- timestamp: 2026-08-06 (E-13)
  checked: Logcat after installing the first fixed build and exercising the map.
  found: `E/flutter: Unhandled Exception: An unexpected error occurred invoking 'ReportLocation' on the server.` The backend's `ReportLocation` hub method is genuinely failing against the locally-hosted API. Reading `_reportPosition`, `await hubClient.reportLocation(payload)` sat BEFORE `_applyLocation(...)`, with no try/catch.
  implication: A THIRD contributor to symptom 2, and the most severe: the user's own map only displayed their own position if the backend accepted the ping first. With `ReportLocation` failing, every device fix was discarded before it ever reached local state, so `hasDeviceFix` never latched, the camera never recentred, and the pin stayed on the stale server coordinate — regardless of how good the GPS was. Also the source of the unhandled async error, since `_reportPosition` is invoked fire-and-forget from the stream listener.

- timestamp: 2026-08-06 (E-14)
  checked: Cold start of the final build on the physical device (force-stop, relaunch, 30 s).
  found: The map opens on **New Cairo / El Rehab / Lotus Districts (القاهرة الجديدة، الرحاب)** — the device's true location — with the self pin visible and the camera centred on it. Zero unhandled exceptions in logcat (was 1). The `ReportLocation` server failure now appears only as a caught diagnostic line and no longer affects what the map displays. Panning moved the basemap by (-67, -19) displayed and the pin by (-73, -9); the ~4 px difference is within eyeball-measurement error, so the pin tracks the basemap.
  implication: Symptom 2 is resolved end-to-end on the reporting device, with the backend still broken — which is exactly the decoupling the fix was meant to achieve.

## Resolution

root_cause: |
  Three independent defects, two of them behind the same reported symptom.

  RC-1 "the map does not display my correct location" — a three-link chain, every
  link of which had to be broken for the map to be right:
    (a) `_reportPosition` awaited `hubClient.reportLocation()` BEFORE applying the fix
        to local state. The backend's `ReportLocation` was failing, so every device
        GPS fix was thrown away before it reached the map (E-13). Rendering your own
        location on your own map was gated on a successful server round-trip.
    (b) No one-shot GPS read existed anywhere in the app. The only consumer was
        `getPositionStream(distanceFilter: 10)`, which emits nothing while the user
        stays put, so a stationary device could go a whole session without ever
        establishing its own position (E-01, E-02, E-09).
    (c) The camera was bound to `MapLibreMap.initialCameraPosition`, which the plugin
        reads only at platform-view creation; its `didUpdateWidget` diffs map *options*,
        which carry no camera (E-07). So a corrected position moved the pin but left the
        camera stranded on the bootstrap snapshot — observed live as a map sitting on
        Tanaydah with the pin thousands of km away at Googleplex and no pin on screen
        at all (E-08).

  RC-2 "pin rolls/vibrates while panning" — `_reprojectMarkers()` did an async
  `toScreenLocationBatch()` platform-channel round trip on every native camera tick and
  then `setState`. The plugin assigns `controller.cameraPosition` synchronously
  *immediately before* firing the notification that triggered that round trip (E-10), so
  it recomputed, off-thread and with variable latency, a projection whose inputs Dart
  already held. Variable latency means the applied offset advances in irregular
  increments frame to frame, which reads as vibration rather than smooth trailing. The
  missing in-flight guard flagged by the earlier todo was real but not the operative
  mechanism — a generation counter cannot make the newest reply any fresher.

fix: |
  - `location_controller.dart`: apply the device fix to local state FIRST and
    unconditionally, then report to the hub inside a try/catch (best-effort, logged).
    Added `currentPositionProvider`, a one-shot `Geolocator.getCurrentPosition()` taken
    once per bootstrap, unawaited so it can never delay the map or the SOS path, and
    failure-tolerant. Added `LocationState.hasDeviceFix`, latching true only for fixes
    originating from this device's own GPS.
  - `live_map_screen.dart`: `ref.listen` centres the camera on the false -> true edge of
    `hasDeviceFix` — exactly once, so it can never fight the user's panning.
  - `vector_map.dart`: deleted the async reprojection entirely. Markers are now projected
    synchronously during `build()` by a new pure `projectToScreen()` (Web Mercator,
    `worldSize = 512 * 2^zoom` logical px, antimeridian-normalised, latitude-clamped),
    fed by `controller.cameraPosition` and the map's own `LayoutBuilder` size. The
    camera-change listener now only requests a rebuild. `_onMapCreated` replays a pending
    camera command so a centre request issued before the platform view existed is not
    dropped. `physicalToLogicalOffset` and its tests are gone with the code path they served.

verification: |
  - 322 unit/widget tests pass; the only 2 failures are `member_map_pin_semantics_test.dart`,
    confirmed pre-existing by stashing the change and reproducing them on unmodified code.
  - 8 new `projectToScreen` tests, including one that anchors the 512-tile scale convention
    to the WGS84 equatorial circumference rather than to the implementation itself.
  - The `ReportLocation` regression test was confirmed red against the old ordering before
    being made green (temporary revert, `Expected: <30.0444> Actual: <null>`).
  - On-device (Samsung SM-A305F, Android 11, release build): projection validated against
    the native accuracy circle across the viewport including the far corner (E-12); cold
    start now opens on the device's true location in New Cairo with the pin centred (E-14);
    unhandled exceptions 0 (was 1); zero surface churn during map interaction.
  - NOT verified by me: whether the jitter is gone to the human eye. `adb screencap`
    composites the platform-view layer and the Flutter overlay layer independently and
    takes ~200 ms, so it cannot capture the sub-frame transient. This is the checkpoint item.

files_changed:
  - mobile/lib/features/location/presentation/vector_map.dart
  - mobile/lib/features/location/presentation/live_map_screen.dart
  - mobile/lib/features/location/application/location_controller.dart
  - mobile/test/features/location/vector_map_test.dart
  - mobile/test/features/location/location_controller_test.dart

out_of_scope_findings:
  - "`physicalToLogicalOffset` (commit b5aa00b) was correct for Android but would have been WRONG on iOS: Android returns physical px from `Projection.toScreenLocation`, iOS returns UIKit points (already logical), so iOS pins would have clumped toward the top-left by a factor of devicePixelRatio. Moot now — the function and the code path are deleted — but worth knowing if the native projection is ever reintroduced. (E-06)"
  - "The backend's `ReportLocation` hub method is genuinely failing (`An unexpected error occurred invoking 'ReportLocation' on the server`) against the locally-hosted API. The client no longer breaks because of it, and it is now logged rather than silent, but the server-side cause is undiagnosed and location pings are NOT reaching the database or other family members."
  - "`_drawAnnotations()` still has the missing-in-flight-guard pattern flagged as WR-02 (it does `clearFills()/clearLines()` then re-adds, so two overlapping runs can interleave). Not touched — no reported symptom, and it is not on the per-frame path."
