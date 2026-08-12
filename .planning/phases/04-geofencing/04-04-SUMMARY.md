---
phase: 04-geofencing
plan: 04
subsystem: mobile-geofencing
tags: [android, workmanager, flutter, supabase, dio, geofencing]
requires:
  - phase: 04-geofencing
    provides: native geofence outbox and candidate API contract
provides:
  - Unique retryable Android WorkManager bridge for routine geofence candidate uploads
  - Shared authenticated Dart drain for headless workers and cold application relaunch
affects: [04-07-geofence-confirmation, 04-08-geofence-activity]
actuals:
  tokens: 11200
  tasks: 2
  commits: 3
tech-stack:
  added: [androidx-work-runtime-ktx]
  patterns: [native-credential-free-worker, authenticated-native-outbox-drain]
key-files:
  created:
    - mobile/android/app/src/main/kotlin/com/safepath/mobile/GeofenceUploadWorker.kt
    - mobile/android/app/src/main/kotlin/com/safepath/mobile/GeofenceBackgroundEngine.kt
    - mobile/lib/features/geofencing/data/geofence_candidate_uploader.dart
    - mobile/lib/features/geofencing/data/geofence_background_entrypoint.dart
  modified:
    - mobile/android/app/src/main/kotlin/com/safepath/mobile/GeofenceBroadcastReceiver.kt
    - mobile/lib/main.dart
key-decisions:
  - "Kotlin schedules only a unique WorkManager request and receives a retry result; Supabase session material never crosses native storage, worker input, channels, or logs."
  - "The headless engine and normal cold bootstrap share the same candidate-drain coordinator, which acknowledges only 202 Accepted or 200 Duplicate responses."
requirements-completed: [GEO-02]
coverage:
  - id: D1
    description: Restored auth uploads native candidates and acknowledges accepted or duplicate results only.
    requirement: GEO-02
    verification:
      - kind: unit
        ref: flutter test --no-pub test/features/geofencing/geofence_candidate_uploader_test.dart
        status: pass
  - id: D2
    description: Android callbacks enqueue bounded unique worker execution without native credentials.
    requirement: GEO-02
    verification:
      - kind: unit
        ref: cd mobile/android && ./gradlew.bat testDebugUnitTest --tests "*GeofenceUploadWorkerTest"
        status: partial
        rationale: "The app task compiled and passed, but the composite Gradle invocation fails because flutter_local_notifications has no matching test for the app-only filter."
duration: 68min
completed: 2026-08-13
status: complete
---

# Phase 04 Plan 04: Authenticated geofence candidate upload Summary

**A credential-free Android WorkManager bridge now starts a bounded headless Flutter engine, while shared Dart code restores Supabase auth, uploads routine candidates, and preserves any row that is not accepted or replay-confirmed.**

## Accomplishments

- Enqueued one `ExistingWorkPolicy.KEEP` WorkManager request only after synchronous native outbox persistence.
- Added a short-lived headless Flutter engine that calls the named `geofenceBackgroundMain` entry point and maps its completion to success or retry without receiving credentials.
- Added a shared candidate drain that refreshes Supabase auth, builds the existing authenticated Dio client, sends `POST /geofences/candidates`, and acknowledges only HTTP 200/202 success.
- Wired the same authenticated drain into normal bootstrap for deterministic cold-relaunch recovery.

## Task Commits

1. **TDD RED: candidate upload expectations** - `a997db3`
2. **Task 1: schedule headless uploads** - `4b2a2ea`
3. **Task 2: drain authenticated candidates** - `ae238c0`

## Decisions Made

- Routine geofence callbacks remain isolated from SOS and the native outbox remains the sole native persistence point.
- Missing, invalid, or transiently unavailable auth/network state leaves each native row intact and returns retry.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Repaired existing Kotlin compilation blockers exposed by native verification**
- **Found during:** Task 1
- **Issue:** `MainActivity` contained an extra closing brace and `GeofencingEvent.fromIntent` is nullable under the current dependency API.
- **Fix:** Removed the extra brace and returned safely for a null event before persistence or scheduling.
- **Files modified:** `mobile/android/app/src/main/kotlin/com/safepath/mobile/MainActivity.kt`, `mobile/android/app/src/main/kotlin/com/safepath/mobile/GeofenceBroadcastReceiver.kt`
- **Commit:** `4b2a2ea`

## Verification

- Passed: `flutter test --no-pub test/features/geofencing/geofence_candidate_uploader_test.dart` (3/3).
- Partial: Android Gradle compiled the app and ran `:app:testDebugUnitTest`, including the focused worker test. The overall filtered command exited nonzero because the unrelated `flutter_local_notifications` module has no test matching the app-only filter.
- Unrun: focused `flutter analyze` timed out after 124 seconds without diagnostics on this machine.

## Threat Surface

- No access token or refresh token was added to Kotlin, WorkManager data, shared preferences, a method channel payload, or logs.
- WorkManager uses one unique work name with exponential backoff; native candidates stay durable until Dart receives accepted or duplicate success.

## Self-Check: PASSED

- Verified the worker, headless engine, uploader, entry point, and focused test files exist.
- Verified commits `a997db3`, `4b2a2ea`, and `ae238c0` exist in local history.
