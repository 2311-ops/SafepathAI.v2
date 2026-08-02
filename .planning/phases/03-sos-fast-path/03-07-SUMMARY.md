---
phase: 03-sos-fast-path
plan: 07
subsystem: ui
tags: [flutter, riverpod, connectivity_plus, offline-retry, emergency-contacts, sos]

# Dependency graph
requires:
  - phase: 03-sos-fast-path
    provides: "03-04 -- sosHubClientProvider/SosResponderController, delivery-status vocabulary, sender_emergency_session_screen.dart scaffold with SosOfflineQueued declared-but-unrendered"
  - phase: 03-sos-fast-path
    provides: "03-05 -- EmergencyContact backend CRUD (/me/emergency-contacts), PhoneNumberNormalizer as the sole validity authority"
provides:
  - "ConnectivityService/ConnectivityPlusConnectivityService/connectivityServiceProvider -- a hint-only network-interface signal, never reachability proof"
  - "SosController offline queue: writes the pending trigger payload before the first network attempt, enters SosOfflineQueued on a network-class failure, retries on an escalating capped backoff via an injectable SosRetryScheduler seam, retries immediately on a connectivity-restored hint, resumes the same queued session id after a cold start, and surfaces only non-network failures as a terminal error"
  - "EmergencyContactApi/DioEmergencyContactApi/emergencyContactApiProvider, EmergencyContactsController/emergencyContactsControllerProvider -- CRUD against plan 03-05's endpoints, mutation failures never blank the loaded list"
  - "EmergencyContactsScreen at route '/settings/emergency-contacts' (D-30), reachable from Privacy Center"
  - "SosOfflineQueued rendering on sender_emergency_session_screen.dart: 'Not sent yet' + relative last-retry timestamp (150ms cross-fade, whole-screen chrome untouched), 'Call {contact}'/'Copy my location' local fallback actions"
  - "FakeConnectivityService, FakeEmergencyContactApi test helpers"
affects: [03-08, 03-09]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SosRetryScheduler/SosRetryHandle seam in sos_controller.dart: the offline-retry backoff timer is injected, not a bare dart:async Timer, so tests fire a scheduled retry deterministically instead of sleeping in real wall-clock time"
    - "connectivity_plus is consulted only as a retry-sooner hint (onConnectivityChanged -> immediate resubmit attempt); the actual HTTP call outcome is the only thing that ever decides success/failure, matching 03-RESEARCH.md's anti-pattern guidance"

key-files:
  created:
    - mobile/lib/core/network/connectivity_service.dart
    - mobile/lib/features/sos/data/emergency_contact_api.dart
    - mobile/lib/features/sos/application/emergency_contacts_controller.dart
    - mobile/lib/features/sos/presentation/emergency_contacts_screen.dart
    - mobile/test/helpers/fake_connectivity_service.dart
    - mobile/test/helpers/fake_emergency_contact_api.dart
    - mobile/test/features/sos/sos_offline_retry_test.dart
    - mobile/test/features/sos/emergency_contacts_screen_test.dart
  modified:
    - mobile/lib/features/sos/application/sos_controller.dart
    - mobile/lib/features/sos/data/sos_local_store.dart
    - mobile/lib/features/sos/presentation/sender_emergency_session_screen.dart
    - mobile/lib/core/router/app_router.dart
    - mobile/lib/features/privacy/presentation/privacy_center_screen.dart
    - mobile/test/features/sos/sos_controller_test.dart
    - mobile/test/features/sos/sos_delivery_status_test.dart
    - mobile/test/features/privacy/privacy_center_screen_test.dart
    - mobile/test/helpers/fake_sos_local_store.dart

