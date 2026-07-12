# Phase 02 Plan 01: User Setup Required

**Generated:** 2026-07-12
**Phase:** 02-real-time-location-history-privacy
**Plan:** 01
**Status:** Incomplete

Complete these items before the Phase 2 map screens render live map tiles. The real-time SignalR transport built in Plan 01 is complete without these keys; this setup is pre-provisioning for the later Google Maps UI work.

## Environment Variables

| Status | Variable | Source | Add to |
|--------|----------|--------|--------|
| [ ] | `MAPS_API_KEY_ANDROID` | Google Cloud Console -> APIs & Services -> Credentials -> Maps SDK for Android key | mobile build env / Android dart-define or platform config |
| [ ] | `MAPS_API_KEY_IOS` | Google Cloud Console -> APIs & Services -> Credentials -> Maps SDK for iOS key | mobile build env / iOS dart-define or platform config |

## Dashboard Configuration

- [ ] **Enable Maps SDK APIs and create restricted keys**
  - Location: Google Cloud Console -> APIs & Services -> Library
  - Enable: `Maps SDK for Android` and `Maps SDK for iOS`
  - Create: One restricted API key per platform
  - Restrict Android key by Android app package name and SHA-1 certificate fingerprint
  - Restrict iOS key by iOS bundle identifier

## Verification

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

**Once all items complete:** Mark status as "Complete" at top of file.
