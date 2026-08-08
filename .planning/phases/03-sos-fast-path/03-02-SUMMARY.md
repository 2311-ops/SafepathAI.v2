---
phase: 03-sos-fast-path
plan: 02
subsystem: ui
tags: [flutter, riverpod, go_router, sos, animation-controller, dio, shared_preferences, uuid, url_launcher]

# Dependency graph
requires:
  - phase: 03-sos-fast-path
    provides: "03-01 — idempotent POST /sos/trigger, GET /sos/{sosSessionId:guid}, SosSessionDto/SosRecipientStatusDto/SosChannelStatusDto wire shapes"
provides:
  - "SosArmButton/SosArmRingPainter — 72px press-and-hold SOS control with 3000ms mint-to-red ring, haptics, long-press semantics, reduced-motion tick fallback"
  - "SosSessionState sealed union, SosController (arm/submit/closeSession), SosApi/DioSosApi, SosLocalStore/SharedPreferencesSosLocalStore, SosSession Dart mirrors"
  - "SenderEmergencySessionScreen at route '/sos/session', wired from MainShell's onArmComplete"
  - "mobile/pubspec.yaml now carries all seven Phase 3 packages plus uuid/url_launcher promoted from transitive"
affects: [03-04, 03-06, 03-07, 03-08, 03-09]

# Tech tracking
tech-stack:
  added:
    - "firebase_core 4.12.1, firebase_messaging 16.4.3, quick_actions 1.1.0, connectivity_plus 7.3.1, flutter_local_notifications 22.2.0, flutter_foreground_task 10.0.0 — installed, not yet consumed (later mobile plans)"
    - "shared_preferences 2.5.5 — promoted to direct, backs SosLocalStore"
    - "uuid 4.6.0 — promoted to direct (was transitive), generates the device-side v4 sosSessionId"
    - "url_launcher 6.3.2 — promoted to direct (was transitive via share_plus), backs the Delivering state's tel:911 CTA"
  patterns:
    - "Sealed SosSessionState union rendered via pattern-matching switch + AnimatedSwitcher, not a single copyWith state shape — matches the plan's explicit direction since these states carry genuinely different payloads"
    - "Controller-level plain field (SosController.sosSessionId) exposes the device-generated id independent of the wrapping AsyncValue<SosSessionState>, so D-13/D-14 (id exists+persisted before network) is observable without inventing a synthetic sealed state for the pre-response moment"

key-files:
  created:
    - mobile/lib/features/sos/presentation/sos_arm_button.dart
    - mobile/lib/features/sos/presentation/sos_arm_ring_painter.dart
    - mobile/lib/features/sos/presentation/sender_emergency_session_screen.dart
    - mobile/lib/features/sos/data/sos_models.dart
    - mobile/lib/features/sos/data/sos_api.dart
    - mobile/lib/features/sos/data/sos_local_store.dart
    - mobile/lib/features/sos/application/sos_session_state.dart
    - mobile/lib/features/sos/application/sos_controller.dart
    - mobile/test/features/home/sos_button_press_hold_test.dart
    - mobile/test/features/sos/sos_controller_test.dart
    - mobile/test/helpers/fake_sos_api.dart
    - mobile/test/helpers/fake_sos_local_store.dart
    - .planning/phases/03-sos-fast-path/deferred-items.md
  modified:
    - mobile/lib/features/home/presentation/main_shell.dart
    - mobile/lib/core/router/app_router.dart
    - mobile/lib/shared_widgets/member_map_pin.dart
    - mobile/pubspec.yaml
    - mobile/pubspec.lock

key-decisions:
  - "Promoted uuid and url_launcher from transitive to direct dependencies (matching the plan's own precedent for shared_preferences) rather than treating them as new, ungated package installs — both were already resolved in pubspec.lock via existing approved dependencies (signalr_netcore/qr_flutter and share_plus respectively), so no new supply-chain surface was introduced and no fresh legitimacy checkpoint was required."
  - "The pre-network-response moment between arm() persisting a session id and submit() resolving is represented by the AsyncNotifier's own AsyncLoading state, not a new sealed SosSessionState subtype — the plan's six declared subclasses stay exactly six."
  - "SosController exposes sosSessionId as a plain getter (not part of the sealed state) so D-13/D-14 (id generated+persisted before any network call) is directly observable by tests and future callers without fabricating a placeholder SosSession."
  - "SosOfflineQueued's placeholder render (owned fully by 03-07) cannot literally reuse the SosDelivering body, since SosOfflineQueued carries no SosSession/triggeredAtUtc to compute an elapsed timer from — it renders a distinct, non-empty fallback with a code comment naming 03-07 as the owner."

