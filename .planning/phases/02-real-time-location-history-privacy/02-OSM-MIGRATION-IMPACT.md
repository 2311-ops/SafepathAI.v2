# Migration Impact Analysis: Google Maps → OpenStreetMap

**Date:** 2026-07-13
**Trigger:** Project direction change — replace Google Maps SDK with OpenStreetMap across all map rendering, from Phase 2 onward.
**Status of Phase 2 at time of writing:** COMPLETE (11/11 plans, shipped with `google_maps_flutter`). This is a **retrofit**, not a greenfield choice.

## 1. Why this changes anything

Phase 2 shipped live map, history, and route-display features on `google_maps_flutter`, which requires a
billed Google Cloud Maps SDK API key per platform. Switching to OpenStreetMap removes that billing/API-key
dependency but is not a drop-in swap — `google_maps_flutter`'s widget API (`GoogleMap`, `Marker`, `Circle`,
`Polyline`, `CameraPosition`, `LatLng` from that package) has no official OSM equivalent; the community
standard is `flutter_map` (tile-based, OSM raster/vector tiles), which uses a different widget/programming
model (`FlutterMap`, `Marker`, `CircleLayer`, `PolylineLayer`, `MapController`, `LatLng` from `latlong2`).

## 2. Code surface affected (for future execution — not touched in this pass)

| File | Current | Impact |
|---|---|---|
| `mobile/pubspec.yaml` | `google_maps_flutter: 2.17.1` | Replace with `flutter_map` + `latlong2`; drop Google Maps platform packages |
| `mobile/lib/features/location/presentation/live_map_screen.dart` | `GoogleMap`, `Marker`, `Circle`, `CameraPosition`, `LatLng` (google_maps_flutter) | Full rewrite of map widget tree: `FlutterMap` + `TileLayer` (OSM tile server) + `MarkerLayer` + `CircleLayer`; `LatLng` import switches to `latlong2` |
| `mobile/lib/features/location/presentation/route_stats_sheet.dart` | Same package imports for route/polyline rendering | `PolylineLayer` replaces `Polyline`/`GoogleMap` polyline rendering |
| `mobile/android/app/src/main/AndroidManifest.xml` | Google Maps API key meta-data entry | Remove; no API key needed for OSM tile fetch (attribution required instead) |
| `mobile/ios/Runner/GeneratedPluginRegistrant.m` | Auto-regenerated on next `flutter pub get` once `google_maps_flutter` is removed | No manual action |
| `.planning/debug/resolved/maps-not-loading-missing-api-key.md` | Documents a Google Maps API key setup bug | Now moot under OSM (no API key), keep as historical record, do not delete |
| `02-01-USER-SETUP.md` (Phase 2 plan 1) | Likely contains Google Cloud Maps SDK API key setup instructions | Superseded — needs an OSM-equivalent setup note (attribution requirement, no billing) at execution time |

**Geofencing (Phase 4, not started) is largely unaffected at the data/detection layer** — `native_geofence`
binds to native OS geofencing APIs (`GeofencingClient`/`CLCircularRegion`), independent of which map SDK
renders the zone visually. Only the **visual representation** of a safe-zone radius on the map (drawing a
`Circle`) needs the same `flutter_map`/`CircleLayer` swap as Phase 2.

## 3. Recommended Flutter package(s)

| Package | Version (as of 2026-07) | Role |
|---|---|---|
| `flutter_map` | 8.x stable | Core OSM-compatible map widget (tile rendering, markers, polylines, circles, camera control) |
| `latlong2` | 0.9.x | Coordinate type used by `flutter_map` (replaces `google_maps_flutter`'s `LatLng`) |
| `flutter_map_marker_cluster` | current stable | Optional — marker clustering for family/guardian overview maps if member density grows |
| Tile source | OpenStreetMap standard tile server for dev, or a hosted tile provider (e.g. MapTiler, Stadia Maps, Thunderforest free/paid tiers) for production | OSM's own tile server (`tile.openstreetmap.org`) is rate-limited and its usage policy **disallows production app traffic** at scale — budget a tile-provider account before shipping, even though it removes the Google Maps *billing floor*, not all hosting cost |

**Note on cost:** removing Google Maps billing does not mean "free forever" — OSM's raw tile server is
explicitly for light/dev use per its tile usage policy. A production-grade deployment should plan for a
tile-hosting provider (most have a generous free tier sufficient for a graduation-project scale, then
usage-based pricing beyond that).

`geolocator` (foreground location) and `flutter_foreground_task` (background tracking) are unaffected —
neither depends on Google Maps; they only produce lat/lng, which any map renderer consumes.

## 4. Non-code planning updates made in this pass

- `.claude/CLAUDE.md` tech stack table: `google_maps_flutter` row replaced with `flutter_map`/`latlong2`; alternatives table updated
- `.planning/PROJECT.md`: "Google Maps SDK" reference in constraints replaced with "OpenStreetMap (flutter_map)"
- `.planning/ROADMAP.md`: no direct Google Maps mentions existed (roadmap describes phases at requirement level, not SDK level) — no change needed there beyond this note
- Phase 2 planning docs (`02-*-PLAN.md`, `02-*-SUMMARY.md`) are **preserved as historical record of what was actually built** and are NOT rewritten — they describe completed, shipped work under the old SDK choice. This document is the authoritative record of the pending retrofit.

## 5. What is NOT done here

Per explicit instruction, **no production code was modified**. `pubspec.yaml`, the two `live_map_screen.dart`/
`route_stats_sheet.dart` files, the Android manifest, and `02-01-USER-SETUP.md` still reference Google Maps.
A follow-up execution phase (recommend: a new plan under Phase 2, e.g. `02-12-PLAN.md`, "OSM map rendering
migration") is needed to actually perform the swap, since Phase 2 is already marked complete/shipped.
