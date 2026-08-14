---
phase: 04-geofencing
plan: 11
subsystem: mobile-geofencing
tags: [android, ios, core-location, geofencing, flutter, recovery]
requires:
  - phase: 04-geofencing
    provides: 04-04 durable candidate outbox and authenticated Dart drain
  - phase: 04-geofencing
    provides: 04-06/04-07 canonical registration generations and candidate confirmation contract
provides:
  - Android boot and package-recovery markers without SOS-service coupling
  - iOS Core Location region registration, durable relaunch outbox, and shared method-channel capability mapping
affects: [04-17-device-validation, GEO-02, mobile-geofence-registration]
actuals:
  tokens: 4742
  tasks: 2
  commits: 4
tech-stack:
  added: []
  patterns: [credential-free-native-outbox, canonical-authenticated-resync, bounded-ios-relaunch-window]
key-files:
  created:
    - mobile/android/app/src/main/kotlin/com/safepath/mobile/GeofenceBootReceiver.kt
    - mobile/ios/Runner/GeofenceRegionManager.swift
  modified:
    - mobile/android/app/src/main/AndroidManifest.xml
    - mobile/android/app/src/main/kotlin/com/safepath/mobile/GeofenceBroadcastReceiver.kt
    - mobile/ios/Runner/AppDelegate.swift
    - mobile/ios/Runner/Info.plist
    - mobile/lib/features/geofencing/data/native_geofence_gateway.dart
key-decisions:
  - "Boot, package replacement, and GEOFENCE_NOT_AVAILABLE request only a bounded canonical resync; they never start a tracker, copy auth material, or involve SOS."
  - "iOS persists routine candidates in app-private UserDefaults and starts a short relaunch window, while the existing Dart drain remains the sole Supabase-authenticated uploader."
  - "Plan 04-11 was executed source-complete under an explicit user-approved bypass because 04-05 remains an unverified physical Android tracer checkpoint with no SUMMARY.md."
requirements-completed: []
coverage:
  - id: D1
    description: Android boot/package recovery and GEOFENCE_NOT_AVAILABLE handling remain bounded, credential-free, and SOS-independent.
    requirement: GEO-02
    verification:
      - kind: unit
        ref: flutter test test/features/geofencing/native_geofence_gateway_test.dart
        status: pass
      - kind: unit
        ref: cd mobile/android && ./gradlew.bat :app:testDebugUnitTest
        status: pass
    human_judgment: true
    rationale: "The blocked 04-05 physical process-death tracer has not been approved; source and unit checks cannot prove device lifecycle behavior."
  - id: D2
    description: iOS source registers Core Location regions, maps authorization states, preserves an app-private outbox, and launches the shared authenticated drain path.
    requirement: GEO-02
    verification:
      - kind: unit
        ref: flutter test test/features/geofencing/native_geofence_gateway_test.dart
        status: pass
      - kind: other
        ref: Runner.xcodeproj source-registration and method-channel link check
        status: pass
    human_judgment: true
    rationale: "Windows cannot run Xcode or a signed physical-iPhone Always-location acceptance; PR-04 evidence remains mandatory in 04-17."
duration: ~1h 15m
completed: 2026-08-14
status: complete
---

# Phase 04 Plan 11: Platform Recovery and iOS Adapter Summary

**Android now requests bounded canonical geofence recovery after OS lifecycle loss, while an iOS Core Location adapter persists relaunch candidates and delegates authenticated upload to the existing Dart drain.**

## Performance

- **Duration:** ~1h 15m
- **Completed:** 2026-08-14
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments

- Added Android boot/package receivers and recoverable `GEOFENCE_NOT_AVAILABLE` handling without adding a foreground tracker, SOS service dependency, or native token storage.
- Added the iOS Core Location method-channel adapter with authorization-state mapping, 20-region validation, app-private candidate persistence, bounded location-relaunch time, and Runner target registration.
- Extended shared Dart tests to pin recovery and iOS authorization mappings, including the cross-platform 20-zone limit.

## Task Commits

1. **Task 1 TDD RED: Android recovery contract** - `8cdf3a5`
2. **Task 1 GREEN: Android boot/platform recovery** - `36f0d57`
3. **Task 2 TDD RED: iOS capability contract** - `5694c25`
4. **Task 2 GREEN: iOS Core Location recovery adapter** - `2709ba4`

## Verification

- Passed: `flutter test test/features/geofencing/native_geofence_gateway_test.dart` (5 tests).
- Passed: `cd mobile/android && ./gradlew.bat :app:testDebugUnitTest`.
- Source link checks passed: `GeofenceRegionManager.swift` is registered in the Runner Xcode target and exposes the same `safepath/geofencing` methods that Dart drains.
- `flutter analyze` reported the three pre-existing infos in `geofence_candidate_uploader.dart` specified before execution; no new analyzer diagnostics were introduced.
- The plan's broad `./gradlew.bat testDebugUnitTest` command was attempted but failed only in the external `:geolocator_android` plugin's three unit tests. The focused app task above passed, so the unrelated plugin failure was not changed.
- iOS Xcode build, signed-device lifecycle, and Always-location acceptance were not run on Windows. No Android or iOS runtime validation is claimed here.

## Decisions Made

- Native recovery remains a signal to the existing authenticated bootstrap rather than a second registration or upload path.
- iOS stores no Supabase token, refresh token, or credential in UserDefaults, a native channel payload, or logs.
- The iOS source file is explicitly listed in `Runner.xcodeproj` because this project does not use Xcode filesystem-synchronized source groups.

## Deviations from Plan

### Dependency Bypass

**[Explicit user override]** Plan 04-11 depends on Plan 04-05, whose physical Android tracer checkpoint is incomplete and has no `04-05-SUMMARY.md`.

- **Context used instead:** `04-CONTEXT.md`, `04-04-SUMMARY.md`, `04-06-SUMMARY.md`, `04-07-SUMMARY.md`, and the incomplete `04-05-PLAN.md`.
- **Boundary:** This is source-complete work only. It does not fabricate 04-05 evidence, mark 04-05 complete, or close device-runtime validation.

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Registered the new iOS source in the Runner target**

- **Found during:** Task 2
- **Issue:** The Xcode project statically enumerates Runner source files and has no filesystem-synchronized group, so the required `GeofenceRegionManager.swift` would otherwise be excluded from every iOS build.
- **Fix:** Added only the file reference and Runner Sources build-phase entry in `mobile/ios/Runner.xcodeproj/project.pbxproj`.
- **Verification:** Project source-link check confirms both entries are present.
- **Committed in:** `2709ba4`

**Total deviations:** 1 Rule-3 build-registration fix and 1 explicit dependency bypass.

## Issues Encountered

- The full Android composite unit-test command fails in three unrelated `geolocator_android` plugin tests. The plan-owned focused app test task passes.
- Flutter analysis retains three existing informational lints in `mobile/lib/features/geofencing/data/geofence_candidate_uploader.dart`; they were explicitly pre-existing and out of this plan's scope.

## Next Phase Readiness

- Source contracts are ready for the physical lifecycle evidence deferred to 04-17.
- Plan 04-05 remains incomplete and requires its original Android device tracer approval; this summary is not evidence for it.

## TDD Gate Compliance

- Task 1: RED `8cdf3a5` precedes GREEN `36f0d57`.
- Task 2: RED `5694c25` precedes GREEN `2709ba4`.

## Self-Check: PASSED

- Verified all nine task files exist.
- Verified commits `8cdf3a5`, `36f0d57`, `5694c25`, and `2709ba4` exist in local history.