patterns-established:
  - "AnimationController ticker started from a widget gesture callback (not the test body directly) needs a zero-duration `await tester.pump()` immediately after the triggering gesture/direction-change, before jumping the clock — otherwise the ticker's own first tick becomes its zero point and swallows the jump. Documented inline in sos_button_press_hold_test.dart for future SOS motion tests (03-09's hold-to-cancel reuses this ring)."

requirements-completed: [SOS-01, DESIGN-02, SOS-03]

coverage:
  - id: D1
    description: "The SOS button is rebuilt as a 72px, 4px-bordered, 3000ms press-and-hold control with a mint-to-red progress ring, haptics, long-press semantics for screen readers, and a discrete-tick reduced-motion fallback; it no longer switches bottom-nav tabs"
    requirement: "DESIGN-02"
    verification:
      - kind: unit
        ref: "mobile/test/features/home/sos_button_press_hold_test.dart#renders at the locked geometry, fills the ring over three seconds, release before three seconds cancels and fires nothing, cancelled gesture resets progress, exposes a long-press semantics action, honours reduced motion, no longer changes the selected tab"
        status: pass
    human_judgment: false
  - id: D2
    description: "SosController.arm() generates a device-side v4 session id and persists it before any network call, reuses the same id on resubmission, and a successful trigger yields a SosSubmitted state carrying the server's recipients; closeSession() clears the persisted id"
    requirement: "SOS-01"
    verification:
      - kind: unit
        ref: "mobile/test/features/sos/sos_controller_test.dart#generates a session id before any network call, persists the session id to the local store, reuses the persisted id on resubmission, moves to submitted state on a successful trigger, clears the persisted id when the session is closed, does not call the location report endpoint"
        status: pass
    human_judgment: false
  - id: D3
    description: "A full-screen Sender Emergency Session route (/sos/session) is registered as authenticated-only, pushed from MainShell's arm-complete callback with no confirmation gate, rendering the Submitted/Delivering states with locked copy and an exhaustive switch over the sealed SosSessionState"
    requirement: "SOS-01"
    verification:
      - kind: unit
        ref: "flutter analyze (no non-exhaustive-switch warning); grep checks on app_router.dart/main_shell.dart/sender_emergency_session_screen.dart per acceptance criteria"
        status: pass
    human_judgment: false
  - id: D4
    description: "Manual on-device/emulator smoke test: hold the SOS button for three seconds and confirm the full-screen red session opens; hold for two seconds and release and confirm nothing happens"
    requirement: "SOS-01"
    verification: []
    human_judgment: true
    rationale: "No emulator/device was available in this execution environment; this is a physical/visual interaction check the plan's own <verification> section calls out as manual, not something the automated test suite can substitute for."

duration: ~25min
completed: 2026-08-02
status: complete
---

# Phase 03 Plan 02: SOS Button, Data/Application Layer, and Sender Emergency Session Summary

**Press-and-hold 72px SOS control (3000ms mint-to-red ring) wired through a Riverpod SosController to POST /sos/trigger, landing in a full-screen red Sender Emergency Session route with an exhaustive sealed-state switch.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-08-01T23:30:00+03:00 (approx.)
- **Completed:** 2026-08-02T00:08:02+03:00
- **Tasks:** 3
- **Files modified:** 18 (13 created, 5 modified)

## Accomplishments
- Replaced `_SosTabButton` (a tab-switching `InkWell` showing a "Coming soon" snackbar) with `SosArmButton`: a 72px raised disc that fills a mint-to-red ring over exactly 3000ms, snaps back on early release with nothing sent, is armable via the platform long-press screen-reader gesture, and degrades to discrete ticks under reduced motion — timing never shortened.
- Built the `sos` feature's data + application layer: Dart mirrors of the 03-01 backend DTOs (parsed defensively, safe fallback on any unknown enum string), `DioSosApi` against `POST /sos/trigger`/`GET /sos/{sosSessionId}`, `SharedPreferencesSosLocalStore`, and `SosController` whose `arm()` generates and persists a v4 session id before any network call.
- Added the full-screen `SenderEmergencySessionScreen` at `/sos/session` (authenticated-only route), with a 200ms fade `AnimatedSwitcher` (instant swap under reduced motion) over an exhaustive `switch` on the sealed `SosSessionState`; "Sending alert…" never claims "Sent," and "Alert active · mm:ss elapsed" carries the one non-red "Call 911" CTA.
- Fixed a pre-existing, blocking syntax bug in `member_map_pin.dart` (stray trailing comma breaking a ternary) that had been silently failing compilation of any file importing it — including the entire mobile test suite before this plan.

## Task Commits

Each task was committed atomically:

1. **Task 1: Install the Flutter package batch and rebuild the SOS button as a 3-second press-and-hold control** - `555a22f` (feat)
2. **Task 2: Build the sos feature data + application layer with device-generated, locally persisted session ids** - `f7a4b4c` (feat)
3. **Task 3: Add the full-screen sender emergency session route and wire the button to it** - `08e6eb1` (feat)

