---
phase: 04-geofencing
plan: 03
subsystem: mobile-geofencing
tags: [android, kotlin, flutter, riverpod, google-play-services, geofencing]
requires:
  - phase: 04-geofencing
    provides: authenticated safe-zone registrations and durable server-side candidate records
provides:
  - Non-exported Android geofence receiver with a synchronous app-private candidate outbox
  - Capability-aware Flutter registration lifecycle with exact generation acknowledgements
  - Typed routine-geofence native channel contract with a 20-zone budget
affects: [04-04-geofence-candidate-upload, 04-07-geofence-confirmation, 04-12-zone-save-flow]
actuals:
  tokens: 9353
  tasks: 2
  commits: 3
tech-stack:
  added: [com.google.android.gms:play-services-location:21.3.0]
  patterns: [synchronous native outbox, capability-gated registration, native-success-before-server-ack]
key-files:
  created:
    - mobile/android/app/src/main/kotlin/com/safepath/mobile/GeofenceBroadcastReceiver.kt
    - mobile/android/app/src/main/kotlin/com/safepath/mobile/GeofenceNativeStore.kt
    - mobile/lib/features/geofencing/data/native_geofence_gateway.dart
    - mobile/lib/features/geofencing/application/geofence_registration_controller.dart
  modified:
    - mobile/android/app/src/main/AndroidManifest.xml
    - mobile/android/app/src/main/kotlin/com/safepath/mobile/MainActivity.kt
    - mobile/android/app/build.gradle.kts
key-decisions:
  - "Routine geofence callbacks synchronously commit to an app-private, bounded JSON outbox before the receiver returns; no auth token is copied into native storage."
  - "The registration controller acknowledges a server generation only after native replacement succeeds and clears routine zones on logout without using the SOS service."
  - "Android registrations use a fixed 20-zone cross-platform budget and non-exported PendingIntent receiver."
patterns-established:
  - "Native geofencing: expose typed capability, replacement, drain, and acknowledgement operations through safepath/geofencing."
  - "Registration lifecycle: do not prompt during controller build; permission coordination is explicit and save-triggered."
requirements-completed: [GEO-02]
coverage:
  - id: D1
    description: Android stores routine callback candidates durably before Flutter, with a non-exported receiver and no SOS-service coupling.
    requirement: GEO-02
    verification:
      - kind: unit
        ref: cd mobile/android && ./gradlew testDebugUnitTest --tests "*GeofenceNativeStoreTest"
        status: unknown
    human_judgment: true
    rationale: Android Gradle configuration is blocked on this machine by a pre-existing F:-project/C:-Pub-cache path error, and device callback delivery still needs physical-device evidence.
  - id: D2
    description: Flutter replaces canonical zones only when background capability is ready and acknowledges the matching generation after native success.
    requirement: GEO-02
    verification:
      - kind: unit
        ref: flutter test --no-pub test/features/geofencing/native_geofence_gateway_test.dart test/features/geofencing/geofence_registration_controller_test.dart
        status: pass
      - kind: other
        ref: flutter analyze --no-pub lib/features/geofencing/data/native_geofence_gateway.dart lib/features/geofencing/application/geofence_registration_controller.dart test/features/geofencing/native_geofence_gateway_test.dart test/features/geofencing/geofence_registration_controller_test.dart
        status: pass
    human_judgment: false
duration: 55min
completed: 2026-08-13
status: complete
---

# Phase 04 Plan 03: Android geofence registration and outbox Summary

**Android routine geofence callbacks now persist to a bounded native outbox, while Flutter registers only capability-ready canonical zones and acknowledges the exact server generation after native success.**

## Performance

- **Duration:** 55 min
- **Completed:** 2026-08-13
- **Tasks:** 2/2
- **Files modified:** 9

## Accomplishments

- Added Google Play Services geofencing, a non-exported callback receiver, and a versioned, synchronously committed app-private outbox with deduplication and acknowledgement removal.
- Kept routine monitoring structurally separate from the SOS foreground service; receiver callbacks only persist routine candidates.
- Added `safepath/geofencing` methods for capability checks, canonical zone replacement, pending-candidate drain, and acknowledgement.
- Added a Riverpod registration lifecycle that requires background capability, applies native replacement before generation acknowledgement, and removes routine zones at logout.
- Added focused Flutter coverage for capability refusal, acknowledgement ordering, candidate draining, 20-zone enforcement, and logout cleanup.

## Task Commits

1. **Task 1: Persist Android callbacks before Dart and deduplicate them** - `3d0d2cf` (feat)
2. **Task 2: Register canonical zones through a capability-aware Flutter gateway** - `e32d115` (feat)

**TDD RED:** `7bcc829` - failing native gateway and registration-controller expectations before implementation.

## Files Created/Modified

- `mobile/android/app/src/main/kotlin/com/safepath/mobile/GeofenceNativeStore.kt` - bounded versioned native outbox with synchronous commits and replay-id deduplication.
- `mobile/android/app/src/main/kotlin/com/safepath/mobile/GeofenceBroadcastReceiver.kt` - non-exported OS callback receiver that persists routine candidates before return.
- `mobile/android/app/src/main/kotlin/com/safepath/mobile/MainActivity.kt` - Play Services registration plus typed Flutter method-channel operations.
- `mobile/lib/features/geofencing/data/native_geofence_gateway.dart` - typed native bridge, 20-zone guard, and registration API client.
- `mobile/lib/features/geofencing/application/geofence_registration_controller.dart` - authenticated, capability-aware native registration and acknowledgement lifecycle.

## Decisions Made

- The native outbox has no access token, refresh token, or SOS-service integration; later authenticated upload/drain work owns server submission.
- Native replacement is complete before a matching-generation acknowledgement is sent, so permissions, unavailable Play Services, and native failure never claim a registration.
- The method channel accepts a canonical zone set but enforces 20 zones so Android and future platform implementations share one limit.

## Deviations from Plan

None - plan implementation followed the specified scope and preserved SOS declarations verbatim.

## Issues Encountered

- The required Android Gradle test command reached configuration after stale-lock cleanup but could not configure `flutter_plugin_android_lifecycle`: Gradle rejects the existing mixed-drive build paths (`F:\SafepathAI.v2\mobile\build` and the Pub cache under `C:\Users\DELL`). This is an environment/build-layout issue outside the plan files, so it was not changed. The exact command is recorded as unrun verification above.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The following candidate-upload work can drain authenticated native candidates without a live Flutter process being required at callback time.
- Android device verification remains required once the cross-drive Gradle configuration issue is resolved.

---
*Phase: 04-geofencing*
*Completed: 2026-08-13*

## Self-Check: PASSED

- Verified the nine planned Android, Flutter, and test files exist.
- Verified commits `7bcc829`, `3d0d2cf`, and `e32d115` exist in git history.