key-decisions:
  - "SosController's retry loop is a single injectable SosRetryScheduler seam (schedule(Duration, callback) -> SosRetryHandle), not a bespoke backoff package -- kept the idempotency (server-side, 03-01) as the only part that must not be improvised, per 03-RESEARCH.md."
  - "Added SosLocalStore.clearPendingTrigger() (clears only the pending payload, not the session id) so a successful retry can resolve to SosSubmitted without losing the resumable session id closeSession() still owns."
  - "sosHubClientProvider's default construction depends on an initialized Supabase client, which is never initialized in the unit-test process -- every test container in this plan that reads sosControllerProvider now overrides sosHubClientProvider with FakeSosHubClient so SosController.build() completes and its connectivity subscription actually establishes, instead of silently failing into an unobserved AsyncError."
  - "Corrected the pre-existing generic AsyncError-state copy on the sender screen ('...Keep trying...') which predates this plan's offline queue: since Task 1 now routes every network failure through SosOfflineQueued instead, the AsyncError branch is reached only for a genuine non-network rejection (validation/forbidden) that will NOT retry automatically -- the old copy falsely implied it would, so it now surfaces the server's own rejection message instead."
  - "Emergency contacts entry point placed in Privacy Center's 'Your data' actions section (not Profile) -- the existing information architecture already groups account-level settings actions there."

requirements: [SOS-03, SOS-02]

coverage:
  - id: D1
    description: "Offline queue: the pending trigger persists before the first network attempt, a network-class failure enters SosOfflineQueued with an escalating capped backoff, connectivity-restored fires an immediate retry, the same session id is reused on every retry, a cold start resumes the same queued session, and a non-network rejection surfaces as an error instead of retrying forever"
    requirement: "SOS-03"
    verification:
      - kind: unit
        ref: "mobile/test/features/sos/sos_offline_retry_test.dart -- 10/10 tests pass"
        status: pass
    human_judgment: false
  - id: D2
    description: "Emergency contacts can be added, edited, and removed (behind confirmation) from a reachable settings screen; the server's rejection message renders verbatim with no client-side phone regex; a failed mutation never blanks the already-loaded list; the screen never uses AppColors.sosRed"
    requirement: "SOS-03"
    verification:
      - kind: unit
        ref: "mobile/test/features/sos/emergency_contacts_screen_test.dart -- 8/8 tests pass"
        status: pass
    human_judgment: false
  - id: D3
    description: "The offline/queued sender session renders 'Not sent yet', a relative last-retry timestamp that cross-fades in place (150ms, whole-screen chrome untouched), and the two zero-network local fallback actions (call/copy-location), including the no-contact and no-fix disabled variants"
    requirement: "SOS-03"
    verification:
      - kind: other
        ref: "grep checks against the locked copy strings in sender_emergency_session_screen.dart ('Not sent yet, retrying' x1, 'Copy my location' x1, 'Keep trying' x1, 'Clipboard.setData' x1); full mobile test suite green with the new SosOfflineQueued branch wired into the existing exhaustive switch"
        status: pass
    human_judgment: true
    rationale: "No dedicated widget test constructs a live SosOfflineQueued state against this screen (not in this task's own file list); a manual ad-hoc render was used during development to confirm no runtime crash but was not committed as a permanent test, since Task 3 designates the airplane-mode device smoke as its own verification step."
  - id: D4
    description: "Manual two-device/airplane-mode smoke: trigger SOS offline, confirm the queued session appears instantly; kill the app; reopen it and confirm the same session resumes still queued; re-enable networking and confirm it submits without user action and only one emergency exists server-side"
    verification: []
    human_judgment: true
    rationale: "Requires a physical/emulator device with airplane-mode toggling and app-kill/relaunch, which is not available in this execution sandbox -- this is the plan's own explicitly-called-out manual verification step."

duration: ~17min
completed: 2026-08-02
status: complete
---

# Phase 03 Plan 07: Offline SOS Queue/Retry, Emergency Contacts, and Offline Fallback UI Summary

**A connectivity-hint-driven offline retry loop in SosController (persist-before-send, escalating capped backoff, connectivity-triggered fast retry, cold-start resume), a full emergency-contact management screen at `/settings/emergency-contacts`, and the offline "Not sent yet, retrying" session UI with zero-network call/copy-location fallback actions.**

## Performance

