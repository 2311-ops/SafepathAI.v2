# Quick Task 260806-3zb: Migrate map rendering from flutter_map to maplibre_gl for OpenFreeMap vector-tile styles - Context

**Gathered:** 2026-08-05
**Status:** Ready for planning

<domain>
## Task Boundary

Migrate the map rendering in `mobile/lib/features/location/presentation/live_map_screen.dart` and `mobile/lib/features/location/presentation/route_stats_sheet.dart` from `flutter_map` (raster `TileLayer` against `tile.openstreetmap.org`) to the `maplibre_gl` Flutter plugin, so the app renders OpenFreeMap's vector-tile styles (https://github.com/hyperknot/openfreemap). This is a deliberate map-library migration, not a small config swap — user confirmed after being shown the trade-off (bigger migration than staying on `flutter_map`, but OpenFreeMap only serves vector tiles, so a vector-capable renderer is required either way).

</domain>

<decisions>
### Map Style
- Use the **Liberty** style (flat, top-down), served from OpenFreeMap's style JSON endpoint (e.g. `https://tiles.openfreemap.org/styles/liberty`).
- Explicitly rejected: "Fiord 3D" (terrain-relief style) — flagged as a legibility risk for a live safety-tracking map (tilted/elevation rendering can occlude pins, adds render cost during continuous location streaming). User chose flat Liberty specifically to keep SOS/staleness pins and route lines fully legible.

### Tile Hosting
- Use OpenFreeMap's free public hosted instance (no API key, no usage limits) as the tile source. Same trust model as the current `tile.openstreetmap.org` source. Self-hosting is an accepted future hardening step, not required now — no follow-up todo needed per user's explicit choice ("Accept it for now").

### Claude's Discretion
- Exact `maplibre_gl` pub.dev version, Android/iOS native setup steps (build.gradle, Info.plist), and the annotation API used to replace `flutter_map`'s `Marker`/`Polyline` widgets (symbols/circles for member pins preserving staleness-opacity, line layers for route polylines) — to be nailed down by the research phase and executed per its findings.
- Camera/zoom/follow-user interaction parity with the current `flutter_map` implementation should be preserved as closely as `maplibre_gl`'s API allows; any behavior that cannot be preserved 1:1 must be flagged explicitly in the plan/summary rather than silently dropped.

</decisions>

<specifics>
## Specific Ideas

- Reference repo for styles/tiles: https://github.com/hyperknot/openfreemap (and its styles sub-repo).
- Style URL pattern: `https://tiles.openfreemap.org/styles/{style_id}` — use `liberty`.
- Existing staleness-based pin opacity logic lives in `mobile/lib/features/location/application/staleness.dart` (`stalenessFor()`) and must carry over to whatever marker/annotation mechanism replaces `flutter_map`'s `Marker` widget.

</specifics>

<canonical_refs>
## Canonical References

- https://github.com/hyperknot/openfreemap — tile/style source, confirmed vector-tile-only (no raster endpoint).
- `.claude/CLAUDE.md` Technology Stack table — current `flutter_map` 8.x entry will need updating to reflect this migration once executed.

</canonical_refs>
