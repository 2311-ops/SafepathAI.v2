---
phase: 03-sos-fast-path
plan: 08
subsystem: sos
tags: [signalr, flutter_foreground_task, geolocator, maplibre_gl, dotnet, riverpod, live-location]

# Dependency graph
requires:
  - phase: 03-sos-fast-path
    provides: "03-01 -- SosSession.LiveWindowEndsAtUtc field, SosSessionDto, TriggerSosCommandHandler"
  - phase: 03-sos-fast-path
    provides: "03-03 -- IAlertBroadcastService.LiveLocationWindowUpdate/IAlertClient contract declared but unpopulated, AlertHub"
  - phase: 03-sos-fast-path
    provides: "03-04 -- sosHubClientProvider/SosResponderController, ResponderAlertScreen's live-location card region left for this plan"
  - phase: 03-sos-fast-path
    provides: "03-06/03-07 -- FCM push arm + offline retry/SosOfflineQueued, both wired into this plan's SosLiveActive state machine"
provides:
  - "SosLiveWindowOptions/ReportSosLocationCommand/ReportSosLocationCommandHandler, POST /sos/{id}/location -- server-authoritative live window, stamped from ReceivedAtUtc, window-gated position ingest restricted to the triggering user"
  - "SosLiveLocationService/SosForegroundTaskHost/SosPositionSource -- flutter_foreground_task-backed position stream scoped strictly to an active SOS window (D-31), surviving lock/backgrounding and a swiped-away recents task on Android (D-33)"
  - "SosCountdown/SosLiveIndicator/SosPulseRing, AppTypography.countdownLarge -- the locked tabular-figure countdown and live-motion tokens, shared verbatim between the sender and responder screens"
  - "SosController deriving/refreshing SosLiveActive from the server's own liveWindowEndsAtUtc, and rendering it on both sender_emergency_session_screen.dart and responder_alert_screen.dart (with a live VectorMap of the sender's position on the responder side)"
affects: [03-09]

tech-stack:
  added: []
  patterns:
    - "SosController._replaceState is the single funnel every state mutation goes through, so entering/leaving SosLiveActive starts/stops SosLiveLocationService exactly once per transition rather than on every live-location refresh"
    - "SosLiveLocationService reuses the existing SosRetryScheduler/SosRetryHandle seam (03-07) as its window-expiry timer abstraction, instead of introducing a second scheduling interface"
    - "flutter_foreground_task's own stopWithWithTask=false + onTaskRemoved restart-alarm logic (already built into the plugin) supplies D-33's force-kill survival with zero custom native code -- only Dart-side config and the matching manifest flag"

key-files:
  created:
    - backend/src/SafePath.Application/Sos/SosLiveWindowOptions.cs
    - backend/src/SafePath.Application/Sos/ReportSosLocationCommand.cs
    - backend/tests/SafePath.Application.Tests/Sos/SosLiveWindowTests.cs
    - mobile/lib/features/sos/application/sos_live_location_service.dart
    - mobile/lib/features/sos/presentation/sos_countdown.dart
    - mobile/test/features/sos/sos_live_window_test.dart
  modified:
    - backend/src/SafePath.Application/Sos/TriggerSosCommand.cs
    - backend/src/SafePath.Application/DependencyInjection.cs
    - backend/src/SafePath.Api/Controllers/SosController.cs
    - backend/tests/SafePath.Api.IntegrationTests/AlertHubSmokeTests.cs
    - mobile/lib/features/sos/application/sos_controller.dart
    - mobile/lib/features/sos/data/sos_api.dart
    - mobile/lib/core/theme/app_typography.dart
    - mobile/lib/features/sos/presentation/sender_emergency_session_screen.dart
    - mobile/lib/features/sos/presentation/responder_alert_screen.dart
    - mobile/android/app/src/main/AndroidManifest.xml
    - mobile/ios/Runner/Info.plist
    - mobile/test/features/sos/responder_alert_screen_test.dart
    - mobile/test/helpers/fake_sos_api.dart