- **Duration:** ~17 min (task-commit span; excludes reading/context time)
- **Started:** 2026-08-02T20:50:24+03:00
- **Completed:** 2026-08-02T21:07:10+03:00
- **Tasks:** 3
- **Files modified:** 17 (8 created, 9 modified)

## Accomplishments

- Built `ConnectivityService` (`connectivity_plus`-backed) documented and used strictly as a retry-sooner hint, never reachability proof — the actual `SosApi.trigger` call outcome is the only thing that ever decides success or failure.
- `SosController.arm()`/`submit()` now persist the composed `SosTriggerRequest` to `SosLocalStore` before the first network attempt; a network-class `SosApiException` enters `SosOfflineQueued` and schedules a retry via an injectable `SosRetryScheduler` seam (short initial delay, doubling, capped ~60s) — the same session id is reused on every attempt, a connectivity-restored event fires an immediate resubmit, and a cold start with a still-pending payload resumes the same queued emergency instead of losing it or minting a new one.
- A non-network rejection (validation/forbidden) now surfaces as a genuine error state instead of retrying forever — and the sender screen's pre-existing generic error copy was corrected to stop implying an automatic retry that Task 1's design no longer performs for that branch.
- Built `EmergencyContactApi`/`DioEmergencyContactApi` against plan 03-05's `/me/emergency-contacts` CRUD, and `EmergencyContactsController` (load-on-build, mutation failures never blank the already-loaded list).
- Built `EmergencyContactsScreen` (D-30): list + edit/remove-behind-confirmation + add form, server's rejection message surfaced verbatim, no client-side phone regex, never uses `AppColors.sosRed`. Reachable from Privacy Center's "Your data" section.
- Filled the `SosOfflineQueued` branch of `sender_emergency_session_screen.dart`: same red gradient chrome as every other active state (deliberately no pulse/blink), "Not sent yet, retrying… Last retry: {relative time}" with only the timestamp text cross-fading (150ms, gated on `disableAnimations`), and two local fallback actions — "Call {contact}" (falls back to a link to the emergency-contacts screen when none exist) and "Copy my location" (disabled with an explanatory caption, never a silent empty-string copy, when no fix is available).

## Task Commits

Each task was committed atomically:

1. **Task 1: Queue, retry, and resume an SOS that could not be sent** - `0627b6d` (feat)
2. **Task 2: Emergency-contact management screen and API client** - `459dcf3` (feat)
3. **Task 3: Render the offline emergency session with its local fallback actions** - `8930a6b` (feat)

**Plan metadata:** commit pending (this SUMMARY + STATE/ROADMAP update)

## Files Created/Modified

- `mobile/lib/core/network/connectivity_service.dart` - `ConnectivityService`/`ConnectivityPlusConnectivityService`/`connectivityServiceProvider`
- `mobile/lib/features/sos/application/sos_controller.dart` - Offline queue/retry loop, `SosRetryScheduler`/`SosRetryHandle`/`sosRetrySchedulerProvider`, `checkQueuedSessionStatus()`
- `mobile/lib/features/sos/data/sos_local_store.dart` - Added `clearPendingTrigger()`
- `mobile/lib/features/sos/data/emergency_contact_api.dart` - `EmergencyContact` model, `EmergencyContactApi`/`DioEmergencyContactApi`, `emergencyContactApiProvider`
- `mobile/lib/features/sos/application/emergency_contacts_controller.dart` - `EmergencyContactsController`/`EmergencyContactsState`/`emergencyContactsControllerProvider`
- `mobile/lib/features/sos/presentation/emergency_contacts_screen.dart` - List/add/edit/remove UI, no SOS red, no client phone regex
- `mobile/lib/features/sos/presentation/sender_emergency_session_screen.dart` - `SosOfflineQueued` rendering, corrected AsyncError-branch copy
- `mobile/lib/core/router/app_router.dart` - `/settings/emergency-contacts` route + authenticated-only entry
- `mobile/lib/features/privacy/presentation/privacy_center_screen.dart` - "Emergency contacts" entry point
- `mobile/test/helpers/fake_connectivity_service.dart` - `FakeConnectivityService`
- `mobile/test/helpers/fake_emergency_contact_api.dart` - `FakeEmergencyContactApi`
- `mobile/test/helpers/fake_sos_local_store.dart` - Added `clearPendingTrigger` tracking
- `mobile/test/features/sos/sos_offline_retry_test.dart` - 10 tests, incl. `FakeSosRetryScheduler`
- `mobile/test/features/sos/emergency_contacts_screen_test.dart` - 8 tests
- `mobile/test/features/sos/sos_controller_test.dart` - Added `connectivityServiceProvider`/`sosHubClientProvider` overrides
- `mobile/test/features/sos/sos_delivery_status_test.dart` - Added `connectivityServiceProvider` override to its screen-widget test
- `mobile/test/features/privacy/privacy_center_screen_test.dart` - Widened a scroll-drag distance after the new entry point shifted layout

