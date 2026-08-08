---
task: 260806-3zb-migrate-map-rendering-from-flutter-map-t
verified: 2026-08-06T00:00:00Z
status: human_needed
score: 6/9 must-haves verified
behavior_unverified: 3
overrides_applied: 0
gaps: []
behavior_unverified_items:
  - truth: "The SOS button stays instantly responsive while the native map platform view is live and location is streaming (plan Task 3 step 12, threat register T-3ZB-03, project's own CLAUDE.md non-negotiable)."
    test: "Open Live Map with location streaming, press-and-hold the SOS button, confirm the very first touch responds with no perceptible delay, the press animation and 3-2-1 countdown run smoothly, and a full hold arms and opens the emergency session screen exactly as before this migration."
    expected: "No hesitation or dropped frames anywhere in the SOS press/countdown/arm sequence while the vector map is composited on the same UI isolate."
    why_human: "Cannot be exercised without a real Android device/emulator with live location streaming and a physical hold-and-release gesture; the SUMMARY explicitly states this check was deferred to the user and 'remains genuinely unverified as of this SUMMARY' — it was not attempted by anyone (human or the executing agent) during this task's own execution."
  - truth: "Route-sheet numbered stop pins stay glued to their real-world coordinate through pan/zoom and are actually visible on a real device (must_haves truth 3, applied to RouteStatsSheet)."
    test: "Open a member's history with route data, tap 'View route', pan/zoom the sheet's map, confirm each numbered stop pin tracks the basemap and settles on its street."
    expected: "Stop pins behave identically to the now-confirmed member pins (same VectorMap/_reprojectMarkers/physicalToLogicalOffset mechanism)."
    why_human: "SUMMARY's own 'Known Gaps' #1: the only test account had no location history ('No history yet'), so RouteStatsSheet was never opened during any on-device pass. High confidence by shared-mechanism inference only, not an eyeball confirmation."
  - truth: "A family member's pin fades per staleness the same way the pre-migration marker alpha did (must_haves truth 2), end-to-end on a real device."
    test: "With a multi-member family circle where a non-self member's last ping is >15 min old, confirm that member's pin is visibly faded relative to a fresh one on the vector basemap."
    expected: "Pin opacity matches stalenessFor(...).opacity, visibly dimmer than an online member's pin."
    why_human: "SUMMARY's own 'Known Gaps' #2: the only account available on the test emulator is a self-only family circle, and isSelf always renders at full opacity by design, so the fade path was never reachable during any on-device pass. The underlying unit test passes, but end-to-end visual confirmation with a real stale multi-member circle is outstanding."
---

# Quick Task 260806-3zb: Migrate map rendering from flutter_map to maplibre_gl Verification Report

