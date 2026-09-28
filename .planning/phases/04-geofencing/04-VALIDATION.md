---
phase: 04
slug: geofencing
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-10
---

# Phase 04 — Validation Strategy

> Nyquist validation contract for the resliced backend -> Android tracer -> device gate -> expansion sequence.

## Test Infrastructure

| Stack | Framework | Quick command | Full command |
|---|---|---|---|
| Backend | xUnit/Moq/EF Core test projects | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~Geofenc` | `dotnet test backend/SafePath.sln` |
| Mobile | `flutter_test`, Android Gradle/JUnit | `cd mobile; flutter test test/features/geofencing` | `cd mobile; flutter analyze; flutter test` |

No new test framework is required. Android WorkManager/GeofencingClient use official Android dependencies; Core Location is platform-provided.

## Sampling Rate

- **After every task:** run the task's focused `<automated>` command; target feedback under 90 seconds.
- **After every wave:** run the affected stack's full suite; after Waves 4, 11, and 12 also build Android debug.
- **Before phase verification:** both full suites, Android build, pending EF model check, early Android tracer evidence, and final Android+iOS device evidence must exist.
- **Blocking continuity:** no plan after 04-05 may execute until its physical Android checkpoint is approved.

## Per-Task Verification Map

| Plan/Task | Wave | Requirements | Behavior | Automated command / gate | Test file status |
|---|---:|---|---|---|---|
| 04-01 T1 | 1 | GEO-01/02 | Guardian create -> member config/ack -> authenticated candidate | `dotnet test backend/tests/SafePath.Api.IntegrationTests --filter FullyQualifiedName~GeofenceTracerEndpointTests` | Wave 0, created in task |
| 04-01 T2 | 1 | GEO-02 | caller/generation/replay/SOS isolation | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~GeofenceTracerTests` | Wave 0, created in task |
| 04-02 T1 | 2 | all | PR-01 schema and PR-03 ownership invariants | `dotnet test backend/tests/SafePath.Application.Tests --filter FullyQualifiedName~GeofencingSchemaTests` | Wave 0, created in task |
| 04-02 T2 | 2 | all | migration applies and matches model | `dotnet ef database update ... && dotnet ef migrations has-pending-model-changes ...` | migration created in task |
| 04-03 T1 | 3 | GEO-02 | dead-process callback persistence/dedupe | `cd mobile/android && ./gradlew testDebugUnitTest --tests "*GeofenceNativeStoreTest"` | Wave 0, created in task |
| 04-03 T2 | 3 | GEO-02 | capability-aware canonical registration/ack | `flutter test test/features/geofencing/native_geofence_gateway_test.dart test/features/geofencing/geofence_registration_controller_test.dart` | Wave 0, created in task |
| 04-04 T1 | 4 | GEO-02 | unique WorkManager/headless engine bridge | `cd mobile/android && ./gradlew testDebugUnitTest --tests "*GeofenceUploadWorkerTest"` | Wave 0, created in task |
| 04-04 T2 | 4 | GEO-02 | Supabase restore, authenticated upload, relaunch fallback | `flutter test test/features/geofencing/geofence_candidate_uploader_test.dart` | Wave 0, created in task |
| 04-05 T1 | 5 | GEO-01/02 | physical Android process-death upload and SOS concurrency | blocking device checklist | manual-only, justified |
| 04-06 T1/T2 | 6 | GEO-01 | CRUD, validation, IDOR, canonical sync | `dotnet test ... --filter FullyQualifiedName~ZoneCommandTests`; integration filter `GeofencesControllerTests` | Wave 0, created in task |
| 04-07 T1 | 7 | GEO-02 | envelope/dwell/reset/sensitivity | `dotnet test ... --filter FullyQualifiedName~GeofenceTransitionEvaluatorTests` | Wave 0, created in task |
| 04-07 T2 | 7 | GEO-02/NOTIF-02 | exactly-once activity/feed/job transaction | `dotnet test ... --filter FullyQualifiedName~SubmitGeofenceEvidenceTests` | Wave 0, created in task |
| 04-08 T1 | 8 | GEO-03 | pairing/filter/auth/date clamp | `dotnet test ... --filter FullyQualifiedName~GeofenceActivityQueryTests` | Wave 0, created in task |
| 04-08 T2 | 8 | GEO-03 | seven-day query/purge and SOS non-interference | `dotnet test ... --filter FullyQualifiedName~GeofenceRetentionTests` | Wave 0, created in task |
| 04-09 T1 | 9 | NOTIF-02 | recipient-owned durable feed/read | integration filter `NotificationsControllerTests` | Wave 0, created in task |
| 04-09 T2 | 9 | NOTIF-02 | PR-03 overnight/DST/defer/SOS isolation | `dotnet test ... --filter FullyQualifiedName~QuietHoursTests` | Wave 0, created in task |
| 04-10 T1/T2 | 10 | NOTIF-02 | routine payload/priority/retry plus SOS regression | filters `RoutineNotificationDispatcherTests|PushFanOutTests` | Wave 0, created/extended in task |
| 04-11 T1 | 6 | GEO-02 | Android boot/package recovery | `cd mobile/android && ./gradlew testDebugUnitTest` | Wave 0, extended in task |
| 04-11 T2 | 6 | GEO-02 | iOS capability/relaunch contract | `flutter analyze && flutter test test/features/geofencing/native_geofence_gateway_test.dart` | source automated; runtime manual |
| 04-12 T1/T2 | 7 | GEO-01 | draft/save permission plus map-first review | controller/editor widget tests and analyze | Wave 0, created in task |
| 04-13 T1/T2 | 8 | GEO-01 | list/detail/routes/role/shell | `flutter test test/features/geofencing/safe_zone_flow_test.dart` | Wave 0, created in task |
| 04-14 T1/T2 | 10 | GEO-03 | filters/localization/paired timeline | `flutter test test/features/geofencing/zone_activity_screen_test.dart` | Wave 0, created in task |
| 04-15 T1 | 11 | NOTIF-02 | durable feed/read/activity route | `flutter test test/features/geofencing/notifications_screen_test.dart` | Wave 0, created in task |
| 04-15 T2 | 11 | NOTIF-02 | recipient quiet-hours settings UI | `flutter test test/features/geofencing/quiet_hours_screen_test.dart` | Wave 0, created in task |
| 04-16 T1/T2 | 12 | NOTIF-02 | normal user-tap routing and SOS fence | routine route + existing SOS push tests | Wave 0, created/extended in task |
| 04-17 T1 | 13 | all | full suites/build/migration/static isolation | `dotnet test ... && flutter analyze && flutter test` | existing + phase tests |
| 04-17 T2 | 13 | all | physical Android/iOS/quiet-hours/SOS acceptance | blocking PR-04 checklist | manual-only, justified |