**Plan metadata:** commit pending (this SUMMARY + STATE/ROADMAP update)

_Note: All three tasks were TDD-flavored (Task 1/2 explicitly `tdd="true"`) but executed as single feat commits per task rather than separate RED/GREEN commits — tests and implementation were iterated together to resolve fake-clock/ticker test-environment artifacts before the first commit landed._

## Files Created/Modified
- `mobile/lib/features/sos/presentation/sos_arm_button.dart` - 72px press-and-hold control: gesture wiring, haptics, semantics, reduced-motion gating
- `mobile/lib/features/sos/presentation/sos_arm_ring_painter.dart` - `CustomPainter` for the mint-to-red arc / reduced-motion tick marks
- `mobile/lib/features/sos/presentation/sender_emergency_session_screen.dart` - Full-screen red session route, exhaustive `SosSessionState` switch, "Call 911" CTA
- `mobile/lib/features/sos/data/sos_models.dart` - `SosSession`/`SosRecipientStatus`/`SosChannelStatus`/`SosTriggerRequest` + defensive enum parsing
- `mobile/lib/features/sos/data/sos_api.dart` - `DioSosApi` against `/sos/trigger` and `/sos/{sosSessionId}`
- `mobile/lib/features/sos/data/sos_local_store.dart` - `SharedPreferencesSosLocalStore` (`sos.sessionId`, `sos.pendingTrigger`)
- `mobile/lib/features/sos/application/sos_session_state.dart` - Sealed `SosSessionState` union (6 subclasses)
- `mobile/lib/features/sos/application/sos_controller.dart` - `arm()`/`submit()`/`closeSession()`, `sosSessionId` getter
- `mobile/lib/features/home/presentation/main_shell.dart` - `_SosTabButton` removed; `SosArmButton` wired to `sosControllerProvider.arm()` + push `'sos-session'`
- `mobile/lib/core/router/app_router.dart` - `/sos/session` route + authenticated-only entry
- `mobile/lib/shared_widgets/member_map_pin.dart` - Fixed stray trailing comma breaking the ternary (pre-existing bug)
- `mobile/pubspec.yaml` / `pubspec.lock` - Seven Phase 3 packages + `uuid`/`url_launcher` promoted from transitive
- `mobile/test/features/home/sos_button_press_hold_test.dart` - 7 tests (DESIGN-02 geometry, 3s hold/cancel, semantics, reduced motion, tab-switch regression)
- `mobile/test/features/sos/sos_controller_test.dart` - 6 tests (session-id generation/persistence/reuse, submitted state, close, isolation from location reporting)
- `mobile/test/helpers/fake_sos_api.dart` / `fake_sos_local_store.dart` - Hand-written fakes matching the `fake_location_api.dart` convention