## Decisions Made

See `key-decisions` in frontmatter above.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `sosHubClientProvider`'s default construction requires an initialized Supabase client, which is absent in the unit-test process**
- **Found during:** Task 1, writing `sos_offline_retry_test.dart`'s "submits immediately when connectivity returns" test
- **Issue:** `SosController.build()` reads `sosHubClientProvider` before establishing its own connectivity subscription; the default provider throws `Failed assertion: You must initialize the supabase instance` in a plain `ProviderContainer` test, silently swallowing every line of `build()` after that point (including the connectivity listener) into an unobserved `AsyncError` — the notifier instance still worked for direct method calls, masking the failure entirely until a test actually exercised the connectivity subscription.
- **Fix:** Overrode `sosHubClientProvider` with the existing `FakeSosHubClient` test double in every `ProviderContainer` in `sos_offline_retry_test.dart` and `sos_controller_test.dart` (and added the missing `connectivityServiceProvider` override to `sos_delivery_status_test.dart`'s one screen-widget test that also reads `sosControllerProvider`), so `build()` completes for real.
- **Files modified:** `mobile/test/features/sos/sos_offline_retry_test.dart`, `mobile/test/features/sos/sos_controller_test.dart`, `mobile/test/features/sos/sos_delivery_status_test.dart`
- **Verification:** All 16 `sos_offline_retry_test.dart`/`sos_controller_test.dart` tests pass; `sos_delivery_status_test.dart`'s full suite still green.
- **Committed in:** `0627b6d` (Task 1 commit)

**2. [Rule 1 - Bug] Edit-contact dialog's `TextEditingController`s used after disposal**
- **Found during:** Task 2, the "edits a contact" widget test
- **Issue:** Manually disposing the dialog's controllers immediately after `showDialog` returned raced the dialog route's own exit transition, throwing "A TextEditingController was used after being disposed."
- **Fix:** Extracted the dialog into its own `_EditContactDialog` `StatefulWidget` that owns and disposes its controllers in its own `dispose()`, tying their lifecycle to the framework's own unmount timing instead of a manual call-site dispose.
- **Files modified:** `mobile/lib/features/sos/presentation/emergency_contacts_screen.dart`
- **Verification:** "edits a contact" test passes; `flutter analyze` clean.
- **Committed in:** `459dcf3` (Task 2 commit)

**3. [Rule 1 - Bug] "Delete my data" became unreachable in the pre-existing Privacy Center test after adding the new entry point above it**
- **Found during:** Task 2 / full-suite verification, `privacy_center_screen_test.dart`'s "delete data is confirmation-gated"
- **Issue:** The new "Emergency contacts" button pushed "Delete my data" further down the list; the existing test's fixed `drag` distance no longer scrolled it into the hit-testable viewport.
- **Fix:** Widened the drag distance (Scrollable clamps overshoot harmlessly).
- **Files modified:** `mobile/test/features/privacy/privacy_center_screen_test.dart`
- **Verification:** `privacy_center_screen_test.dart` full suite green; full mobile suite re-run clean afterward.
- **Committed in:** `8930a6b` (Task 3 commit, alongside the copy-collision fix below — both surfaced during the same final full-suite verification pass)

**4. [Rule 1 - Bug] Task 3's new offline-state copy accidentally duplicated two locked-copy grep counts**
- **Found during:** Task 3, verifying its own acceptance criteria
- **Issue:** A doc comment repeated the literal "Copy my location" label text, and the new offline body's own "Keep trying…" copy coexisted with the pre-existing (and now contextually stale) AsyncError-branch copy of the same phrase — both acceptance criteria require exactly one occurrence in the file.
- **Fix:** Reworded the doc comment to drop the literal label string, and corrected the AsyncError branch's copy (see key-decisions) so "Keep trying" appears exactly once, in the branch that actually keeps retrying.
- **Files modified:** `mobile/lib/features/sos/presentation/sender_emergency_session_screen.dart`
- **Verification:** All four grep-based acceptance criteria return exactly 1; full mobile suite green.
- **Committed in:** `8930a6b` (Task 3 commit)

---

**Total deviations:** 4 auto-fixed (1 Rule 3 blocking test-infra fix, 3 Rule 1 bugs — a controller-disposal race, a test-suite scroll-distance break, and a copy-fidelity/duplication correction)
**Impact on plan:** All four were necessary for correctness (a masked build failure, a real disposal crash, a pre-existing test broken by this plan's own UI change, and copy accuracy against this plan's own acceptance criteria); no scope creep beyond what each task already required.

## Issues Encountered

- Diagnosing the masked `sosHubClientProvider`/Supabase-initialization failure (deviation 1) took the bulk of Task 1's debugging time: the symptom (a connectivity-hint test silently not firing) had no stack trace until the initial `AsyncError` state was explicitly inspected, since `build()`'s partial failure never surfaced through any assertion the earlier tests happened to make.
- `flutter test <directory>` (e.g. `flutter test test/features/sos`) intermittently omitted two of the five files in that directory from its run in this environment without any error; explicit per-file invocation (`flutter test test/features/sos/a.dart test/features/sos/b.dart ...`) was used throughout instead and is reliable. Not a code defect — flagged here in case a future plan hits the same directory-glob quirk.
- `mobile/test/shared_widgets/member_map_pin_semantics_test.dart`'s two pre-existing `SemanticsHandle`-teardown failures (first logged in `03-02-SUMMARY.md`, reconfirmed in `03-04-SUMMARY.md`) are still present and still untouched by this plan's files — confirmed out of scope, not re-fixed here.

## Known Stubs

None. Both local fallback actions (call, copy-location) and the emergency-contacts screen are fully wired to real data sources — no hardcoded/empty placeholders.

## Threat Flags

None beyond what `03-07-PLAN.md`'s own `<threat_model>` already registers (T-03-10, T-03-25, T-03-20, T-03-26, T-03-02) — no new network endpoint, auth path, or trust-boundary surface was introduced beyond that register. `EmergencyContactsScreen` calls only the already-threat-modeled `/me/emergency-contacts` endpoints from 03-05.

## User Setup Required

None - no external service configuration required this plan.

## Next Phase Readiness

- 03-08 (live-location streaming window) and 03-09 (hold-to-cancel + canceled chrome) can both build on `ConnectivityService`/`connectivityServiceProvider` and the now-complete `SosOfflineQueued` rendering without touching this plan's files again.
- The manual airplane-mode/two-device smoke verification (D4 above) was not performed in this execution environment — flagged as human-judgment coverage, matching this plan's own explicitly-called-out manual step.
- `.planning/phases/03-sos-fast-path/.continue-here.md`'s advisory note (SOS-02/SOS-03 marked complete in REQUIREMENTS.md ahead of full delivery via 03-01/03-03's frontmatter) is unchanged by this plan — this SUMMARY does not itself mark either requirement as newly/finally verified beyond the standard plan-completion requirements-tracking step.
- No blockers identified. 03-06 (FCM push) remains intentionally paused mid-Task-3 on a human-owned Firebase/APNs checkpoint, untouched by this plan.

---
*Phase: 03-sos-fast-path*
*Completed: 2026-08-02*