## Wave 0 Test Files

- [ ] `backend/tests/SafePath.Application.Tests/Geofencing/GeofenceTracerTests.cs` — 04-01 T2
- [ ] `backend/tests/SafePath.Api.IntegrationTests/GeofenceTracerEndpointTests.cs` — 04-01 T1
- [ ] `backend/tests/SafePath.Application.Tests/Geofencing/GeofencingSchemaTests.cs` — 04-02 T1
- [ ] `mobile/android/app/src/test/kotlin/com/safepath/mobile/GeofenceNativeStoreTest.kt` — 04-03 T1
- [ ] `mobile/android/app/src/test/kotlin/com/safepath/mobile/GeofenceUploadWorkerTest.kt` — 04-04 T1
- [ ] `mobile/test/features/geofencing/native_geofence_gateway_test.dart` — 04-03 T2, extended 04-11
- [ ] `mobile/test/features/geofencing/geofence_registration_controller_test.dart` — 04-03 T2
- [ ] `mobile/test/features/geofencing/geofence_candidate_uploader_test.dart` — 04-04 T2
- [ ] Backend `Geofencing/*Tests.cs` and integration controller tests — owning tasks 04-06 through 04-10
- [ ] Mobile controller/widget/route tests — owning tasks 04-12 through 04-16

Compiled production symbols prevent a standalone test-only wave; every missing test is created first inside its owning `tdd="true"` task.

## Manual-Only Gating

| Gate | Why manual | Owning plan | Pass rule |
|---|---|---|---|
| Android process-death authenticated tracer | Requires real Google Play Services lifecycle, OS permission, movement/mock provider, and existing persisted Supabase session | 04-05 | Must pass before any 04-06+ plan executes |
| Final Android/iOS platform acceptance | Core Location relaunch/APNs and physical accuracy/boot behavior cannot be simulated by unit tests; PR-04 requires signed physical iPhone | 04-17 | Both platforms required; unavailable iOS environment leaves phase open |

## Validation Sign-Off

- [x] Every automatic task has a focused `<automated>` command.
- [x] Every Research Validation Architecture row maps to an owning task and test file.
- [x] Manual-only behavior has a blocking checkpoint and objective evidence requirements.
- [x] Early checkpoint dependencies prevent later CRUD/UI/activity/push work from running first.
- [x] No watch-mode command.
- [ ] `wave_0_complete: true` — set when owning tasks create the files.
- [ ] `nyquist_compliant: true` — set when Wave 0 files exist and focused commands pass.

**Approval:** planner-populated 2026-08-10; pending execution.
