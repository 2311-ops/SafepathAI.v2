---
status: resolved
trigger: "confirmed fixed on problem is i cant see the maps gui nor the exact location of the member i need you help to undersatnd why maps isnt loading"
created: 2026-07-13
updated: 2026-07-13
---

# Debug Session: Google Maps Not Rendering on Live Map Screen

## Symptoms
- expected_behavior: Live Map tab should render an interactive Google Map with member location markers/accuracy circles.
- actual_behavior: Map area is blank/does not render.
- error_messages: (found via logcat, not initially reported by user)
- timeline: Reported live during A30 testing on 2026-07-13, immediately after confirming the circle-create/invite-code fix.
- reproduction: Open the Map tab with an active family circle.

## Current Focus
- hypothesis: N/A — root cause found and confirmed on first pass, no fix possible without a real credential.
- test: N/A
- expecting: N/A
- next_action: User must obtain a Google Maps Android API key and supply it via `android/local.properties` (gitignored) as `MAPS_API_KEY_ANDROID=...`.
- reasoning_checkpoint:
- tdd_checkpoint:

## Evidence
- timestamp: 2026-07-13
  observation: `adb logcat -d` on device R58M30TGNXV shows:
  ```
  E Google Maps Android API: Error requesting API token. StatusCode=INVALID_ARGUMENT
  E Google Android Maps SDK: Authorization failure. Please see https://developers.google.com/maps/documentation/android-sdk/start
  E Google Android Maps SDK: Ensure that the following Android Key exists:
  E Google Android Maps SDK: API Key:
  ```
  (API Key line is blank — this is the Google Maps SDK's own diagnostic output confirming no key was supplied.)
- timestamp: 2026-07-13
  observation: `android/app/src/main/AndroidManifest.xml:49-50` declares `com.google.android.geo.API_KEY` with value `${MAPS_API_KEY_ANDROID}` (a manifest placeholder).
- timestamp: 2026-07-13
  observation: `android/app/build.gradle.kts:26-27` resolves that placeholder via `providers.gradleProperty("MAPS_API_KEY_ANDROID").orElse("").get()` — defaults to empty string if the Gradle property isn't set anywhere.
- timestamp: 2026-07-13
  observation: Grepped `android/gradle.properties`, `android/local.properties`, and the whole repo for `MAPS_API_KEY_ANDROID` — zero matches outside the build.gradle.kts resolver itself. No `.env.example`/template documents this either.
- timestamp: 2026-07-13
  observation: iOS side (`ios/Runner/AppDelegate.swift:13`) also calls `GMSServices.provideAPIKey(mapsApiKey)` from a similarly-sourced variable — same class of gap likely exists for iOS, not verified live (no iOS device in this session).

## Eliminated
- hypothesis: Code bug in `LiveMapScreen` / `GoogleMap` widget usage.
  reason: Widget code is correct; this is purely a missing platform credential, confirmed by the SDK's own "Authorization failure" diagnostic naming the empty key.

## Resolution
- root_cause: `MAPS_API_KEY_ANDROID` Gradle property was never configured for this project (no `local.properties`/CI secret ever set it), so the Android Manifest's Google Maps API key placeholder resolves to an empty string and the native SDK refuses to render tiles.
- fix: Not a code fix — requires a real Google Cloud Maps SDK for Android API key, supplied via `android/local.properties` (gitignored, per-developer) as `MAPS_API_KEY_ANDROID=<key>`. Documented in the response to the user; not yet added to project docs (follow-up).
- verification: Pending — user needs to supply a real key and rebuild before this can be confirmed fixed.
- files_changed: none (credential-only issue)