key-decisions:
  - "LiveWindowEndsAtUtc is stamped from TriggerSosCommandHandler's server-side ReceivedAtUtc via a new optional SosLiveWindowOptions constructor parameter (default 15 min), never the client-supplied TriggeredAtUtc -- a skewed/manipulated device clock cannot extend how long it is tracked (T-03-28)."
  - "ReportSosLocationCommandHandler returns a typed ReportSosLocationOutcome (Accepted/WindowClosed/SessionNotFound) rather than throwing for a closed window or missing session -- a client that keeps sending after expiry gets a normal refusal it can act on (stop streaming), not an exception."
  - "SosLiveLocationService never persists a LocationPing row and never calls ReportLocationCommandHandler/ILocationBroadcastService/ISharingAuthorizationService/ILowBatteryAlertTracker in either the mobile or backend implementation -- the emergency stream stays structurally isolated from the routine location pipeline in both directions (SOS-01)."
  - "D-33 (force-kill survival) needed zero custom Kotlin: flutter_foreground_task v10.0.0's own ForegroundService.kt already calls RestartReceiver.setRestartAlarm() on onTaskRemoved whenever stopWithTask is false, and marks a real stopService() call as 'correctly stopped' so it is never resurrected -- only android:stopWithTask=\"false\" (manifest) plus the matching Dart-side ForegroundTaskOptions.stopWithTask=false were needed."
  - "SosLiveLocationService reports SosLiveLocationAvailability.unavailablePermissionDenied when location permission is missing (rather than throwing or silently doing nothing), but this plan does not wire that signal into any screen -- SosLiveActive still renders normally from the server's own session data even when the local stream can't run. Documented as a deliberate scope boundary, not a stub (see Known Gaps)."
  - "responder_alert_screen.dart's live-location card uses maplibre_gl's VectorMap (this project's actual post-migration map stack, 2026-08-06) rather than the plan's own read_first pointer to flutter_map, which predates that migration."

requirements: [SOS-04]

coverage:
  - id: D1
    description: "The live window's start/end are decided by the server (stamped from ReceivedAtUtc, never client TriggeredAtUtc), enforced on every position report, and re-broadcast identically on every LiveLocationWindowUpdate"
    requirement: "SOS-04"
    verification:
      - kind: unit
        ref: "backend/tests/SafePath.Application.Tests/Sos/SosLiveWindowTests.cs -- 7/7 tests pass"
        status: pass
      - kind: integration
        ref: "backend/tests/SafePath.Api.IntegrationTests/AlertHubSmokeTests.cs -- 5/5 tests pass (incl. the new end-to-end trigger -> report -> hub-delivery case)"
        status: pass
    human_judgment: false
  - id: D2
    description: "SosLiveLocationService streams the sender's position into the window via a foreground-task-backed geolocator stream, self-terminating on window-end, cancellation, or a server-reported closed window, and never starting outside an active SOS or without location permission"
    requirement: "SOS-04"
    verification:
      - kind: unit
        ref: "mobile/test/features/sos/sos_live_window_test.dart -- 8/8 tests pass"
        status: pass
    human_judgment: false
  - id: D3
    description: "Both the sender's Live-active state and the responder's live-location card render the identical server-issued countdown (tabular figures, no layout-width jitter), a labelled live indicator, and (responder-side) the sender's position on a live map, stopping updates cleanly at window expiry without blanking the view"
    requirement: "SOS-04"
    verification:
      - kind: unit
        ref: "mobile/test/features/sos/responder_alert_screen_test.dart -- 14/14 tests pass (7 from 03-04 plus 7 added here)"
        status: pass
    human_judgment: false
  - id: D4
    description: "D-33: the Android foreground service survives the sender swiping the app from recents mid-emergency (android:stopWithTask=\"false\" + the plugin's own onTaskRemoved restart-alarm), while still stopping cleanly on window-end/cancellation/explicit stop; OEM battery managers remain an accepted residual risk"
    verification:
      - kind: unit
        ref: "mobile/test/features/sos/sos_live_window_test.dart 'starts no host when the app has no active SOS session' / 'stops streaming...' cases cover the clean-stop paths; the swipe-survival path itself relies on the plugin's own native onTaskRemoved handler, not testable from Dart"
        status: pass
    human_judgment: true
    rationale: "The actual force-kill-and-resume behavior can only be observed on a physical/emulated Android device (swipe the app from recents mid-window, confirm the notification and stream resume) -- not exercisable in this execution sandbox. Verified analytically against the plugin's own ForegroundService.kt source (RestartReceiver.setRestartAlarm on onTaskRemoved when stopWithTask is unset/false) rather than a live device."
  - id: D5
    description: "Manual two-device smoke: trigger SOS on device A, lock device A, walk a short distance, confirm device B's responder map keeps updating and both devices show the same countdown; wait for window expiry and confirm updates stop while the last position remains visible"
    verification: []
    human_judgment: true
    rationale: "Requires two physical/emulated devices with real GPS movement and wall-clock window expiry, which is not available in this execution sandbox -- this is the plan's own explicitly-called-out manual verification step (same category as 03-06/03-07's prior manual gates)."