**Task Goal:** Migrate map rendering from flutter_map to maplibre_gl for OpenFreeMap vector-tile styles
**Verified:** 2026-08-06
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (from PLAN frontmatter `must_haves.truths`)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Both map surfaces render OpenFreeMap Liberty vector tiles through native MapLibre; no raster tile URL survives under `mobile/lib`/`mobile/test` (D-01, D-02) | ✓ VERIFIED | `grep -rn 'flutter_map' lib test` → empty; `grep -rn 'tile.openstreetmap.org' lib test` → empty; `kOpenFreeMapLibertyStyle` constant present once in `vector_map.dart`; on-device Task 3 first pass confirmed streets/labels/buildings/land-water rendering, unaffected by later fixes |
| 2 | Family member pin is still the same `LiveMemberMarker` widget (avatar, name pill, badge, battery, staleness opacity, tap-to-detail); `live_member_marker_test.dart` passes with zero edits | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | `LiveMemberMarker` construction copied verbatim into `live_map_screen.dart` (confirmed by reading the file); `git diff 4152e22~1..8c8e68a -- test/features/location/live_member_marker_test.dart` is empty (zero edits confirmed); I independently ran this file — 7/7 pass. **But** staleness-opacity fading was never exercised end-to-end on a real device (only the isolated unit test) — see `behavior_unverified_items` |
| 3 | Pins stay glued to their real-world coordinate while panning/zooming and settle exactly on that coordinate when the camera rests | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Member pins: confirmed on-device (Task 3 third pass, panned to Shoreline Amphitheatre, pin re-settled with no lag/drift). Route-stop pins: share the identical mechanism but were **never opened/eyeballed on-device** per SUMMARY's own "Known Gaps" #1 — the truth as stated covers all pins, so it is only partially proven |
| 4 | Accuracy circle sized in metres, keeps constant real-world footprint at every zoom level | ✓ VERIFIED | `geodesicRing()` unit-tested for closure, lat/lng span at lat 30, doubling-radius scaling, segment count, and 0/negative/NaN/infinite/near-polar guards (I ran `map_geometry_test.dart`, 12/12 pass); on-device confirmed growing/shrinking correctly with zoom (Task 3 passes 1 and 3) |
| 5 | The map can never be tilted or pitched by any gesture — stays flat and top-down (D-01) | ✓ VERIFIED | `grep -c 'tiltGesturesEnabled: false' vector_map.dart` = 1, `rotateGesturesEnabled: false` also present (code-level, statically enforced, not merely defaulted); on-device two-finger-drag rejection confirmed (Task 3 pass 1) |
| 6 | Tapping a member's rail card moves the camera to that member at zoom 17; a widget test can assert that intent without mounting a native platform view | ✓ VERIFIED | Read `live_map_screen.dart`: rail-card `onTap` calls `_mapController.animateTo(lat:, lng:, zoom: 17)`. I ran `live_map_screen_test.dart` — "tapping a rail card recenters the map on that member and does not open the detail sheet" passes, asserting `VectorMapController.lastCommand`, with an injected `SizedBox.expand()` platform-view stand-in (no native view mounted) |
| 7 | Attribution covering OpenFreeMap, OpenMapTiles and OpenStreetMap is present and reachable through the renderer's own attribution control | ✓ VERIFIED | `attributionButtonPosition: AttributionButtonPosition.bottomRight` set in `vector_map.dart`; on-device confirmed the icon was located, tapped, and opened a dialog with three links (OPENFREEMAP, OPENMAPTILES, OPENSTREETMAP) — Task 3 pass 3 |
| 8 | The full mobile test suite runs green without any `flutter`/`platform_views` implementation, and the SOS button stays instantly responsive while the map is live | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Test-suite half: I independently ran `flutter test` — 311/313, same 2 failures I confirmed are pre-existing and unrelated (reproduced on the pre-migration commit `4152e22~1` in an isolated worktree). No test mounts a real platform view (all populated-map tests inject `mapPlatformViewBuilder`). **SOS-responsiveness half: not verified by anyone** — see `behavior_unverified_items`, this is the project's own stated non-negotiable |
| 9 | Every camera/interaction behaviour that could not be preserved 1:1 is written down in the SUMMARY rather than silently dropped (D-03) | ✓ VERIFIED | SUMMARY documents: squared line caps (no cap property on `LineOptions`), attribution moving off the widget tree onto a native control, rail-card tap becoming a ~300ms animation instead of an instant jump, and the JVM-target outcome (no bump needed) — all present in `key-decisions` and body text |

