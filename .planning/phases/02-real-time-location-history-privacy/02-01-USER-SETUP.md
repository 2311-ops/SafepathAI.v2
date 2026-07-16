# Phase 02 Plan 01: User Setup Required

**Generated:** 2026-07-12
**Phase:** 02-real-time-location-history-privacy
**Plan:** 01
**Status:** Incomplete

> **SUPERSEDED 2026-07-13 — Google Maps replaced by OpenStreetMap.** The map rendering
> engine was retrofitted from `google_maps_flutter` (billed Google Cloud Maps SDK) to
> `flutter_map` + `latlong2` (OpenStreetMap raster tiles) in plan `02-12`. The Google
> Maps environment-variable and dashboard-configuration sections below are historical
> record only — do NOT provision a Google Cloud Maps SDK key for this project. See the
> active "OpenStreetMap setup (active)" section below, and
> `.planning/phases/02-real-time-location-history-privacy/02-OSM-MIGRATION-IMPACT.md`
> for the full migration rationale.

Complete these items before the Phase 2 map screens render live map tiles. The real-time SignalR transport built in Plan 01 is complete without these keys; this setup is pre-provisioning for the later Google Maps UI work.

## Environment Variables (historical — Google Maps, superseded)

| Status | Variable | Source | Add to |
|--------|----------|--------|--------|
| [ ] | `MAPS_API_KEY_ANDROID` | Google Cloud Console -> APIs & Services -> Credentials -> Maps SDK for Android key | mobile build env / Android dart-define or platform config |
| [ ] | `MAPS_API_KEY_IOS` | Google Cloud Console -> APIs & Services -> Credentials -> Maps SDK for iOS key | mobile build env / iOS dart-define or platform config |

## Dashboard Configuration (historical — Google Maps, superseded)

- [ ] **Enable Maps SDK APIs and create restricted keys**
  - Location: Google Cloud Console -> APIs & Services -> Library
  - Enable: `Maps SDK for Android` and `Maps SDK for iOS`
  - Create: One restricted API key per platform
  - Restrict Android key by Android app package name and SHA-1 certificate fingerprint
  - Restrict iOS key by iOS bundle identifier

## Verification (historical — Google Maps, superseded)

After completing setup, verify during the later map-screen plan with:

```bash
cd mobile
flutter analyze lib/features/location
flutter run --dart-define=MAPS_API_KEY_ANDROID=<android-key>
```

Expected results:
- The app builds with the configured key.
- Map tiles render on the live map screen once Plan 02-06 wires `google_maps_flutter`.

---

## OpenStreetMap setup (active)

**No API key and no billing account are required for development.** `flutter_map`
fetches OpenStreetMap raster tiles directly over HTTPS from `tile.openstreetmap.org` —
there is no Google Cloud project, no restricted key, and no per-platform dashboard
configuration to provision.

Requirements enforced by OSM's tile usage policy (both are hard ToS requirements, not
polish):

- A valid `userAgentPackageName` must be set on every `TileLayer` (this project uses
  `com.safepath.mobile`, matching the Android `applicationId`).
- A persistently visible on-map attribution crediting "OpenStreetMap contributors" must
  be shown on every map surface (implemented via `SimpleAttributionWidget` on both
  `live_map_screen.dart` and `route_stats_sheet.dart`).

**Before production traffic:** OSM's own tile server (`tile.openstreetmap.org`) is
rate-limited and its usage policy explicitly disallows production app traffic at scale.
A dedicated tile-hosting provider must be selected before shipping to real users —
options include MapTiler, Stadia Maps, or Thunderforest, most of which have a free tier
sufficient for graduation-project scale. This only requires changing the `TileLayer`'s
`urlTemplate` (and possibly adding an API key query param for the chosen provider); no
other application code changes.

**Once all items complete:** Mark status as "Complete" at top of file.