duration: ~45min (commit span; excludes reading/context/background-build wait time)
completed: 2026-08-07
status: complete
---

# Phase 03 Plan 08: Live-Location Streaming Window Summary

**Server-authoritative live-location window (stamped from server receive time, window-gated `POST /sos/{id}/location` ingest) plus a `flutter_foreground_task`-backed mobile stream that survives phone-lock, backgrounding, and an Android recents-swipe mid-emergency, rendered as an identical tabular-figure countdown and live map on both the sender's and responder's screens.**

## Performance

- **Duration:** ~45 min (task-commit span; excludes reading/context time and background build/test wait time)
- **Tasks:** 3
- **Files modified:** 20 (6 created, 14 modified)

## Accomplishments

- `SosLiveWindowOptions` (configurable `Sos:LiveWindowMinutes`, default 15) and `TriggerSosCommandHandler` now stamp `LiveWindowEndsAtUtc` from the server's own `ReceivedAtUtc` at session creation, never re-stamped by an idempotent replay.
- `ReportSosLocationCommand`/`ReportSosLocationCommandHandler` + `POST /sos/{sosSessionId}/location`: window-gated position ingest restricted to the triggering user, refusing (via a typed outcome, not an exception) once the session is canceled or the window has expired, and broadcasting `LiveLocationWindowUpdate` to the session's resolved recipients. Never touches `LocationPings`, `ISharingAuthorizationService`, or any routine-tracking service.
- `SosLiveLocationService` (mobile): starts a `flutter_foreground_task` foreground service plus a high-accuracy `geolocator` stream the moment `SosController` enters `SosLiveActive`, posts every fix to the new endpoint, and self-terminates on window-end (local timer), cancellation, or the server reporting a closed window in a report response — never outside an active SOS, and never silently failing when location permission is denied.
- Android `android:stopWithTask="false"` (manifest) + matching Dart-side `ForegroundTaskOptions.stopWithTask: false` (D-33): the plugin's own `onTaskRemoved`/`RestartReceiver` logic keeps the stream alive if the sender swipes the app from recents mid-emergency, while every legitimate stop path still shuts the service down cleanly. iOS gained `NSLocationAlwaysAndWhenInUseUsageDescription` + the `location` background mode (no `stopWithTask` equivalent needed — iOS background location modes already survive the equivalent gesture).
- `SosController` now derives `SosLiveActive` directly from a session's own `liveWindowEndsAtUtc` (trigger response or rehydrate fetch) and keeps it refreshed from every `LiveLocationWindowUpdate` the hub delivers, funnelling every state mutation through one `_replaceState` method so the live-location service starts/stops exactly once per transition.
- `AppTypography.countdownLarge` (44px/800 JetBrains Mono, explicit `FontFeature.tabularFigures()`) backs the new `SosCountdown`/`SosLiveIndicator`/`SosPulseRing` widgets, rendered identically on the sender's Live-active state ("Streaming your live location", pulse ring behind the header icon) and the responder's live-location card (same countdown/indicator above a `VectorMap` tracking the sender's latest reported position — updates stop cleanly at expiry, leaving the last position and a zeroed countdown rather than blanking the view).

## Task Commits

Each task was committed atomically:

1. **Task 1: Server-authoritative live window and window-gated position ingest** — `e5e65ec` (feat)
2. **Task 2: Stream the sender's position for the window, surviving lock and backgrounding** — `d305444` (feat)
3. **Task 3: Render the live-active state and a countdown that does not jitter** — `f7a692f` (feat)

**Plan metadata:** commit pending (this SUMMARY + STATE/ROADMAP update)

## Files Created/Modified

- `backend/src/SafePath.Application/Sos/SosLiveWindowOptions.cs` — `Sos:LiveWindowMinutes` config binding, default 15
- `backend/src/SafePath.Application/Sos/ReportSosLocationCommand.cs` — `ReportSosLocationCommand`/`Handler`/`Outcome`/`Result`
- `backend/src/SafePath.Application/Sos/TriggerSosCommand.cs` — stamps `LiveWindowEndsAtUtc` from `ReceivedAtUtc`
- `backend/src/SafePath.Application/DependencyInjection.cs` — registers `SosLiveWindowOptions` + the new handler
- `backend/src/SafePath.Api/Controllers/SosController.cs` — `POST /sos/{sosSessionId}/location`
- `backend/tests/SafePath.Application.Tests/Sos/SosLiveWindowTests.cs` — 7 tests
- `backend/tests/SafePath.Api.IntegrationTests/AlertHubSmokeTests.cs` — +1 end-to-end test, seeds `Users` rows
- `mobile/lib/features/sos/application/sos_live_location_service.dart` — `SosLiveLocationService`, `SosForegroundTaskHost`, `SosPositionSource`
- `mobile/lib/features/sos/application/sos_controller.dart` — `_deriveSessionState`/`_replaceState`, live-location wiring
- `mobile/lib/features/sos/data/sos_api.dart` — `reportSosLocation`, `SosLocationWindow`
- `mobile/lib/core/theme/app_typography.dart` — `countdownLarge`
- `mobile/lib/features/sos/presentation/sos_countdown.dart` — `SosCountdown`/`SosLiveIndicator`/`SosPulseRing`
- `mobile/lib/features/sos/presentation/sender_emergency_session_screen.dart` — `_LiveActiveBody`
- `mobile/lib/features/sos/presentation/responder_alert_screen.dart` — `_LiveLocationCard`, live subscription/expiry state
- `mobile/android/app/src/main/AndroidManifest.xml` — foreground-service permissions + `<service>` declaration
- `mobile/ios/Runner/Info.plist` — always-location description + `location` background mode
- `mobile/test/features/sos/sos_live_window_test.dart` — 8 tests
- `mobile/test/features/sos/responder_alert_screen_test.dart` — +7 tests (14 total)
- `mobile/test/helpers/fake_sos_api.dart` — `reportSosLocation` tracking

## Decisions Made

See `key-decisions` in frontmatter above.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `AlertHubSmokeTests.SeedFamily()` was missing `Users` rows, breaking the new end-to-end test with a FOREIGN KEY constraint failure**
- **Found during:** Task 1, writing `AlertHub_DeliversLiveLocationUpdateToAConnectedRecipient`
- **Issue:** The existing shared `SeedFamily()` helper only wrote `Families`/`FamilyMembers` rows (fine for the pre-existing connection-only tests), but `TriggerSosCommandHandler`'s recipient-resolution join and the `SosDeliveryAttempts.RecipientUserId` foreign key both require matching `Users` rows — the new test's real `/sos/trigger` call failed with `SQLite Error 19: 'FOREIGN KEY constraint failed'`.
- **Fix:** Added `Users` rows for the guardian and member ids to the shared `SeedFamily()` helper.
- **Files modified:** `backend/tests/SafePath.Api.IntegrationTests/AlertHubSmokeTests.cs`
- **Verification:** `AlertHubSmokeTests` 5/5 pass.
- **Committed in:** `e5e65ec` (Task 1 commit)

**2. [Rule 1 - Bug] XML comments in `AndroidManifest.xml` containing `--` broke the Gradle manifest merger**
- **Found during:** Task 2, first `flutter build apk --debug` verification run
- **Issue:** New doc comments used `--` (double-hyphen) as a clause separator, which is illegal inside an XML comment (only permitted immediately before the closing `-->`). The build failed with `org.xml.sax.SAXParseException: The string "--" is not permitted within comments.`
- **Fix:** Reworded the two offending comment blocks to avoid `--`, matching the file's own pre-existing em-dash convention.
- **Files modified:** `mobile/android/app/src/main/AndroidManifest.xml`
- **Verification:** `flutter build apk --debug` succeeds.
- **Committed in:** `d305444` (Task 2 commit)

**3. [Rule 1 - Bug] A duplicated literal string broke this task's own acceptance-criteria grep count**
- **Found during:** Task 3, verifying its own acceptance criteria
- **Issue:** A doc comment quoted the exact locked headline string ("Streaming your live location"), so `grep -c` against `sender_emergency_session_screen.dart` returned 2 instead of the required 1.
- **Fix:** Reworded the doc comment to reference "the `Text` below" instead of repeating the literal string.
- **Files modified:** `mobile/lib/features/sos/presentation/sender_emergency_session_screen.dart`
- **Verification:** `grep -c 'Streaming your live location' ...` returns exactly 1; full suite still green.
- **Committed in:** `f7a692f` (Task 3 commit)

**4. [Rule 3 - Blocking] `SosApi`'s new `reportSosLocation` abstract method required a matching implementation in the hand-written test fake**
- **Found during:** Task 2, writing `sos_live_window_test.dart`
- **Issue:** `SosApi` gained a new abstract method; `FakeSosApi` (used across the whole SOS test suite) would no longer compile without implementing it.
- **Fix:** Added `reportSosLocation` tracking/response-builder support to `FakeSosApi`, matching its existing per-method convention.
- **Files modified:** `mobile/test/helpers/fake_sos_api.dart`
- **Verification:** Full `mobile/test/features/sos/` suite (76 tests) green.
- **Committed in:** `d305444` (Task 2 commit)

**5. [Rule 3 - Blocking] `ResponderAlertScreen` needed a `mapPlatformViewBuilder` test seam to be widget-testable**
- **Found during:** Task 3, writing the live-map rendering tests
- **Issue:** The new `VectorMap` usage mounts a real MapLibre platform view, which has no test implementation and throws on the platform-views channel in a widget test.
- **Fix:** Added a `@visibleForTesting` `mapPlatformViewBuilder` field threaded straight through to `VectorMap`'s identically-scoped seam, mirroring `LiveMapScreen`'s own established convention exactly.
- **Files modified:** `mobile/lib/features/sos/presentation/responder_alert_screen.dart`, `mobile/test/features/sos/responder_alert_screen_test.dart`
- **Verification:** `responder_alert_screen_test.dart` 14/14 pass.
- **Committed in:** `f7a692f` (Task 3 commit)

---

**Total deviations:** 5 auto-fixed (3 Rule 1 bugs — a missing FK seed, an XML syntax error, and a copy-duplication grep break; 2 Rule 3 blocking — a required fake-implementation update and a required test seam)
**Impact on plan:** All five were necessary for correctness or to unblock this plan's own acceptance criteria (a real backend FK failure, a real Gradle build failure, a real acceptance-criteria mismatch, and two required-but-unlisted test-infrastructure updates). No scope creep beyond what each task already required.

## Issues Encountered

- A stale `SafePath.Api.exe` process from a prior session was holding a file lock on the backend build output, causing the first `dotnet build` attempt to fail with `MSB3027`/`MSB3021` copy errors. Not a code defect — the process was stopped and the build succeeded immediately after. Flagged here in case a future session hits the same stale-process lock in this environment.
- `flutter test test/features/sos/` (directory-wide, multi-file concurrent run) intermittently prints the same completing-test's name several times in a row in its compact-reporter output before moving to the next file — a known reporter/concurrency quirk already flagged in `03-07-SUMMARY.md` ("intermittently omitted two of the five files ... without any error"). Every acceptance-criteria count in this plan was independently confirmed via a **standalone** per-file `flutter test` run (exact `+N`/`All tests passed!` counts: 7/7, 5/5, 8/8, 14/14), not the directory-wide run, so this did not affect verification confidence.

## Known Gaps

- **`SosLiveLocationAvailability.unavailablePermissionDenied` is not yet surfaced in any screen.** `SosLiveLocationService` correctly detects and reports a denied location permission (rather than throwing or silently doing nothing) via its own `availability`/`availabilityChanges`, and `SosLiveActive` still renders normally from the server's own session data in that case (the emergency itself is never hidden). Wiring that availability signal into a visible "live location unavailable on this device" UI treatment was not required by this plan's `<behavior>` list or `<must_haves>` and is left for a future pass — documented here rather than silently dropped.
- **D-33's force-kill survival and the manual two-device smoke test (D5 above) were not exercised on real hardware** in this execution sandbox — see the `human_judgment: true` entries in `coverage` above for what was verified analytically (against the plugin's own source) versus what genuinely requires a physical/emulated device.