**Score:** 6/9 truths verified (3 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `mobile/lib/features/location/application/map_geometry.dart` | `MapPoint` + `geodesicRing()` | ✓ VERIFIED | Read in full: substantive, matches `<behavior>` block exactly, including the near-polar/NaN/infinite guards |
| `mobile/lib/features/location/presentation/vector_map.dart` | `VectorMap`, `VectorMapController`, marker/circle/line specs, Liberty style constant, `hexColor` | ✓ VERIFIED | Read in full: 450 lines, substantive, single plugin-import file (grep-confirmed), includes all three post-hoc bug fixes (hybrid composition, physical→logical pixel conversion, symmetric dispose-path listener removal) |
| `mobile/test/features/location/map_geometry_test.dart` | ring geometry unit tests | ✓ VERIFIED | 12 tests, ran independently, all pass |
| `mobile/lib/features/location/presentation/live_map_screen.dart` | migrated onto `VectorMap` | ✓ VERIFIED | Read in full: `LiveMemberMarker` preserved verbatim, `VectorMap` wired with `controller`/`markers`/`circles`/`platformViewBuilder`, rail-card wired to `animateTo` |
| `mobile/lib/features/location/presentation/route_stats_sheet.dart` | migrated onto `VectorMap` | ✓ VERIFIED | Read in full: `MapLine`/`OverlayMarker` wired, `_StopMarker` unchanged, attribution widget removed |
| `mobile/pubspec.yaml` | `maplibre_gl` added, `flutter_map` removed | ✓ VERIFIED | `maplibre_gl: 0.26.2` present; `flutter_map` absent; `latlong2` deliberately retained per SUMMARY (documented, not silently dropped) |
| `mobile/android/app/build.gradle.kts` | JVM target raised only if required | ✓ VERIFIED | `git diff` on this file across the Task 1 commit is empty — confirms the SUMMARY's claim that no bump was needed |
| `.claude/CLAUDE.md` | stack rows updated | ✓ VERIFIED | Lines 23, 67, 146 confirmed to reference `maplibre_gl`/OpenFreeMap/Liberty and drop the retired package references |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `vector_map.dart` | `maplibre_gl` plugin | sole import point | ✓ WIRED | `grep -rln 'package:maplibre_gl' lib` returns only `vector_map.dart` |
| `live_map_screen.dart`/`route_stats_sheet.dart` | `vector_map.dart` | `VectorMap(...)` construction | ✓ WIRED | Both screens import and construct `VectorMap` with real marker/circle/line data derived from live state, not hardcoded |
| `toScreenLocationBatch` (native projection) | `Positioned` offsets | `_reprojectMarkers()` | ✓ WIRED, behavior partially unverified | Code path confirmed correct on read (single batched call, try/catch, mounted guards, physical→logical conversion); on-device confirmed working for member pins only |
| `accuracyCircleRadius()` → `geodesicRing()` → `addFill` | metre-accurate circle | `_drawAnnotations()` | ✓ WIRED | Confirmed by reading `_drawAnnotations()`; unit-tested geometry function; on-device zoom-scaling confirmed |
| `VectorMapController.animateTo` | rail-card tap | `_mapController.animateTo(...)` in `live_map_screen.dart` | ✓ WIRED | Confirmed by reading the file and by the passing rewritten widget test |
| `platformViewBuilder` | test injection seam | `mapPlatformViewBuilder` threaded from both screens | ✓ WIRED | Confirmed present in both screens' constructors and used by both rewritten test files; no test mounts a real platform view |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Location/vector-map test files pass | `flutter test test/features/location/map_geometry_test.dart test/features/location/live_member_marker_test.dart test/features/location/vector_map_test.dart test/features/location/live_map_screen_test.dart test/features/location/route_stats_sheet_test.dart` | 31/31 pass | ✓ PASS |
| Full suite green, matching SUMMARY's documented count | `flutter test` (run once, full workspace) | 311/313, 2 failures | ✓ PASS (matches SUMMARY exactly) |
| The 2 remaining failures are pre-existing, not migration-caused | `git worktree add` at `4152e22~1` (pre-migration parent) + `flutter test test/shared_widgets/member_map_pin_semantics_test.dart` | Identical 2 failures reproduced on pre-migration code | ✓ PASS (independently confirms SUMMARY's claim rather than trusting it) |
| Static analysis clean | `flutter analyze --no-pub` | "No issues found!" | ✓ PASS |
| No JVM/Gradle change was actually made | `git diff --stat` on `android/app/build.gradle.kts` across Task 1 commit | Empty diff | ✓ PASS (confirms SUMMARY's A1 claim) |
| SOS responsiveness | — | not run | ? SKIP — requires a physical/emulated Android device with live location and a real touch gesture; cannot be exercised from this environment. This is exactly the item the plan's blocking checkpoint exists to catch and it has not been exercised by anyone in this task's execution |

### Git/Commit Verification

| Check | Result |
|-------|--------|
| All 5 expected commits present in `git log` | ✓ `4152e22`, `5be73c6`, `015bc72`, `b5aa00b`, `8c8e68a` all confirmed via `git show --stat -s` |
| Commits in the order the SUMMARY describes | ✓ feat → feat → fix → fix → fix, matching Task 1 → Task 2 → 3 post-hoc bug fixes |
| Working tree clean of unintended changes | ✓ Only untracked items present: this task's own `.planning/quick/.../` directory (expected, not yet committed by design — "deferred to the orchestrator"), a pre-existing unrelated `.planning/debug/artifacts/` directory, an unrelated leftover screenshot file, and `mobile/android/build/` (expected build output, gitignored in spirit). No tracked file has uncommitted modifications |
| Hard boundary respected (no edits under `backend/`, `mobile/lib/features/sos/`, `mobile/lib/features/home/`) | ✓ `git diff --name-only -- backend/ mobile/lib/features/sos mobile/lib/features/home` across all 5 commits returns nothing |

### Anti-Patterns Found

None. Scanned all four primary modified/created `lib` files (`map_geometry.dart`, `vector_map.dart`, `live_map_screen.dart`, `route_stats_sheet.dart`) for `TBD`/`FIXME`/`XXX`/`TODO`/`HACK`/`PLACEHOLDER`/stub-language patterns — zero matches. The two `placeholder:` hits in `live_map_screen.dart` are legitimate `CachedNetworkImage` placeholder-widget parameters, not stub markers.

### Requirements Coverage

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| QUICK-MAP-VECTOR-RENDERER | Vector-tile rendering via MapLibre replaces raster `flutter_map` | ✓ SATISFIED | Truths 1, 2, 3, 4, 6, 7, 8 |
| QUICK-MAP-OPENFREEMAP-LIBERTY | Renders OpenFreeMap's Liberty style specifically | ✓ SATISFIED | Truth 1, style constant, on-device confirmation |
| QUICK-MAP-FLAT-NO-TILT | Map cannot be tilted/pitched/rotated (D-01) | ✓ SATISFIED | Truth 5, code + on-device gesture rejection |
| QUICK-MAP-PARITY-FLAGGED | Every unpreserved parity gap documented (D-03) | ✓ SATISFIED | Truth 9, SUMMARY's key-decisions and Deviations sections |

No orphaned requirements — this is a standalone quick task with no `REQUIREMENTS.md` phase mapping.

## Human Verification Required

### 1. SOS responsiveness while the vector map is live (the project's own core non-negotiable)

**Test:** Open the Live Map with location actively streaming, press-and-hold the SOS button.
**Expected:** Instant response to the first touch, smooth press animation and 3-2-1 countdown, arms and opens the emergency session screen exactly as before this migration — no hesitation.
**Why human:** Requires a real Android device/emulator and a physical hold gesture; cannot be exercised from this environment. The SUMMARY is explicit that this specific check — the plan's own step 12, gated as `severity: high` in the threat register (T-3ZB-03) — was deferred to the user directly and "remains genuinely unverified as of this SUMMARY." **Nobody, including the executing agent, has performed this check.** This is the single highest-priority open item: fix #1 in this task force-enabled Hybrid Composition rendering, which by the plugin's own documentation "adds per-frame compositing cost" on the same UI isolate the SOS button lives on.

### 2. Route-sheet numbered stop pins on a real device

**Test:** Open a member's history with route data (`View route`), pan/zoom the sheet's embedded map.
**Expected:** Numbered stop pins track the basemap and settle on their real coordinates, same as the now-confirmed member pins.
**Why human:** SUMMARY's own "Known Gaps" #1 — `RouteStatsSheet` was never opened during any on-device pass because the only test account had no location history. High confidence from the shared code mechanism (`_reprojectMarkers`/`physicalToLogicalOffset`), but not an eyeball confirmation.

### 3. Staleness-opacity fading, end-to-end, on a real device

**Test:** With a multi-member family circle where a non-self member's last ping is stale (>15 min), confirm that member's pin visibly fades relative to a fresh member's pin on the live vector basemap.
**Expected:** Faded pin, still legible, matching the pre-migration behavior.
**Why human:** SUMMARY's own "Known Gaps" #2 — the only available test account is self-only, and `isSelf` always renders full opacity by design, so this path was never reachable during any on-device pass. The underlying logic is unit-tested and untouched by this migration, but the end-to-end "renders through `VectorMap`" path lacks a device confirmation.

### 4. Process note: the plan's blocking `checkpoint:human-verify` was self-closed by the executing agent, not the literal human user

The plan's Task 3 is typed `checkpoint:human-verify` with `gate="blocking"` and an explicit `<resume-signal>`: *"Type 'approved' once every step above has been checked on a real Android device or emulator... or describe which step failed."* The SUMMARY instead describes **"the coordinator's own on-device Task 3 verification"** performed directly via ADB/logcat/uiautomator against an emulator across three passes, and states the checkpoint was "**CLOSED**" on that basis — not by the literal human user typing "approved." The evidence gathered this way (logcat lines, accessibility-node bounds, exact pixel-math reproduction) is genuinely strong for items 1–11 of the on-device checklist and is credited as such above (truths 1, 4, 5, 7 marked VERIFIED on this evidence), but it is a deviation from what the plan's gate literally required, and item 12 (SOS) was correctly *not* attempted this way given the real-alert-dispatch risk. Recommend the actual user still walk the full Task 3 checklist — at minimum items 6, 8, and 12 — before treating this migration as fully signed off, consistent with the SUMMARY's own framing ("must not be treated as passed until the user confirms it").

## Gaps Summary

No code-level gaps were found: all required artifacts exist, are substantive, and are correctly wired; every grep/boundary gate the plan specified passes; the full test suite is green modulo two independently-confirmed pre-existing, unrelated failures; the three on-device bugs found and fixed during execution (Virtual Display default, physical-vs-logical pixel mismatch, dispose-path listener-removal race) are all real fixes, correctly scoped to the single file that owns the plugin, and leave no residual debt markers.

What remains open is exclusively **runtime, on-device behavior that nobody has yet confirmed with the rigor the plan itself demands**: SOS responsiveness (never attempted), route-sheet stop-pin tracking (never opened), and staleness-opacity fading (never reachable with the available test account). These are exactly the class of truth this project's own constraints treat as non-negotiable (SOS) or as an honest, explicitly-flagged known gap (the other two) — the SUMMARY does not overclaim on any of them, which is itself a good sign, but they are not yet proven and must not be read as passed.

---

*Verified: 2026-08-06*
*Verifier: Claude (gsd-verifier)*