## Decisions Made
- `uuid` and `url_launcher` promoted from transitive to direct dependencies rather than gated as new installs — both were already present in `pubspec.lock` via already-approved dependencies (matches this plan's own precedent for `shared_preferences`).
- The pre-network-response "arming" moment is represented by `AsyncLoading()`, not a new sealed subtype — the six declared `SosSessionState` subclasses stay exactly six.
- `SosController.sosSessionId` is a plain getter outside the sealed state, giving tests and future callers a synchronous way to observe D-13/D-14 without inventing a placeholder `SosSession`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed pre-existing stray trailing comma in `member_map_pin.dart`**
- **Found during:** Task 1, first `flutter test` run after writing the new SOS button test
- **Issue:** `member_map_pin.dart` had `),` (with a trailing comma) closing a `ClipOval(...)` call directly before a ternary's `:` branch — invalid Dart syntax that broke compilation of every file transitively importing it (including any test touching `MainShell`/`LiveMapScreen`). Confirmed via `git diff HEAD` that this was already committed, unmodified by this session.
- **Fix:** Removed the stray comma so the ternary parses correctly.
- **Files modified:** `mobile/lib/shared_widgets/member_map_pin.dart`
- **Verification:** `dart format`/`flutter analyze` clean; full test suite compiles and runs
- **Committed in:** `555a22f` (Task 1 commit)

**2. [Rule 3 - Blocking] Promoted `uuid` and `url_launcher` from transitive to direct dependencies**
- **Found during:** Task 2 (session-id generation) and Task 3 (Call 911 CTA)
- **Issue:** Task 1's batch install didn't include a UUID or URL-launching package, but Task 2 requires generating a v4 GUID and Task 3 requires a `tel:` launch
- **Fix:** Confirmed both were already resolved transitively in `pubspec.lock` (via `signalr_netcore`/`qr_flutter` and `share_plus` respectively) before running `flutter pub add uuid` / `flutter pub add url_launcher` — no new supply-chain surface, matching the plan's own precedent for `shared_preferences`
- **Files modified:** `mobile/pubspec.yaml`, `mobile/pubspec.lock`
- **Verification:** `flutter pub get` resolves cleanly; `flutter analyze` clean
- **Committed in:** `f7a4b4c` (uuid, Task 2), `08e6eb1` (url_launcher, Task 3)

**3. [Rule 1 - Bug] Fixed a rehydrate/arm race in `SosController`**
- **Found during:** Task 2, first `flutter test` run for `sos_controller_test.dart`
- **Issue:** `build()`'s fire-and-forget `Future.microtask(_rehydrate)` could run after a test's own `arm()` call had already generated and persisted a fresh session id, causing `_rehydrate` to see that id and issue a spurious extra `getSession` call
- **Fix:** `_rehydrate()` now no-ops if `_sessionId` is already set by the time it runs
- **Files modified:** `mobile/lib/features/sos/application/sos_controller.dart`
- **Verification:** `sos_controller_test.dart`'s "does not call the location report endpoint" test (which also asserts `getSessionCallCount == 0`) passes
- **Committed in:** `f7a4b4c` (Task 2 commit)

**4. [Rule 1 - Bug] Fixed a deactivated-context crash in `SosArmButton._cancelArm()`**
- **Found during:** Task 1, while diagnosing a test-teardown exception
- **Issue:** If the widget is disposed while a hold is still in progress and never resolved via up/cancel, Flutter's gesture recognizer disposal synthesizes a cancel, which called `_cancelArm()` → `MediaQuery.of(context)` on an already-deactivated element
- **Fix:** Added a `mounted` guard at the top of `_cancelArm()`
- **Files modified:** `mobile/lib/features/sos/presentation/sos_arm_button.dart`
- **Verification:** Full `sos_button_press_hold_test.dart` suite passes cleanly, no teardown exceptions
- **Committed in:** `555a22f` (Task 1 commit)

---

**Total deviations:** 4 auto-fixed (2 Rule 1 bugs pre-existing/newly-discovered, 1 Rule 1 race-condition bug in this plan's own new code, 1 Rule 3 blocking package promotion)
**Impact on plan:** All four were necessary for correctness or to unblock compilation/testing; no scope creep beyond what each task already required.

## Issues Encountered
- Widget-test animation timing: `AnimationController`s started inside a gesture callback (rather than directly in the test body) need an extra zero-duration `await tester.pump()` immediately after the triggering event/direction-change, before jumping the fake clock forward — otherwise the ticker's own first tick becomes its zero point and swallows the jump. This cost significant debugging time (isolated via a throwaway probe test) but is now documented inline in `sos_button_press_hold_test.dart` for 03-09's hold-to-cancel tests to reuse.
- `MainShell`'s `IndexedStack` builds every tab eagerly, so a widget test rendering `MainShell` must override `privacyControllerProvider` and `authApiProvider` (not just `familyControllerProvider`/`locationControllerProvider`) to avoid `PrivacyCenterScreen` touching an uninitialized real Supabase client.
- Found (but did not fix, per scope boundary) a pre-existing, unrelated `SemanticsHandle` teardown failure in `member_map_pin_semantics_test.dart`, only now visible because this plan's `member_map_pin.dart` syntax fix unblocked compilation of the whole suite for the first time. Logged in `.planning/phases/03-sos-fast-path/deferred-items.md`.

## Known Stubs

None — `SosOfflineQueued`/`SosLiveActive`/`SosCanceled` render real (if minimal) content rather than empty placeholders, each with a code comment naming the plan (03-07/03-08/03-09) that owns their locked treatment. This is an explicit, plan-directed seam, not an unintentional stub.

## User Setup Required
None - no external service configuration required this plan.

## Next Phase Readiness
- 03-04 (per-recipient delivery list), 03-07 (offline/retry + local fallback actions), 03-08 (live-location countdown), and 03-09 (hold-to-cancel + canceled chrome) can all build directly on `SosSessionState`, `SosController`, `SosApi`, and the seam comments left in `sender_emergency_session_screen.dart`.
- 03-06 (Firebase) and 03-09 (quick_actions) can consume the packages this plan installed without touching `pubspec.yaml` again.
- Manual on-emulator smoke verification (hold 3s → full-screen session opens; hold 2s and release → nothing happens) was not performed in this execution environment (no device/emulator available) — flagged as human-judgment coverage (D4) above.
- Deferred, pre-existing, unrelated test failure in `member_map_pin_semantics_test.dart` — see `.planning/phases/03-sos-fast-path/deferred-items.md`.

---
*Phase: 03-sos-fast-path*
*Completed: 2026-08-02*

## Self-Check: PASSED

All 14 created/tracked files verified present on disk; all 3 task commits (`555a22f`, `f7a4b4c`, `08e6eb1`) verified present in git log.