## Threat Flags

None beyond `03-08-PLAN.md`'s own `<threat_model>` register (T-03-09, T-03-27, T-03-28, T-03-29, T-03-30) — no new network endpoint, auth path, or trust-boundary surface was introduced beyond what that register already covers. All five threats' stated mitigations are implemented and asserted by the tests listed in `coverage` above.

## User Setup Required

None — no new external service configuration required this plan. (The pre-existing Firebase/Twilio setup gaps from earlier plans, tracked in `STATE.md`, are unaffected by this plan.)

## Next Phase Readiness

- 03-09 (hold-to-cancel + canceled-state chrome) can build directly on this plan's `SosLiveActive`/`SosCanceled` wiring: `SosController._applySosCanceled` already calls `SosLiveLocationService.handleSessionCanceled()` and `_replaceState`'s generic leaving-live-active handling stops the foreground service, so 03-09's cancel action needs no new live-location plumbing.
- The `artifacts_this_phase_produces` table's forward note (`SosLiveLocationService` consumed by 03-09's "cancel must stop it") is already satisfied.
- The two `human_judgment: true` coverage items (D4's on-device swipe survival, D5's two-device smoke) are the only items this plan could not close in this sandbox — carry them forward as the next manual-verification session's scope, alongside the still-open Firebase/Twilio items already tracked in `STATE.md`.

---
*Phase: 03-sos-fast-path*
*Completed: 2026-08-07*

## Self-Check: PASSED

- All 6 created files verified present on disk (backend: `SosLiveWindowOptions.cs`, `ReportSosLocationCommand.cs`, `SosLiveWindowTests.cs`; mobile: `sos_live_location_service.dart`, `sos_countdown.dart`, `sos_live_window_test.dart`), plus this SUMMARY.md itself.
- All 3 task commits (`e5e65ec`, `d305444`, `f7a692f`) verified present in `git log --oneline --all`.
- Backend: `dotnet build backend/SafePath.sln` and `dotnet test backend/SafePath.sln` both green (179/179 tests: 165 Application.Tests + 14 Api.IntegrationTests).
- Mobile: `flutter analyze` clean (0 issues); standalone per-file runs confirm `sos_live_window_test.dart` 8/8, `responder_alert_screen_test.dart` 14/14; `flutter build apk --debug` succeeds; full-suite run is green apart from 2 pre-existing, unrelated `member_map_pin_semantics_test.dart` SemanticsHandle-teardown failures already documented in `03-02-SUMMARY.md`/`03-04-SUMMARY.md` as out of scope.
